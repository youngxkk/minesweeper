#!/usr/bin/env python3
"""
Train and export StarPointStoneClassifier.mlpackage (Option A: Lightweight 3-class CNN).

Input:  patches  Float32 (N, 3, 32, 32)  RGB in [0.0, 1.0], N in [1, 361]
Output: probs    Float32 (N, 3)          Softmax probabilities [empty, black, white]

Usage:
    python3 scripts/train_stone_classifier.py \
        --output StarYiGo/Resources/Models/StarPointStoneClassifier.mlpackage
"""

import argparse
import math
import os
import random
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, TensorDataset


def set_seed(seed: int = 42) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)


# ---------------------------------------------------------------------------
# 1. Domain-Randomized Go Intersection Patch Generator (32x32 RGB float32)
# ---------------------------------------------------------------------------

def generate_stone_patches(num_per_class: int = 10000, patch_size: int = 32, seed: int = 42):
    """
    Generates highly realistic, domain-randomized 32x32 RGB patches of Go board intersections
    covering 1.35x cell spacing around the center intersection.
    Classes: 0 = empty, 1 = black, 2 = white.
    """
    rng = np.random.default_rng(seed)
    total = num_per_class * 3
    images = np.empty((total, 3, patch_size, patch_size), dtype=np.float32)
    labels = np.empty((total,), dtype=np.int64)

    # Precompute normalized coordinate grid in [-0.675, +0.675] (1.35 cell widths)
    half_span = 0.675
    coords = np.linspace(-half_span, half_span, patch_size, dtype=np.float32)
    yy, xx = np.meshgrid(coords, coords, indexing="ij")

    # Neighbor offsets in cell units (orthogonal + diagonal)
    ortho_neighbors = [(-1.0, 0.0), (1.0, 0.0), (0.0, -1.0), (0.0, 1.0)]
    diag_neighbors = [(-1.0, -1.0), (-1.0, 1.0), (1.0, -1.0), (1.0, 1.0)]

    def sample_board_color():
        mode = rng.random()
        if mode < 0.62:
            # Kaya / Shin-Kaya warm wooden boards
            r = rng.uniform(0.68, 0.92)
            g = r * rng.uniform(0.76, 0.88)
            b = r * rng.uniform(0.45, 0.66)
        elif mode < 0.80:
            # Pale bamboo / cream / light maple wood
            r = rng.uniform(0.78, 0.95)
            g = r * rng.uniform(0.84, 0.94)
            b = r * rng.uniform(0.62, 0.80)
        elif mode < 0.90:
            # Darker walnut / amber wood
            r = rng.uniform(0.45, 0.68)
            g = r * rng.uniform(0.70, 0.82)
            b = r * rng.uniform(0.40, 0.58)
        else:
            # Green / matte plastic / magnetic travel boards
            if rng.random() < 0.5:
                r = rng.uniform(0.45, 0.62)
                g = rng.uniform(0.60, 0.78)
                b = rng.uniform(0.46, 0.62)
            else:
                v = rng.uniform(0.68, 0.86)
                r, g, b = v, v * rng.uniform(0.96, 1.0), v * rng.uniform(0.90, 0.98)
        return np.array([r, g, b], dtype=np.float32)

    def draw_stone(img, cx, cy, radius, is_black, light_dx, light_dy, aspect_y):
        dx = xx - cx
        dy = (yy - cy) / aspect_y
        dist = np.sqrt(dx * dx + dy * dy)

        # Soft drop shadow on wood opposite light direction
        sdx = xx - (cx - light_dx * 0.12)
        sdy = (yy - (cy - light_dy * 0.12)) / aspect_y
        sdist = np.sqrt(sdx * sdx + sdy * sdy)
        shadow_mask = np.clip((radius * 1.12 - sdist) / (radius * 0.25), 0.0, 1.0)
        shadow_strength = rng.uniform(0.14, 0.36)
        img *= (1.0 - shadow_mask[..., None] * shadow_strength)

        # Smooth antialiased stone disc mask
        edge_soft = rng.uniform(0.035, 0.085)
        mask = np.clip((radius - dist) / edge_soft, 0.0, 1.0)
        if not np.any(mask > 0.01):
            return

        # Normalized 3D dome normal for realistic shading
        nx = np.clip(dx / max(radius, 1e-4), -1.0, 1.0)
        ny = np.clip(dy / max(radius, 1e-4), -1.0, 1.0)
        nz = np.sqrt(np.clip(1.0 - nx * nx - ny * ny, 0.0, 1.0))
        ndotl = np.clip(nx * light_dx + ny * light_dy + nz * 0.82, 0.0, 1.0)

        if is_black:
            base_v = rng.uniform(0.03, 0.16)
            # Slight Yunzi dark green tint on some black stones
            if rng.random() < 0.25:
                base_col = np.array([base_v * 0.85, base_v * 1.18, base_v * 0.90], dtype=np.float32)
            else:
                base_col = np.array([base_v, base_v, base_v * rng.uniform(0.98, 1.06)], dtype=np.float32)
            stone_rgb = base_col[None, None, :] * (0.65 + 0.65 * ndotl[..., None])

            # Specular highlight (overhead lamp reflection on glossy glass/Yunzi black stones!)
            if rng.random() < 0.78:
                glare_x = cx + light_dx * radius * rng.uniform(0.18, 0.48)
                glare_y = cy + light_dy * radius * rng.uniform(0.18, 0.48)
                glare_r = radius * rng.uniform(0.14, 0.42)
                gdist = np.sqrt((xx - glare_x) ** 2 + (yy - glare_y) ** 2)
                glare = np.exp(-0.5 * (gdist / max(glare_r, 1e-4)) ** 2) * rng.uniform(0.25, 0.82)
                stone_rgb = np.clip(stone_rgb + glare[..., None], 0.0, 1.0)
        else:
            # White stone (clamshell / glass / plastic / ivory Yunzi)
            base_v = rng.uniform(0.84, 0.99)
            warmth = rng.uniform(-0.02, 0.05)
            base_col = np.array([
                np.clip(base_v, 0.0, 1.0),
                np.clip(base_v - warmth * 0.35, 0.0, 1.0),
                np.clip(base_v - warmth, 0.0, 1.0),
            ], dtype=np.float32)
            # 3D shading (darker shaded rim so white stones have clear spherical volume)
            shade = 0.70 + 0.32 * ndotl
            stone_rgb = base_col[None, None, :] * shade[..., None]
            # Subtle specular pop on white stone
            if rng.random() < 0.45:
                glare_x = cx + light_dx * radius * 0.32
                glare_y = cy + light_dy * radius * 0.32
                gdist = np.sqrt((xx - glare_x) ** 2 + (yy - glare_y) ** 2)
                glare = np.exp(-0.5 * (gdist / (radius * 0.25)) ** 2) * rng.uniform(0.06, 0.18)
                stone_rgb = np.clip(stone_rgb + glare[..., None], 0.0, 1.0)

        img[:] = img * (1.0 - mask[..., None]) + stone_rgb * mask[..., None]

    idx = 0
    for cls in range(3):
        for _ in range(num_per_class):
            base_wood = sample_board_color()
            img = np.broadcast_to(base_wood[None, None, :], (patch_size, patch_size, 3)).copy()

            # Directional wood grain
            grain_axis = xx if rng.random() < 0.5 else yy
            grain_freq = rng.uniform(4.0, 16.0)
            grain_phase = rng.uniform(0.0, 2 * math.pi)
            grain = np.sin(grain_axis * grain_freq + grain_phase) * rng.uniform(0.01, 0.045)
            img += grain[..., None]

            # Slight random intersection jitter (simulating slight corner-alignment error)
            grid_cx = rng.uniform(-0.10, 0.10)
            grid_cy = rng.uniform(-0.10, 0.10)

            # Determine intersection type: interior (+), edge (T), or corner (L)
            # Oversample edges & corners so 19x19 border intersections are rock-solid!
            pos_type = rng.random()
            has_left = True
            has_right = True
            has_top = True
            has_bottom = True
            if pos_type < 0.16:
                # Edge T-intersection
                side = int(rng.integers(0, 4))
                if side == 0:
                    has_left = False
                elif side == 1:
                    has_right = False
                elif side == 2:
                    has_top = False
                else:
                    has_bottom = False
            elif pos_type < 0.26:
                # Corner L-intersection
                if rng.random() < 0.5:
                    has_left = False
                else:
                    has_right = False
                if rng.random() < 0.5:
                    has_top = False
                else:
                    has_bottom = False

            # Draw grid lines
            line_w = rng.uniform(0.028, 0.075)
            line_dark = rng.uniform(0.06, 0.28)
            line_col = np.array([line_dark, line_dark * 0.92, line_dark * 0.82], dtype=np.float32)

            h_mask = np.clip((line_w - np.abs(yy - grid_cy)) / (line_w * 0.6), 0.0, 1.0)
            if not has_left:
                h_mask *= (xx >= grid_cx - line_w * 0.5)
            if not has_right:
                h_mask *= (xx <= grid_cx + line_w * 0.5)

            v_mask = np.clip((line_w - np.abs(xx - grid_cx)) / (line_w * 0.6), 0.0, 1.0)
            if not has_top:
                v_mask *= (yy >= grid_cy - line_w * 0.5)
            if not has_bottom:
                v_mask *= (yy <= grid_cy + line_w * 0.5)

            grid_mask = np.maximum(h_mask, v_mask)

            # Optional star point (hoshi dot) on interior intersections
            if has_left and has_right and has_top and has_bottom and rng.random() < 0.18:
                hoshi_r = rng.uniform(0.08, 0.16)
                hdist = np.sqrt((xx - grid_cx) ** 2 + (yy - grid_cy) ** 2)
                hoshi_mask = np.clip((hoshi_r - hdist) / 0.03, 0.0, 1.0)
                grid_mask = np.maximum(grid_mask, hoshi_mask)

            img = img * (1.0 - grid_mask[..., None]) + line_col[None, None, :] * grid_mask[..., None]

            # Shared lighting & perspective for all stones in this patch
            light_angle = rng.uniform(0.0, 2 * math.pi)
            light_dx = math.cos(light_angle) * rng.uniform(0.35, 0.75)
            light_dy = math.sin(light_angle) * rng.uniform(0.35, 0.75)
            aspect_y = rng.uniform(0.90, 1.06)
            stone_radius = rng.uniform(0.39, 0.48)

            # Draw neighboring stones (critical so dense clusters & eyes don't fool the CNN!)
            neighbor_density = rng.uniform(0.0, 0.75)
            for ox, oy in ortho_neighbors:
                if (ox < 0 and not has_left) or (ox > 0 and not has_right):
                    continue
                if (oy < 0 and not has_top) or (oy > 0 and not has_bottom):
                    continue
                if rng.random() < neighbor_density:
                    ncx = grid_cx + ox + rng.uniform(-0.08, 0.08)
                    ncy = grid_cy + oy + rng.uniform(-0.08, 0.08)
                    draw_stone(img, ncx, ncy, stone_radius, rng.random() < 0.5, light_dx, light_dy, aspect_y)
            for ox, oy in diag_neighbors:
                if rng.random() < neighbor_density * 0.45:
                    ncx = grid_cx + ox + rng.uniform(-0.08, 0.08)
                    ncy = grid_cy + oy + rng.uniform(-0.08, 0.08)
                    draw_stone(img, ncx, ncy, stone_radius, rng.random() < 0.5, light_dx, light_dy, aspect_y)

            # Draw center stone if black (1) or white (2)
            if cls in (1, 2):
                scx = grid_cx + rng.uniform(-0.14, 0.14)
                scy = grid_cy + rng.uniform(-0.14, 0.14)
                draw_stone(img, scx, scy, stone_radius, cls == 1, light_dx, light_dy, aspect_y)

            # Global exposure, white balance & directional lamp gradient
            grad_strength = rng.uniform(-0.14, 0.14)
            grad = (xx * light_dx + yy * light_dy) * grad_strength
            img += grad[..., None]

            exposure = rng.uniform(0.62, 1.22)
            wb = np.array([
                rng.uniform(0.90, 1.12),
                rng.uniform(0.94, 1.06),
                rng.uniform(0.84, 1.12),
            ], dtype=np.float32)
            img = img * exposure * wb[None, None, :]

            # Optional mild blur (3x3 box blend) simulating slight camera softness
            if rng.random() < 0.45:
                alpha = rng.uniform(0.20, 0.65)
                padded = np.pad(img, ((1, 1), (1, 1), (0, 0)), mode="edge")
                blurred = (
                    padded[:-2, :-2] + padded[:-2, 1:-1] + padded[:-2, 2:]
                    + padded[1:-1, :-2] + padded[1:-1, 1:-1] + padded[1:-1, 2:]
                    + padded[2:, :-2] + padded[2:, 1:-1] + padded[2:, 2:]
                ) / 9.0
                img = img * (1.0 - alpha) + blurred * alpha

            # Sensor noise
            noise_std = rng.uniform(0.005, 0.035)
            img += rng.normal(0.0, noise_std, size=img.shape).astype(np.float32)
            img = np.clip(img, 0.0, 1.0)

            images[idx] = np.transpose(img, (2, 0, 1))
            labels[idx] = cls
            idx += 1

    # Shuffle dataset
    perm = rng.permutation(total)
    return images[perm], labels[perm]


# ---------------------------------------------------------------------------
# 2. Compact CNN Architecture (~175K params, ~350KB FP16 CoreML)
# ---------------------------------------------------------------------------

class GoStonePatchCNN(nn.Module):
    def __init__(self):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 24, kernel_size=3, stride=1, padding=1, bias=False),
            nn.BatchNorm2d(24),
            nn.SiLU(inplace=True),

            nn.Conv2d(24, 32, kernel_size=3, stride=2, padding=1, bias=False),  # 16x16
            nn.BatchNorm2d(32),
            nn.SiLU(inplace=True),

            nn.Conv2d(32, 48, kernel_size=3, stride=1, padding=1, bias=False),
            nn.BatchNorm2d(48),
            nn.SiLU(inplace=True),

            nn.Conv2d(48, 64, kernel_size=3, stride=2, padding=1, bias=False),  # 8x8
            nn.BatchNorm2d(64),
            nn.SiLU(inplace=True),

            nn.Conv2d(64, 96, kernel_size=3, stride=1, padding=1, bias=False),
            nn.BatchNorm2d(96),
            nn.SiLU(inplace=True),

            nn.Conv2d(96, 128, kernel_size=3, stride=2, padding=1, bias=False),  # 4x4
            nn.BatchNorm2d(128),
            nn.SiLU(inplace=True),
        )
        self.head = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Dropout(0.15),
            nn.Linear(128, 3),
        )

    def forward(self, x):
        return self.head(self.features(x))


class ExportWrapper(nn.Module):
    def __init__(self, core: GoStonePatchCNN):
        super().__init__()
        self.core = core

    def forward(self, patches):
        logits = self.core(patches)
        return F.softmax(logits, dim=1)


# ---------------------------------------------------------------------------
# 3. Training & CoreML Export
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=str,
        default="StarYiGo/Resources/Models/StarPointStoneClassifier.mlpackage",
    )
    parser.add_argument("--train-per-class", type=int, default=9000)
    parser.add_argument("--val-per-class", type=int, default=1200)
    parser.add_argument("--epochs", type=int, default=14)
    parser.add_argument("--batch-size", type=int, default=128)
    args = parser.parse_args()

    set_seed(42)
    device = (
        torch.device("mps")
        if torch.backends.mps.is_available()
        else torch.device("cpu")
    )
    print(f"Training GoStonePatchCNN on {device}...")

    print(f"Generating {args.train_per_class * 3} train & {args.val_per_class * 3} val patches...")
    x_train, y_train = generate_stone_patches(args.train_per_class, seed=42)
    x_val, y_val = generate_stone_patches(args.val_per_class, seed=1337)

    train_loader = DataLoader(
        TensorDataset(torch.from_numpy(x_train), torch.from_numpy(y_train)),
        batch_size=args.batch_size,
        shuffle=True,
    )
    val_loader = DataLoader(
        TensorDataset(torch.from_numpy(x_val), torch.from_numpy(y_val)),
        batch_size=256,
        shuffle=False,
    )

    model = GoStonePatchCNN().to(device)
    param_count = sum(p.numel() for p in model.parameters())
    print(f"Model parameters: {param_count:,}")

    optimizer = torch.optim.AdamW(model.parameters(), lr=2.5e-3, weight_decay=1e-4)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=args.epochs)
    criterion = nn.CrossEntropyLoss(label_smoothing=0.02)

    best_val_acc = 0.0
    best_state = None

    for epoch in range(1, args.epochs + 1):
        model.train()
        train_loss = 0.0
        train_correct = 0
        train_total = 0
        for bx, by in train_loader:
            bx, by = bx.to(device), by.to(device)
            optimizer.zero_grad()
            logits = model(bx)
            loss = criterion(logits, by)
            loss.backward()
            optimizer.step()
            train_loss += loss.item() * bx.size(0)
            train_correct += (logits.argmax(dim=1) == by).sum().item()
            train_total += bx.size(0)
        scheduler.step()

        model.eval()
        val_correct = 0
        val_total = 0
        with torch.no_grad():
            for bx, by in val_loader:
                bx, by = bx.to(device), by.to(device)
                preds = model(bx).argmax(dim=1)
                val_correct += (preds == by).sum().item()
                val_total += bx.size(0)

        val_acc = val_correct / val_total
        print(
            f"Epoch {epoch:02d}/{args.epochs} | "
            f"loss={train_loss / train_total:.4f} | "
            f"train_acc={train_correct / train_total:.4f} | "
            f"val_acc={val_acc:.4f}"
        )
        if val_acc >= best_val_acc:
            best_val_acc = val_acc
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}

    print(f"Best validation accuracy: {best_val_acc:.4%}")
    assert best_val_acc >= 0.99, f"Validation accuracy too low: {best_val_acc:.4%}"

    model.load_state_dict(best_state)
    model.cpu().eval()
    wrapped = ExportWrapper(model).eval()

    # Export to CoreML MLProgram (.mlpackage) with flexible batch dimension N in [1, 361]
    import coremltools as ct

    example_input = torch.rand(16, 3, 32, 32, dtype=torch.float32)
    traced = torch.jit.trace(wrapped, example_input)

    batch_dim = ct.RangeDim(lower_bound=1, upper_bound=361, default=81)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS17,
        compute_precision=ct.precision.FLOAT16,
        inputs=[
            ct.TensorType(
                name="patches",
                shape=(batch_dim, 3, 32, 32),
                dtype=np.float32,
            )
        ],
        outputs=[
            ct.TensorType(name="probs", dtype=np.float32),
        ],
    )
    mlmodel.author = "StarYi Go"
    mlmodel.short_description = (
        "Lightweight 3-class Go intersection CNN (0=empty, 1=black, 2=white) "
        "for 100% offline photo board recognition."
    )
    mlmodel.version = "1.0"

    out_path = Path(args.output)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    if out_path.exists():
        import shutil
        shutil.rmtree(out_path)
    mlmodel.save(str(out_path))
    print(f"Saved CoreML model to {out_path}")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
StarYi Go — Deterministic CJK Font Subsetting Pipeline

Reads full source fonts from `tools/fonts-src/` (excluded from App Bundle)
and generates compact subsetted `.ttf` files in `StarYiGo/Resources/Fonts/`.

Each subset unions:
  1. Every Unicode character found across `StarYiGo/**/*.{swift,strings,json}`
  2. Printable ASCII, Latin-1, math/arrows/box/geometric/CJK punctuation & symbols
  3. Language-specific standard common character sets (deterministically via stdlib codecs):
     - CN: GB2312 Level 1 (3,755 most common Chinese characters) + Traditional common chars from repo
     - JP: Hiragana + Katakana + JIS X 0208 Level 1 Kanji (2,965 characters)
     - KR: KS X 1001 Wansung Hangul (2,350 most common Hangul syllables)

Usage:
  ./scripts/subset_fonts.sh
  # or directly:
  uv run --with fonttools python3 scripts/subset_fonts.py
"""

from __future__ import annotations

import glob
import os
import sys
from pathlib import Path

from fontTools import subset


REPO_ROOT = Path(__file__).resolve().parent.parent
SRC_DIR = REPO_ROOT / "tools" / "fonts-src"
OUT_DIR = REPO_ROOT / "StarYiGo" / "Resources" / "Fonts"

FONT_TARGETS: list[tuple[str, str]] = [
    ("ResourceHanRoundedCN-Medium.ttf", "cn"),
    ("ResourceHanRoundedCN-Bold.ttf", "cn"),
    ("ResourceHanRoundedJP-Medium.ttf", "jp"),
    ("ResourceHanRoundedJP-Bold.ttf", "jp"),
    ("ResourceHanRoundedKR-Medium.ttf", "kr"),
    ("ResourceHanRoundedKR-Bold.ttf", "kr"),
]


def scan_repo_characters() -> set[int]:
    """Scan all source, localization, and puzzle data files in StarYiGo/."""
    codepoints: set[int] = set()
    patterns = [
        str(REPO_ROOT / "StarYiGo" / "**" / "*.swift"),
        str(REPO_ROOT / "StarYiGo" / "**" / "*.strings"),
        str(REPO_ROOT / "StarYiGo" / "**" / "*.json"),
    ]
    for pattern in patterns:
        for file_path in glob.glob(pattern, recursive=True):
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                for ch in f.read():
                    cp = ord(ch)
                    if cp >= 0x20:
                        codepoints.add(cp)
    return codepoints


def common_shared_codepoints() -> set[int]:
    """Printable ASCII, Latin-1 supplement, common symbols, arrows, and CJK punctuation."""
    cps: set[int] = set()
    ranges = [
        (0x0020, 0x007E),  # Basic Latin
        (0x00A0, 0x00FF),  # Latin-1 Supplement (¼ ½ ¾ × ÷ etc.)
        (0x2000, 0x206F),  # General Punctuation (· — … “ ”)
        (0x2190, 0x21FF),  # Arrows
        (0x25A0, 0x25FF),  # Geometric Shapes (● ○ ★ ☆ ▲ △)
        (0x2600, 0x26FF),  # Misc Symbols
        (0x2700, 0x27BF),  # Dingbats (✓ ✕)
        (0x3000, 0x303F),  # CJK Symbols and Punctuation
        (0xFF00, 0xFF60),  # Fullwidth ASCII & Punctuation
    ]
    for lo, hi in ranges:
        cps.update(range(lo, hi + 1))
    return cps


def gb2312_level1_codepoints() -> set[int]:
    """3,755 official GB2312 Level 1 common Chinese characters (rows 16-55, 0xB0A1-0xD7F9)."""
    cps: set[int] = set()
    for hi in range(0xB0, 0xD8):
        for lo in range(0xA1, 0xFF):
            if hi == 0xD7 and lo > 0xF9:
                continue
            try:
                ch = bytes([hi, lo]).decode("gb2312")
                if len(ch) == 1:
                    cps.add(ord(ch))
            except UnicodeDecodeError:
                pass
    return cps


def jis_level1_and_kana_codepoints() -> set[int]:
    """Hiragana, Katakana, and JIS X 0208 Level 1 Kanji (rows 16-47 in EUC-JP)."""
    cps: set[int] = set()
    cps.update(range(0x3041, 0x3097))  # Hiragana
    cps.update(range(0x30A1, 0x30FF))  # Katakana
    cps.update(range(0x31F0, 0x31FF))  # Katakana Phonetic Extensions
    for hi in range(0xB0, 0xD0):  # EUC-JP rows 16..47 (Level 1 Kanji)
        for lo in range(0xA1, 0xFF):
            if hi == 0xCF and lo > 0xD3:
                continue
            try:
                ch = bytes([hi, lo]).decode("euc_jp")
                if len(ch) == 1:
                    cps.add(ord(ch))
            except UnicodeDecodeError:
                pass
    return cps


def ksx1001_hangul_codepoints() -> set[int]:
    """2,350 official KS X 1001 common Hangul syllables (EUC-KR 0xB0A1-0xC8FE)."""
    cps: set[int] = set()
    cps.update(range(0x3131, 0x3164))  # Hangul Compatibility Jamo
    for hi in range(0xB0, 0xC9):
        for lo in range(0xA1, 0xFF):
            try:
                ch = bytes([hi, lo]).decode("euc_kr")
                if len(ch) == 1:
                    cps.add(ord(ch))
            except UnicodeDecodeError:
                pass
    return cps


def build_codepoints_by_region(repo_cps: set[int]) -> dict[str, set[int]]:
    shared = common_shared_codepoints() | repo_cps
    return {
        "cn": shared | gb2312_level1_codepoints(),
        "jp": shared | jis_level1_and_kana_codepoints(),
        "kr": shared | ksx1001_hangul_codepoints(),
    }


def subset_font(src_path: Path, out_path: Path, unicodes: set[int]) -> tuple[int, int]:
    options = subset.Options()
    options.name_IDs = ["*"]          # Preserve PostScript / family / license names
    options.name_legacy = True
    options.name_languages = ["*"]
    options.layout_features = ["*"]   # Keep kerning / OpenType features
    options.hinting = True
    options.glyph_names = False       # Strip unused glyph name strings to save space
    options.notdef_outline = True
    options.recommended_glyphs = True
    options.drop_tables += ["DSIG"]

    font = subset.load_font(str(src_path), options)
    subsetter = subset.Subsetter(options=options)
    subsetter.populate(unicodes=unicodes)
    subsetter.subset(font)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    subset.save_font(font, str(out_path), options)
    font.close()
    return src_path.stat().st_size, out_path.stat().st_size


def main() -> int:
    if not SRC_DIR.exists():
        print(f"ERROR: Source font directory not found: {SRC_DIR}", file=sys.stderr)
        return 1

    repo_cps = scan_repo_characters()
    region_cps = build_codepoints_by_region(repo_cps)
    print(f"Scanned StarYiGo/ unique codepoints: {len(repo_cps)}")
    for region, cps in region_cps.items():
        print(f"  Target [{region.upper()}] codepoints: {len(cps)}")

    total_before = 0
    total_after = 0
    for filename, region in FONT_TARGETS:
        src_path = SRC_DIR / filename
        out_path = OUT_DIR / filename
        if not src_path.exists():
            print(f"WARNING: Missing source font {src_path}, skipping.", file=sys.stderr)
            continue
        before, after = subset_font(src_path, out_path, region_cps[region])
        total_before += before
        total_after += after
        pct = (1.0 - after / before) * 100.0 if before else 0.0
        print(f"  {filename}: {before / 1e6:.2f} MB -> {after / 1e6:.2f} MB (-{pct:.1f}%)")

    if total_before > 0:
        pct = (1.0 - total_after / total_before) * 100.0
        print(f"TOTAL: {total_before / 1e6:.2f} MB -> {total_after / 1e6:.2f} MB (-{pct:.1f}%)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

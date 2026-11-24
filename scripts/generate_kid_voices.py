#!/usr/bin/env python3
"""
Generate Nintendo-style Chinese kid voice encouragement clips for StarYi Go
using local Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit (MLX Audio).

Outputs compact AAC (.m4a) files into StarYiGo/Resources/Voice/zh/.
"""

import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

MODEL_DIR = Path("/Users/max/code/Qwen3-TTS/models/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit")
OUT_DIR = Path("/Users/max/code/minesweeper/StarYiGo/Resources/Voice/zh")

BASE_PERSONA = (
    "活泼可爱的7岁中国小女孩童声，声音清脆甜美、软萌有元气，"
    "像任天堂儿童游戏里的小精灵伙伴一样充满活力，咬字清晰干脆，语速轻快不拖沓。"
)

CLIPS: list[tuple[str, str, str]] = [
    # 1. 答对了 (5 variants)
    ("voice_zh_correct_1", "答对啦！", "开心雀跃地欢呼表扬，短促有力，结尾微微上扬。"),
    ("voice_zh_correct_2", "太棒啦！", "充满惊喜和赞叹地夸奖，活泼响亮。"),
    ("voice_zh_correct_3", "哇，真聪明！", "像发现宝藏一样惊喜地夸奖小朋友，甜美欢快。"),
    ("voice_zh_correct_4", "好厉害！", "元气满满地竖大拇指夸奖，清脆干脆。"),
    ("voice_zh_correct_5", "漂亮！", "短促利落地喝彩，像下出妙手时的欢呼。"),

    # 2. 答错了 (4 variants — warm, gentle, never discouraging)
    ("voice_zh_wrong_1", "哎呀，再想想哦！", "俏皮温柔地提醒，带着一点可爱的惊讶和鼓励，完全不严厉。"),
    ("voice_zh_wrong_2", "差一点点，再试一次！", "温暖轻快地加油打气，声音柔和亲切。"),
    ("voice_zh_wrong_3", "嗯？换个地方试试吧！", "好奇又温柔地启发小朋友，带着微笑的语气。"),
    ("voice_zh_wrong_4", "没关系，仔细看看哦！", "暖心安慰并轻轻鼓励，亲切软萌。"),

    # 3. 连对 Combo (4 variants)
    ("voice_zh_combo3_1", "哇，三连击！", "像任天堂游戏触发连击一样兴奋欢呼，活力四射。"),
    ("voice_zh_combo3_2", "连对三题啦，好厉害！", "开心地为连胜喝彩，语速轻快有节奏感。"),
    ("voice_zh_combo5_1", "五连胜，势不可挡！", "超级激动、自豪地大声欢呼，充满燃感。"),
    ("voice_zh_combo5_2", "哇，你也太厉害了吧！", "崇拜又惊喜地大声夸奖，元气爆棚。"),

    # 4. 提示 Hint (2 variants)
    ("voice_zh_hint_1", "看看这里哦！", "像小伙伴悄悄指路一样，神秘又俏皮地轻声提醒。"),
    ("voice_zh_hint_2", "给你一个小提示！", "调皮又热心地帮忙，清脆可爱。"),

    # 5. 打劫反弹 / 禁着点 (2 variants)
    ("voice_zh_illegal_1", "这里不能下哦！", "俏皮可爱地轻轻阻止，像游戏里撞到小弹簧一样。"),
    ("voice_zh_illegal_2", "哎呀，不能下这里呀！", "软萌地提醒规则，不严厉，带一点童趣。"),

    # 6. 实战对弈高光 (7 variants)
    ("voice_zh_atari_1", "打吃！", "清脆响亮、短促有精神地喊出围棋术语。"),
    ("voice_zh_atari_2", "小心哦，叫吃啦！", "俏皮又带一点小紧张地提醒，清脆生动。"),
    ("voice_zh_capture_small_1", "吃掉啦！", "开心调皮地欢呼，短促明快。"),
    ("voice_zh_capture_small_2", "哈哈，抓到啦！", "带着一点小得意的童真笑意，轻快可爱。"),
    ("voice_zh_capture_big_1", "哇，吃掉一大片！", "超级惊喜地张大眼睛欢呼，非常有成就感。"),
    ("voice_zh_capture_big_2", "好厉害的大吃子！", "激动地拍手称赞，活力满满。"),
    ("voice_zh_rewind_1", "时光倒流！", "充满魔法感和童趣地念出，声音轻盈灵动。"),

    # 7. 胜利 / 通关 / Boss / 安慰 (7 variants)
    ("voice_zh_victory_1", "耶！你赢啦！", "超级开心跳起来欢呼，像任天堂过关结算一样有感染力。"),
    ("voice_zh_victory_2", "太棒啦，过关成功！", "欢快热烈地祝贺通关，甜美响亮。"),
    ("voice_zh_victory_3", "好厉害，全部通关啦！", "激动自豪地大声表扬，充满仪式感。"),
    ("voice_zh_boss_victory_1", "哇！打败守关大师啦！", "无比惊喜和崇拜地欢呼，庆祝赢得大胜利。"),
    ("voice_zh_boss_victory_2", "太强啦，守关挑战大成功！", "热血又可爱地大声祝贺，元气十足。"),
    ("voice_zh_encourage_1", "下得很棒啦，我们再来一局！", "温柔暖心地安慰并热情邀请再来一局，充满正能量。"),
    ("voice_zh_encourage_2", "没关系，下次一定能赢！", "亲切温柔地给小朋友打气，甜美鼓励。"),

    # 8. 考试 / 晋级 (2 variants)
    ("voice_zh_exam_pass_1", "恭喜晋级，你真棒！", "隆重又欢快地祝贺升段晋级，充满喜悦。"),
    ("voice_zh_exam_pass_2", "太厉害了，挑战成功！", "响亮开心地宣布挑战成功，节奏明快。"),

    # 9. 探索 / 收集 / 商店 / 拍照数子 / 欢迎 (7 variants)
    ("voice_zh_codex_1", "解锁新招式啦！", "像打开宝箱发现新技能一样兴奋清脆。"),
    ("voice_zh_shop_unlock_1", "哇，换新装啦！", "惊喜又开心地赞叹新皮肤，甜美可爱。"),
    ("voice_zh_no_coins_1", "星币还差一点点，去做题赚星币吧！", "俏皮温柔地鼓励去做题赚星币，语气轻快。"),
    ("voice_zh_locked_1", "先通过前面的关卡哦！", "友好可爱地提醒，软萌清晰。"),
    ("voice_zh_photo_done_1", "数好啦，快来看看结果吧！", "欢快利落地报喜，像小助手完成任务一样。"),
    ("voice_zh_welcome_1", "你好呀，一起下围棋吧！", "热情甜美地打招呼，像好朋友一样亲切有元气。"),
    ("voice_zh_welcome_2", "准备好了吗？出发吧！", "充满冒险精神地号召出发，像马里奥开场一样轻快。"),
]


def trim_and_normalize(samples: np.ndarray, sr: int = 24000) -> np.ndarray:
    """Trim leading/trailing silence, normalize peak to -1.5 dBFS, add smooth micro-fades."""
    if samples.size == 0:
        return samples
    # Remove DC offset
    samples = samples - np.mean(samples)
    peak = float(np.max(np.abs(samples)))
    if peak < 1e-5:
        return samples

    # Threshold at -36 dB relative to peak
    thresh = peak * 0.016
    above = np.flatnonzero(np.abs(samples) > thresh)
    if above.size > 0:
        lead = int(0.020 * sr)   # 20ms crisp attack lead
        tail = int(0.075 * sr)   # 75ms natural tail
        start = max(0, int(above[0]) - lead)
        end = min(samples.size, int(above[-1]) + tail)
        samples = samples[start:end]

    # Normalize peak to 0.84 (-1.5 dBFS)
    peak = float(np.max(np.abs(samples)))
    if peak > 1e-5:
        samples = samples * (0.84 / peak)

    # 8ms fade-in and 18ms fade-out to eliminate any edge clicks
    fade_in = min(int(0.008 * sr), samples.size // 4)
    fade_out = min(int(0.018 * sr), samples.size // 4)
    if fade_in > 1:
        samples[:fade_in] *= np.linspace(0.0, 1.0, fade_in, dtype=np.float32)
    if fade_out > 1:
        samples[-fade_out:] *= np.linspace(1.0, 0.0, fade_out, dtype=np.float32)

    return np.clip(samples, -0.99, 0.99)


def write_m4a(samples: np.ndarray, sr: int, dest_m4a: Path) -> None:
    """Write PCM float32 array to AAC .m4a via macOS afconvert."""
    dest_m4a.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.rint(samples * 32767.0).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=True) as tmp_wav:
        with wave.open(tmp_wav.name, "wb") as wf:
            wf.setparams((1, 2, sr, 0, "NONE", "not compressed"))
            wf.writeframes(pcm.tobytes())
        subprocess.run(
            [
                "afconvert",
                "-f", "m4af",
                "-d", "aac",
                "-b", "64000",
                tmp_wav.name,
                str(dest_m4a),
            ],
            check=True,
            capture_output=True,
        )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Regenerate existing clips")
    parser.add_argument("--only", nargs="*", help="Only generate specific clip keys")
    args = parser.parse_args()

    if not (MODEL_DIR / ".download-complete").exists():
        raise SystemExit(f"Model not ready at {MODEL_DIR}")

    from mlx_audio.tts.utils import load_model

    print(f"Loading model from {MODEL_DIR}...", flush=True)
    model = load_model(str(MODEL_DIR))
    print("Model loaded! Generating clips...", flush=True)

    selected = CLIPS
    if args.only:
        only_set = set(args.only)
        selected = [c for c in CLIPS if c[0] in only_set]

    for idx, (key, text, nuance) in enumerate(selected, 1):
        out_path = OUT_DIR / f"{key}.m4a"
        if out_path.exists() and not args.force:
            print(f"[{idx}/{len(selected)}] Skip existing: {key}", flush=True)
            continue

        instruct = f"{BASE_PERSONA}{nuance}"
        best_audio = None
        sr = 24000

        # Retry up to 3 times if duration is abnormally short (<0.25s) or too long (>3.8s)
        for attempt in range(3):
            chunks = []
            for result in model.generate_voice_design(
                text=text,
                instruct=instruct,
                language="Chinese",
                temperature=0.72,
                top_p=0.88,
            ):
                sr = result.sample_rate
                chunks.append(np.asarray(result.audio, dtype=np.float32).reshape(-1))
            if not chunks:
                continue
            raw = np.concatenate(chunks)
            trimmed = trim_and_normalize(raw, sr=sr)
            dur = trimmed.size / float(sr)
            best_audio = trimmed
            if 0.28 <= dur <= 3.6:
                break
            print(f"  Retry {key} (attempt {attempt + 1}, dur={dur:.2f}s)", flush=True)

        if best_audio is None or best_audio.size == 0:
            raise RuntimeError(f"Failed to generate audio for {key}")

        write_m4a(best_audio, sr, out_path)
        dur = best_audio.size / float(sr)
        kb = out_path.stat().st_size / 1024.0
        print(f"[{idx}/{len(selected)}] {key}.m4a — \"{text}\" ({dur:.2f}s, {kb:.1f} KB)", flush=True)

    print(f"\nAll {len(selected)} voice clips ready in {OUT_DIR}!", flush=True)


if __name__ == "__main__":
    main()

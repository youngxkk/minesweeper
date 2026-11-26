#!/usr/bin/env python3
"""
Generate Nintendo-style kid voice encouragement clips for StarYi Go
using local Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit (MLX Audio).

Supports zh, en, ja, ko voice packs.
Outputs compact AAC (.m4a) files into StarYiGo/Resources/Voice/<lang>/.
"""

import argparse
import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

MODEL_DIR = Path("/Users/max/code/Qwen3-TTS/models/Qwen3-TTS-12Hz-1.7B-VoiceDesign-8bit")
VOICE_ROOT = Path("/Users/max/code/minesweeper/StarYiGo/Resources/Voice")

LANG_CONFIG: dict[str, dict] = {
    "zh": {
        "tts_language": "Chinese",
        "base_persona": (
            "活泼可爱的7岁中国小女孩童声，声音清脆甜美、软萌有元气，"
            "像任天堂儿童游戏里的小精灵伙伴一样充满活力，咬字清晰干脆，语速轻快不拖沓。"
        ),
        "clips": [
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
        ],
    },
    "en": {
        "tts_language": "English",
        "base_persona": (
            "A cheerful, adorable 7-year-old girl's voice, bright, sweet, crisp, and full of energy, "
            "like a lively Nintendo game sidekick, with clear articulation and a brisk, upbeat pace. "
        ),
        "clips": [
            # 1. Correct (5 variants)
            ("voice_en_correct_1", "You got it!", "Cheering joyfully with a short, punchy upward lilt."),
            ("voice_en_correct_2", "Awesome!", "Full of bright excitement and enthusiastic praise."),
            ("voice_en_correct_3", "Whoa, so smart!", "Delighted and amazed, like finding a hidden treasure."),
            ("voice_en_correct_4", "Great job!", "Energetic, crisp thumbs-up praise."),
            ("voice_en_correct_5", "Nice move!", "Snappy, celebratory cheer for a brilliant move."),

            # 2. Wrong (4 variants — warm, gentle, never discouraging)
            ("voice_en_wrong_1", "Oops, not quite! Try again!", "Playful, gentle reminder with cute surprise and zero harshness."),
            ("voice_en_wrong_2", "Almost! Give it another try!", "Warm, upbeat encouragement with a soft friendly smile."),
            ("voice_en_wrong_3", "Hmm? Try another spot!", "Curious and kind, gently nudging with a cheerful tone."),
            ("voice_en_wrong_4", "It's okay, look closely!", "Warmly comforting and softly encouraging."),

            # 3. Combo (4 variants)
            ("voice_en_combo3_1", "Whoa, triple combo!", "Excited game-combo cheer bursting with energy."),
            ("voice_en_combo3_2", "Three in a row, amazing!", "Happy, rhythmic celebration of a winning streak."),
            ("voice_en_combo5_1", "Five in a row, unstoppable!", "Super thrilled and proud cheer, full of hype."),
            ("voice_en_combo5_2", "Whoa, you're incredible!", "Admiring, amazed, and overflowing with excitement."),

            # 4. Hint (2 variants)
            ("voice_en_hint_1", "Look right here!", "Playful, conspiratorial little tip like a helpful buddy."),
            ("voice_en_hint_2", "Here's a little hint!", "Cheeky, warm, and eager to help."),

            # 5. Illegal move / Ko bounce (2 variants)
            ("voice_en_illegal_1", "Can't play there!", "Cute, bouncy gentle stop like bumping a cartoon spring."),
            ("voice_en_illegal_2", "Oops, you can't go there!", "Soft, playful rule reminder with childlike charm."),

            # 6. Match highlights (7 variants)
            ("voice_en_atari_1", "Atari!", "Crisp, bright, spirited callout of the Go term."),
            ("voice_en_atari_2", "Watch out, Atari!", "Playful with a tiny dash of suspense, clear and lively."),
            ("voice_en_capture_small_1", "Nice capture!", "Happy, snappy, mischievous mini-celebration."),
            ("voice_en_capture_small_2", "Haha, got it!", "Cute playful giggle and triumphant little cheer."),
            ("voice_en_capture_big_1", "Whoa, huge capture!", "Wide-eyed amazement and huge sense of triumph."),
            ("voice_en_capture_big_2", "What a big capture!", "Clapping excitedly with bright, bubbly praise."),
            ("voice_en_rewind_1", "Turn back time!", "Magical, whimsical, and light-hearted delivery."),

            # 7. Victory / Boss / Encourage (7 variants)
            ("voice_en_victory_1", "Yay! You won!", "Jumping-for-joy cheer like a Nintendo stage-clear fanfare."),
            ("voice_en_victory_2", "Awesome, stage clear!", "Bright, festive congratulation, sweet and loud."),
            ("voice_en_victory_3", "Amazing! You cleared them all!", "Proud, celebratory cheer full of joy."),
            ("voice_en_boss_victory_1", "Whoa! You beat the Island Master!", "Overjoyed, admiring cheer for a big boss win."),
            ("voice_en_boss_victory_2", "Way to go! Master challenge cleared!", "Hyped, cute, high-energy victory celebration."),
            ("voice_en_encourage_1", "Great game! Let's play again!", "Warm, comforting praise and enthusiastic rematch invite."),
            ("voice_en_encourage_2", "It's okay, you'll win next time!", "Sweet, kind reassurance cheering the player on."),

            # 8. Exam / Rank up (2 variants)
            ("voice_en_exam_pass_1", "Rank up! You did great!", "Joyful, grand congratulation on leveling up."),
            ("voice_en_exam_pass_2", "Awesome! Challenge complete!", "Bright, snappy announcement of success."),

            # 9. Explore / Shop / Photo / Welcome (7 variants)
            ("voice_en_codex_1", "New Go move unlocked!", "Excited and crisp, like opening a treasure chest."),
            ("voice_en_shop_unlock_1", "Whoa, cool new look!", "Delighted and sweet admiration for a new style."),
            ("voice_en_no_coins_1", "Almost enough Star Coins! Solve puzzles to earn more!", "Playful, friendly encouragement to earn coins."),
            ("voice_en_locked_1", "Clear the previous stage first!", "Friendly, cute, and clear reminder."),
            ("voice_en_photo_done_1", "All counted! Let's check the score!", "Cheerful, crisp little helper announcing the result."),
            ("voice_en_welcome_1", "Hi there! Let's play Go together!", "Warm, sweet greeting like a best friend full of energy."),
            ("voice_en_welcome_2", "Ready? Let's go!", "Adventurous, bouncy call to start playing."),
        ],
    },
    "ja": {
        "tts_language": "Japanese",
        "base_persona": (
            "元気いっぱいで可愛い7歳の日本の女の子の声。透明感があって明るく愛らしい子供声で、"
            "任天堂ゲームの相棒キャラのように生き生きとしており、滑舌がよくテンポも軽快。"
        ),
        "clips": [
            # 1. 正解 (5 variants)
            ("voice_ja_correct_1", "せいかい！", "嬉しそうに弾む声で短く元気にほめる。"),
            ("voice_ja_correct_2", "すごいね！", "驚きと称賛を込めて明るく元気にほめる。"),
            ("voice_ja_correct_3", "わあ、あたまいいね！", "宝物を見つけたみたいに目を輝かせて可愛くほめる。"),
            ("voice_ja_correct_4", "やったね！", "元気いっぱいにハイタッチする感じで歯切れよく。"),
            ("voice_ja_correct_5", "ナイス！", "名手を打ったときのようにテンポよく爽やかに歓声。"),

            # 2. 不正解 (4 variants — warm, gentle, never discouraging)
            ("voice_ja_wrong_1", "おっと、もういちど考えてみて！", "お茶目で優しく、少し驚いた可愛い声で励ます。"),
            ("voice_ja_wrong_2", "おしい！もういっかい！", "温かく軽やかに応援する優しいトーン。"),
            ("voice_ja_wrong_3", "あれ？ほかのところも見てみよう！", "不思議そうに微笑みながら優しくヒントを促す。"),
            ("voice_ja_wrong_4", "だいじょうぶ、よく見てね！", "ふんわり安心させてそっと応援する可愛い声。"),

            # 3. コンボ (4 variants)
            ("voice_ja_combo3_1", "わあ、さんれんコンボ！", "ゲームのコンボが決まったみたいに大興奮で歓声。"),
            ("voice_ja_combo3_2", "三問れんぞくせいかい、すごい！", "リズムよく嬉しそうに連続正解をお祝い。"),
            ("voice_ja_combo5_1", "ごれんコンボ！だれにも止められないよ！", "めちゃくちゃワクワクして誇らしげに大きく歓声。"),
            ("voice_ja_combo5_2", "わあ、すごすぎるよ！", "キラキラ尊敬しながら元気いっぱいにほめる。"),

            # 4. ヒント (2 variants)
            ("voice_ja_hint_1", "ここを見てね！", "こっそり教えてあげる相棒のように茶目っ気たっぷりに。"),
            ("voice_ja_hint_2", "ちょっとだけヒントだよ！", "いたずらっぽく親切に、明るく可愛く。"),

            # 5. 着手禁止・コウ (2 variants)
            ("voice_ja_illegal_1", "そこには打てないよ！", "ゲームでバネに跳ね返るみたいに可愛く優しく止める。"),
            ("voice_ja_illegal_2", "おっと、ここはダメだよ！", "厳しくなく、愛らしくルールを教える。"),

            # 6. 対局ハイライト (7 variants)
            ("voice_ja_atari_1", "アタリ！", "はっきり明るく、勢いよく囲碁用語を叫ぶ。"),
            ("voice_ja_atari_2", "きをつけて、アタリだよ！", "ちょっとドキドキ感を入れて可愛く生き生きと注意。"),
            ("voice_ja_capture_small_1", "とったよ！", "嬉しそうにテンポよく元気に歓声。"),
            ("voice_ja_capture_small_2", "やった、つかまえた！", "ちょっと得意げに可愛く笑みを込めて。"),
            ("voice_ja_capture_big_1", "わあ、たくさんとった！", "目を丸くして大喜び、達成感たっぷり。"),
            ("voice_ja_capture_big_2", "すごい！ごっそり取ったね！", "拍手しながら大興奮でほめる。"),
            ("voice_ja_rewind_1", "ときをもどそう！", "魔法みたいでワクワクする軽やかな声。"),

            # 7. 勝利・ボス・励まし (7 variants)
            ("voice_ja_victory_1", "やったあ！きみの勝ちだよ！", "飛び跳ねて喜ぶみたいに最高にハッピーな歓声。"),
            ("voice_ja_victory_2", "すごい、ステージクリア！", "明るく華やかにクリアをお祝い。"),
            ("voice_ja_victory_3", "やったね、ぜんぶクリア！", "誇らしげに大きくほめて盛大にお祝い。"),
            ("voice_ja_boss_victory_1", "わあ！しまのマスターに勝ったよ！", "大驚きと尊敬いっぱいで大勝利をお祝い。"),
            ("voice_ja_boss_victory_2", "つよいね！マスター戦クリアだよ！", "熱くて可愛いテンションで元気にお祝い。"),
            ("voice_ja_encourage_1", "いい勝負だったね、もう一局やろう！", "優しく労いながら明るく次の一局へ誘う。"),
            ("voice_ja_encourage_2", "だいじょうぶ、つぎはきっと勝てるよ！", "温かく寄り添って甘く元気に励ます。"),

            # 8. 昇級試験 (2 variants)
            ("voice_ja_exam_pass_1", "昇級おめでとう、すごいね！", "華やかで嬉しそうに昇級を祝福。"),
            ("voice_ja_exam_pass_2", "やったね、チャレンジ成功！", "歯切れよく元気に成功を宣言。"),

            # 9. 図鑑・ショップ・写真数え・あいさつ (7 variants)
            ("voice_ja_codex_1", "あたらしいワザをゲット！", "宝箱を開けたみたいにワクワク弾む声。"),
            ("voice_ja_shop_unlock_1", "わあ、すてきなデザインだね！", "嬉しそうに目を輝かせて新デザインをほめる。"),
            ("voice_ja_no_coins_1", "スターコインがあとすこし！問題をといてあつめよう！", "お茶目で優しく、軽やかに応援。"),
            ("voice_ja_locked_1", "まえのステージをクリアしてね！", "フレンドリーで可愛くはっきり案内。"),
            ("voice_ja_photo_done_1", "かぞえ終わったよ、結果を見てみよう！", "小さなアシスタントが任務完了したみたいに元気に報告。"),
            ("voice_ja_welcome_1", "こんにちは！いっしょに囲碁であそぼう！", "仲良しのお友達みたいに明るく甘くごあいさつ。"),
            ("voice_ja_welcome_2", "じゅんびはいい？しゅっぱつだよ！", "冒険のはじまりみたいにワクワク元気に呼びかけ。"),
        ],
    },
    "ko": {
        "tts_language": "Korean",
        "base_persona": (
            "밝고 귀여운 7살 한국 여자아이 목소리. 맑고 또렷하며 사랑스럽고 에너지 넘치는 "
            "닌텐도 게임 친구 같은 어린아이 말투로, 발음이 정확하고 경쾌한 속도. "
        ),
        "clips": [
            # 1. 정답 (5 variants)
            ("voice_ko_correct_1", "정답이야!", "신나고 통통 튀는 목소리로 짧고 힘차게 칭찬."),
            ("voice_ko_correct_2", "최고야!", "놀라움과 감탄을 담아 밝고 시원하게 칭찬."),
            ("voice_ko_correct_3", "우와, 정말 똑똑해!", "보물을 찾은 것처럼 반짝반짝 기쁘게 칭찬."),
            ("voice_ko_correct_4", "대단해!", "엄지척하며 에너지 넘치고 또렷하게 칭찬."),
            ("voice_ko_correct_5", "멋진 수야!", "묘수를 뒀을 때처럼 경쾌하고 산뜻하게 환호."),

            # 2. 오답 (4 variants — warm, gentle, never discouraging)
            ("voice_ko_wrong_1", "어라, 다시 한번 생각해 봐!", "장난스럽고 다정하게, 귀엽게 놀라며 부드럽게 격려."),
            ("voice_ko_wrong_2", "아깝다, 한 번 더 해 보자!", "따뜻하고 경쾌하게 파이팅을 불어넣는 친근한 말투."),
            ("voice_ko_wrong_3", "음? 다른 곳을 찾아볼까?", "호기심 가득하고 미소 띤 부드러운 목소리."),
            ("voice_ko_wrong_4", "괜찮아, 천천히 살펴봐!", "포근하게 다독이며 다정하게 응원."),

            # 3. 콤보 (4 variants)
            ("voice_ko_combo3_1", "우와, 세 번 연속 정답!", "게임 콤보가 터진 것처럼 신나고 활기차게 환호."),
            ("voice_ko_combo3_2", "세 문제 연속 성공, 대단해!", "리듬감 있고 즐겁게 연속 정답을 축하."),
            ("voice_ko_combo5_1", "다섯 번 연속 정답! 아무도 못 말려!", "엄청 신나고 뿌듯하게 크게 환호."),
            ("voice_ko_combo5_2", "우와, 너 정말 대단하다!", "존경심과 놀라움 가득, 에너지 폭발하는 칭찬."),

            # 4. 힌트 (2 variants)
            ("voice_ko_hint_1", "여기를 봐 봐!", "단짝 친구가 몰래 알려주듯 귀엽고 장난스럽게."),
            ("voice_ko_hint_2", "살짝 힌트 줄게!", "상냥하고 발랄하게 도와주는 귀여운 목소리."),

            # 5. 착수 금지 / 패 (2 variants)
            ("voice_ko_illegal_1", "여기는 둘 수 없어!", "게임에서 스프링에 튕기듯 귀엽고 부드럽게 말리기."),
            ("voice_ko_illegal_2", "어라, 여기는 안 돼!", "전혀 엄격하지 않고 동심 가득하게 규칙 안내."),

            # 6. 대국 하이라이트 (7 variants)
            ("voice_ko_atari_1", "단수!", "맑고 또렷하며 힘차게 바둑 용어를 외치기."),
            ("voice_ko_atari_2", "조심해, 단수야!", "약간의 긴장감을 담아 귀엽고 생동감 있게 알림."),
            ("voice_ko_capture_small_1", "따냈어!", "신나고 장난스럽게 짧고 경쾌한 환호."),
            ("voice_ko_capture_small_2", "하하, 잡았다!", "살짝 뿌듯한 어린아이 웃음기를 담아 귀엽게."),
            ("voice_ko_capture_big_1", "우와, 엄청 많이 따냈어!", "눈이 휘둥그레져서 크게 기뻐하는 성취감."),
            ("voice_ko_capture_big_2", "우와, 대마를 잡았어!", "박수 치며 흥분해서 에너지 넘치게 칭찬."),
            ("voice_ko_rewind_1", "시간 되돌리기!", "마법처럼 신비롭고 가볍고 발랄하게."),

            # 7. 승리 / 보스 / 격려 (7 variants)
            ("voice_ko_victory_1", "야호! 네가 이겼어!", "펄쩍 뛰며 기뻐하듯 닌텐도 클리어처럼 신나게 환호."),
            ("voice_ko_victory_2", "최고야, 스테이지 클리어!", "밝고 경쾌하게 클리어를 크게 축하."),
            ("voice_ko_victory_3", "대단해, 모두 클리어했어!", "뿌듯하고 감동적으로 크게 칭찬."),
            ("voice_ko_boss_victory_1", "우와! 섬 마스터를 이겼어!", "엄청난 놀라움과 감탄으로 대승리를 축하."),
            ("voice_ko_boss_victory_2", "정말 멋져! 마스터전 클리어!", "열정적이고 귀엽게 에너지 넘치는 축하."),
            ("voice_ko_encourage_1", "정말 잘 뒀어, 한 판 더 하자!", "따뜻하게 위로하고 밝게 다음 대국을 제안."),
            ("voice_ko_encourage_2", "괜찮아, 다음엔 꼭 이길 거야!", "다정하고 사랑스럽게 힘을 북돋아 주는 응원."),

            # 8. 승급 시험 (2 variants)
            ("voice_ko_exam_pass_1", "승급 축하해, 정말 멋져!", "화려하고 기쁘게 승급을 축하."),
            ("voice_ko_exam_pass_2", "대단해, 도전 성공이야!", "시원하고 경쾌하게 성공을 선언."),

            # 9. 도감 / 상점 / 사진 계가 / 인사 (7 variants)
            ("voice_ko_codex_1", "새 바둑 기술이 열렸어!", "보물상자를 연 것처럼 신나고 또렷하게."),
            ("voice_ko_shop_unlock_1", "우와, 멋지게 바뀌었네!", "기쁘고 사랑스럽게 새 디자인을 감탄."),
            ("voice_ko_no_coins_1", "별코인이 조금 모자라, 문제를 풀어서 모아 보자!", "귀엽고 다정하게 문제 풀이를 격려."),
            ("voice_ko_locked_1", "이전 스테이지를 먼저 클리어해 봐!", "친근하고 귀엽고 또렷하게 안내."),
            ("voice_ko_photo_done_1", "계가 끝났어, 결과를 확인해 봐!", "작은 도우미가 임무를 마친 것처럼 경쾌하게 보고."),
            ("voice_ko_welcome_1", "안녕! 같이 바둑 두자!", "단짝 친구처럼 반갑고 달콤하고 에너지 넘치게 인사."),
            ("voice_ko_welcome_2", "준비됐지? 출발하자!", "모험을 떠나는 것처럼 신나고 경쾌하게 외치기."),
        ],
    },
}


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


def generate_language_pack(model, lang: str, force: bool, only_set: set[str] | None) -> None:
    cfg = LANG_CONFIG[lang]
    tts_language = cfg["tts_language"]
    base_persona = cfg["base_persona"]
    out_dir = VOICE_ROOT / lang
    clips = cfg["clips"]

    selected = [c for c in clips if c[0] in only_set] if only_set else clips
    if not selected:
        return

    print(f"\n=== Generating '{lang}' ({tts_language}) pack -> {out_dir} ({len(selected)} clips) ===", flush=True)

    for idx, (key, text, nuance) in enumerate(selected, 1):
        out_path = out_dir / f"{key}.m4a"
        if out_path.exists() and not force:
            print(f"[{lang} {idx}/{len(selected)}] Skip existing: {key}", flush=True)
            continue

        instruct = f"{base_persona}{nuance}"
        best_audio = None
        sr = 24000

        # Retry up to 3 times if duration is abnormally short (<0.28s) or too long (>4.2s)
        for attempt in range(3):
            chunks = []
            for result in model.generate_voice_design(
                text=text,
                instruct=instruct,
                language=tts_language,
                temperature=0.72,
                top_p=0.88,
                max_tokens=120,
            ):
                sr = result.sample_rate
                chunks.append(np.asarray(result.audio, dtype=np.float32).reshape(-1))
            if not chunks:
                continue
            raw = np.concatenate(chunks)
            trimmed = trim_and_normalize(raw, sr=sr)
            dur = trimmed.size / float(sr)
            best_audio = trimmed
            if 0.28 <= dur <= 4.2:
                break
            print(f"  Retry {key} (attempt {attempt + 1}, dur={dur:.2f}s)", flush=True)

        if best_audio is None or best_audio.size == 0:
            raise RuntimeError(f"Failed to generate audio for {key}")

        write_m4a(best_audio, sr, out_path)
        dur = best_audio.size / float(sr)
        kb = out_path.stat().st_size / 1024.0
        print(f"[{lang} {idx}/{len(selected)}] {key}.m4a — \"{text}\" ({dur:.2f}s, {kb:.1f} KB)", flush=True)

    print(f"All {len(selected)} '{lang}' voice clips ready in {out_dir}!", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--lang",
        nargs="+",
        default=["all"],
        choices=["all", *LANG_CONFIG.keys()],
        help="Language packs to generate (default: all)",
    )
    parser.add_argument("--force", action="store_true", help="Regenerate existing clips")
    parser.add_argument("--only", nargs="*", help="Only generate specific clip keys")
    args = parser.parse_args()

    langs = list(LANG_CONFIG.keys()) if "all" in args.lang else args.lang

    if not (MODEL_DIR / ".download-complete").exists():
        raise SystemExit(f"Model not ready at {MODEL_DIR}")

    from mlx_audio.tts.utils import load_model

    print(f"Loading model from {MODEL_DIR}...", flush=True)
    model = load_model(str(MODEL_DIR))
    print("Model loaded!", flush=True)

    only_set = set(args.only) if args.only else None
    for lang in langs:
        generate_language_pack(model, lang, force=args.force, only_set=only_set)


if __name__ == "__main__":
    main()

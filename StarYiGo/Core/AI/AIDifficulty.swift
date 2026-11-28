//
//  AIDifficulty.swift
//  StarYi Go
//

import Foundation

enum CompanionEvent: String, Sendable {
    case greet
    case thinking
    case playerCaptured
    case playerBigCapture
    case aiCaptured
    case playerAtari
    case goodMove
    case pass
    case playerWin
    case aiWin
}

enum AIDifficulty: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case sprout   // 25K
    case rabbit   // 20K
    case fox      // 15K
    case deer     // 12K
    case panda    // 10K
    case crane    // 5K
    case tiger    // 3K
    case dragon   // 1D
    case phoenix  // 3D
    case kirin    // 5D

    var id: String { rawValue }

    var rankBadge: String {
        switch self {
        case .sprout: return "25K"
        case .rabbit: return "20K"
        case .fox: return "15K"
        case .deer: return "12K"
        case .panda: return "10K"
        case .crane: return "5K"
        case .tiger: return "3K"
        case .dragon: return "1D"
        case .phoenix: return "3D"
        case .kirin: return "5D"
        }
    }

    /// Official Go rank progression tier unlocked when defeating this master.
    var certifiedRankTier: Int {
        switch self {
        case .sprout: return 1   // 22K
        case .rabbit: return 2   // 18K
        case .fox: return 3      // 15K
        case .deer: return 3     // 15K
        case .panda: return 4    // 10K
        case .crane: return 5    // 5K
        case .tiger: return 5    // 5K
        case .dragon: return 6   // 1D
        case .phoenix: return 7  // 3D
        case .kirin: return 8    // 5D
        }
    }

    var avatarEmoji: String {
        switch self {
        case .sprout: return "🌱"
        case .rabbit: return "🐰"
        case .fox: return "🦊"
        case .deer: return "🦌"
        case .panda: return "🐼"
        case .crane: return "🦢"
        case .tiger: return "🐯"
        case .dragon: return "🐉"
        case .phoenix: return "🦅"
        case .kirin: return "🦄"
        }
    }

    var isHighDan: Bool {
        self == .dragon || self == .phoenix || self == .kirin
    }

    var nameKey: String { "ai.\(rawValue).name" }
    var descKey: String { "ai.\(rawValue).desc" }
    var styleTagKey: String { "ai.\(rawValue).style" }

    /// Character-specific localized dialogue key with automatic fallback to generic `companion.<event>`.
    func dialogue(for event: CompanionEvent, l10n: L10n) -> String {
        let specificKey = "companion.\(rawValue).\(event.rawValue)"
        let specific = l10n.t(specificKey)
        if specific != specificKey {
            return specific
        }
        return l10n.t("companion.\(event.rawValue)")
    }

    /// MCTS rollout count calibrated per board size and level so iPad/iPhone stays snappy (< 0.8s).
    func mctsIterations(for boardSize: Int) -> Int {
        let scale: Double = boardSize <= 7 ? 1.15 : (boardSize <= 9 ? 1.0 : (boardSize <= 13 ? 0.65 : 0.35))
        let base: Int
        switch self {
        case .sprout: base = 0
        case .rabbit: base = 24
        case .fox: base = 75
        case .deer: base = 115
        case .panda: base = 160
        case .crane: base = 290
        case .tiger: base = 380
        case .dragon: base = 480
        case .phoenix: base = 620
        case .kirin: base = 780
        }
        return max(0, Int(Double(base) * scale))
    }

    /// Randomness temperature for lower levels so kids can genuinely win and learn.
    var explorationNoise: Double {
        switch self {
        case .sprout: return 18.0
        case .rabbit: return 10.0
        case .fox: return 4.5
        case .deer: return 2.8
        case .panda: return 1.6
        case .crane: return 0.5
        case .tiger: return 0.25
        case .dragon: return 0.0
        case .phoenix: return 0.0
        case .kirin: return 0.0
        }
    }
}

/// User-selectable AI thinking pace presets.
/// Balances anti-impulsive calm pacing for kids with snappy match flow.
enum AIThinkingPace: String, CaseIterable, Codable, Identifiable, Equatable, Sendable {
    case instant
    case brisk
    case human
    case deep

    var id: String { rawValue }

    func shortTitle(_ l10n: L10n) -> String {
        switch self {
        case .instant:
            return l10n.localized(zh: "极速", en: "Instant", ja: "最速", ko: "즉시", zhHant: "極速")
        case .brisk:
            return l10n.localized(zh: "轻快", en: "Brisk", ja: "軽快", ko: "경쾌", zhHant: "輕快")
        case .human:
            return l10n.localized(zh: "拟人", en: "Natural", ja: "標準", ko: "자연", zhHant: "擬人")
        case .deep:
            return l10n.localized(zh: "慢棋", en: "Slow", ja: "じっくり", ko: "느림", zhHant: "慢棋")
        }
    }

    func summaryText(_ l10n: L10n) -> String {
        switch self {
        case .instant:
            return l10n.localized(
                zh: "约 0.3 秒 · 适合快速试下或复盘",
                en: "~0.3s · Best for quick play or review",
                ja: "約 0.3 秒 · 素早い対局や検討向け",
                ko: "약 0.3초 · 빠른 대국 및 복기용",
                zhHant: "約 0.3 秒 · 適合快速試下或復盤"
            )
        case .brisk:
            return l10n.localized(
                zh: "约 1.5~3.5 秒 · 推荐，有思考停顿不拖沓（冲动落子自动稳节奏）",
                en: "~1.5–3.5s · Recommended: calm pause without drag (steadies rushed taps)",
                ja: "約 1.5〜3.5 秒 · おすすめ：程よい間合いでテンポ良好",
                ko: "약 1.5~3.5초 · 추천: 적당한 생각 시간과 경쾌한 템포",
                zhHant: "約 1.5~3.5 秒 · 推薦，有思考停頓不拖沓（衝動落子自動穩節奏）"
            )
        case .human:
            return l10n.localized(
                zh: "约 2.5~5.5 秒 · 接近真人平时对弈节奏",
                en: "~2.5–5.5s · Natural human match rhythm",
                ja: "約 2.5〜5.5 秒 · 人間に近い自然な対局リズム",
                ko: "약 2.5~5.5초 · 사람과 비슷한 자연스러운 대국 리듬",
                zhHant: "約 2.5~5.5 秒 · 接近真人平時對弈節奏"
            )
        case .deep:
            return l10n.localized(
                zh: "约 4~8 秒 · 模拟考级或比赛的沉稳长考节奏",
                en: "~4–8s · Deliberate tournament-style rhythm",
                ja: "約 4〜8 秒 · 昇級試験や公式戦向けの落ち着いたペース",
                ko: "약 4~8초 · 승급전/대회처럼 차분한 대국 리듬",
                zhHant: "約 4~8 秒 · 模擬考級或比賽的沉穩長考節奏"
            )
        }
    }
}

/// Simulates natural, human-like thinking time for AI opponents so kids experience a calm,
/// unhurried match rhythm instead of instant millisecond replies, without wasting time.
///
/// Duration adapts to:
/// 1. User-selected `AIThinkingPace` preset (`instant`, `brisk`, `human`, `deep`).
/// 2. Board density & game phase (brisk on an empty opening board, deeper in the midgame).
/// 3. Gentle rank-tier offset (keeps high-dan opponents crisp instead of sluggish).
/// 4. Local tactical tension (Atari, Ko, or close-quarters fighting adds brief reading time).
/// 5. Anti-impulsive steady tempo: if the child clicked impulsively (< 2s), AI pauses slightly
///    longer to steady the rhythm; if the child already thought patiently (>= 8s), AI responds
///    more briskly instead of stacking another long wait.
/// 6. Clock safety (never risks flagging in timed or byoyomi matches).
enum AIThinkingPacer {
    struct PaceProfile {
        let openingBase: TimeInterval
        let midgameBase: TimeInterval
        let openingFloor: TimeInterval
        let openingCeiling: TimeInterval
        let midgameFloor: TimeInterval
        let maxCeiling: TimeInterval
        let tacticalCap: TimeInterval
        let antiImpulseBonus: TimeInterval
        let deepThinkChance: Double
        let deepThinkMin: TimeInterval
        let deepThinkSpan: TimeInterval
    }

    struct RankOffset {
        let opening: TimeInterval
        let midgame: TimeInterval
        let ceiling: TimeInterval
    }

    static func paceProfile(for pace: AIThinkingPace) -> PaceProfile {
        switch pace {
        case .instant:
            return PaceProfile(
                openingBase: 0.26,
                midgameBase: 0.26,
                openingFloor: 0.26,
                openingCeiling: 0.26,
                midgameFloor: 0.26,
                maxCeiling: 0.26,
                tacticalCap: 0,
                antiImpulseBonus: 0,
                deepThinkChance: 0,
                deepThinkMin: 0,
                deepThinkSpan: 0
            )
        case .brisk:
            return PaceProfile(
                openingBase: 1.0,
                midgameBase: 2.1,
                openingFloor: 0.9,
                openingCeiling: 2.2,
                midgameFloor: 1.3,
                maxCeiling: 3.6,
                tacticalCap: 0.9,
                antiImpulseBonus: 0.9,
                deepThinkChance: 0.08,
                deepThinkMin: 0.4,
                deepThinkSpan: 0.4
            )
        case .human:
            return PaceProfile(
                openingBase: 1.4,
                midgameBase: 3.3,
                openingFloor: 1.1,
                openingCeiling: 3.2,
                midgameFloor: 2.0,
                maxCeiling: 5.5,
                tacticalCap: 1.2,
                antiImpulseBonus: 1.2,
                deepThinkChance: 0.12,
                deepThinkMin: 0.6,
                deepThinkSpan: 0.5
            )
        case .deep:
            return PaceProfile(
                openingBase: 2.0,
                midgameBase: 5.0,
                openingFloor: 1.4,
                openingCeiling: 4.2,
                midgameFloor: 3.2,
                maxCeiling: 8.0,
                tacticalCap: 1.6,
                antiImpulseBonus: 1.4,
                deepThinkChance: 0.15,
                deepThinkMin: 0.8,
                deepThinkSpan: 0.7
            )
        }
    }

    static func rankOffset(for difficulty: AIDifficulty) -> RankOffset {
        switch difficulty {
        case .sprout, .rabbit, .fox:
            return RankOffset(opening: 0.0, midgame: 0.0, ceiling: 0.0)
        case .deer, .panda, .crane, .tiger:
            return RankOffset(opening: 0.15, midgame: 0.35, ceiling: 0.4)
        case .dragon, .phoenix, .kirin:
            return RankOffset(opening: 0.30, midgame: 0.70, ceiling: 0.8)
        }
    }

    static func targetThinkingDuration(
        for state: GoBoardState,
        difficulty: AIDifficulty,
        chosenAction: MoveAction,
        lastHumanThinkDuration: TimeInterval?,
        clock: GoClock,
        aiColor: StoneColor,
        pace: AIThinkingPace = .brisk,
        randomUnit: () -> Double = { Double.random(in: 0.0...1.0) }
    ) -> TimeInterval {
        if pace == .instant {
            return 0.26
        }

        let profile = paceProfile(for: pace)
        let offset = rankOffset(for: difficulty)
        let openingBase = profile.openingBase + offset.opening
        let midgameBase = profile.midgameBase + offset.midgame
        let maxCeiling = profile.maxCeiling + offset.ceiling

        let stoneCount = state.grid.reduce(0) { $0 + ($1 == nil ? 0 : 1) }
        let boardArea = Double(max(1, state.size * state.size))
        let density = Double(stoneCount) / boardArea

        // 1. Game phase / board occupancy curve:
        //    Very empty opening -> brisk; ramps smoothly as stones fill the board; eases slightly in late endgame.
        var phaseFactor: Double
        if stoneCount <= 3 {
            phaseFactor = 0.08 * Double(stoneCount)
        } else {
            let linear = min(1.0, max(0.0, (density - 0.03) / 0.35))
            phaseFactor = 1.0 - pow(1.0 - linear, 2.0)
            if density > 0.62 {
                phaseFactor *= 0.82
            }
        }
        if chosenAction == .pass || chosenAction == .resign {
            phaseFactor *= 0.45
        }

        var duration = openingBase + (midgameBase - openingBase) * phaseFactor

        // 2. Tactical complexity reading bonus (Atari, Ko, or close-quarters contact fight)
        var tacticalBonus: TimeInterval = 0
        if state.koIndex != nil {
            tacticalBonus += 0.7
        }
        if !state.atariPoints().isEmpty {
            tacticalBonus += 0.5
        }
        if stoneCount >= 6,
           case .place(let prev) = state.lastMove,
           case .place(let next) = chosenAction,
           abs(prev.row - next.row) + abs(prev.col - next.col) <= 2 {
            tacticalBonus += 0.35
        }
        duration += min(profile.tacticalCap, tacticalBonus)

        // 3. Anti-impulsive steady tempo:
        //    - If the child tapped impulsively (< 2.0s), pause slightly longer to calm their rhythm.
        //    - If the child already thought patiently (>= 8.0s), respond faster instead of wasting extra time.
        if let humanThink = lastHumanThinkDuration, stoneCount >= 4, chosenAction != .pass {
            if humanThink < 2.0 {
                let impulsivity = max(0.0, min(1.0, (2.0 - humanThink) / 2.0))
                duration += impulsivity * profile.antiImpulseBonus
            } else if humanThink >= 8.0 {
                let patience = max(0.0, min(1.0, (humanThink - 8.0) / 12.0))
                duration *= (1.0 - 0.32 * patience)
            }
        }

        // 4. Natural human randomness + occasional brief deep-think
        let jitter = 0.82 + randomUnit() * 0.36 // 0.82 ... 1.18
        duration *= jitter

        if stoneCount >= 8 && chosenAction != .pass && randomUnit() < profile.deepThinkChance {
            duration += profile.deepThinkMin + randomUnit() * profile.deepThinkSpan
        }

        // 5. Clamp to realistic pace-calibrated bounds
        if stoneCount < 4 || chosenAction == .pass {
            duration = min(profile.openingCeiling, max(profile.openingFloor, duration))
        } else {
            duration = min(maxCeiling, max(profile.midgameFloor, duration))
        }

        // 6. Clock safety: never risk timing out in timed / byoyomi games (allow down to 0.0s in extreme time trouble)
        if clock.isActive {
            let aiClock = clock.state(for: aiColor)
            if aiClock.inByoyomi {
                let remaining = Double(aiClock.byoyomiSecondsRemaining)
                let safeCap = max(0.0, min(remaining * 0.45, remaining - 2.0))
                duration = min(duration, safeCap)
            } else if aiClock.mainSecondsRemaining <= 40 {
                let remaining = Double(aiClock.mainSecondsRemaining)
                let safeCap = max(0.0, min(remaining * 0.35, remaining - 3.0))
                duration = min(duration, safeCap)
            }
        }

        return duration
    }
}

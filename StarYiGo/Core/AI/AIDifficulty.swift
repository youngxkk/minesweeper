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

/// Simulates natural, human-like thinking time for AI opponents so kids experience a calm,
/// unhurried match rhythm instead of instant millisecond replies.
///
/// Duration adapts to:
/// 1. Board density & game phase (brisk on an empty opening board, deeper in the midgame).
/// 2. AI rank tier (higher ranks take slightly longer to read complex positions).
/// 3. Local tactical tension (Atari, Ko, or close-quarters fighting adds brief reading time).
/// 4. The child's own recent thinking pace (gently mirrors patient thinking while keeping a calm floor).
/// 5. Clock safety (never risks flagging in timed or byoyomi matches).
enum AIThinkingPacer {
    struct RankProfile {
        let openingBase: TimeInterval
        let midgameBase: TimeInterval
        let maxCeiling: TimeInterval
        let humanMirrorWeight: Double
    }

    static func profile(for difficulty: AIDifficulty) -> RankProfile {
        switch difficulty {
        case .sprout, .rabbit, .fox:
            return RankProfile(openingBase: 1.8, midgameBase: 4.9, maxCeiling: 8.2, humanMirrorWeight: 0.28)
        case .deer, .panda, .crane, .tiger:
            return RankProfile(openingBase: 2.2, midgameBase: 6.1, maxCeiling: 9.5, humanMirrorWeight: 0.18)
        case .dragon, .phoenix, .kirin:
            return RankProfile(openingBase: 2.6, midgameBase: 7.2, maxCeiling: 10.5, humanMirrorWeight: 0.10)
        }
    }

    static func targetThinkingDuration(
        for state: GoBoardState,
        difficulty: AIDifficulty,
        chosenAction: MoveAction,
        lastHumanThinkDuration: TimeInterval?,
        clock: GoClock,
        aiColor: StoneColor,
        randomUnit: () -> Double = { Double.random(in: 0.0...1.0) }
    ) -> TimeInterval {
        let rankProfile = profile(for: difficulty)
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
        if chosenAction == .pass {
            phaseFactor *= 0.45
        }

        var duration = rankProfile.openingBase + (rankProfile.midgameBase - rankProfile.openingBase) * phaseFactor

        // 2. Tactical complexity reading bonus (Atari, Ko, or close-quarters contact fight)
        var tacticalBonus: TimeInterval = 0
        if state.koIndex != nil {
            tacticalBonus += 1.2
        }
        if !state.atariPoints().isEmpty {
            tacticalBonus += 0.9
        }
        if stoneCount >= 6,
           case .place(let prev) = state.lastMove,
           case .place(let next) = chosenAction,
           abs(prev.row - next.row) + abs(prev.col - next.col) <= 2 {
            tacticalBonus += 0.6
        }
        duration += min(1.8, tacticalBonus)

        // 3. Gently echo the child's calm thinking rhythm without ever rushing if the child clicked impulsively
        if let humanThink = lastHumanThinkDuration, stoneCount >= 4, chosenAction != .pass {
            let calmHumanPace = min(11.0, max(2.6, humanThink))
            let w = rankProfile.humanMirrorWeight
            duration = duration * (1.0 - w) + calmHumanPace * w
        }

        // 4. Natural human randomness + occasional brief deep-think
        let jitter = 0.78 + randomUnit() * 0.44 // 0.78 ... 1.22
        duration *= jitter

        if stoneCount >= 8 && chosenAction != .pass && randomUnit() < 0.15 {
            duration += 1.0 + randomUnit() * 1.5
        }

        // 5. Clamp to realistic human bounds
        if stoneCount < 4 || chosenAction == .pass {
            duration = min(4.5, max(1.2, duration))
        } else {
            duration = min(rankProfile.maxCeiling, max(2.8, duration))
        }

        // 6. Clock safety: never risk timing out in timed / byoyomi games
        if clock.isActive {
            let aiClock = clock.state(for: aiColor)
            if aiClock.inByoyomi {
                let remaining = Double(aiClock.byoyomiSecondsRemaining)
                let safeCap = max(0.5, min(remaining * 0.45, remaining - 2.0))
                duration = min(duration, safeCap)
            } else if aiClock.mainSecondsRemaining <= 40 {
                let remaining = Double(aiClock.mainSecondsRemaining)
                let safeCap = max(0.5, min(remaining * 0.35, remaining - 3.0))
                duration = min(duration, safeCap)
            }
        }

        return duration
    }
}

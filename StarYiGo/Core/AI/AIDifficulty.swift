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
    case sprout  // 25K
    case rabbit  // 20K
    case fox     // 15K
    case panda   // 10K
    case crane   // 5K
    case dragon  // 1D

    var id: String { rawValue }

    var rankBadge: String {
        switch self {
        case .sprout: return "25K"
        case .rabbit: return "20K"
        case .fox: return "15K"
        case .panda: return "10K"
        case .crane: return "5K"
        case .dragon: return "1D"
        }
    }

    /// Official Go rank progression tier unlocked when defeating this master.
    var certifiedRankTier: Int {
        switch self {
        case .sprout: return 1 // 22K
        case .rabbit: return 2 // 18K
        case .fox: return 3    // 15K
        case .panda: return 4  // 10K
        case .crane: return 5  // 5K
        case .dragon: return 6 // 1D
        }
    }

    var avatarEmoji: String {
        switch self {
        case .sprout: return "🌱"
        case .rabbit: return "🐰"
        case .fox: return "🦊"
        case .panda: return "🐼"
        case .crane: return "🦢"
        case .dragon: return "🐉"
        }
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

    /// MCTS rollout count calibrated per board size and level so iPad/iPhone stays snappy (< 0.6s).
    func mctsIterations(for boardSize: Int) -> Int {
        let scale: Double = boardSize <= 7 ? 1.15 : (boardSize <= 9 ? 1.0 : (boardSize <= 13 ? 0.65 : 0.35))
        let base: Int
        switch self {
        case .sprout: base = 0
        case .rabbit: base = 24
        case .fox: base = 75
        case .panda: base = 160
        case .crane: base = 290
        case .dragon: base = 480
        }
        return max(0, Int(Double(base) * scale))
    }

    /// Randomness temperature for lower levels so kids can genuinely win and learn.
    var explorationNoise: Double {
        switch self {
        case .sprout: return 18.0
        case .rabbit: return 10.0
        case .fox: return 4.5
        case .panda: return 1.6
        case .crane: return 0.5
        case .dragon: return 0.0
        }
    }
}

//
//  GoAIEngineProtocol.swift
//  StarYi Go
//

import Foundation

enum HintReason: String, Sendable {
    case capture = "hint.capture"
    case escape = "hint.escape"
    case atari = "hint.atari"
    case corner = "hint.corner"
    case connect = "hint.connect"
    case territory = "hint.territory"
    case bestMove = "hint.bestMove"
}

struct MoveSuggestion: Identifiable, Hashable, Sendable {
    let id = UUID()
    let point: BoardPoint
    let score: Double
    let reason: HintReason
    let pvMoves: [BoardPoint]

    init(point: BoardPoint, score: Double, reason: HintReason, pvMoves: [BoardPoint] = []) {
        self.point = point
        self.score = score
        self.reason = reason
        self.pvMoves = pvMoves
    }
}

/// Detailed AI candidate line with Principal Variation (推荐变化图) for Game Review.
struct MoveVariation: Identifiable, Hashable, Sendable {
    let id = UUID()
    let firstMove: BoardPoint
    let winrateForMover: Double // 0.0...1.0
    let scoreLeadForBlack: Double
    let pvMoves: [BoardPoint]
    let reason: HintReason
}

/// Snapshot evaluation of a single board position.
struct PositionAnalysis: Sendable {
    let blackWinrate: Double     // 0.0...1.0
    let blackScoreLead: Double   // Positive = Black ahead
    let topVariations: [MoveVariation]
}

/// Per-move AI review entry with kid-friendly diagnostic explanation.
struct ReviewedMove: Identifiable, Sendable {
    let id: Int // 1-based moveNumber
    let moveNumber: Int
    let color: StoneColor
    let playedAction: MoveAction
    let blackWinrateAfter: Double
    let blackScoreLeadAfter: Double
    let moverWinrateDrop: Double // positive means move lost winrate
    let moverScoreDrop: Double   // positive means move lost points
    let quality: MoveQuality
    let diagnosisZh: String
    let diagnosisEn: String
    let topVariations: [MoveVariation]

    func diagnosis(_ l10n: L10n) -> String {
        l10n.bilingual(zh: diagnosisZh, en: diagnosisEn)
    }

    var isBlunderOrMistake: Bool {
        quality == .blunder || quality == .mistake
    }
}

/// Complete post-game AI analysis report (Winrate Curve + Diagnostics + Blunder List).
struct GameReviewReport: Sendable {
    let initialBlackWinrate: Double
    let winrateHistory: [Double]    // index 0 = start, index i = after move i
    let scoreLeadHistory: [Double]  // index 0 = start, index i = after move i
    let reviewedMoves: [ReviewedMove]

    var keyMistakes: [ReviewedMove] {
        reviewedMoves
            .filter { $0.isBlunderOrMistake }
            .sorted { $0.moverWinrateDrop > $1.moverWinrateDrop }
    }
}

/// Clean modular protocol for offline Go AI engines.
/// Implemented by `LocalMCTSGoEngine` (multi-ply UCT+RAVE + Tactical Ladder Reader + Joseki Book)
/// and `CoreMLGoAIEngine` (drop-in CoreML/Metal KataGo neural network adapter with seamless fallback).
protocol GoAIEngine: Sendable {
    var engineName: String { get }

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty
    ) async -> MoveAction

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle
    ) async -> MoveAction

    func suggestMoves(
        for state: GoBoardState,
        color: StoneColor,
        count: Int
    ) async -> [MoveSuggestion]

    func analyzePosition(
        for state: GoBoardState,
        color: StoneColor,
        maxVariations: Int
    ) async -> PositionAnalysis

    func analyzeGame(
        initialState: GoBoardState,
        moves: [GoMove]
    ) async -> GameReviewReport
}

extension GoAIEngine {
    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet
    ) async -> MoveAction {
        await selectMove(for: state, color: color, level: level, ruleSet: ruleSet, coachingStyle: .standard)
    }

    func selectMove(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle
    ) async -> MoveAction {
        await selectMove(for: state, color: color, level: level)
    }
}

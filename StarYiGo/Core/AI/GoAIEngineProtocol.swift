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

/// Structured result of an AI move selection, optionally carrying the engine's
/// own winrate, score-lead, and ownership evaluation (zero extra inference cost for KataGo).
struct AIMoveDecision: Sendable {
    let action: MoveAction
    let moverWinrate: Double?
    let moverScoreLead: Double?
    let ownershipForMover: [Double]?

    init(
        action: MoveAction,
        moverWinrate: Double? = nil,
        moverScoreLead: Double? = nil,
        ownershipForMover: [Double]? = nil
    ) {
        self.action = action
        self.moverWinrate = moverWinrate
        self.moverScoreLead = moverScoreLead
        self.ownershipForMover = ownershipForMover
    }
}

/// Evaluates whether an AI opponent is in a genuinely unrecoverable position and should politely
/// offer resignation (soft-resign flow: player may accept victory or keep playing).
///
/// Crucially accounts for **remaining open/unsettled board space** so the AI never resigns early
/// while a large empty area still offers real comeback potential!
enum AIResignationEvaluator {
    struct Assessment: Sendable, Equatable {
        let isPositionHopeless: Bool
        let shouldOfferResign: Bool
        let nextConsecutiveHopelessTurns: Int
        let estimatedHumanLead: Double
        let unsettledRatio: Double
        let solidOpponentPoints: Int
    }

    static func minimumMoveCount(for boardSize: Int) -> Int {
        switch boardSize {
        case ...6: return Int.max // Never auto-resign on 5x5 starter boards
        case 7: return 18
        case 8...9: return 26
        case 10...13: return 45
        default: return 75 // 19x19
        }
    }

    /// Severe deficit threshold (points behind) for offering resignation once the board is settled.
    static func despairMargin(for boardSize: Int) -> Double {
        switch boardSize {
        case 7: return 11.0
        case 8...9: return 16.0
        case 10...13: return 26.0
        default: return 40.0 // 19x19
        }
    }

    /// Late-game deficit threshold once the board is substantially settled or opponent locked a majority.
    static func lateMargin(for boardSize: Int) -> Double {
        switch boardSize {
        case 7: return 8.0
        case 8...9: return 12.0
        case 10...13: return 18.0
        default: return 26.0 // 19x19
        }
    }

    /// Number of solidly controlled intersections (live stones + firmly enclosed territory)
    /// beyond the half-board win line that guarantees an unrecoverable majority.
    static func guaranteedMajorityThreshold(for boardSize: Int) -> Int {
        switch boardSize {
        case 7: return 30       // > 61% of 49
        case 8...9: return 48   // > 59% of 81
        case 10...13: return 96 // > 56.8% of 169
        default: return 200     // > 55.4% of 361 (well past 185 win line)
        }
    }

    /// Rank-aware tolerance multiplier: beginner/low-kyu AI is more resilient (higher deficit bar)
    /// because casual players can still make big swings; Dan AI follows crisper pro etiquette.
    static func rankTolerance(for difficulty: AIDifficulty) -> (deficitScale: Double, maxUnsettledRatio: Double) {
        switch difficulty {
        case .sprout, .rabbit, .fox:
            return (deficitScale: 1.25, maxUnsettledRatio: 0.22)
        case .deer, .panda, .crane, .tiger:
            return (deficitScale: 1.00, maxUnsettledRatio: 0.26)
        case .dragon, .phoenix, .kirin:
            return (deficitScale: 0.85, maxUnsettledRatio: 0.30)
        }
    }

    static func majorCaptureThreshold(for boardSize: Int) -> Int {
        switch boardSize {
        case 7: return 4
        case 8...9: return 5
        default: return 6 // 13x13 & 19x19
        }
    }

    static func evaluate(
        state: GoBoardState,
        aiColor: StoneColor,
        difficulty: AIDifficulty = .panda,
        ruleSet: GameRuleSet,
        isTacticalScenario: Bool,
        consecutiveHopelessTurns: Int,
        chosenAction: MoveAction = .pass,
        recentMaxCaptureAgainstAI: Int = 0,
        neuralWinrateForAI: Double? = nil,
        neuralScoreLeadForAI: Double? = nil,
        neuralOwnershipForAI: [Double]? = nil
    ) -> Assessment {
        guard !ruleSet.isCaptureRace,
              !isTacticalScenario,
              state.size >= 7,
              state.consecutivePasses == 0,
              state.moveCount >= minimumMoveCount(for: state.size) else {
            return Assessment(
                isPositionHopeless: false,
                shouldOfferResign: false,
                nextConsecutiveHopelessTurns: 0,
                estimatedHumanLead: 0,
                unsettledRatio: 1.0,
                solidOpponentPoints: 0
            )
        }

        let total = max(1, state.size * state.size)
        let totalDouble = Double(total)
        let dead = GoScoring.autoEstimateDeadStones(state: state)
        let est = GoScoring.estimateTerritory(state: state, deadStoneIndices: dead)
        let opponent = aiColor.opposite

        // Measure solidly controlled opponent territory vs. truly open/unsettled board space.
        // Loose influence (0.28..0.64) in wide-open areas counts as unsettled comeback space!
        let solidThreshold = (neuralOwnershipForAI != nil) ? 0.72 : 0.65
        var solidOpponentPoints = 0
        var unsettledCount = 0

        for idx in 0..<total {
            if let neuralOwn = neuralOwnershipForAI, idx < neuralOwn.count {
                // neuralOwn is from AI's perspective: +1 = AI, -1 = opponent
                let v = neuralOwn[idx]
                if v <= -solidThreshold {
                    solidOpponentPoints += 1
                } else if abs(v) < solidThreshold {
                    unsettledCount += 1
                }
            } else {
                // est.ownership is from Black's perspective: +1 = Black, -1 = White
                if let stone = state.grid[idx], !dead.contains(idx) {
                    if stone == opponent {
                        solidOpponentPoints += 1
                    }
                } else {
                    let oppSign: Double = (opponent == .black) ? 1.0 : -1.0
                    let oppOwn = est.ownership[idx] * oppSign
                    if oppOwn >= solidThreshold {
                        solidOpponentPoints += 1
                    } else if abs(est.ownership[idx]) < solidThreshold {
                        unsettledCount += 1
                    }
                }
            }
        }

        let unsettledRatio = Double(unsettledCount) / totalDouble
        let tolerance = rankTolerance(for: difficulty)
        let despair = despairMargin(for: state.size) * tolerance.deficitScale
        let late = lateMargin(for: state.size) * tolerance.deficitScale
        let majorityThreshold = guaranteedMajorityThreshold(for: state.size)

        let aiLead: Double
        let isHopeless: Bool
        let isMoveExhausted = (chosenAction == .pass)
        let hadMajorCapture = recentMaxCaptureAgainstAI >= majorCaptureThreshold(for: state.size)

        // Deficit must overcome remaining open-space comeback potential unless opponent already
        // solidly locked a guaranteed winning majority of the entire board!
        let comebackGuardMargin = Double(unsettledCount) * 0.65 + late

        if let wr = neuralWinrateForAI, let lead = neuralScoreLeadForAI {
            aiLead = lead
            let deficit = -lead
            let lockedMajority = (solidOpponentPoints >= majorityThreshold && wr <= 0.035 && deficit >= late)
            let settledCollapse = (unsettledRatio <= tolerance.maxUnsettledRatio && wr <= 0.025 && deficit >= max(despair, comebackGuardMargin))
            let extremeNeuralCollapse = (unsettledRatio <= min(0.35, tolerance.maxUnsettledRatio + 0.08) && wr <= 0.015 && deficit >= max(despair * 1.25, Double(unsettledCount) * 0.55 + late))
            let exhaustedLoss = (isMoveExhausted && unsettledRatio <= 0.30 && wr <= 0.05 && deficit >= late * 0.85)
            isHopeless = lockedMajority || settledCollapse || extremeNeuralCollapse || exhaustedLoss
        } else {
            aiLead = (aiColor == .black) ? est.blackLead : -est.blackLead
            let deficit = -aiLead
            let lockedMajority = (solidOpponentPoints >= majorityThreshold && deficit >= late)
            let settledCollapse = (unsettledRatio <= tolerance.maxUnsettledRatio && deficit >= max(despair, comebackGuardMargin))
            let exhaustedLoss = (isMoveExhausted && unsettledRatio <= 0.30 && deficit >= late * 0.85)
            isHopeless = lockedMajority || settledCollapse || exhaustedLoss
        }

        let nextStreak = isHopeless ? (consecutiveHopelessTurns + 1) : 0
        let deficit = -aiLead
        let extremeCollapse = (deficit >= despair * 1.8) && (unsettledRatio <= 0.22 || solidOpponentPoints >= majorityThreshold)
        let immediateExhaustedCollapse = isMoveExhausted && isHopeless && deficit >= despair
        let requiredStreak: Int
        if immediateExhaustedCollapse {
            requiredStreak = 1
        } else if extremeCollapse || (hadMajorCapture && isHopeless) || (isMoveExhausted && isHopeless) {
            requiredStreak = 2
        } else {
            requiredStreak = 3
        }
        let shouldOffer = isHopeless && nextStreak >= requiredStreak

        return Assessment(
            isPositionHopeless: isHopeless,
            shouldOfferResign: shouldOffer,
            nextConsecutiveHopelessTurns: nextStreak,
            estimatedHumanLead: max(0.0, deficit),
            unsettledRatio: unsettledRatio,
            solidOpponentPoints: solidOpponentPoints
        )
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

    func selectMoveDecision(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle
    ) async -> AIMoveDecision

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

    func selectMoveDecision(
        for state: GoBoardState,
        color: StoneColor,
        level: AIDifficulty,
        ruleSet: GameRuleSet,
        coachingStyle: AICoachingStyle
    ) async -> AIMoveDecision {
        let action = await selectMove(for: state, color: color, level: level, ruleSet: ruleSet, coachingStyle: coachingStyle)
        return AIMoveDecision(action: action)
    }
}

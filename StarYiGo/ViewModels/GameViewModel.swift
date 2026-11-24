//
//  GameViewModel.swift
//  StarYi Go
//

import Combine
import Foundation
import UIKit

enum CompanionMood: Equatable {
    case greeting
    case thinking
    case surprised
    case excited
    case playful
    case calm
    case cheering
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published var boardState: GoBoardState
    @Published var moves: [GoMove] = []
    @Published var isAIThinking: Bool = false
    @Published var showTerritoryOverlay: Bool = false
    @Published var territoryEstimate: TerritoryEstimate?
    @Published var suggestions: [MoveSuggestion] = []
    @Published var isComputingHint: Bool = false
    @Published var pendingPoint: BoardPoint?
    @Published var statusBanner: String?
    @Published var gameResult: GameResult?
    @Published var savedRecordId: UUID?

    // Interactive Endgame Dead-Stone Confirmation ("点按标记死子，精准数子")
    @Published var isMarkingDeadStones: Bool = false
    @Published var markedDeadIndices: Set<Int> = []
    @Published var deadStonePreviewResult: GameResult?
    @Published var scoringRule: ScoringRule = .chinese
    @Published var endgameReadiness: EndgameReadiness? = nil
    @Published var unsealedWarningPoints: [BoardPoint] = []
    @Published var showUnsealedScoreAlert: Bool = false
    @Published var highlightedPocketPoints: Set<BoardPoint> = []
    @Published var activeCountingPocketLabel: String? = nil

    // Go Clock & Byoyomi State + Per-Player Elapsed Time
    @Published var clock: GoClock
    @Published var blackElapsedSeconds: Int = 0
    @Published var whiteElapsedSeconds: Int = 0

    // Nintendo Companion Personality State
    @Published var companionMood: CompanionMood = .greeting
    @Published var companionEvent: CompanionEvent = .greet

    // Time Hourglass Highlight & Turning-Point Analysis
    @Published var bestMoveNumber: Int?
    @Published var turningPointMoveNumber: Int?

    // Two-Player Tabletop 180° Face-to-Face Mode + Parent-Child Assist
    @Published var isTabletopFaceToFace: Bool = false
    @Published var tabletopKidAssistColor: StoneColor? = nil

    // Tactile physical feedback events for GoBoardView animations
    @Published var lastCapturedPoints: [BoardPoint] = []
    @Published var captureEventID: UUID = UUID()
    @Published var illegalFlashPoint: BoardPoint?
    @Published var illegalEventID: UUID = UUID()

    let boardSize: BoardSize
    let mode: GameMode
    let ruleSet: GameRuleSet
    let timeControl: TimeControl
    let coachingStyle: AICoachingStyle
    let handicap: Int
    let bossIslandId: String?
    let examTier: Int?
    let tacticalScenario: TacticalScenario?
    let campaignNodeId: String?

    /// Board marker labels for tactical scenarios (e.g. 🎯 on the target White group or ★ on the Black dragon to save).
    var scenarioBoardLabels: [BoardPoint: String] {
        guard let scenario = tacticalScenario, let pt = scenario.markedPoint, boardState.stone(at: pt) != nil else {
            return [:]
        }
        switch scenario.goal {
        case .captureMarkedGroup: return [pt: "🎯"]
        case .surviveAndLive: return [pt: "★"]
        default: return [:]
        }
    }

    var scenarioProgressSummary: String? {
        guard let scenario = tacticalScenario else { return nil }
        let isZh = appState?.l10n.language.isChinese ?? true
        switch scenario.goal {
        case .captureRace(let target):
            return isZh ? "提子目标：\(boardState.blackCaptures)/\(target)" : "Captures: \(boardState.blackCaptures)/\(target)"
        case .captureMarkedGroup(_, let maxPlies):
            let left = max(0, maxPlies - moves.count)
            return isZh ? "吃掉 🎯 目标 · 剩余 \(left) 手" : "Capture 🎯 · \(left) moves left"
        case .surviveAndLive(_, let survivePlies):
            let left = max(0, survivePlies - moves.count)
            return isZh ? "守住 ★ 黑龙 · 还需坚持 \(left) 手或两眼活" : "Keep ★ alive · \(left) moves left"
        case .endgameComeback(let maxPlies):
            let left = max(0, maxPlies - moves.count)
            return isZh ? "收官逆转 · 剩余 \(left) 手结算" : "Endgame · \(left) moves to score"
        }
    }

    private let aiEngine: GoAIEngine
    private weak var appState: AppState?
    private var stateHistory: [GoBoardState] = []
    /// Tracks human-perspective lead after each ply for Time Hourglass turning-point analysis.
    private var humanLeadHistory: [Double] = [0]
    private(set) var aiTask: Task<Void, Never>?
    private var bannerDismissTask: Task<Void, Never>?
    private var pocketAnimTask: Task<Void, Never>?
    private var isSuspended = false
    private var clockTimer: Timer?
    private var lastTurnStartTime: Date = Date()
    private var lastHumanThinkDuration: TimeInterval?
    private let simulateHumanThinkingPacing: Bool

    var isExamMatch: Bool {
        examTier != nil || (appState?.settings.assistPreset == .examSim)
    }

    var isUndoAllowed: Bool {
        guard !isExamMatch, !isAIThinking, !isGameOver else { return false }
        if let humanColor {
            return moves.contains { $0.color == humanColor }
        }
        return !moves.isEmpty
    }

    var isGameOver: Bool {
        gameResult != nil
    }

    var isTwoPlayer: Bool {
        if case .twoPlayer = mode { return true }
        return false
    }

    var shouldConfirmBeforeLeaving: Bool {
        !isTwoPlayer && !isGameOver && !moves.isEmpty
    }

    func makePausedAIMatchSnapshot() -> PausedAIMatchSnapshot? {
        guard case .vsAI(let difficulty, let playerColor) = mode,
              !isExamMatch,
              bossIslandId == nil,
              tacticalScenario == nil,
              !isGameOver,
              !moves.isEmpty else {
            return nil
        }
        return PausedAIMatchSnapshot(
            boardSize: boardSize,
            difficulty: difficulty,
            playerColor: playerColor,
            handicap: handicap,
            ruleSet: ruleSet,
            scoringRule: scoringRule,
            timeControl: timeControl,
            coachingStyle: coachingStyle,
            moves: moves,
            clock: clock,
            blackElapsedSeconds: blackElapsedSeconds,
            whiteElapsedSeconds: whiteElapsedSeconds,
            savedAt: Date()
        )
    }

    var aiDifficulty: AIDifficulty? {
        if case .vsAI(let diff, _) = mode { return diff }
        return nil
    }

    var humanColor: StoneColor? {
        if case .vsAI(_, let color) = mode { return color }
        return nil
    }

    var isHumansTurn: Bool {
        guard !isGameOver, !isMarkingDeadStones else { return false }
        switch mode {
        case .twoPlayer:
            return true
        case .vsAI(_, let humanColor):
            return boardState.currentTurn == humanColor
        }
    }

    var stonePlacementMode: StonePlacementMode {
        appState?.settings.stonePlacementMode ?? .doubleTap
    }

    var showsConfirmPlacementButton: Bool {
        appState != nil && stonePlacementMode == .confirmButton
    }

    var requiresConfirmBeforePlace: Bool {
        appState != nil
    }

    var companionDialogueText: String {
        guard let l10n = appState?.l10n else { return "" }
        if let diff = aiDifficulty {
            return diff.dialogue(for: companionEvent, l10n: l10n)
        }
        return l10n.t("companion.\(companionEvent.rawValue)")
    }

    var moveNumberLookup: [BoardPoint: Int] {
        var map: [BoardPoint: Int] = [:]
        for move in moves {
            if case .place(let pt) = move.action {
                if boardState.stone(at: pt) != nil {
                    map[pt] = move.moveNumber
                }
            }
        }
        return map
    }

    init(
        boardSize: BoardSize,
        mode: GameMode,
        ruleSet: GameRuleSet = .standard,
        scoringRule: ScoringRule = .chinese,
        timeControl: TimeControl = .unlimited,
        coachingStyle: AICoachingStyle = .standard,
        handicap: Int = 0,
        bossIslandId: String? = nil,
        examTier: Int? = nil,
        tacticalScenario: TacticalScenario? = nil,
        campaignNodeId: String? = nil,
        aiEngine: GoAIEngine = CoreMLGoAIEngine.shared,
        appState: AppState? = nil,
        simulateHumanThinkingPacing: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    ) {
        self.boardSize = boardSize
        self.mode = mode
        self.ruleSet = ruleSet
        self.scoringRule = scoringRule
        self.timeControl = timeControl
        self.coachingStyle = coachingStyle
        self.clock = GoClock(timeControl: timeControl)
        self.handicap = handicap
        self.bossIslandId = bossIslandId
        self.examTier = examTier
        self.tacticalScenario = tacticalScenario
        self.campaignNodeId = campaignNodeId
        self.aiEngine = aiEngine
        self.appState = appState
        self.simulateHumanThinkingPacing = simulateHumanThinkingPacing

        let initial: GoBoardState
        if let scenario = tacticalScenario {
            initial = scenario.makeInitialState()
        } else {
            let komi = handicap > 0 ? 0.5 : scoringRule.defaultKomi(for: boardSize)
            initial = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: handicap)
        }
        self.boardState = initial
        self.stateHistory = [initial]
        self.humanLeadHistory = [0]
        self.lastTurnStartTime = Date()

        startClockIfNeeded()
        triggerAIIfNeeded()
    }

    convenience init(
        resuming snapshot: PausedAIMatchSnapshot,
        aiEngine: GoAIEngine = CoreMLGoAIEngine.shared,
        appState: AppState? = nil,
        simulateHumanThinkingPacing: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil
    ) {
        self.init(
            boardSize: snapshot.boardSize,
            mode: .vsAI(difficulty: snapshot.difficulty, playerColor: snapshot.playerColor),
            ruleSet: snapshot.ruleSet,
            scoringRule: snapshot.scoringRule,
            timeControl: snapshot.timeControl,
            coachingStyle: snapshot.coachingStyle,
            handicap: snapshot.handicap,
            bossIslandId: nil,
            examTier: nil,
            tacticalScenario: nil,
            campaignNodeId: nil,
            aiEngine: aiEngine,
            appState: appState,
            simulateHumanThinkingPacing: simulateHumanThinkingPacing
        )
        restore(from: snapshot)
    }

    private func restore(from snapshot: PausedAIMatchSnapshot) {
        aiTask?.cancel()
        isAIThinking = false
        pendingPoint = nil
        suggestions = []

        let komi = snapshot.handicap > 0 ? 0.5 : snapshot.scoringRule.defaultKomi(for: snapshot.boardSize)
        var state = GoBoardState(size: snapshot.boardSize.rawValue, komi: komi, handicap: snapshot.handicap)
        var history: [GoBoardState] = [state]
        var replayedMoves: [GoMove] = []
        var leads: [Double] = [0]

        for move in snapshot.moves {
            if case .success(let outcome) = state.applying(action: move.action, color: move.color) {
                state = outcome.nextState
                history.append(state)
                replayedMoves.append(
                    GoMove(
                        moveNumber: replayedMoves.count + 1,
                        color: move.color,
                        action: move.action,
                        capturedPoints: outcome.capturedPoints
                    )
                )
                let est = GoScoring.estimateTerritory(state: state)
                let lead = (snapshot.playerColor == .black) ? est.blackLead : -est.blackLead
                leads.append(lead)
            }
        }

        boardState = state
        stateHistory = history
        moves = replayedMoves
        humanLeadHistory = leads
        clock = snapshot.clock
        blackElapsedSeconds = snapshot.blackElapsedSeconds
        whiteElapsedSeconds = snapshot.whiteElapsedSeconds
        lastTurnStartTime = Date()
        lastHumanThinkDuration = nil
        companionMood = .greeting
        companionEvent = .greet

        startClockIfNeeded()
        triggerAIIfNeeded()
    }

    deinit {
        aiTask?.cancel()
        bannerDismissTask?.cancel()
        pocketAnimTask?.cancel()
        clockTimer?.invalidate()
    }

    func formattedElapsedTime(for color: StoneColor) -> String {
        let secs = color == .black ? blackElapsedSeconds : whiteElapsedSeconds
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startClockIfNeeded() {
        clockTimer?.invalidate()
        clockTimer = nil
        guard !isSuspended, !isGameOver else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickClock()
            }
        }
    }

    func setSuspended(_ suspended: Bool) {
        guard isSuspended != suspended else { return }
        isSuspended = suspended
        if suspended {
            clockTimer?.invalidate()
            clockTimer = nil
            aiTask?.cancel()
            isAIThinking = false
        } else if !isGameOver {
            startClockIfNeeded()
            triggerAIIfNeeded()
        }
    }

    func tickClock() {
        guard !isSuspended, !isGameOver, !isMarkingDeadStones else { return }
        let activeColor = boardState.currentTurn
        if activeColor == .black {
            blackElapsedSeconds += 1
        } else {
            whiteElapsedSeconds += 1
        }
        guard timeControl.isTimed else { return }
        let event = clock.tick(activeColor: activeColor)
        switch event {
        case .normal:
            break
        case .countdownBeep:
            SoundAndHapticsManager.shared.playGridTick()
        case .periodConsumed:
            SoundAndHapticsManager.shared.playHint()
        case .timeout(let loser):
            clockTimer?.invalidate()
            aiTask?.cancel()
            isAIThinking = false
            finishGame(with: GameResult(
                winner: loser.opposite,
                blackScore: 0,
                whiteScore: 0,
                komi: boardState.komi,
                byResignation: false,
                byCaptureRace: false,
                captureTarget: nil,
                byTimeout: true,
                scoringRule: scoringRule,
                boardSize: boardSize.rawValue
            ))
        }
    }

    // MARK: - User Interactions

    func handleBoardTap(at point: BoardPoint) {
        if isMarkingDeadStones {
            toggleDeadGroup(at: point)
            return
        }

        guard isHumansTurn, !isAIThinking, !isGameOver else { return }

        // Clear any endgame unsealed warnings once player resumes sealing
        if !unsealedWarningPoints.isEmpty {
            unsealedWarningPoints = []
        }

        if requiresConfirmBeforePlace {
            switch stonePlacementMode {
            case .doubleTap:
                if pendingPoint == point {
                    confirmPendingPlacement()
                } else if boardState.stone(at: point) == nil {
                    pendingPoint = point
                    SoundAndHapticsManager.shared.playGridTick()
                    statusBanner = nil
                } else {
                    triggerIllegalFeedback(at: point, error: .occupied)
                }
            case .confirmButton:
                if boardState.stone(at: point) == nil {
                    pendingPoint = point
                    SoundAndHapticsManager.shared.playGridTick()
                    statusBanner = nil
                } else {
                    triggerIllegalFeedback(at: point, error: .occupied)
                }
            }
            return
        }

        attemptHumanMove(.place(point))
    }

    func confirmPendingPlacement() {
        guard let pt = pendingPoint else { return }
        pendingPoint = nil
        attemptHumanMove(.place(pt))
    }

    func cancelPendingPlacement() {
        pendingPoint = nil
        SoundAndHapticsManager.shared.playUITap()
    }

    func passTurn() {
        guard isHumansTurn, !isAIThinking, !isGameOver else { return }
        pendingPoint = nil

        // If standard territory game and boundaries are visibly unsealed, warn once before passing!
        if !ruleSet.isCaptureRace && moves.count >= 6 {
            let readiness = GoScoring.analyzeEndgameReadiness(state: boardState)
            if !readiness.isReadyToScore && unsealedWarningPoints.isEmpty {
                unsealedWarningPoints = readiness.unsealedBoundaryPoints
                endgameReadiness = readiness
                let isZh = appState?.l10n.language.isChinese ?? true
                showTransientBanner(
                    isZh
                        ? "发现 \(readiness.warningCount) 处边界还没封口（红圈处）！建议先补好再停一手，或再点一次确认停一手。"
                        : "\(readiness.warningCount) unsealed boundary spot(s) highlighted! Seal them first, or tap Pass again.",
                    duration: 4.0
                )
                SoundAndHapticsManager.shared.playHint()
                return
            }
        }
        unsealedWarningPoints = []
        attemptHumanMove(.pass)
    }

    func undo() {
        guard isUndoAllowed else { return }
        if isMarkingDeadStones {
            cancelDeadStoneReview()
        }
        aiTask?.cancel()
        pendingPoint = nil
        suggestions = []
        statusBanner = nil
        SoundAndHapticsManager.shared.playUndo()

        switch mode {
        case .twoPlayer:
            popOnePly()
        case .vsAI(_, let humanColor):
            popOnePly()
            while boardState.currentTurn != humanColor && stateHistory.count > 1 {
                popOnePly()
            }
        }

        refreshTerritoryIfVisible()
        triggerAIIfNeeded()
    }

    /// Nintendo "Time Hourglass" — rewinds the match straight back to before a turning-point move so kids can retry!
    func rewindToMove(_ moveNumber: Int) {
        let targetStateIndex = max(0, min(stateHistory.count - 1, moveNumber - 1))
        aiTask?.cancel()
        isAIThinking = false
        isMarkingDeadStones = false
        markedDeadIndices = []
        deadStonePreviewResult = nil
        pendingPoint = nil
        suggestions = []
        statusBanner = nil
        gameResult = nil
        savedRecordId = nil
        bestMoveNumber = nil
        turningPointMoveNumber = nil
        showTerritoryOverlay = false
        territoryEstimate = nil

        stateHistory = Array(stateHistory.prefix(targetStateIndex + 1))
        moves = Array(moves.prefix(targetStateIndex))
        humanLeadHistory = Array(humanLeadHistory.prefix(targetStateIndex + 1))
        boardState = stateHistory.last ?? GoBoardState(size: boardSize.rawValue, handicap: handicap)

        companionMood = .cheering
        companionEvent = .greet
        SoundAndHapticsManager.shared.playHourglassRewind()
        SoundAndHapticsManager.shared.playVoice(.rewind, delay: 0.12)

        triggerAIIfNeeded()
    }

    func requestHint() {
        guard isHumansTurn, !isAIThinking, !isComputingHint, !isGameOver else { return }
        isComputingHint = true
        suggestions = []
        let snapshot = boardState
        let color = boardState.currentTurn

        Task {
            let results = await aiEngine.suggestMoves(for: snapshot, color: color, count: 2)
            self.isComputingHint = false
            self.suggestions = results
            if results.isEmpty, let l10n = self.appState?.l10n {
                self.showTransientBanner(l10n.t("game.status.noHint"), duration: 3.0)
            } else if let first = results.first, let l10n = self.appState?.l10n {
                SoundAndHapticsManager.shared.playHint()
                let coord = first.point.humanLabel(boardSize: snapshot.size)
                self.showTransientBanner("\(coord) · \(l10n.t(first.reason.rawValue))", duration: 4.0)
            }
        }
    }

    func toggleTerritory() {
        showTerritoryOverlay.toggle()
        refreshTerritoryIfVisible()
    }

    // MARK: - Interactive Dead-Stone Endgame Review

    /// Enters dead-stone confirmation (auto-marking trapped dead stones) with unsealed-boundary readiness check!
    func beginDeadStoneReview(bypassUnsealedWarning: Bool = false) {
        guard !isGameOver, !ruleSet.isCaptureRace else { return }

        let estimatedDead = GoScoring.autoEstimateDeadStones(state: boardState)
        let readiness = GoScoring.analyzeEndgameReadiness(state: boardState, deadStoneIndices: estimatedDead)
        endgameReadiness = readiness

        if !bypassUnsealedWarning && !readiness.isReadyToScore && moves.count >= 4 {
            unsealedWarningPoints = readiness.unsealedBoundaryPoints
            showUnsealedScoreAlert = true
            SoundAndHapticsManager.shared.playHint()
            return
        }

        unsealedWarningPoints = []
        showUnsealedScoreAlert = false
        aiTask?.cancel()
        isAIThinking = false
        pendingPoint = nil
        suggestions = []
        isMarkingDeadStones = true
        markedDeadIndices = estimatedDead
        showTerritoryOverlay = true
        updateDeadStonePreview()
        runVisualPocketCountingDemo()
        SoundAndHapticsManager.shared.playUITap()
    }

    /// Lets players immediately resume the game to play out any disputed dead/alive group!
    func playOutDispute() {
        guard isMarkingDeadStones else { return }
        cancelDeadStoneReview()
        // Resuming opens a new passing sequence, even if the AI passes immediately.
        boardState.consecutivePasses = 0
        stateHistory[stateHistory.count - 1] = boardState
        triggerAIIfNeeded()
        let isZh = appState?.l10n.language.isChinese ?? true
        showTransientBanner(
            isZh ? "已恢复对局：请直接续下验证争议棋块的死活！" : "Match resumed: Play out the disputed group to prove life or death!",
            duration: 3.5
        )
    }

    func switchScoringRule(_ newRule: ScoringRule) {
        scoringRule = newRule
        updateDeadStonePreview()
        SoundAndHapticsManager.shared.playUITap()
    }

    /// Gently animates enclosed territory pockets one-by-one so kids visually understand how territory is counted!
    func runVisualPocketCountingDemo() {
        pocketAnimTask?.cancel()
        highlightedPocketPoints = []
        activeCountingPocketLabel = nil
        let pockets = GoScoring.territoryPockets(state: boardState, deadStoneIndices: markedDeadIndices)
        guard !pockets.isEmpty else { return }
        let isZh = appState?.l10n.language.isChinese ?? true

        pocketAnimTask = Task { [weak self] in
            var cumulative: Set<BoardPoint> = []
            for pocket in pockets.prefix(8) {
                guard !Task.isCancelled, let self, self.isMarkingDeadStones else { return }
                cumulative.formUnion(pocket.points)
                self.highlightedPocketPoints = Set(pocket.points)
                let side = pocket.owner == .black ? (isZh ? "黑空" : "Black") : (isZh ? "白空" : "White")
                self.activeCountingPocketLabel = isZh ? "\(side) +\(pocket.points.count) 目" : "\(side) +\(pocket.points.count) pts"
                SoundAndHapticsManager.shared.playGridTick()
                try? await Task.sleep(nanoseconds: 420_000_000)
            }
            guard !Task.isCancelled, let self else { return }
            self.highlightedPocketPoints = []
            self.activeCountingPocketLabel = nil
        }
    }

    func toggleDeadGroup(at point: BoardPoint) {
        guard isMarkingDeadStones else { return }
        let idx = boardState.index(row: point.row, col: point.col)
        guard let group = boardState.groupAndLiberties(at: idx) else { return }

        if markedDeadIndices.contains(idx) {
            markedDeadIndices.subtract(group.stones)
        } else {
            markedDeadIndices.formUnion(group.stones)
        }
        SoundAndHapticsManager.shared.playGridTick()
        updateDeadStonePreview()
    }

    func confirmDeadStoneScore() {
        guard isMarkingDeadStones else { return }
        pocketAnimTask?.cancel()
        highlightedPocketPoints = []
        activeCountingPocketLabel = nil
        let result = GoScoring.score(state: boardState, rule: scoringRule, deadStoneIndices: markedDeadIndices)
        isMarkingDeadStones = false
        deadStonePreviewResult = nil
        finishGame(with: result)
    }

    private func cancelDeadStoneReview() {
        pocketAnimTask?.cancel()
        highlightedPocketPoints = []
        activeCountingPocketLabel = nil
        isMarkingDeadStones = false
        markedDeadIndices = []
        deadStonePreviewResult = nil
        showTerritoryOverlay = false
        territoryEstimate = nil
        SoundAndHapticsManager.shared.playUndo()
    }

    /// Direct instant score (preserved for compatibility or quick-confirm).
    func scoreAndFinishNow() {
        beginDeadStoneReview()
    }

    private func updateDeadStonePreview() {
        territoryEstimate = GoScoring.estimateTerritory(state: boardState, deadStoneIndices: markedDeadIndices)
        deadStonePreviewResult = GoScoring.score(state: boardState, rule: scoringRule, deadStoneIndices: markedDeadIndices)
    }

    func resignCurrentPlayer() {
        guard !isGameOver else { return }
        aiTask?.cancel()
        isAIThinking = false
        isMarkingDeadStones = false
        pendingPoint = nil

        let loser: StoneColor = humanColor ?? boardState.currentTurn
        let winner = loser.opposite
        let result = GameResult(
            winner: winner,
            blackScore: 0,
            whiteScore: 0,
            komi: boardState.komi,
            byResignation: true
        )
        finishGame(with: result)
    }

    func restartMatch() {
        aiTask?.cancel()
        bannerDismissTask?.cancel()
        isAIThinking = false
        isMarkingDeadStones = false
        markedDeadIndices = []
        deadStonePreviewResult = nil
        pendingPoint = nil
        suggestions = []
        statusBanner = nil
        gameResult = nil
        savedRecordId = nil
        bestMoveNumber = nil
        turningPointMoveNumber = nil
        showTerritoryOverlay = false
        territoryEstimate = nil
        lastCapturedPoints = []
        illegalFlashPoint = nil
        moves = []
        companionMood = .greeting
        companionEvent = .greet

        let initial: GoBoardState
        if let scenario = tacticalScenario {
            initial = scenario.makeInitialState()
        } else {
            let komi = handicap > 0 ? 0.5 : scoringRule.defaultKomi(for: boardSize)
            initial = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: handicap)
        }
        boardState = initial
        stateHistory = [initial]
        humanLeadHistory = [0]
        clock = GoClock(timeControl: timeControl)
        blackElapsedSeconds = 0
        whiteElapsedSeconds = 0
        unsealedWarningPoints = []
        highlightedPocketPoints = []
        activeCountingPocketLabel = nil
        lastTurnStartTime = Date()
        lastHumanThinkDuration = nil
        startClockIfNeeded()
        triggerAIIfNeeded()
    }

    // MARK: - Internal Move Engine

    private func attemptHumanMove(_ action: MoveAction) {
        let color = boardState.currentTurn
        switch boardState.applying(action: action, color: color) {
        case .failure(let error):
            if case .place(let pt) = action {
                triggerIllegalFeedback(at: pt, error: error)
            } else {
                SoundAndHapticsManager.shared.playWrong()
            }
        case .success(let outcome):
            lastHumanThinkDuration = max(0, Date().timeIntervalSince(lastTurnStartTime))
            applySuccessfulOutcome(outcome, action: action, color: color)
            if !isGameOver {
                triggerAIIfNeeded()
            }
        }
    }

    private func triggerIllegalFeedback(at point: BoardPoint, error: MoveError) {
        if error == .koViolation || error == .suicide {
            SoundAndHapticsManager.shared.playKoBounce()
            SoundAndHapticsManager.shared.playVoice(.illegalMove, delay: 0.08, cooldown: 2.5)
            if error == .koViolation {
                appState?.unlockCodexTerm("ko", showToast: true)
            } else {
                appState?.unlockCodexTerm("suicide", showToast: true)
            }
        } else {
            SoundAndHapticsManager.shared.playWrong()
            SoundAndHapticsManager.shared.playVoice(.illegalMove, delay: 0.08, cooldown: 2.5)
        }
        illegalFlashPoint = point
        illegalEventID = UUID()
        if let l10n = appState?.l10n {
            showTransientBanner(l10n.t(error.localizationKey), duration: 2.6)
        }
    }

    private func showTransientBanner(_ text: String, duration: Double) {
        bannerDismissTask?.cancel()
        statusBanner = text
        bannerDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            if self.statusBanner == text {
                self.statusBanner = nil
            }
        }
    }

    private func triggerAIIfNeeded() {
        guard case .vsAI(let difficulty, let humanColor) = mode else { return }
        guard !isSuspended, !isGameOver, !isMarkingDeadStones, boardState.currentTurn != humanColor else { return }

        isAIThinking = true
        companionMood = .thinking
        companionEvent = .thinking
        let snapshot = boardState
        let aiColor = boardState.currentTurn
        let currentRules = ruleSet
        let style = coachingStyle
        let humanThinkDuration = lastHumanThinkDuration
        let clockSnapshot = clock
        let useHumanPacing = simulateHumanThinkingPacing && (appState?.settings.aiSimulatedThinkingEnabled ?? true)

        aiTask?.cancel()
        aiTask = Task { [weak self] in
            let start = Date()
            let moveAction = await self?.aiEngine.selectMove(
                for: snapshot,
                color: aiColor,
                level: difficulty,
                ruleSet: currentRules,
                coachingStyle: style
            ) ?? .pass
            let targetDuration: TimeInterval = useHumanPacing
                ? AIThinkingPacer.targetThinkingDuration(
                    for: snapshot,
                    difficulty: difficulty,
                    chosenAction: moveAction,
                    lastHumanThinkDuration: humanThinkDuration,
                    clock: clockSnapshot,
                    aiColor: aiColor
                )
                : 0.26
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < targetDuration {
                try? await Task.sleep(nanoseconds: UInt64((targetDuration - elapsed) * 1_000_000_000))
            }
            guard !Task.isCancelled, let self else { return }
            self.isAIThinking = false

            switch self.boardState.applying(action: moveAction, color: aiColor) {
            case .success(let outcome):
                self.applySuccessfulOutcome(outcome, action: moveAction, color: aiColor)
            case .failure:
                if case .success(let passOut) = self.boardState.applying(action: .pass, color: aiColor) {
                    self.applySuccessfulOutcome(passOut, action: .pass, color: aiColor)
                }
            }
        }
    }

    private func applySuccessfulOutcome(_ outcome: MoveOutcome, action: MoveAction, color: StoneColor) {
        suggestions = []
        clock.completeMove(for: color)
        lastTurnStartTime = Date()
        boardState = outcome.nextState
        stateHistory.append(outcome.nextState)

        let move = GoMove(
            moveNumber: moves.count + 1,
            color: color,
            action: action,
            capturedPoints: outcome.capturedPoints
        )
        moves.append(move)

        let est = GoScoring.estimateTerritory(state: outcome.nextState)
        let perspective = humanColor ?? .black
        let lead = (perspective == .black) ? est.blackLead : -est.blackLead
        humanLeadHistory.append(lead)

        updateCompanionReaction(move: move, outcome: outcome)

        let nextAtariPoints = outcome.nextState.atariPoints()
        let hasTension = (outcome.nextState.koIndex != nil) || !nextAtariPoints.isEmpty
        SoundAndHapticsManager.shared.setMatchTension(hasTension)

        if !outcome.capturedPoints.isEmpty {
            lastCapturedPoints = outcome.capturedPoints
            captureEventID = UUID()
            SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
            let isHumanMove = (humanColor == nil || color == humanColor)
            if outcome.capturedPoints.count >= 3 {
                SoundAndHapticsManager.shared.playWonderMoment()
                if isHumanMove {
                    SoundAndHapticsManager.shared.playVoice(.captureBig, delay: 0.16, cooldown: 3.0)
                }
            } else if isHumanMove {
                SoundAndHapticsManager.shared.playVoice(.captureSmall, delay: 0.14, cooldown: 8.0)
            }
        } else if case .place(let pt) = action {
            let createdAtari = nextAtariPoints.contains { outcome.nextState.stone(at: $0) == color.opposite }
            SoundAndHapticsManager.shared.playStonePlace(at: pt, boardSize: boardState.size, isAtari: createdAtari)
            if createdAtari {
                SoundAndHapticsManager.shared.playVoice(.atari, delay: 0.10, cooldown: 10.0)
            }
        }

        if UIAccessibility.isVoiceOverRunning, let l10n = appState?.l10n {
            let side = color == .black ? l10n.t("stone.black") : l10n.t("stone.white")
            var parts: [String] = []
            switch action {
            case .place(let pt):
                parts.append("\(side) \(pt.humanLabel(boardSize: boardState.size))")
            case .pass:
                parts.append(l10n.t("game.status.passBanner", side))
            case .resign:
                parts.append(l10n.t("game.action.resign"))
            }
            if !outcome.capturedPoints.isEmpty {
                parts.append(l10n.localized(
                    zh: "提掉 \(outcome.capturedPoints.count) 子",
                    en: "captured \(outcome.capturedPoints.count)",
                    ja: "\(outcome.capturedPoints.count)子取り",
                    ko: "\(outcome.capturedPoints.count)점 따냄",
                    zhHant: "提掉 \(outcome.capturedPoints.count) 子"
                ))
            } else if nextAtariPoints.contains(where: { outcome.nextState.stone(at: $0) == color.opposite }) {
                parts.append(l10n.localized(zh: "叫吃", en: "Atari", ja: "アタリ", ko: "단수", zhHant: "叫吃"))
            }
            UIAccessibility.post(notification: .announcement, argument: parts.joined(separator: ", "))
        }

        if outcome.nextState.koIndex != nil {
            appState?.unlockCodexTerm("ko", showToast: true)
        }

        if case .pass = action, let l10n = appState?.l10n {
            let side = color == .black ? l10n.t("stone.black") : l10n.t("stone.white")
            showTransientBanner(l10n.t("game.status.passBanner", side), duration: 2.4)
        } else {
            statusBanner = nil
        }

        refreshTerritoryIfVisible()

        // Check Capture Race (吃子棋) win condition!
        if case .captureRace(let target) = ruleSet {
            let captures = color == .black ? boardState.blackCaptures : boardState.whiteCaptures
            if captures >= target {
                finishGame(with: GameResult(
                    winner: color,
                    blackScore: Double(boardState.blackCaptures),
                    whiteScore: Double(boardState.whiteCaptures),
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: target,
                    boardSize: boardState.size
                ))
            }
            return
        }

        // Check Preset SGF Tactical Scenario win/loss conditions!
        if let scenario = tacticalScenario {
            if evaluateTacticalScenarioGoal(scenario) {
                return
            }
        }

        if boardState.isDoublePassEnded {
            beginDeadStoneReview(bypassUnsealedWarning: true)
        }
    }

    /// Evaluates Phase 2 Tactical Scenario objectives after each ply. Returns true if the match ended.
    private func evaluateTacticalScenarioGoal(_ scenario: TacticalScenario) -> Bool {
        let human = humanColor ?? .black
        switch scenario.goal {
        case .captureRace:
            return false // Handled above by standard `ruleSet == .captureRace(target)`
        case .captureMarkedGroup(let targetSGF, let maxPlies):
            if let pt = BoardPoint(sgf: targetSGF), boardState.stone(at: pt) != human.opposite {
                // Target enemy anchor stone was captured!
                finishGame(with: GameResult(
                    winner: human,
                    blackScore: Double(boardState.blackCaptures),
                    whiteScore: Double(boardState.whiteCaptures),
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: nil,
                    boardSize: boardSize.rawValue
                ))
                return true
            }
            if moves.count >= maxPlies {
                finishGame(with: GameResult(
                    winner: human.opposite,
                    blackScore: Double(boardState.blackCaptures),
                    whiteScore: Double(boardState.whiteCaptures),
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: nil,
                    boardSize: boardSize.rawValue
                ))
                return true
            }
            return false

        case .surviveAndLive(let anchorSGF, let survivePlies):
            guard let pt = BoardPoint(sgf: anchorSGF) else { return false }
            if boardState.stone(at: pt) != human {
                // Our anchor dragon was captured -> loss
                finishGame(with: GameResult(
                    winner: human.opposite,
                    blackScore: 0,
                    whiteScore: 1,
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: nil,
                    boardSize: boardSize.rawValue
                ))
                return true
            }
            let aliveInfo = boardState.twoEyeAliveAnalysis()
            let anchorIdx = boardState.index(row: pt.row, col: pt.col)
            if aliveInfo.aliveStoneIndices.contains(anchorIdx) || moves.count >= survivePlies {
                finishGame(with: GameResult(
                    winner: human,
                    blackScore: 1,
                    whiteScore: 0,
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: nil,
                    boardSize: boardSize.rawValue
                ))
                return true
            }
            return false

        case .endgameComeback(let maxPlies):
            if moves.count >= maxPlies || boardState.isDoublePassEnded {
                let dead = GoScoring.autoEstimateDeadStones(state: boardState)
                let scored = GoScoring.score(state: boardState, rule: scoringRule, deadStoneIndices: dead)
                finishGame(with: scored)
                return true
            }
            return false
        }
    }

    private func updateCompanionReaction(move: GoMove, outcome: MoveOutcome) {
        guard let humanColor else { return }
        let isHumanMove = (move.color == humanColor)

        if case .pass = move.action, !isHumanMove {
            companionMood = .calm
            companionEvent = .pass
            return
        }

        if isHumanMove {
            if outcome.capturedPoints.count >= 3 {
                companionMood = .excited
                companionEvent = .playerBigCapture
            } else if !outcome.capturedPoints.isEmpty {
                companionMood = .surprised
                companionEvent = .playerCaptured
            } else {
                companionMood = .calm
                companionEvent = .goodMove
            }
        } else {
            if !outcome.capturedPoints.isEmpty {
                companionMood = .playful
                companionEvent = .aiCaptured
            } else {
                let atari = outcome.nextState.atariPoints()
                let humanInAtari = atari.contains { outcome.nextState.stone(at: $0) == humanColor }
                if humanInAtari {
                    companionMood = .playful
                    companionEvent = .playerAtari
                } else {
                    companionMood = .calm
                    companionEvent = .goodMove
                }
            }
        }
    }

    private func computeTimeHourglassMoments() {
        let perspective = humanColor ?? .black
        var bestGain = -Double.infinity
        var bestIdx: Int?
        var worstDrop = Double.infinity
        var worstIdx: Int?

        for (i, move) in moves.enumerated() where move.color == perspective {
            let before = humanLeadHistory[i]
            let after = humanLeadHistory[min(i + 1, humanLeadHistory.count - 1)]
            let delta = (after - before) + Double(move.capturedPoints.count) * 2.5

            if delta > bestGain {
                bestGain = delta
                bestIdx = move.moveNumber
            }
            if delta < worstDrop {
                worstDrop = delta
                worstIdx = move.moveNumber
            }
        }

        let hasCapture = moves.contains { $0.color == perspective && !$0.capturedPoints.isEmpty }
        if moves.count >= 6 || hasCapture {
            bestMoveNumber = bestIdx
        } else {
            bestMoveNumber = nil
        }
        if let worstIdx, worstDrop < -1.0 {
            turningPointMoveNumber = worstIdx
        } else {
            turningPointMoveNumber = moves.count >= 4 ? max(1, moves.count - 3) : nil
        }
    }

    private func popOnePly() {
        guard stateHistory.count > 1, !moves.isEmpty else { return }
        stateHistory.removeLast()
        moves.removeLast()
        if humanLeadHistory.count > 1 { humanLeadHistory.removeLast() }
        boardState = stateHistory.last!
    }

    private func refreshTerritoryIfVisible() {
        if showTerritoryOverlay {
            territoryEstimate = GoScoring.estimateTerritory(state: boardState, deadStoneIndices: markedDeadIndices)
        }
    }

    private func finishGame(with result: GameResult) {
        gameResult = result
        computeTimeHourglassMoments()

        let didHumanWin: Bool
        let humanCaps: Int
        switch mode {
        case .vsAI(_, let color):
            didHumanWin = (result.winner == color)
            humanCaps = (color == .black) ? boardState.blackCaptures : boardState.whiteCaptures
        case .twoPlayer:
            didHumanWin = true
            humanCaps = boardState.blackCaptures + boardState.whiteCaptures
        }

        companionMood = didHumanWin ? .cheering : .playful
        companionEvent = didHumanWin ? .playerWin : .aiWin

        if didHumanWin {
            if bossIslandId != nil {
                SoundAndHapticsManager.shared.playBossFanfare()
                SoundAndHapticsManager.shared.playVoice(.bossVictory, delay: 0.26)
            } else {
                SoundAndHapticsManager.shared.playVictoryFanfare()
                SoundAndHapticsManager.shared.playVoice(.victory, delay: 0.24)
            }
        } else {
            SoundAndHapticsManager.shared.playVoice(.encourageLoss, delay: 0.20)
        }

        guard let appState else { return }
        let l10n = appState.l10n
        let blackName: String
        let whiteName: String

        switch mode {
        case .vsAI(let diff, let humanColor):
            let aiName = "\(l10n.t(diff.nameKey)) (\(diff.rankBadge))"
            let playerLabel = appState.profile.nickname
            if humanColor == .black {
                blackName = playerLabel
                whiteName = aiName
            } else {
                blackName = aiName
                whiteName = playerLabel
            }
        case .twoPlayer:
            blackName = l10n.t("stone.black")
            whiteName = l10n.t("stone.white")
        }

        let sgf = SGFParser.export(
            initialState: stateHistory[0],
            blackName: blackName,
            whiteName: whiteName,
            result: result.sgfResultString,
            date: Date(),
            moves: moves
        )

        let record = SavedGameRecord(
            boardSize: boardState.size,
            komi: boardState.komi,
            handicap: handicap,
            blackName: blackName,
            whiteName: whiteName,
            resultString: result.sgfResultString,
            moveCount: moves.count,
            sgf: sgf
        )
        savedRecordId = record.id
        if let examTier {
            appState.recordExamMatchResult(tier: examTier, didWin: didHumanWin)
        }
        if let nodeId = campaignNodeId, didHumanWin {
            appState.recordCampaignNodeCleared(nodeId: nodeId, stars: 3, masteryTier: .normal)
        }
        appState.saveCompletedGame(
            record,
            didHumanWin: didHumanWin,
            capturesByHuman: humanCaps,
            opponentDifficulty: examTier == nil ? aiDifficulty : nil,
            bossIslandId: bossIslandId
        )
    }
}

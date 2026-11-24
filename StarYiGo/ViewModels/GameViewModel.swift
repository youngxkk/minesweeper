//
//  GameViewModel.swift
//  StarYi Go
//

import Combine
import Foundation

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

    // Go Clock & Byoyomi State
    @Published var clock: GoClock
    @Published var impulseWarningBanner: String? = nil

    // Nintendo Companion Personality State
    @Published var companionMood: CompanionMood = .greeting
    @Published var companionEvent: CompanionEvent = .greet

    // Time Hourglass Highlight & Turning-Point Analysis
    @Published var bestMoveNumber: Int?
    @Published var turningPointMoveNumber: Int?

    // Two-Player Tabletop 180° Face-to-Face Mode + Parent-Child Assist
    @Published var isTabletopFaceToFace: Bool = false
    @Published var tabletopKidAssistColor: StoneColor? = nil

    // Co-op Pair Go vs Boss (Parent & Child alternate turns together!)
    @Published var isCoopMode: Bool = false
    @Published var coopTurnSeat: Int = 1 // 1 = Kid, 2 = Parent

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

    private let aiEngine: GoAIEngine
    private weak var appState: AppState?
    private var stateHistory: [GoBoardState] = []
    /// Tracks human-perspective lead after each ply for Time Hourglass turning-point analysis.
    private var humanLeadHistory: [Double] = [0]
    private var aiTask: Task<Void, Never>?
    private var bannerDismissTask: Task<Void, Never>?
    private var pocketAnimTask: Task<Void, Never>?
    private var clockTimer: Timer?
    private var lastTurnStartTime: Date = Date()
    private var didWarnImpulseThisTurn: Bool = false

    var isExamMatch: Bool {
        examTier != nil || (appState?.settings.assistPreset == .examSim)
    }

    var isUndoAllowed: Bool {
        !isExamMatch
    }

    var isGameOver: Bool {
        gameResult != nil
    }

    var isTwoPlayer: Bool {
        if case .twoPlayer = mode { return true }
        return false
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

    var requiresConfirmBeforePlace: Bool {
        guard let settings = appState?.settings else { return false }
        return settings.confirmBeforePlace && boardSize.rawValue >= 13
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
        isCoopMode: Bool = false,
        examTier: Int? = nil,
        aiEngine: GoAIEngine = CoreMLGoAIEngine.shared,
        appState: AppState? = nil
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
        self.isCoopMode = isCoopMode
        self.examTier = examTier
        self.aiEngine = aiEngine
        self.appState = appState

        let komi = handicap > 0 ? 0.5 : scoringRule.defaultKomi(for: boardSize)
        let initial = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: handicap)
        self.boardState = initial
        self.stateHistory = [initial]
        self.humanLeadHistory = [0]
        self.lastTurnStartTime = Date()

        startClockIfNeeded()
        triggerAIIfNeeded()
    }

    deinit {
        aiTask?.cancel()
        bannerDismissTask?.cancel()
        pocketAnimTask?.cancel()
        clockTimer?.invalidate()
    }

    private func startClockIfNeeded() {
        clockTimer?.invalidate()
        clockTimer = nil
        guard timeControl.isTimed else { return }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickClock()
            }
        }
    }

    private func tickClock() {
        guard timeControl.isTimed, !isGameOver, !isMarkingDeadStones else { return }
        let activeColor = boardState.currentTurn
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

        // Anti-Impulse Guard ("防随手冷静保护"): gentle nudge if a kid taps < 1.5s after opponent's move
        if appState?.settings.antiImpulseGuard == true,
           !didWarnImpulseThisTurn,
           moves.count >= 2,
           Date().timeIntervalSince(lastTurnStartTime) < 1.5,
           pendingPoint == nil {
            didWarnImpulseThisTurn = true
            SoundAndHapticsManager.shared.playHint()
            let isZh = appState?.l10n.language.isChinese ?? true
            showTransientBanner(
                isZh ? "别着急秒拍！先看一眼对手刚走的棋再落子哦 ✨" : "Hold on! Take 2 seconds to check your opponent's move first ✨",
                duration: 2.2
            )
            return
        }

        if requiresConfirmBeforePlace {
            if pendingPoint == point {
                confirmPendingPlacement()
            } else if boardState.stone(at: point) == nil {
                pendingPoint = point
                SoundAndHapticsManager.shared.playGridTick()
                statusBanner = nil
            } else {
                triggerIllegalFeedback(at: point, error: .occupied)
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
        guard isUndoAllowed, !isAIThinking, !isGameOver, !moves.isEmpty else { return }
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
        guard !isGameOver else { return }
        if ruleSet.isCaptureRace {
            let winner: StoneColor = boardState.blackCaptures >= boardState.whiteCaptures ? .black : .white
            finishGame(with: GameResult(
                winner: winner,
                blackScore: Double(boardState.blackCaptures),
                whiteScore: Double(boardState.whiteCaptures),
                komi: 0,
                byResignation: false,
                byCaptureRace: true,
                captureTarget: ruleSet.captureTarget,
                boardSize: boardSize.rawValue
            ))
            return
        }

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
        pocketAnimTask?.cancel()
        highlightedPocketPoints = []
        activeCountingPocketLabel = nil
        cancelDeadStoneReview()
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

    func cancelDeadStoneReview() {
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
        coopTurnSeat = 1
        companionMood = .greeting
        companionEvent = .greet

        let komi = handicap > 0 ? 0.5 : scoringRule.defaultKomi(for: boardSize)
        let initial = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: handicap)
        boardState = initial
        stateHistory = [initial]
        humanLeadHistory = [0]
        clock = GoClock(timeControl: timeControl)
        unsealedWarningPoints = []
        highlightedPocketPoints = []
        activeCountingPocketLabel = nil
        lastTurnStartTime = Date()
        didWarnImpulseThisTurn = false
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
            if isCoopMode {
                coopTurnSeat = (coopTurnSeat == 1) ? 2 : 1
            }
            applySuccessfulOutcome(outcome, action: action, color: color)
            if !isGameOver {
                triggerAIIfNeeded()
            }
        }
    }

    private func triggerIllegalFeedback(at point: BoardPoint, error: MoveError) {
        if error == .koViolation || error == .suicide {
            SoundAndHapticsManager.shared.playKoBounce()
            if error == .koViolation {
                appState?.unlockCodexTerm("ko", showToast: true)
            } else {
                appState?.unlockCodexTerm("suicide", showToast: true)
            }
        } else {
            SoundAndHapticsManager.shared.playWrong()
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
        guard !isGameOver, !isMarkingDeadStones, boardState.currentTurn != humanColor else { return }

        isAIThinking = true
        companionMood = .thinking
        companionEvent = .thinking
        let snapshot = boardState
        let aiColor = boardState.currentTurn
        let currentRules = ruleSet
        let style = coachingStyle

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
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < 0.26 {
                try? await Task.sleep(nanoseconds: UInt64((0.26 - elapsed) * 1_000_000_000))
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
        didWarnImpulseThisTurn = false
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

        if !outcome.capturedPoints.isEmpty {
            lastCapturedPoints = outcome.capturedPoints
            captureEventID = UUID()
            SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
        } else if case .place = action {
            SoundAndHapticsManager.shared.playStonePlace()
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
            if boardState.blackCaptures >= target {
                finishGame(with: GameResult(
                    winner: .black,
                    blackScore: Double(boardState.blackCaptures),
                    whiteScore: Double(boardState.whiteCaptures),
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: target
                ))
                return
            } else if boardState.whiteCaptures >= target {
                finishGame(with: GameResult(
                    winner: .white,
                    blackScore: Double(boardState.blackCaptures),
                    whiteScore: Double(boardState.whiteCaptures),
                    komi: 0,
                    byResignation: false,
                    byCaptureRace: true,
                    captureTarget: target
                ))
                return
            }
        }

        if boardState.isDoublePassEnded {
            beginDeadStoneReview(bypassUnsealedWarning: true)
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

        bestMoveNumber = bestIdx
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
            } else {
                SoundAndHapticsManager.shared.playVictoryFanfare()
            }
        }

        guard let appState else { return }
        let l10n = appState.l10n
        let blackName: String
        let whiteName: String

        switch mode {
        case .vsAI(let diff, let humanColor):
            let aiName = "\(l10n.t(diff.nameKey)) (\(diff.rankBadge))"
            let playerLabel = isCoopMode ? l10n.t("game.coopTeamName", appState.profile.nickname) : appState.profile.nickname
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
            size: boardState.size,
            komi: boardState.komi,
            handicap: handicap,
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
        appState.saveCompletedGame(
            record,
            didHumanWin: didHumanWin,
            capturesByHuman: humanCaps,
            opponentDifficulty: examTier == nil ? aiDifficulty : nil,
            bossIslandId: bossIslandId
        )
    }
}

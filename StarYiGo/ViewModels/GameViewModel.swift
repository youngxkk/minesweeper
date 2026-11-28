//
//  GameViewModel.swift
//  StarYi Go
//

import Combine
import Foundation
import Observation
import UIKit

/// Isolated `@Observable` clock display state so 1 Hz timer ticks ONLY re-render
/// tiny clock pills without invalidating the 2,000-line `GamePlayView` or `GoBoardView`.
@MainActor
@Observable
final class GameClockDisplayState {
    var clock: GoClock
    var blackElapsedSeconds: Int = 0
    var whiteElapsedSeconds: Int = 0

    init(clock: GoClock) {
        self.clock = clock
    }

    func formattedElapsedTime(for color: StoneColor) -> String {
        let secs = color == .black ? blackElapsedSeconds : whiteElapsedSeconds
        let m = secs / 60
        let s = secs % 60
        return String(format: "%02d:%02d", m, s)
    }
}

enum CompanionMood: Equatable {
    case greeting
    case thinking
    case surprised
    case excited
    case playful
    case calm
    case cheering
}

enum BestMoveReason: Equatable, Sendable {
    case capture(count: Int)
    case rescue(stoneCount: Int)
    case doubleAtari
    case bigAtari(stoneCount: Int)
    case territoryGain

    func badge(_ l10n: L10n) -> String {
        switch self {
        case .capture(let count):
            return l10n.localized(
                zh: count >= 2 ? "一举提掉 \(count) 子" : "漂亮提子",
                en: count >= 2 ? "Captured \(count) stones" : "Clean capture",
                ja: count >= 2 ? "\(count)子取り" : "ナイス抜き",
                ko: count >= 2 ? "\(count)점 따냄" : "깔끔한 따내기",
                zhHant: count >= 2 ? "一舉提掉 \(count) 子" : "漂亮提子"
            )
        case .rescue(let stoneCount):
            return l10n.localized(
                zh: stoneCount >= 2 ? "绝境救回 \(stoneCount) 子" : "及时逃出叫吃",
                en: stoneCount >= 2 ? "Saved \(stoneCount) stones" : "Escaped Atari",
                ja: stoneCount >= 2 ? "\(stoneCount)子を救出" : "アタリ脱出",
                ko: stoneCount >= 2 ? "\(stoneCount)점 구출" : "단수 탈출",
                zhHant: stoneCount >= 2 ? "絕境救回 \(stoneCount) 子" : "及時逃出叫吃"
            )
        case .doubleAtari:
            return l10n.localized(
                zh: "精彩双打吃",
                en: "Double Atari",
                ja: "見事な両アタリ",
                ko: "멋진 양단수",
                zhHant: "精彩雙打吃"
            )
        case .bigAtari(let stoneCount):
            return l10n.localized(
                zh: "叫吃对方 \(stoneCount) 子",
                en: "Atari on \(stoneCount) stones",
                ja: "\(stoneCount)子にアタリ",
                ko: "\(stoneCount)점 단수",
                zhHant: "叫吃對方 \(stoneCount) 子"
            )
        case .territoryGain:
            return l10n.localized(
                zh: "巧妙围出大空",
                en: "Big Territory",
                ja: "大きな地を確保",
                ko: "큰 집 확보",
                zhHant: "巧妙圍出大空"
            )
        }
    }
}

struct TimeHourglassAnalysis: Equatable, Sendable {
    let bestMoveNumber: Int?
    let bestMoveReason: BestMoveReason?
    let turningPointMoveNumber: Int?
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
    @Published var showAIResignOfferDialog: Bool = false
    @Published var aiResignOfferLead: Double = 0
    @Published var highlightedPocketPoints: Set<BoardPoint> = []
    @Published var activeCountingPocketLabel: String? = nil

    // Go Clock & Byoyomi State + Per-Player Elapsed Time (stored without @Published to avoid 1 Hz full-view invalidation;
    // UI clock pills observe `clockDisplay` directly via Observation).
    let clockDisplay: GameClockDisplayState
    var clock: GoClock {
        didSet { clockDisplay.clock = clock }
    }
    var blackElapsedSeconds: Int = 0 {
        didSet { clockDisplay.blackElapsedSeconds = blackElapsedSeconds }
    }
    var whiteElapsedSeconds: Int = 0 {
        didSet { clockDisplay.whiteElapsedSeconds = whiteElapsedSeconds }
    }

    /// Cached per-move board graph analysis so `GamePlayView` / `GoBoardView` don't repeat full-board BFS on every render.
    private(set) var cachedAtariPoints: Set<BoardPoint> = []
    private var hasFinalizedMatchOnce: Bool = false

    // Nintendo Companion Personality State
    @Published var companionMood: CompanionMood = .greeting
    @Published var companionEvent: CompanionEvent = .greet

    // Time Hourglass Highlight & Turning-Point Analysis
    @Published var bestMoveNumber: Int?
    @Published var bestMoveReason: BestMoveReason?
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
    private var hintTask: Task<Void, Never>?
    private var bannerDismissTask: Task<Void, Never>?
    private var pocketAnimTask: Task<Void, Never>?
    private var isSuspended = false
    private var clockTimer: Timer?
    private var lastTurnStartTime: Date = Date()
    private var lastHumanThinkDuration: TimeInterval?
    private let simulateHumanThinkingPacing: Bool
    private var consecutiveAIHopelessTurns: Int = 0
    private var aiResignOfferDeclined: Bool = false
    private var deferredAIMoveAfterResignOffer: (action: MoveAction, color: StoneColor)? = nil

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

    var isRegularAIMatch: Bool {
        !isTwoPlayer && !isExamMatch && bossIslandId == nil && tacticalScenario == nil
    }

    var hasHumanMoved: Bool {
        if let humanColor {
            return moves.contains { $0.color == humanColor }
        }
        return !moves.isEmpty
    }

    /// Whether the top-bar "Resume Last Match" button may be offered for this match.
    /// Hidden once the player has started playing in the current match.
    var canOfferResumePausedAIMatch: Bool {
        isRegularAIMatch && !isGameOver && !hasHumanMoved
    }

    var shouldConfirmBeforeLeaving: Bool {
        !isTwoPlayer && !isGameOver && !moves.isEmpty
    }

    func makePausedAIMatchSnapshot() -> PausedAIMatchSnapshot? {
        guard case .vsAI(let difficulty, let playerColor) = mode,
              isRegularAIMatch,
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
        guard !isGameOver, !isMarkingDeadStones, !showAIResignOfferDialog else { return false }
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

    private var cachedMoveNumberLookup: [BoardPoint: Int] = [:]

    var moveNumberLookup: [BoardPoint: Int] {
        cachedMoveNumberLookup
    }

    private func rebuildMoveNumberLookup() {
        var map: [BoardPoint: Int] = [:]
        map.reserveCapacity(moves.count)
        for move in moves {
            if case .place(let pt) = move.action, boardState.stone(at: pt) != nil {
                map[pt] = move.moveNumber
            }
        }
        cachedMoveNumberLookup = map
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
        simulateHumanThinkingPacing: Bool = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil,
        deferInitialStart: Bool = false
    ) {
        self.boardSize = boardSize
        self.mode = mode
        self.ruleSet = ruleSet
        self.scoringRule = scoringRule
        self.timeControl = timeControl
        self.coachingStyle = coachingStyle
        let initialClock = GoClock(timeControl: timeControl)
        self.clock = initialClock
        self.clockDisplay = GameClockDisplayState(clock: initialClock)
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
            let komi = handicap >= 2 ? 0.5 : scoringRule.defaultKomi(for: boardSize)
            initial = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: handicap)
        }
        self.boardState = initial
        self.cachedAtariPoints = initial.atariPoints()
        self.stateHistory = [initial]
        self.humanLeadHistory = [0]
        self.lastTurnStartTime = Date()

        if !deferInitialStart {
            startClockIfNeeded()
            triggerAIIfNeeded()
        }
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
            simulateHumanThinkingPacing: simulateHumanThinkingPacing,
            deferInitialStart: true
        )
        restore(from: snapshot)
    }

    private func restore(from snapshot: PausedAIMatchSnapshot) {
        aiTask?.cancel()
        isAIThinking = false
        pendingPoint = nil
        suggestions = []

        let komi = snapshot.handicap >= 2 ? 0.5 : snapshot.scoringRule.defaultKomi(for: snapshot.boardSize)
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
                leads.append(0)
            }
        }

        boardState = state
        cachedAtariPoints = state.atariPoints()
        stateHistory = history
        moves = replayedMoves
        rebuildMoveNumberLookup()
        humanLeadHistory = leads
        clock = snapshot.clock
        blackElapsedSeconds = snapshot.blackElapsedSeconds
        whiteElapsedSeconds = snapshot.whiteElapsedSeconds
        lastTurnStartTime = Date()
        lastHumanThinkDuration = nil
        consecutiveAIHopelessTurns = 0
        aiResignOfferDeclined = false
        deferredAIMoveAfterResignOffer = nil
        showAIResignOfferDialog = false
        aiResignOfferLead = 0
        companionMood = .greeting
        companionEvent = .greet

        startClockIfNeeded()
        triggerAIIfNeeded()
    }

    deinit {
        aiTask?.cancel()
        hintTask?.cancel()
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
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tickClock()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        clockTimer = timer
    }

    func setSuspended(_ suspended: Bool) {
        guard isSuspended != suspended else { return }
        isSuspended = suspended
        if suspended {
            clockTimer?.invalidate()
            clockTimer = nil
            aiTask?.cancel()
            hintTask?.cancel()
            hintTask = nil
            isComputingHint = false
            isAIThinking = false
        } else if !isGameOver {
            startClockIfNeeded()
            triggerAIIfNeeded()
        }
    }

    func tickClock() {
        guard !isSuspended, !isGameOver, !isMarkingDeadStones, !showAIResignOfferDialog else { return }
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
        showAIResignOfferDialog = false
        deferredAIMoveAfterResignOffer = nil
        consecutiveAIHopelessTurns = 0
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
        lastTurnStartTime = Date()
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
        showAIResignOfferDialog = false
        deferredAIMoveAfterResignOffer = nil
        consecutiveAIHopelessTurns = 0
        aiResignOfferDeclined = false
        aiResignOfferLead = 0
        pendingPoint = nil
        suggestions = []
        statusBanner = nil
        gameResult = nil
        savedRecordId = nil
        bestMoveNumber = nil
        bestMoveReason = nil
        turningPointMoveNumber = nil
        showTerritoryOverlay = false
        territoryEstimate = nil

        stateHistory = Array(stateHistory.prefix(targetStateIndex + 1))
        hintTask?.cancel()
        hintTask = nil
        isComputingHint = false
        moves = Array(moves.prefix(targetStateIndex))
        rebuildMoveNumberLookup()
        humanLeadHistory = Array(humanLeadHistory.prefix(targetStateIndex + 1))
        boardState = stateHistory.last ?? GoBoardState(size: boardSize.rawValue, handicap: handicap)
        cachedAtariPoints = boardState.atariPoints()

        // If rewinding from a flagged timeout, grant safe grace time so the player can actually continue
        if clock.isActive {
            if clock.black.isFlagged {
                clock.black.mainSecondsRemaining = max(clock.black.mainSecondsRemaining, 60)
                if clock.black.periodDuration > 0 {
                    clock.black.byoyomiPeriodsRemaining = max(clock.black.byoyomiPeriodsRemaining, 1)
                    clock.black.byoyomiSecondsRemaining = clock.black.periodDuration
                }
            }
            if clock.white.isFlagged {
                clock.white.mainSecondsRemaining = max(clock.white.mainSecondsRemaining, 60)
                if clock.white.periodDuration > 0 {
                    clock.white.byoyomiPeriodsRemaining = max(clock.white.byoyomiPeriodsRemaining, 1)
                    clock.white.byoyomiSecondsRemaining = clock.white.periodDuration
                }
            }
        }
        lastTurnStartTime = Date()

        companionMood = .cheering
        companionEvent = .greet
        SoundAndHapticsManager.shared.playHourglassRewind()
        SoundAndHapticsManager.shared.playVoice(.rewind, delay: 0.12)

        startClockIfNeeded()
        triggerAIIfNeeded()
    }

    func requestHint() {
        guard isHumansTurn, !isAIThinking, !isComputingHint, !isGameOver else { return }
        hintTask?.cancel()
        isComputingHint = true
        suggestions = []
        let snapshot = boardState
        let color = boardState.currentTurn
        let expectedHash = snapshot.boardHash
        let expectedMoveCount = snapshot.moveCount

        hintTask = Task { [weak self] in
            guard let self else { return }
            let results = await self.aiEngine.suggestMoves(for: snapshot, color: color, count: 2)
            guard !Task.isCancelled,
                  self.boardState.boardHash == expectedHash,
                  self.boardState.moveCount == expectedMoveCount,
                  !self.isGameOver else {
                self.isComputingHint = false
                return
            }
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

    func acceptAIResignation() {
        guard !isGameOver else { return }
        aiTask?.cancel()
        isAIThinking = false
        showAIResignOfferDialog = false
        let aiColor = deferredAIMoveAfterResignOffer?.color ?? (humanColor?.opposite ?? boardState.currentTurn)
        deferredAIMoveAfterResignOffer = nil
        let result = GameResult(
            winner: aiColor.opposite,
            blackScore: 0,
            whiteScore: 0,
            komi: boardState.komi,
            byResignation: true,
            scoringRule: scoringRule,
            boardSize: boardSize.rawValue
        )
        finishGame(with: result)
    }

    func declineAIResignation() {
        showAIResignOfferDialog = false
        aiResignOfferDeclined = true
        guard let deferred = deferredAIMoveAfterResignOffer else {
            triggerAIIfNeeded()
            return
        }
        deferredAIMoveAfterResignOffer = nil
        guard !isGameOver, boardState.currentTurn == deferred.color else { return }
        switch boardState.applying(action: deferred.action, color: deferred.color) {
        case .success(let outcome):
            applySuccessfulOutcome(outcome, action: deferred.action, color: deferred.color)
        case .failure:
            if case .success(let passOut) = boardState.applying(action: .pass, color: deferred.color) {
                applySuccessfulOutcome(passOut, action: .pass, color: deferred.color)
            }
        }
    }

    func resignCurrentPlayer() {
        guard !isGameOver else { return }
        aiTask?.cancel()
        isAIThinking = false
        isMarkingDeadStones = false
        showAIResignOfferDialog = false
        deferredAIMoveAfterResignOffer = nil
        pendingPoint = nil

        let loser: StoneColor = humanColor ?? boardState.currentTurn
        let winner = loser.opposite
        let result = GameResult(
            winner: winner,
            blackScore: 0,
            whiteScore: 0,
            komi: boardState.komi,
            byResignation: true,
            scoringRule: scoringRule,
            boardSize: boardSize.rawValue
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
        showAIResignOfferDialog = false
        deferredAIMoveAfterResignOffer = nil
        consecutiveAIHopelessTurns = 0
        aiResignOfferDeclined = false
        aiResignOfferLead = 0
        pendingPoint = nil
        suggestions = []
        statusBanner = nil
        gameResult = nil
        savedRecordId = nil
        bestMoveNumber = nil
        bestMoveReason = nil
        turningPointMoveNumber = nil
        showTerritoryOverlay = false
        territoryEstimate = nil
        lastCapturedPoints = []
        illegalFlashPoint = nil
        hintTask?.cancel()
        hintTask = nil
        isComputingHint = false
        moves = []
        cachedMoveNumberLookup = [:]
        companionMood = .greeting
        companionEvent = .greet

        let initial: GoBoardState
        if let scenario = tacticalScenario {
            initial = scenario.makeInitialState()
        } else {
            let komi = handicap >= 2 ? 0.5 : scoringRule.defaultKomi(for: boardSize)
            initial = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: handicap)
        }
        boardState = initial
        cachedAtariPoints = initial.atariPoints()
        hasFinalizedMatchOnce = false
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
            if isRegularAIMatch && appState?.pausedAIMatch != nil {
                appState?.clearPausedAIMatch()
            }
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
        guard !isSuspended, !isGameOver, !isMarkingDeadStones, !showAIResignOfferDialog, boardState.currentTurn != humanColor else { return }

        isAIThinking = true
        companionMood = .thinking
        companionEvent = .thinking
        let snapshot = boardState
        let aiColor = boardState.currentTurn
        let currentRules = ruleSet
        let style = coachingStyle
        let humanThinkDuration = lastHumanThinkDuration
        let clockSnapshot = clock
        let configuredPace = appState?.settings.aiThinkingPace ?? .brisk
        let effectivePace: AIThinkingPace = simulateHumanThinkingPacing ? configuredPace : .instant

        aiTask?.cancel()
        aiTask = Task { [weak self] in
            let start = Date()
            let decision = await self?.aiEngine.selectMoveDecision(
                for: snapshot,
                color: aiColor,
                level: difficulty,
                ruleSet: currentRules,
                coachingStyle: style
            ) ?? AIMoveDecision(action: .pass)
            let moveAction = decision.action
            let targetDuration: TimeInterval = AIThinkingPacer.targetThinkingDuration(
                for: snapshot,
                difficulty: difficulty,
                chosenAction: moveAction,
                lastHumanThinkDuration: humanThinkDuration,
                clock: clockSnapshot,
                aiColor: aiColor,
                pace: effectivePace
            )
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < targetDuration {
                try? await Task.sleep(nanoseconds: UInt64((targetDuration - elapsed) * 1_000_000_000))
            }
            guard !Task.isCancelled, let self else { return }
            guard !self.isSuspended,
                  !self.isGameOver,
                  !self.isMarkingDeadStones,
                  self.boardState.boardHash == snapshot.boardHash,
                  self.boardState.moveCount == snapshot.moveCount else {
                self.isAIThinking = false
                return
            }
            self.isAIThinking = false

            let recentMaxCaptureAgainstAI = self.moves
                .suffix(4)
                .filter { $0.color == aiColor.opposite }
                .map { $0.capturedPoints.count }
                .max() ?? 0
            let resignCheck = AIResignationEvaluator.evaluate(
                state: snapshot,
                aiColor: aiColor,
                difficulty: difficulty,
                ruleSet: currentRules,
                isTacticalScenario: self.tacticalScenario != nil,
                consecutiveHopelessTurns: self.consecutiveAIHopelessTurns,
                chosenAction: moveAction,
                recentMaxCaptureAgainstAI: recentMaxCaptureAgainstAI,
                neuralWinrateForAI: decision.moverWinrate,
                neuralScoreLeadForAI: decision.moverScoreLead,
                neuralOwnershipForAI: decision.ownershipForMover
            )
            self.consecutiveAIHopelessTurns = resignCheck.nextConsecutiveHopelessTurns

            if !self.aiResignOfferDeclined && (moveAction == .resign || resignCheck.shouldOfferResign) {
                let fallbackAction: MoveAction = (moveAction == .resign) ? .pass : moveAction
                self.deferredAIMoveAfterResignOffer = (action: fallbackAction, color: aiColor)
                self.aiResignOfferLead = resignCheck.estimatedHumanLead
                self.companionMood = .surprised
                self.showAIResignOfferDialog = true
                SoundAndHapticsManager.shared.playHint()
                return
            }

            let effectiveAction: MoveAction = (moveAction == .resign) ? .pass : moveAction
            switch self.boardState.applying(action: effectiveAction, color: aiColor) {
            case .success(let outcome):
                self.applySuccessfulOutcome(outcome, action: effectiveAction, color: aiColor)
            case .failure:
                if case .success(let passOut) = self.boardState.applying(action: .pass, color: aiColor) {
                    self.applySuccessfulOutcome(passOut, action: .pass, color: aiColor)
                }
            }
        }
    }

    private func applySuccessfulOutcome(_ outcome: MoveOutcome, action: MoveAction, color: StoneColor) {
        hintTask?.cancel()
        hintTask = nil
        isComputingHint = false
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
        if case .place(let pt) = action {
            cachedMoveNumberLookup[pt] = move.moveNumber
            for cap in outcome.capturedPoints {
                cachedMoveNumberLookup.removeValue(forKey: cap)
            }
        }

        let est = GoScoring.estimateTerritory(state: outcome.nextState)
        let perspective = humanColor ?? .black
        let lead = (perspective == .black) ? est.blackLead : -est.blackLead
        humanLeadHistory.append(lead)

        let nextAtariPoints = outcome.nextState.atariPoints()
        cachedAtariPoints = nextAtariPoints
        updateCompanionReaction(move: move, outcome: outcome, nextAtariPoints: nextAtariPoints)

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

    private func updateCompanionReaction(move: GoMove, outcome: MoveOutcome, nextAtariPoints: Set<BoardPoint>) {
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
                let humanInAtari = nextAtariPoints.contains { outcome.nextState.stone(at: $0) == humanColor }
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
        let analysis = Self.analyzeTimeHourglassMoments(
            moves: moves,
            stateHistory: stateHistory,
            humanLeadHistory: humanLeadHistory,
            perspective: perspective,
            boardSize: boardSize.rawValue
        )
        bestMoveNumber = analysis.bestMoveNumber
        bestMoveReason = analysis.bestMoveReason
        turningPointMoveNumber = analysis.turningPointMoveNumber
    }

    /// Evaluates real tactical highlights (captures, Atari rescues, double/big Atari, and stabilized midgame territory gains)
    /// while excluding empty-board opening flood-fill spikes so Move 1 never falsely dominates "Best Move".
    static func analyzeTimeHourglassMoments(
        moves: [GoMove],
        stateHistory: [GoBoardState],
        humanLeadHistory: [Double],
        perspective: StoneColor,
        boardSize: Int
    ) -> TimeHourglassAnalysis {
        let openingSkipPlies: Int = {
            if boardSize <= 7 { return 2 }
            if boardSize <= 9 { return 4 }
            return 6
        }()

        var bestScore: Double = 0
        var bestMove: Int?
        var bestReason: BestMoveReason?

        var worstSeverity: Double = 0
        var worstMove: Int?

        for (i, move) in moves.enumerated() where move.color == perspective {
            guard case .place = move.action else { continue }
            guard i + 1 < stateHistory.count else { continue }

            let stateBefore = stateHistory[i]
            let stateAfter = stateHistory[i + 1]
            let blackBefore = stateBefore.grid.reduce(0) { $0 + ($1 == .black ? 1 : 0) }
            let whiteBefore = stateBefore.grid.reduce(0) { $0 + ($1 == .white ? 1 : 0) }
            let bothSidesEstablished = move.moveNumber > openingSkipPlies && blackBefore >= 3 && whiteBefore >= 3

            // 1. Tactical: Captures
            let capturedCount = move.capturedPoints.count
            let captureScore: Double = capturedCount > 0 ? (12.0 + Double(capturedCount) * 7.5) : 0

            // 2. Tactical: Rescuing a friendly group that was in Atari (1 liberty -> >= 2 liberties)
            var rescuedStones = 0
            let beforeGroups = stateBefore.allGroups()
            let endangeredBefore = beforeGroups.filter { $0.color == perspective && $0.liberties.count == 1 }
            if !endangeredBefore.isEmpty {
                for g in endangeredBefore {
                    if let anchor = g.stones.first,
                       stateAfter.grid[anchor] == perspective,
                       let afterGroup = stateAfter.groupAndLiberties(at: anchor),
                       afterGroup.liberties.count >= 2 {
                        rescuedStones = max(rescuedStones, g.stones.count)
                    }
                }
            }
            let rescueScore: Double = rescuedStones > 0 ? (10.0 + Double(rescuedStones) * 4.5) : 0

            // 3. Tactical: Double Atari or Big Atari on opponent groups
            let oppColor = perspective.opposite
            let beforeOppAtariAnchors: Set<Int> = Set(
                beforeGroups
                    .filter { $0.color == oppColor && $0.liberties.count == 1 }
                    .flatMap(\.stones)
            )
            let newlyAtariedOppGroups = stateAfter.allGroups().filter { group in
                group.color == oppColor
                    && group.liberties.count == 1
                    && group.stones.contains { !beforeOppAtariAnchors.contains($0) }
            }
            let isDoubleAtari = newlyAtariedOppGroups.count >= 2
            let maxAtariedOppStones = newlyAtariedOppGroups.map(\.stones.count).max() ?? 0
            let attackScore: Double = {
                if isDoubleAtari { return 26.0 }
                if maxAtariedOppStones >= 2 { return 9.0 + Double(maxAtariedOppStones) * 3.0 }
                return 0
            }()

            // 4. Positional: Stabilized mid/endgame territory gain (never on empty opening boards!)
            let rawDelta: Double = {
                guard i + 1 < humanLeadHistory.count else { return 0 }
                return humanLeadHistory[i + 1] - humanLeadHistory[i]
            }()
            let clampedDelta = min(14.0, max(-14.0, rawDelta))
            let territoryScore: Double = (bothSidesEstablished && clampedDelta >= 3.0) ? (clampedDelta * 0.9) : 0

            let hasTacticalHighlight = captureScore > 0 || rescueScore > 0 || attackScore > 0
            if move.moveNumber <= openingSkipPlies && !hasTacticalHighlight {
                continue
            }

            let moveScore = max(captureScore, max(rescueScore, max(attackScore, territoryScore)))
                + (hasTacticalHighlight && bothSidesEstablished && clampedDelta > 0 ? min(4.0, clampedDelta * 0.25) : 0)

            let candidateReason: BestMoveReason? = {
                if captureScore >= rescueScore && captureScore >= attackScore && captureScore > 0 {
                    return .capture(count: capturedCount)
                }
                if rescueScore >= attackScore && rescueScore > 0 {
                    return .rescue(stoneCount: rescuedStones)
                }
                if isDoubleAtari {
                    return .doubleAtari
                }
                if maxAtariedOppStones >= 2 {
                    return .bigAtari(stoneCount: maxAtariedOppStones)
                }
                if territoryScore > 0 {
                    return .territoryGain
                }
                return nil
            }()

            if let candidateReason, moveScore > bestScore {
                bestScore = moveScore
                bestMove = move.moveNumber
                bestReason = candidateReason
            }

            // Turning point evaluation (only after opening settles, or when opponent immediately captures >= 2 stones)
            var blunderSeverity: Double = 0
            if bothSidesEstablished && rawDelta < -2.5 {
                blunderSeverity = max(blunderSeverity, min(20.0, -rawDelta))
            }
            if i + 1 < moves.count {
                let oppReply = moves[i + 1]
                if oppReply.color == oppColor && oppReply.capturedPoints.count >= 2 {
                    blunderSeverity = max(blunderSeverity, 8.0 + Double(oppReply.capturedPoints.count) * 4.0)
                }
            }
            if blunderSeverity > worstSeverity {
                worstSeverity = blunderSeverity
                worstMove = move.moveNumber
            }
        }

        let hasAnyTactical = bestReason != nil && bestReason != .territoryGain
        let finalBestMove: Int?
        let finalBestReason: BestMoveReason?
        if bestScore >= 3.5 && (moves.count >= 6 || hasAnyTactical) {
            finalBestMove = bestMove
            finalBestReason = bestReason
        } else {
            finalBestMove = nil
            finalBestReason = nil
        }

        let finalTurningPoint: Int?
        if let worstMove {
            finalTurningPoint = worstMove
        } else if moves.count >= openingSkipPlies + 3 {
            finalTurningPoint = max(openingSkipPlies + 1, moves.count - 3)
        } else {
            finalTurningPoint = nil
        }

        return TimeHourglassAnalysis(
            bestMoveNumber: finalBestMove,
            bestMoveReason: finalBestReason,
            turningPointMoveNumber: finalTurningPoint
        )
    }

    private func popOnePly() {
        guard stateHistory.count > 1, !moves.isEmpty else { return }
        hintTask?.cancel()
        hintTask = nil
        isComputingHint = false
        stateHistory.removeLast()
        moves.removeLast()
        if humanLeadHistory.count > 1 { humanLeadHistory.removeLast() }
        if let previous = stateHistory.last {
            boardState = previous
            cachedAtariPoints = previous.atariPoints()
        }
        rebuildMoveNumberLookup()
    }

    private func refreshTerritoryIfVisible() {
        if showTerritoryOverlay {
            territoryEstimate = GoScoring.estimateTerritory(state: boardState, deadStoneIndices: markedDeadIndices)
        }
    }

    private func finishGame(with result: GameResult) {
        clockTimer?.invalidate()
        clockTimer = nil
        aiTask?.cancel()
        hintTask?.cancel()
        hintTask = nil
        isAIThinking = false
        isComputingHint = false
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
        let isFirstFinalization = !hasFinalizedMatchOnce
        hasFinalizedMatchOnce = true
        if isFirstFinalization {
            ReviewPromptPolicy.shared.recordCompletedGame()
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
}

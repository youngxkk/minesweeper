//
//  PuzzleViewModel.swift
//  StarYi Go — Upgraded Multi-Branch, Symmetry-Transform & Variation-Study Puzzle Engine
//

import Combine
import Foundation

enum PuzzleStatus: Equatable {
    case playing
    case opponentResponding
    case solved(stars: Int)
    case wrong
    case playingSolution
}

@MainActor
final class PuzzleViewModel: ObservableObject {
    @Published var puzzle: GoPuzzle
    @Published var boardState: GoBoardState
    @Published var status: PuzzleStatus = .playing
    @Published var attempts: Int = 0
    @Published var wrongCount: Int = 0
    @Published var usedHint: Bool = false
    @Published var highlightedHintPoint: BoardPoint?
    @Published var showHintText: Bool = false
    @Published var unlockedCodexEntry: GoCodexEntry? = nil

    // P1 Enhancements: Symmetry/Color Transform, Failure Variation Exploration, Exam Mode, Solution Playback
    @Published var activeTransform: PuzzleTransform = .identity
    @Published var isExploringFailure: Bool = false
    @Published var isExamMode: Bool = false
    @Published var failureFollowUpCount: Int = 0

    // Tactile board feedback events
    @Published var lastCapturedPoints: [BoardPoint] = []
    @Published var captureEventID: UUID = UUID()
    @Published var illegalFlashPoint: BoardPoint?
    @Published var illegalEventID: UUID = UUID()

    private var rootNode: SGFNode?
    private var currentNode: SGFNode?
    private weak var appState: AppState?
    private var responseTask: Task<Void, Never>?
    let isDailyChallenge: Bool
    let isStarterBootcamp: Bool
    let forceRandomTransform: Bool
    let dailyDojoQueueIds: [String]

    var dailyDojoProgress: (current: Int, total: Int)? {
        guard isDailyChallenge, !dailyDojoQueueIds.isEmpty,
              let idx = dailyDojoQueueIds.firstIndex(of: puzzle.id) else {
            return nil
        }
        return (idx + 1, dailyDojoQueueIds.count)
    }

    var effectivePlayerColor: StoneColor {
        activeTransform.apply(to: puzzle.playerColor)
    }

    var effectiveCropRegion: BoardCropRegion {
        activeTransform.apply(to: puzzle.cropRegion, boardSize: puzzle.boardSize)
    }

    init(
        puzzle: GoPuzzle,
        appState: AppState? = nil,
        isDailyChallenge: Bool = false,
        isStarterBootcamp: Bool = false,
        isExamMode: Bool = false,
        forceRandomTransform: Bool = false,
        dailyDojoQueueIds: [String] = []
    ) {
        self.puzzle = puzzle
        self.appState = appState
        self.isDailyChallenge = isDailyChallenge
        self.isStarterBootcamp = isStarterBootcamp
        self.isExamMode = isExamMode
        self.forceRandomTransform = forceRandomTransform
        self.dailyDojoQueueIds = dailyDojoQueueIds

        let initialTransform: PuzzleTransform
        if forceRandomTransform || (!isStarterBootcamp && (appState?.settings.autoTransformPuzzles == true)) {
            var candidate = PuzzleTransform.random(allowColorSwap: true)
            if forceRandomTransform && candidate.isIdentity {
                candidate = PuzzleTransform(
                    rotation: Int.random(in: 1..<4),
                    mirrored: Bool.random(),
                    swapColors: Bool.random()
                )
            }
            initialTransform = candidate
        } else {
            initialTransform = .identity
        }
        self.activeTransform = initialTransform
        self.boardState = puzzle.initialBoardState(transform: initialTransform)
        self.rootNode = puzzle.parsedRoot(transform: initialTransform)
        self.currentNode = self.rootNode
    }

    deinit {
        responseTask?.cancel()
    }

    var relatedCodexEntry: GoCodexEntry? {
        let baseId = puzzle.id
            .replacingOccurrences(of: "-r90", with: "")
            .replacingOccurrences(of: "-wm", with: "")
            .replacingOccurrences(of: "-w", with: "")
            .replacingOccurrences(of: "-m", with: "")
        guard let termId = GoTermCodex.codexTermId(forPuzzleId: baseId) else { return nil }
        return GoTermCodex.entry(withId: termId)
    }

    func loadPuzzle(_ newPuzzle: GoPuzzle) {
        responseTask?.cancel()
        puzzle = newPuzzle
        attempts = 0
        wrongCount = 0
        usedHint = false
        highlightedHintPoint = nil
        showHintText = false
        unlockedCodexEntry = nil
        isExploringFailure = false
        failureFollowUpCount = 0
        lastCapturedPoints = []
        illegalFlashPoint = nil

        let shouldTransformDailyTwist: Bool = {
            guard isDailyChallenge, let idx = dailyDojoQueueIds.firstIndex(of: newPuzzle.id) else {
                return false
            }
            return idx == 1 // Stage 2 (承 · 变向) always uses rotated/mirrored/color-swapped view
        }()

        if forceRandomTransform || shouldTransformDailyTwist || (!isStarterBootcamp && !isDailyChallenge && (appState?.settings.autoTransformPuzzles == true)) {
            var candidate = PuzzleTransform.random(allowColorSwap: true)
            if (forceRandomTransform || shouldTransformDailyTwist) && candidate.isIdentity {
                candidate = PuzzleTransform(
                    rotation: Int.random(in: 1..<4),
                    mirrored: Bool.random(),
                    swapColors: Bool.random()
                )
            }
            activeTransform = candidate
        } else {
            activeTransform = .identity
        }
        boardState = newPuzzle.initialBoardState(transform: activeTransform)
        rootNode = newPuzzle.parsedRoot(transform: activeTransform)
        currentNode = rootNode
        status = .playing
    }

    /// Rotates / mirrors / color-swaps the puzzle so kids train true reading instead of memorizing corner coordinates!
    func shuffleTransform() {
        responseTask?.cancel()
        var next = PuzzleTransform.random(allowColorSwap: true)
        if next == activeTransform {
            next = PuzzleTransform(rotation: (activeTransform.rotation + 1) % 4, mirrored: !activeTransform.mirrored, swapColors: !activeTransform.swapColors)
        }
        activeTransform = next
        highlightedHintPoint = nil
        isExploringFailure = false
        failureFollowUpCount = 0
        lastCapturedPoints = []
        illegalFlashPoint = nil
        boardState = puzzle.initialBoardState(transform: activeTransform)
        rootNode = puzzle.parsedRoot(transform: activeTransform)
        currentNode = rootNode
        status = .playing
        SoundAndHapticsManager.shared.playUITap()
    }

    func resetCurrentPuzzle() {
        responseTask?.cancel()
        highlightedHintPoint = nil
        isExploringFailure = false
        failureFollowUpCount = 0
        lastCapturedPoints = []
        illegalFlashPoint = nil
        boardState = puzzle.initialBoardState(transform: activeTransform)
        currentNode = rootNode
        status = .playing
        SoundAndHapticsManager.shared.playUndo()
    }

    func showHint() {
        // Daily Dojo forbids hints so kids build genuine reading & perseverance!
        guard !isExamMode, !isDailyChallenge, status == .playing, let node = currentNode else { return }
        usedHint = true
        showHintText = true
        highlightedHintPoint = GoPuzzle.firstCorrectMove(from: node)
        SoundAndHapticsManager.shared.playHint()
        SoundAndHapticsManager.shared.playVoice(.hint, delay: 0.08)
    }

    /// Plays the official correct Principal Variation step-by-step on the board so kids see the exact solution!
    func playCorrectSolution() {
        guard !isExamMode, !isDailyChallenge, let root = rootNode else { return }
        let line = GoPuzzle.solutionLine(from: root)
        guard !line.isEmpty else { return }

        responseTask?.cancel()
        usedHint = true
        isExploringFailure = false
        highlightedHintPoint = nil
        boardState = puzzle.initialBoardState(transform: activeTransform)
        status = .playingSolution

        responseTask = Task { [weak self] in
            for step in line {
                try? await Task.sleep(nanoseconds: 620_000_000)
                guard !Task.isCancelled, let self else { return }
                if case .success(let out) = self.boardState.applying(action: .place(step.point), color: step.color) {
                    self.boardState = out.nextState
                    if !out.capturedPoints.isEmpty {
                        self.lastCapturedPoints = out.capturedPoints
                        self.captureEventID = UUID()
                        SoundAndHapticsManager.shared.playCapture(count: out.capturedPoints.count)
                    } else {
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                }
            }
            guard !Task.isCancelled, let self else { return }
            self.status = .wrong // Keep reset available so they can solve it themselves for stars!
        }
    }

    func handleTap(at point: BoardPoint) {
        // Allow free follow-up exploration after a wrong move so kids visually see WHY their move fails!
        if status == .wrong && isExploringFailure {
            handleFailureExplorationTap(at: point)
            return
        }

        guard status == .playing, let node = currentNode else { return }

        guard case .success(let outcome) = boardState.applying(action: .place(point), color: effectivePlayerColor) else {
            illegalFlashPoint = point
            illegalEventID = UUID()
            SoundAndHapticsManager.shared.playKoBounce()
            SoundAndHapticsManager.shared.playVoice(.illegalMove, delay: 0.08, cooldown: 1.5)
            return
        }

        attempts += 1
        highlightedHintPoint = nil
        boardState = outcome.nextState

        if !outcome.capturedPoints.isEmpty {
            lastCapturedPoints = outcome.capturedPoints
            captureEventID = UUID()
            SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
        } else {
            SoundAndHapticsManager.shared.playStonePlace()
        }

        let matchedChild = node.children.first { child in
            if let move = child.move, case .place(let childPt) = move.action {
                return childPt == point && move.color == effectivePlayerColor
            }
            return false
        }

        guard let nextNode = matchedChild else {
            demonstrateUnscriptedRefutation(after: point)
            return
        }

        currentNode = nextNode

        if let comment = nextNode.comment?.uppercased(), comment.contains("CORRECT") {
            markSolved()
            return
        }

        // Pick randomly among ALL valid opponent response branches (instead of always children.first!)
        let oppResponses = nextNode.children.filter { child in
            if let oppMove = child.move {
                return oppMove.color == effectivePlayerColor.opposite
            }
            return false
        }

        if let oppResponse = oppResponses.randomElement(),
           let oppMove = oppResponse.move {
            status = .opponentResponding
            responseTask?.cancel()
            responseTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 360_000_000)
                guard !Task.isCancelled, let self else { return }

                if case .success(let oppOutcome) = self.boardState.applying(action: oppMove.action, color: oppMove.color) {
                    self.boardState = oppOutcome.nextState
                    if !oppOutcome.capturedPoints.isEmpty {
                        self.lastCapturedPoints = oppOutcome.capturedPoints
                        self.captureEventID = UUID()
                        SoundAndHapticsManager.shared.playCapture(count: oppOutcome.capturedPoints.count)
                    } else {
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                }
                self.currentNode = oppResponse

                if let c = oppResponse.comment?.uppercased(), c.contains("WRONG") {
                    self.markWrong(at: nil)
                } else if let c = oppResponse.comment?.uppercased(), c.contains("CORRECT") {
                    self.markSolved()
                } else if oppResponse.children.isEmpty {
                    self.markWrong(at: nil)
                } else {
                    self.status = .playing
                }
            }
        } else if let comment = nextNode.comment?.uppercased(), comment.contains("WRONG") {
            markWrong(at: point)
        } else if GoPuzzle.isCorrectBranch(nextNode) {
            markSolved()
        } else {
            markWrong(at: point)
        }
    }

    private func handleFailureExplorationTap(at point: BoardPoint) {
        guard failureFollowUpCount < 4 else { return }
        let mover = effectivePlayerColor
        guard case .success(let outcome) = boardState.applying(action: .place(point), color: mover) else {
            illegalFlashPoint = point
            illegalEventID = UUID()
            SoundAndHapticsManager.shared.playKoBounce()
            return
        }
        failureFollowUpCount += 1
        boardState = outcome.nextState
        if !outcome.capturedPoints.isEmpty {
            lastCapturedPoints = outcome.capturedPoints
            captureEventID = UUID()
            SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
        } else {
            SoundAndHapticsManager.shared.playStonePlace()
        }

        let oppColor = mover.opposite
        let snapshot = boardState
        let region = effectiveCropRegion
        responseTask?.cancel()
        responseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled, let self else { return }
            if let reply = LocalMCTSGoEngine.bestLocalReply(for: snapshot, color: oppColor, near: point, within: region),
               case .success(let oppOut) = self.boardState.applying(action: reply, color: oppColor) {
                self.boardState = oppOut.nextState
                if !oppOut.capturedPoints.isEmpty {
                    self.lastCapturedPoints = oppOut.capturedPoints
                    self.captureEventID = UUID()
                    SoundAndHapticsManager.shared.playCapture(count: oppOut.capturedPoints.count)
                } else {
                    SoundAndHapticsManager.shared.playStonePlace()
                }
            }
        }
    }

    private func demonstrateUnscriptedRefutation(after point: BoardPoint) {
        let oppColor = effectivePlayerColor.opposite
        let snapshot = boardState
        let region = effectiveCropRegion

        status = .opponentResponding
        responseTask?.cancel()
        responseTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled, let self else { return }

            if let reply = LocalMCTSGoEngine.bestLocalReply(for: snapshot, color: oppColor, near: point, within: region),
               case .success(let oppOutcome) = self.boardState.applying(action: reply, color: oppColor) {
                self.boardState = oppOutcome.nextState
                if !oppOutcome.capturedPoints.isEmpty {
                    self.lastCapturedPoints = oppOutcome.capturedPoints
                    self.captureEventID = UUID()
                    SoundAndHapticsManager.shared.playCapture(count: oppOutcome.capturedPoints.count)
                } else {
                    SoundAndHapticsManager.shared.playStonePlace()
                }
            }
            self.markWrong(at: point)
        }
    }

    func nextPuzzleInLibrary() -> GoPuzzle? {
        if isDailyChallenge {
            guard let idx = dailyDojoQueueIds.firstIndex(of: puzzle.id),
                  idx + 1 < dailyDojoQueueIds.count else {
                return nil
            }
            return appState?.findAnyPuzzle(withId: dailyDojoQueueIds[idx + 1])
        }
        if isStarterBootcamp {
            let all = StarterBootcamp.puzzles
            guard let idx = all.firstIndex(where: { $0.id == puzzle.id }), idx + 1 < all.count else {
                return nil
            }
            return all[idx + 1]
        }

        // Check Island puzzles first, then full 320 Dojo Bank
        let islandAll = StarYiIslands.orderedPuzzles
        if let idx = islandAll.firstIndex(where: { $0.id == puzzle.id }), idx + 1 < islandAll.count {
            let next = islandAll[idx + 1]
            if let progress = appState?.puzzleProgress,
               StarYiIslands.isPuzzleUnlocked(puzzleId: next.id, progress: progress) {
                return next
            }
            return nil
        }

        let dojoAll = DojoPuzzleBank.allDojoPuzzles
        if let idx = dojoAll.firstIndex(where: { $0.id == puzzle.id }), idx + 1 < dojoAll.count {
            return dojoAll[idx + 1]
        }
        return nil
    }

    private func markSolved() {
        isExploringFailure = false
        let stars: Int
        if !usedHint && wrongCount == 0 {
            stars = 3
        } else if !usedHint && wrongCount == 1 {
            stars = 2
        } else {
            stars = 1
        }
        status = .solved(stars: stars)
        SoundAndHapticsManager.shared.playSuccess()
        SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.12)
        if isDailyChallenge {
            appState?.recordDailyDojoCorePuzzleSolved(puzzleId: puzzle.id, firstTry: wrongCount == 0)
        }
        unlockedCodexEntry = appState?.recordPuzzleSolved(
            puzzleId: puzzle.id,
            stars: stars,
            isDailyChallenge: isDailyChallenge,
            isStarterBootcamp: isStarterBootcamp
        )
    }

    private func markWrong(at point: BoardPoint?) {
        wrongCount += 1
        isExploringFailure = true
        failureFollowUpCount = 0
        if let point {
            illegalFlashPoint = point
            illegalEventID = UUID()
        }
        status = .wrong
        SoundAndHapticsManager.shared.playWrong()
        SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
        appState?.recordPuzzleMistake(puzzleId: puzzle.id, isStarterBootcamp: isStarterBootcamp)
    }
}

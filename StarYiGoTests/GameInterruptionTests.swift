import Foundation
import Testing
@testable import StarYiGo

@MainActor
struct GameInterruptionTests {
    @Test func whiteCanUndoTheirMoveButNotTheAIOpening() async throws {
        let model = GameViewModel(boardSize: .nine, mode: .vsAI(difficulty: .sprout, playerColor: .white), aiEngine: DelayedReply())
        let opening = try #require(model.aiTask)
        await opening.value
        let openingPosition = model.boardState
        #expect(!model.isUndoAllowed)
        model.undo()
        #expect(model.boardState == openingPosition)
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        let reply = try #require(model.aiTask)
        await reply.value
        #expect(model.isUndoAllowed)
        model.undo()
        #expect(model.boardState == openingPosition)
        #expect(model.moves.count == 1 && model.isHumansTurn)
    }

    @Test func resumingDisputeDuringAITurnProducesOneReply() async throws {
        let model = makeMatch()
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        let interrupted = try #require(model.aiTask)
        model.beginDeadStoneReview(bypassUnsealedWarning: true)
        #expect(model.isMarkingDeadStones)
        model.playOutDispute()
        let resumed = try #require(model.aiTask)
        #expect(model.isAIThinking)
        await interrupted.value
        await resumed.value
        #expect(model.moves.count == 2 && model.isHumansTurn)
        #expect(!model.isAIThinking)
    }

    @Test func resumingAfterTwoPassesLetsTheHumanPlayIfAIPassesAgain() async throws {
        let model = GameViewModel(boardSize: .nine, mode: .vsAI(difficulty: .sprout, playerColor: .white),
                                  aiEngine: DelayedReply(action: .pass))
        let firstPass = try #require(model.aiTask)
        await firstPass.value
        model.passTurn()
        #expect(model.isMarkingDeadStones)
        model.playOutDispute()
        let reply = try #require(model.aiTask)
        await reply.value
        #expect(model.moves.count == 3 && model.isHumansTurn)
        #expect(model.boardState.consecutivePasses == 1)
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        #expect(model.moves.count == 4)
        model.setSuspended(true)
    }

    @Test func captureRaceContinuesAfterPassingOrRequestingScoreUntilTargetIsReached() {
        let model = GameViewModel(boardSize: .five, mode: .twoPlayer, ruleSet: .captureRace(target: 2))
        model.handleBoardTap(at: BoardPoint(row: 0, col: 1))
        model.handleBoardTap(at: BoardPoint(row: 0, col: 0))
        model.scoreAndFinishNow()
        model.passTurn()
        model.passTurn()
        #expect(!model.isGameOver && !model.isMarkingDeadStones)
        model.handleBoardTap(at: BoardPoint(row: 1, col: 0))
        #expect(model.boardState.blackCaptures == 1)
        model.beginDeadStoneReview(bypassUnsealedWarning: true)
        #expect(!model.isGameOver)
        model.handleBoardTap(at: BoardPoint(row: 0, col: 4))
        model.handleBoardTap(at: BoardPoint(row: 0, col: 3))
        model.passTurn()
        model.handleBoardTap(at: BoardPoint(row: 1, col: 4))
        #expect(model.gameResult?.winner == .black)
        #expect(model.gameResult?.blackScore == 2)
        #expect(model.gameResult?.captureTarget == 2)
    }

    @Test func savedTacticalMatchReplaysSetupTurnAndEveryCapture() async throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = AppState(storage: StorageService(defaults: defaults))
        let scenario = TacticalScenario(
            id: "white-capture", rankBadge: "", titleZh: "", titleEn: "", briefingZh: "", briefingEn: "",
            boardSize: .five, komi: 0, playerColor: .white, opponentDifficulty: .sprout, coachingStyle: .standard,
            blackSetupSGF: ["aa"], whiteSetupSGF: ["ba"], goal: .captureRace(target: 1)
        )
        let model = GameViewModel(boardSize: .five, mode: .vsAI(difficulty: .sprout, playerColor: .white),
                                  ruleSet: .captureRace(target: 1), tacticalScenario: scenario, aiEngine: DelayedReply(), appState: app)
        let opening = model.boardState
        model.passTurn()
        let afterPass = model.boardState
        let reply = try #require(model.aiTask)
        await reply.value
        let afterReply = model.boardState
        model.handleBoardTap(at: BoardPoint(row: 1, col: 0))
        model.handleBoardTap(at: BoardPoint(row: 1, col: 0))
        #expect(model.gameResult?.winner == .white)
        let record = try #require(app.savedGames.first)
        let root = try #require(SGFParser.parse(record.sgf))
        var replay = root.initialBoard(size: record.boardSize, komi: record.komi, handicap: record.handicap)
        #expect(replay == opening)
        var node = root
        for (index, expected) in [afterPass, afterReply, model.boardState].enumerated() {
            node = try #require(node.children.first)
            let move = try #require(node.move)
            #expect(replay.currentTurn == move.color)
            let outcome = try replay.applying(action: move.action).get()
            #expect(Set(outcome.capturedPoints) == Set(model.moves[index].capturedPoints))
            replay = outcome.nextState
            #expect(replay == expected)
        }
        #expect(node.children.isEmpty)
    }

    @Test func undoWhileThinkingKeepsPendingTurnIntact() async throws {
        let model = makeMatch()
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        let reply = try #require(model.aiTask)
        #expect(model.isAIThinking)
        model.undo()
        #expect(model.moves.count == 1)
        await reply.value
        #expect(model.moves.count == 2)
        model.undo()
        #expect(model.moves.isEmpty)
        #expect(model.boardState.currentTurn == .black)
    }

    @Test func restartDiscardsReplyFromPreviousMatch() async throws {
        let model = makeMatch()
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        let oldReply = try #require(model.aiTask)
        model.restartMatch()
        await oldReply.value
        #expect(model.moves.isEmpty)
        #expect(model.boardState.currentTurn == .black)
        #expect(!model.isAIThinking)
    }

    @Test func leavingOrBackgroundingPausesClockAndReissuesPendingReplyOnReturn() async throws {
        let model = makeMatch()
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        let oldReply = try #require(model.aiTask)
        model.tickClock()
        let pausedClock = model.clock
        model.setSuspended(true)
        await oldReply.value
        model.tickClock()
        #expect(model.clock == pausedClock)
        #expect(model.moves.count == 1)
        #expect(!model.isAIThinking)

        model.setSuspended(false)
        #expect(model.isAIThinking)
        model.tickClock()
        #expect(model.clock.white.mainSecondsRemaining == pausedClock.white.mainSecondsRemaining - 1)
        let resumedReply = try #require(model.aiTask)
        await resumedReply.value
        #expect(model.moves.count == 2)
        #expect(model.boardState.currentTurn == .black)
    }

    @Test func phoneBoardFocusIncludesRequestedPointAndStaysOnBoard() {
        for row in 0..<19 {
            for col in 0..<19 {
                let point = BoardPoint(row: row, col: col)
                let region = BoardCropRegion.focused(around: point, size: 19)
                #expect(region.contains(point))
                #expect(region.rowCount == 9 && region.colCount == 9)
                #expect(region.minRow >= 0 && region.maxRow < 19)
                #expect(region.minCol >= 0 && region.maxCol < 19)
            }
        }
    }

    @Test func aiThinkingPacerScalesWithBoardDensityRankAndClockSafety() throws {
        let unlimitedClock = GoClock(timeControl: .unlimited)
        let fixedRandom: () -> Double = { 0.5 }

        // 1. Empty opening board is faster than populated midgame board
        let openingBoard = GoBoardState(size: 9)
        var midgameBoard = GoBoardState(size: 9)
        for idx in 0..<24 {
            let row = (idx * 3) % 9
            let col = (idx * 5) % 9
            midgameBoard.setSetupStone(idx % 2 == 0 ? .black : .white, at: BoardPoint(row: row, col: col))
        }

        let openingDelay = AIThinkingPacer.targetThinkingDuration(
            for: openingBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 2, col: 2)),
            lastHumanThinkDuration: nil,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .brisk,
            randomUnit: fixedRandom
        )
        let midgameDelay = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: nil,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .brisk,
            randomUnit: fixedRandom
        )
        #expect(openingDelay >= 0.9 && openingDelay < midgameDelay)
        #expect(midgameDelay >= 1.3 && midgameDelay <= 3.6)

        // 2. Pace presets scale monotonically: instant < brisk < human < deep
        let instantDelay = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: nil,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .instant,
            randomUnit: fixedRandom
        )
        let humanDelay = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: nil,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .human,
            randomUnit: fixedRandom
        )
        let deepDelay = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: nil,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .deep,
            randomUnit: fixedRandom
        )
        #expect(instantDelay == 0.26)
        #expect(instantDelay < midgameDelay)
        #expect(midgameDelay < humanDelay)
        #expect(humanDelay < deepDelay)

        // 3. Higher rank thinks slightly longer in midgame than beginner, but gap stays tight (<= 1.2s)
        let danMidgameDelay = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .phoenix,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: nil,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .brisk,
            randomUnit: fixedRandom
        )
        #expect(danMidgameDelay > midgameDelay)
        #expect(danMidgameDelay - midgameDelay <= 1.2)

        // 4. Anti-impulsive steady tempo:
        //    - Impulsive 0.2s human click slows AI down relative to normal to steady the child's rhythm
        //    - Patient 15s human thinking lets AI respond faster without stacking another long wait
        let afterImpulsiveHuman = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: 0.2,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .brisk,
            randomUnit: fixedRandom
        )
        let afterPatientHuman = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .rabbit,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: 15.0,
            clock: unlimitedClock,
            aiColor: .white,
            pace: .brisk,
            randomUnit: fixedRandom
        )
        #expect(afterImpulsiveHuman > midgameDelay)
        #expect(afterPatientHuman < midgameDelay)
        #expect(afterPatientHuman >= 1.3)

        // 5. Byoyomi clock safety caps thinking time so AI never flags
        let tightByoyomi = GoClock(timeControl: .byoyomi(mainMinutes: 0, periodSeconds: 5, periods: 1))
        let safeByoyomiDelay = AIThinkingPacer.targetThinkingDuration(
            for: midgameBoard,
            difficulty: .kirin,
            chosenAction: .place(BoardPoint(row: 4, col: 4)),
            lastHumanThinkDuration: 0.2,
            clock: tightByoyomi,
            aiColor: .white,
            pace: .deep,
            randomUnit: fixedRandom
        )
        #expect(safeByoyomiDelay <= 2.5)

        // 6. Legacy AppSettings JSON without aiThinkingPace migrates cleanly from aiSimulatedThinkingEnabled
        let legacyOffJSON = #"{"aiSimulatedThinkingEnabled":false}"#.data(using: .utf8)!
        let legacyOnJSON = #"{"aiSimulatedThinkingEnabled":true}"#.data(using: .utf8)!
        let decodedOff = try JSONDecoder().decode(AppSettings.self, from: legacyOffJSON)
        let decodedOn = try JSONDecoder().decode(AppSettings.self, from: legacyOnJSON)
        #expect(decodedOff.aiThinkingPace == .instant)
        #expect(decodedOn.aiThinkingPace == .brisk)
    }

    @Test func stonePlacementModesRespectDoubleTapDefaultAndConfirmButton() async throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = AppState(storage: StorageService(defaults: defaults))

        // Default is doubleTap
        #expect(app.settings.stonePlacementMode == .doubleTap)
        let model = GameViewModel(boardSize: .nine, mode: .twoPlayer, appState: app)
        #expect(!model.showsConfirmPlacementButton)

        // First tap previews; second tap at same point places
        let pt1 = BoardPoint(row: 4, col: 4)
        model.handleBoardTap(at: pt1)
        #expect(model.pendingPoint == pt1)
        #expect(model.moves.isEmpty)
        model.handleBoardTap(at: pt1)
        #expect(model.pendingPoint == nil)
        #expect(model.moves.count == 1)

        // Switch to confirmButton mode
        app.updateSettings { $0.stonePlacementMode = .confirmButton }
        #expect(model.showsConfirmPlacementButton)

        // Tapping same point twice in confirmButton mode does not auto-place; confirmPendingPlacement() does
        let pt2 = BoardPoint(row: 2, col: 2)
        model.handleBoardTap(at: pt2)
        #expect(model.pendingPoint == pt2)
        model.handleBoardTap(at: pt2)
        #expect(model.pendingPoint == pt2)
        #expect(model.moves.count == 1)
        model.confirmPendingPlacement()
        #expect(model.pendingPoint == nil)
        #expect(model.moves.count == 2)
    }

    @Test func unlimitedMatchTracksPerPlayerElapsedThinkingTimeAndPausesWhenSuspended() {
        let model = GameViewModel(boardSize: .nine, mode: .twoPlayer, timeControl: .unlimited)
        #expect(model.formattedElapsedTime(for: .black) == "00:00")
        #expect(model.formattedElapsedTime(for: .white) == "00:00")

        // Black's turn ticks Black's elapsed time
        model.tickClock()
        model.tickClock()
        #expect(model.blackElapsedSeconds == 2)
        #expect(model.whiteElapsedSeconds == 0)
        #expect(model.formattedElapsedTime(for: .black) == "00:02")

        // Suspended pauses elapsed time
        model.setSuspended(true)
        model.tickClock()
        #expect(model.blackElapsedSeconds == 2)
        model.setSuspended(false)

        // After Black plays, White's turn ticks White's elapsed time
        model.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        model.tickClock()
        model.tickClock()
        model.tickClock()
        #expect(model.blackElapsedSeconds == 2)
        #expect(model.whiteElapsedSeconds == 3)
        #expect(model.formattedElapsedTime(for: .white) == "00:03")

        // Restart resets both timers
        model.restartMatch()
        #expect(model.blackElapsedSeconds == 0)
        #expect(model.whiteElapsedSeconds == 0)
    }

    @Test func pausedAIMatchPersistsAcrossRelaunchAndResumesExactBoardAndTimers() async throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let app1 = AppState(storage: StorageService(defaults: defaults))
        let model = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .fox, playerColor: .black),
            aiEngine: DelayedReply(),
            appState: app1
        )
        #expect(!model.shouldConfirmBeforeLeaving)

        // Default placement mode is doubleTap: tap twice to place
        let pt = BoardPoint(row: 4, col: 4)
        model.tickClock()
        model.tickClock()
        model.handleBoardTap(at: pt)
        model.handleBoardTap(at: pt)
        let reply = try #require(model.aiTask)
        await reply.value

        #expect(model.shouldConfirmBeforeLeaving)
        #expect(model.moves.count == 2)
        let savedBoard = model.boardState
        let snapshot = try #require(model.makePausedAIMatchSnapshot())
        app1.savePausedAIMatch(snapshot)
        #expect(app1.pausedAIMatch != nil)

        // Simulate app relaunch with same storage
        let app2 = AppState(storage: StorageService(defaults: defaults))
        #expect(app2.pausedAIMatch == snapshot)

        // Resume paused match
        app2.resumePausedAIMatch()
        #expect(app2.pausedAIMatch == nil)
        let resumed = try #require(app2.activeGameViewModel)
        #expect(resumed.boardState == savedBoard)
        #expect(resumed.moves.count == 2)
        #expect(resumed.blackElapsedSeconds == 2)
        resumed.setSuspended(true)
    }

    @Test func startingNewAIMatchHidesAndClearsResumeLastMatchOnceHumanMoves() async throws {
        let suite = "StarYiGoTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let app = AppState(storage: StorageService(defaults: defaults))

        // First match: play a move and save as paused AI match
        let previous = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .fox, playerColor: .black),
            aiEngine: DelayedReply(),
            appState: app
        )
        let firstMove = BoardPoint(row: 4, col: 4)
        previous.handleBoardTap(at: firstMove)
        previous.handleBoardTap(at: firstMove)
        let prevReply = try #require(previous.aiTask)
        await prevReply.value
        let snapshot = try #require(previous.makePausedAIMatchSnapshot())
        app.savePausedAIMatch(snapshot)
        previous.setSuspended(true)

        // Enter a fresh AI match as Black: resume button should be offered before any move
        let freshBlack = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .fox, playerColor: .black),
            aiEngine: DelayedReply(),
            appState: app
        )
        #expect(app.pausedAIMatch != nil)
        #expect(freshBlack.canOfferResumePausedAIMatch)

        // First tap in double-tap mode is only a preview — resume button should still be offered
        let newMove = BoardPoint(row: 3, col: 3)
        freshBlack.handleBoardTap(at: newMove)
        #expect(freshBlack.canOfferResumePausedAIMatch)
        #expect(app.pausedAIMatch != nil)

        // Second tap confirms placement — resume button is hidden and stale paused match is cleared
        freshBlack.handleBoardTap(at: newMove)
        #expect(!freshBlack.canOfferResumePausedAIMatch)
        #expect(app.pausedAIMatch == nil)
        freshBlack.setSuspended(true)

        // Also verify playing as White: AI's opening black move alone must not hide resume button
        app.savePausedAIMatch(snapshot)
        let freshWhite = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .fox, playerColor: .white),
            aiEngine: DelayedReply(),
            appState: app
        )
        let aiOpening = try #require(freshWhite.aiTask)
        await aiOpening.value
        #expect(freshWhite.moves.count == 1)
        #expect(!freshWhite.hasHumanMoved)
        #expect(freshWhite.canOfferResumePausedAIMatch)
        #expect(app.pausedAIMatch != nil)

        // Once White plays a move, resume button is hidden and paused match is cleared
        let whiteMove = BoardPoint(row: 5, col: 5)
        freshWhite.handleBoardTap(at: whiteMove)
        freshWhite.handleBoardTap(at: whiteMove)
        #expect(freshWhite.hasHumanMoved)
        #expect(!freshWhite.canOfferResumePausedAIMatch)
        #expect(app.pausedAIMatch == nil)
        freshWhite.setSuspended(true)
    }

    private func makeMatch() -> GameViewModel {
        GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .sprout, playerColor: .black),
            timeControl: .suddenDeath(minutes: 5),
            aiEngine: DelayedReply()
        )
    }

    private struct DelayedReply: GoAIEngine {
        let engineName = "Delayed test reply"
        var action: MoveAction = .place(BoardPoint(row: 2, col: 2))

        func selectMove(for state: GoBoardState, color: StoneColor, level: AIDifficulty) async -> MoveAction {
            try? await Task.sleep(for: .milliseconds(350))
            // Simulate an engine returning a result even after its caller cancels.
            return action
        }

        func suggestMoves(for state: GoBoardState, color: StoneColor, count: Int) async -> [MoveSuggestion] { [] }

        func analyzePosition(for state: GoBoardState, color: StoneColor, maxVariations: Int) async -> PositionAnalysis {
            PositionAnalysis(blackWinrate: 0.5, blackScoreLead: 0, topVariations: [])
        }

        func analyzeGame(initialState: GoBoardState, moves: [GoMove]) async -> GameReviewReport {
            GameReviewReport(initialBlackWinrate: 0.5, winrateHistory: [], scoreLeadHistory: [], reviewedMoves: [])
        }
    }
}

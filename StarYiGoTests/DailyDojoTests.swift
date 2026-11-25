//
//  DailyDojoTests.swift
//  StarYi Go Tests — Daily Dojo Curriculum, No-Hint Enforcement & Stamp Calendar
//

import Foundation
import Testing
@testable import StarYiGo

struct DailyDojoTests {

    @Test func dailyPlanBuildsThreeDistinctStagesAndKnowledge() throws {
        let plan = DailyDojoSystem.plan(for: Date(), certifiedRankTier: 2, mistakeBookIds: [])
        #expect(plan.coreSlots.count == 3)
        #expect(plan.coreSlots[0].stage == .intro)
        #expect(plan.coreSlots[1].stage == .transform)
        #expect(plan.coreSlots[1].stage.forceRandomTransform == true)
        #expect(plan.coreSlots[2].stage == .boss)
        #expect(plan.warmupCount >= 2)
        #expect(!plan.knowledgeEntry.id.isEmpty)
    }

    @Test @MainActor func dailyChallengeForbidsHintsAndSolutionPlayback() throws {
        let puzzle = BuiltInPuzzleLibrary.allPuzzles[0]
        let vm = PuzzleViewModel(puzzle: puzzle, appState: nil, isDailyChallenge: true)

        vm.showHint()
        #expect(vm.usedHint == false)
        #expect(vm.showHintText == false)
        #expect(vm.highlightedHintPoint == nil)

        vm.playCorrectSolution()
        #expect(vm.status == .playing)
    }

    @Test @MainActor func dailyDojoThreeStationsUnlockStampAndMilestone() throws {
        let suiteName = "DailyDojoTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let appState = AppState(storage: StorageService(defaults: defaults))
        let plan = appState.todayDailyDojoPlan()

        #expect(appState.dailyDojoStationsDoneCount == 0)
        #expect(appState.isDailyDojoReadyToStamp == false)

        // Station 1: Warmup
        appState.recordDailyDojoWarmupCompleted(score: 2, total: 2)
        #expect(appState.dailyDojoStationsDoneCount == 1)

        // Station 2: 3 Core Puzzles (1 first-try, 2 grit)
        for (idx, slot) in plan.coreSlots.enumerated() {
            appState.recordDailyDojoCorePuzzleSolved(puzzleId: slot.puzzle.id, firstTry: idx == 0)
        }
        #expect(appState.dailyDojoStationsDoneCount == 2)

        // Station 3: Knowledge
        appState.recordDailyDojoKnowledgeCompleted(
            academyEntryId: plan.knowledgeEntry.id,
            themeCodexId: plan.themeCodex.id
        )
        #expect(appState.dailyDojoStationsDoneCount == 3)
        #expect(appState.isDailyDojoReadyToStamp == true)

        // Pre-seed 2 previous stamps so claiming today hits the 3-day milestone!
        appState.updateProfile { p in
            p.dailyDojoStampDates.insert("2026-01-01")
            p.dailyDojoStampDates.insert("2026-01-02")
        }

        let claim = appState.claimDailyDojoStamp()
        #expect(claim.coinsEarned == 70) // 40 daily chest + 30 3-day milestone
        #expect(claim.newMilestones.map(\.requiredStamps) == [3])
        #expect(appState.isDailyChallengeClearedToday == true)
        #expect(appState.isDailyDojoReadyToStamp == false)

        // Claiming twice on the same day is a no-op
        let secondClaim = appState.claimDailyDojoStamp()
        #expect(secondClaim.coinsEarned == 0)
    }

    @Test func goAcademyLibrarySGFsAreLegalCleanAndTacticallyVerified() throws {
        let rawSgfCoordPattern = try NSRegularExpression(pattern: "`[a-s]{2}`")

        func replaySGF(_ sgf: String, size: Int, komi: Double) throws -> (finalState: GoBoardState, totalCaptured: Int, moveCount: Int) {
            let root = try #require(SGFParser.parse(sgf), "Failed to parse Academy SGF")
            var state = GoBoardState(size: size, komi: komi)
            for pt in root.addedBlackPoints { state.setSetupStone(.black, at: pt) }
            for pt in root.addedWhitePoints { state.setSetupStone(.white, at: pt) }
            state.resetPositionHistoryToCurrent()

            var capturedTotal = 0
            var moveCount = 0
            var node: SGFNode? = root
            while let current = node {
                if let comment = current.comment {
                    let range = NSRange(comment.startIndex..., in: comment)
                    #expect(
                        rawSgfCoordPattern.firstMatch(in: comment, range: range) == nil,
                        "Raw SGF coordinate leaked into user-facing comment: \(comment)"
                    )
                }
                if let mv = current.move {
                    let result = state.applying(action: mv.action, color: mv.color)
                    switch result {
                    case .success(let outcome):
                        state = outcome.nextState
                        capturedTotal += outcome.capturedPoints.count
                        moveCount += 1
                    case .failure(let error):
                        Issue.record("Illegal move \(mv.action) in SGF: \(error)")
                    }
                }
                node = current.children.first
            }
            return (state, capturedTotal, moveCount)
        }

        for entry in GoAcademyLibrary.allEntries {
            let zhResult = try replaySGF(entry.sgfZh, size: entry.boardSize, komi: entry.komi)
            let enResult = try replaySGF(entry.sgfEn, size: entry.boardSize, komi: entry.komi)
            #expect(zhResult.moveCount > 0, "Entry \(entry.id) must have moves")
            #expect(zhResult.moveCount == enResult.moveCount, "Entry \(entry.id) zh/en move counts must match")

            if let quiz = entry.quizStep {
                #expect(quiz.beforeMoveIndex >= 0 && quiz.beforeMoveIndex < zhResult.moveCount, "Quiz step out of range for \(entry.id)")
            }
            if let counterZh = entry.counterExampleSgfZh {
                let cZh = try replaySGF(counterZh, size: entry.boardSize, komi: entry.komi)
                #expect(cZh.moveCount > 0)
            }
            if let counterEn = entry.counterExampleSgfEn {
                let cEn = try replaySGF(counterEn, size: entry.boardSize, komi: entry.komi)
                #expect(cEn.moveCount > 0)
            }
        }

        // Verify exact tactical outcomes of the fixed classic lessons:
        // 1. principle-vital-point: B[da] -> W[ca] -> B[ea] captures all 8 white stones!
        let vital = try #require(GoAcademyLibrary.entry(withId: "principle-vital-point"))
        let vitalMain = try replaySGF(vital.sgfZh, size: vital.boardSize, komi: vital.komi)
        #expect(vitalMain.totalCaptured == 8)

        // 2. curiosity-lanke-corner: Snapback captures 5 white stones (1 black + 5 white = 6 total captures)
        let lanke = try #require(GoAcademyLibrary.entry(withId: "curiosity-lanke-corner"))
        let lankeMain = try replaySGF(lanke.sgfZh, size: lanke.boardSize, komi: lanke.komi)
        #expect(lankeMain.totalCaptured == 6)

        // 3. curiosity-pig-snout (先缩小再点杀): Correct line shrinks & reduces White to 1 single eye (1 liberty at ba);
        // counter-example lets White capture B[ba] and have 2 separate eye areas (ba + da/ea)!
        let shrink = try #require(GoAcademyLibrary.entry(withId: "curiosity-pig-snout"))
        let shrinkMain = try replaySGF(shrink.sgfZh, size: shrink.boardSize, komi: shrink.komi)
        #expect(shrinkMain.finalState.twoEyeAliveAnalysis().eyePoints.isEmpty)
        let whiteMainGroup = try #require(shrinkMain.finalState.groupAndLiberties(at: shrinkMain.finalState.index(row: 0, col: 0)))
        #expect(whiteMainGroup.liberties.count == 1)

        let shrinkCounter = try replaySGF(try #require(shrink.counterExampleSgfZh), size: shrink.boardSize, komi: shrink.komi)
        #expect(shrinkCounter.totalCaptured == 1)
        let whiteCounterGroup = try #require(shrinkCounter.finalState.groupAndLiberties(at: shrinkCounter.finalState.index(row: 0, col: 0)))
        #expect(whiteCounterGroup.liberties.count == 3)
        // Sealing outer 1st line at ea immediately yields 2 strictly enclosed pure eyes (ba & da)
        if case .success(let sealed) = shrinkCounter.finalState.applying(action: .place(BoardPoint(row: 0, col: 4)), color: .white) {
            #expect(sealed.nextState.twoEyeAliveAnalysis().eyePoints.count == 2)
        } else {
            Issue.record("White should be able to seal ea to form two pure eyes")
        }
    }

    @Test @MainActor func timeHourglassNeverPicksMove1EmptyBoardSpikeAndPrefersRealTactics() throws {
        // Replay a 13x13 opening where Move 1 creates a massive empty-board flood-fill spike (+162.5),
        // followed by a real capture on Move 9.
        var state = GoBoardState(size: 13, komi: 6.5)
        var history: [GoBoardState] = [state]
        var moves: [GoMove] = []
        var leads: [Double] = [0]

        let sequence: [(StoneColor, Int, Int)] = [
            (.black, 3, 3),  // Move 1: empty-board flood-fill spike!
            (.white, 9, 9),  // Move 2
            (.black, 3, 9),  // Move 3
            (.white, 9, 3),  // Move 4
            (.black, 5, 5),  // Move 5
            (.white, 5, 6),  // Move 6 (White stone to be captured)
            (.black, 4, 6),  // Move 7
            (.white, 9, 6),  // Move 8
            (.black, 6, 6),  // Move 9 (Atari on 5,6)
            (.white, 9, 7),  // Move 10
            (.black, 5, 7)   // Move 11: Captures White at (5,6)!
        ]

        for (idx, step) in sequence.enumerated() {
            let pt = BoardPoint(row: step.1, col: step.2)
            guard case .success(let outcome) = state.applying(action: .place(pt), color: step.0) else {
                Issue.record("Unexpected illegal move at index \(idx)")
                return
            }
            state = outcome.nextState
            history.append(state)
            moves.append(GoMove(moveNumber: idx + 1, color: step.0, action: .place(pt), capturedPoints: outcome.capturedPoints))
            leads.append(GoScoring.estimateTerritory(state: state).blackLead)
        }

        // Sanity check: Move 1 indeed spiked raw flood-fill lead way above normal!
        #expect(leads[1] > 100.0)

        // Short opening (first 4 moves only): should NOT fabricate Move 1 as best move
        let shortAnalysis = GameViewModel.analyzeTimeHourglassMoments(
            moves: Array(moves.prefix(4)),
            stateHistory: Array(history.prefix(5)),
            humanLeadHistory: Array(leads.prefix(5)),
            perspective: .black,
            boardSize: 13
        )
        #expect(shortAnalysis.bestMoveNumber == nil)
        #expect(shortAnalysis.bestMoveReason == nil)

        // Full sequence: must pick Move 11 (real capture!), NEVER Move 1
        let fullAnalysis = GameViewModel.analyzeTimeHourglassMoments(
            moves: moves,
            stateHistory: history,
            humanLeadHistory: leads,
            perspective: .black,
            boardSize: 13
        )
        #expect(fullAnalysis.bestMoveNumber == 11)
        #expect(fullAnalysis.bestMoveReason == .capture(count: 1))
        #expect(fullAnalysis.turningPointMoveNumber != 1)
    }
}

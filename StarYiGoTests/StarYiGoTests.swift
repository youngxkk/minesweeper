//
//  StarYiGoTests.swift
//  StarYi Go Tests
//

import Foundation
import Testing
import UIKit
@testable import StarYiGo

struct StarYiGoEngineTests {

    @Test func basicPlacementAndAlternatingTurns() throws {
        var state = GoBoardState(size: 9)
        #expect(state.currentTurn == .black)

        let pt1 = BoardPoint(row: 4, col: 4)
        let res1 = state.applying(action: .place(pt1))
        guard case .success(let out1) = res1 else {
            Issue.record("Expected legal move at center")
            return
        }
        state = out1.nextState
        #expect(state.stone(at: pt1) == .black)
        #expect(state.currentTurn == .white)

        // Occupied check
        let resOccupied = state.applying(action: .place(pt1))
        #expect(resOccupied == .failure(.occupied))
    }

    @Test func singleStoneAndGroupCapture() throws {
        var state = GoBoardState(size: 9)
        state.setSetupStone(.white, at: BoardPoint(row: 4, col: 4))
        state.setSetupStone(.black, at: BoardPoint(row: 3, col: 4))
        state.setSetupStone(.black, at: BoardPoint(row: 5, col: 4))
        state.setSetupStone(.black, at: BoardPoint(row: 4, col: 3))
        state.resetPositionHistoryToCurrent()

        #expect(state.atariPoints().contains(BoardPoint(row: 4, col: 4)))

        let res = state.applying(action: .place(BoardPoint(row: 4, col: 5)), color: .black)
        guard case .success(let out) = res else {
            Issue.record("Expected capture move to succeed")
            return
        }
        #expect(out.capturedPoints == [BoardPoint(row: 4, col: 4)])
        #expect(out.nextState.stone(at: BoardPoint(row: 4, col: 4)) == nil)
        #expect(out.nextState.blackCaptures == 1)
    }

    @Test func suicideDisallowedUnlessCapturing() throws {
        // Corner suicide disallowed
        var state = GoBoardState(size: 9)
        state.setSetupStone(.white, at: BoardPoint(row: 0, col: 1))
        state.setSetupStone(.white, at: BoardPoint(row: 1, col: 0))
        state.resetPositionHistoryToCurrent()

        let suicideRes = state.applying(action: .place(BoardPoint(row: 0, col: 0)), color: .black)
        #expect(suicideRes == .failure(.suicide))

        // If white stones have no other liberties, playing (0,0) captures them and IS legal
        state.setSetupStone(.black, at: BoardPoint(row: 0, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 1, col: 1))
        state.setSetupStone(.black, at: BoardPoint(row: 2, col: 0))
        state.resetPositionHistoryToCurrent()

        let captureRes = state.applying(action: .place(BoardPoint(row: 0, col: 0)), color: .black)
        guard case .success(let out) = captureRes else {
            Issue.record("Capturing move into zero-liberty spot must be legal")
            return
        }
        #expect(out.capturedPoints.count == 2)
    }

    @Test func simpleKoRuleEnforced() throws {
        // Classic Ko shape
        var state = GoBoardState(size: 9)
        // Black around (2,2): (1,2), (3,2), (2,1)
        state.setSetupStone(.black, at: BoardPoint(row: 1, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 3, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 2, col: 1))
        // White around (2,3): (1,3), (3,3), (2,4), plus white stone at (2,2)
        state.setSetupStone(.white, at: BoardPoint(row: 1, col: 3))
        state.setSetupStone(.white, at: BoardPoint(row: 3, col: 3))
        state.setSetupStone(.white, at: BoardPoint(row: 2, col: 4))
        state.setSetupStone(.white, at: BoardPoint(row: 2, col: 2))
        state.resetPositionHistoryToCurrent()

        // Black captures (2,2) by playing (2,3)
        guard case .success(let out1) = state.applying(action: .place(BoardPoint(row: 2, col: 3)), color: .black) else {
            Issue.record("Ko capture should succeed")
            return
        }
        #expect(out1.capturedPoints == [BoardPoint(row: 2, col: 2)])

        // White immediate recapture at (2,2) MUST fail with koViolation
        let immediateRecapture = out1.nextState.applying(action: .place(BoardPoint(row: 2, col: 2)), color: .white)
        #expect(immediateRecapture == .failure(.koViolation))

        // After a ko threat elsewhere by White and response by Black, White CAN recapture
        guard case .success(let out2) = out1.nextState.applying(action: .place(BoardPoint(row: 7, col: 7)), color: .white),
              case .success(let out3) = out2.nextState.applying(action: .place(BoardPoint(row: 7, col: 6)), color: .black),
              case .success(let out4) = out3.nextState.applying(action: .place(BoardPoint(row: 2, col: 2)), color: .white) else {
            Issue.record("Ko recapture after ko threat should succeed")
            return
        }
        #expect(out4.capturedPoints == [BoardPoint(row: 2, col: 3)])
    }

    @Test func handicapSetupAndChineseScoring() throws {
        let state = GoBoardState(size: 19, handicap: 4)
        #expect(state.currentTurn == .white)
        #expect(state.komi == 0.5)
        let blackStones = state.grid.compactMap { $0 }.filter { $0 == .black }.count
        #expect(blackStones == 4)

        // Pure enclosed territory scoring on 9x9
        var small = GoBoardState(size: 9, komi: 5.5)
        for r in 0..<9 {
            small.setSetupStone(.black, at: BoardPoint(row: r, col: 4))
        }
        let result = GoScoring.chineseAreaScore(state: small)
        #expect(result.winner == .black)
        #expect(result.blackScore == 81.0)
    }

    @Test func sgfExportAndRoundTripParse() throws {
        let moves = [
            GoMove(moveNumber: 1, color: .black, action: .place(BoardPoint(row: 2, col: 2))),
            GoMove(moveNumber: 2, color: .white, action: .place(BoardPoint(row: 6, col: 6))),
            GoMove(moveNumber: 3, color: .black, action: .pass)
        ]
        let sgf = SGFParser.export(
            initialState: GoBoardState(size: 9, komi: 5.5),
            blackName: "Player",
            whiteName: "Fox",
            result: "B+3.5",
            date: Date(),
            moves: moves
        )
        let root = SGFParser.parse(sgf)
        #expect(root != nil)
        #expect(root?.boardSize == 9)
        #expect(root?.children.first?.move?.action == .place(BoardPoint(row: 2, col: 2)))
        #expect(root?.children.first?.children.first?.move?.action == .place(BoardPoint(row: 6, col: 6)))
    }

    @Test func localAIEngineCapturesAndSuggests() async throws {
        var state = GoBoardState(size: 9)
        // White stone at (4,4) in Atari, Black to capture at (4,5)
        state.setSetupStone(.white, at: BoardPoint(row: 4, col: 4))
        state.setSetupStone(.black, at: BoardPoint(row: 3, col: 4))
        state.setSetupStone(.black, at: BoardPoint(row: 5, col: 4))
        state.setSetupStone(.black, at: BoardPoint(row: 4, col: 3))
        state.resetPositionHistoryToCurrent()

        let engine = LocalMCTSGoEngine()
        let move = await engine.selectMove(for: state, color: .black, level: .panda)
        #expect(move == .place(BoardPoint(row: 4, col: 5)))

        let suggestions = await engine.suggestMoves(for: state, color: .black, count: 2)
        #expect(!suggestions.isEmpty)
        #expect(suggestions.first?.point == BoardPoint(row: 4, col: 5))
        #expect(suggestions.first?.reason == .capture)
    }

    @Test func allBuiltInPuzzlesAreMathematicallyValid() throws {
        let puzzles = BuiltInPuzzleLibrary.allPuzzles
        #expect(puzzles.count == 20)

        for puzzle in puzzles {
            let root = SGFParser.parse(puzzle.sgf)
            #expect(root != nil, "Failed to parse SGF for puzzle \(puzzle.id)")
            guard let root else { continue }

            let initial = puzzle.initialBoardState()

            // Every setup stone group must have >= 1 liberty
            for group in initial.allGroups() {
                #expect(!group.liberties.isEmpty, "Setup group has 0 liberties in puzzle \(puzzle.id)")
            }

            // Must have a valid hint move
            let hint = GoPuzzle.firstCorrectMove(from: root)
            #expect(hint != nil, "No correct first move found for puzzle \(puzzle.id)")

            // Recursively verify every branch in SGF tree is 100% legal under Go rules
            var foundCorrectLeaf = false
            func walk(node: SGFNode, state: GoBoardState) {
                if let c = node.comment?.uppercased(), c.contains("CORRECT") {
                    foundCorrectLeaf = true
                }
                for child in node.children {
                    guard let move = child.move else { continue }
                    let result = state.applying(action: move.action, color: move.color)
                    switch result {
                    case .success(let outcome):
                        walk(node: child, state: outcome.nextState)
                    case .failure(let err):
                        Issue.record("Illegal SGF move \(move) in puzzle \(puzzle.id): \(err)")
                    }
                }
            }
            walk(node: root, state: initial)
            #expect(foundCorrectLeaf, "Puzzle \(puzzle.id) has no CORRECT terminal node")
        }
    }

    @Test func starPointIslandsAndClassicGamesAreValid() throws {
        // Verify all 5 islands map all 20 puzzles without duplicates
        let mappedIds = StarYiIslands.allIslands.flatMap(\.puzzleIds)
        #expect(StarYiIslands.allIslands.count == 5)
        #expect(Set(mappedIds).count == 20)
        for island in StarYiIslands.allIslands {
            #expect(StarYiIslands.puzzles(for: island).count == 4)
        }

        // Daily challenge returns a valid puzzle
        let daily = StarYiIslands.dailyChallengePuzzle()
        #expect(SGFParser.parse(daily.sgf) != nil)

        // Built-in Classic Study SGF games (Go Academy) all replay legally
        let classics = BuiltInClassicGames.records(l10n: L10n(language: .en))
        #expect(classics.count == GoAcademyLibrary.allEntries.count)
        for rec in classics {
            guard let root = SGFParser.parse(rec.sgf) else {
                Issue.record("Failed to parse classic game \(rec.blackName)")
                continue
            }
            var state = root.initialBoard(size: rec.boardSize, komi: rec.komi, handicap: rec.handicap)
            var node = root.children.first
            var played = 0
            while let cur = node {
                if let mv = cur.move {
                    guard case .success(let out) = state.applying(action: mv.action, color: mv.color) else {
                        Issue.record("Illegal move in classic game \(rec.blackName)")
                        break
                    }
                    state = out.nextState
                    played += 1
                }
                node = cur.children.first
            }
            #expect(played == rec.moveCount)
        }
    }

    @Test func nintendoSequentialIslandAndStageUnlocking() throws {
        let islands = StarYiIslands.allIslands
        let world1 = islands[0]
        let world2 = islands[1]
        let world3 = islands[2]

        // 1. Fresh progress: ONLY World 1 is active; Worlds 2..5 are locked
        var progress = PuzzleProgressStore()
        #expect(StarYiIslands.unlockState(for: world1, progress: progress) == .active)
        for lockedWorld in islands.dropFirst() {
            #expect(StarYiIslands.unlockState(for: lockedWorld, progress: progress) == .locked)
        }

        // Inside World 1: ONLY Stage 1 is active; Stages 2..4 and Boss are locked
        #expect(StarYiIslands.stageState(at: 0, in: world1, progress: progress) == .active)
        #expect(StarYiIslands.stageState(at: 1, in: world1, progress: progress) == .locked)
        #expect(StarYiIslands.stageState(at: 2, in: world1, progress: progress) == .locked)
        #expect(StarYiIslands.stageState(at: 3, in: world1, progress: progress) == .locked)
        #expect(!StarYiIslands.isBossUnlocked(for: world1, progress: progress))

        // 2. Solving Stage 1 unlocks ONLY Stage 2 (Stages 3..4 & World 2 stay locked)
        progress.starsByPuzzleId[world1.puzzleIds[0]] = 3
        #expect(StarYiIslands.stageState(at: 0, in: world1, progress: progress) == .cleared(stars: 3))
        #expect(StarYiIslands.stageState(at: 1, in: world1, progress: progress) == .active)
        #expect(StarYiIslands.stageState(at: 2, in: world1, progress: progress) == .locked)
        #expect(StarYiIslands.unlockState(for: world2, progress: progress) == .locked)

        // 3. Solving a future puzzle via Daily Challenge does NOT prematurely unlock locked worlds
        progress.starsByPuzzleId[world3.puzzleIds[0]] = 2
        #expect(StarYiIslands.unlockState(for: world2, progress: progress) == .locked)
        #expect(StarYiIslands.unlockState(for: world3, progress: progress) == .locked)
        #expect(StarYiIslands.stageState(at: 0, in: world3, progress: progress) == .locked)

        // 4. Clearing all 4 stages of World 1 marks World 1 cleared, unlocks Boss 1, and activates World 2 Stage 1
        for pid in world1.puzzleIds {
            progress.starsByPuzzleId[pid] = 3
        }
        #expect(StarYiIslands.unlockState(for: world1, progress: progress) == .cleared)
        #expect(StarYiIslands.isBossUnlocked(for: world1, progress: progress))
        #expect(StarYiIslands.unlockState(for: world2, progress: progress) == .active)
        #expect(StarYiIslands.stageState(at: 0, in: world2, progress: progress) == .active)
        #expect(StarYiIslands.stageState(at: 1, in: world2, progress: progress) == .locked)
        #expect(StarYiIslands.unlockState(for: world3, progress: progress) == .locked)
    }

    @Test func starterBootcampAndGoCodexDemosAreMathematicallyValid() throws {
        // 1. Verify all 4 5x5 Starter Bootcamp lessons parse & execute cleanly
        #expect(StarterBootcamp.puzzles.count == 4)
        for puzzle in StarterBootcamp.puzzles {
            #expect(puzzle.boardSize == 5)
            guard let root = SGFParser.parse(puzzle.sgf) else {
                Issue.record("Failed to parse Starter Bootcamp SGF \(puzzle.id)")
                continue
            }
            let initial = puzzle.initialBoardState()
            for g in initial.allGroups() {
                #expect(!g.liberties.isEmpty)
            }
            #expect(GoPuzzle.firstCorrectMove(from: root) != nil)
            func walk(node: SGFNode, state: GoBoardState) {
                for child in node.children {
                    guard let move = child.move else { continue }
                    guard case .success(let out) = state.applying(action: move.action, color: move.color) else {
                        Issue.record("Illegal move \(move) in Starter Bootcamp \(puzzle.id)")
                        continue
                    }
                    walk(node: child, state: out.nextState)
                }
            }
            walk(node: root, state: initial)
        }

        // 2. Verify all 36 Go Term Codex interactive mini-demos across all 4 tiers replay legally
        #expect(GoTermCodex.allEntries.count == 36)
        #expect(GoTermCodex.allEntries.filter { $0.tier == .starter }.count == 10)
        #expect(GoTermCodex.allEntries.filter { $0.tier == .tactics }.count == 10)
        #expect(GoTermCodex.allEntries.filter { $0.tier == .fighting }.count == 8)
        #expect(GoTermCodex.allEntries.filter { $0.tier == .mastery }.count == 8)

        for entry in GoTermCodex.allEntries {
            guard let root = SGFParser.parse(entry.demoSGF) else {
                Issue.record("Failed to parse Codex demo SGF \(entry.id)")
                continue
            }
            #expect(StarYiIslands.findAnyPuzzle(withId: entry.practicePuzzleId) != nil, "Invalid practicePuzzleId \(entry.practicePuzzleId) in Codex \(entry.id)")

            var state = GoBoardState(size: entry.demoBoardSize, komi: 0)
            for pt in root.addedBlackPoints { state.setSetupStone(.black, at: pt) }
            for pt in root.addedWhitePoints { state.setSetupStone(.white, at: pt) }
            state.resetPositionHistoryToCurrent()

            for g in state.allGroups() {
                #expect(!g.liberties.isEmpty, "Setup group has 0 liberties in Codex \(entry.id)")
            }

            var node = root.children.first
            var steps = 0
            while let n = node {
                if let mv = n.move {
                    guard case .success(let out) = state.applying(action: mv.action, color: mv.color) else {
                        Issue.record("Illegal demo move \(mv) in Codex \(entry.id)")
                        break
                    }
                    state = out.nextState
                    steps += 1
                }
                node = n.children.first
            }
            #expect(steps >= 1, "Codex \(entry.id) demo should have at least 1 move")
        }

        // 3. Verify all dedicated Codex practice puzzles replay legally and contain a CORRECT leaf
        for puzzle in GoTermCodex.codexPracticePuzzles {
            let root = try #require(SGFParser.parse(puzzle.sgf), "Failed to parse Codex puzzle \(puzzle.id)")
            let initial = puzzle.initialBoardState()
            for g in initial.allGroups() {
                #expect(!g.liberties.isEmpty, "Setup group has 0 liberties in Codex puzzle \(puzzle.id)")
            }
            #expect(GoPuzzle.firstCorrectMove(from: root) != nil, "Missing firstCorrectMove in Codex puzzle \(puzzle.id)")
            var foundCorrect = false
            func walkCodex(_ node: SGFNode, _ state: GoBoardState) {
                if let c = node.comment?.uppercased(), c.contains("CORRECT") { foundCorrect = true }
                for ch in node.children {
                    guard let mv = ch.move else { continue }
                    guard case .success(let out) = state.applying(action: mv.action, color: mv.color) else {
                        Issue.record("Illegal move \(mv) in Codex puzzle \(puzzle.id)")
                        return
                    }
                    walkCodex(ch, out.nextState)
                }
            }
            walkCodex(root, initial)
            #expect(foundCorrect, "Missing CORRECT leaf in Codex puzzle \(puzzle.id)")
        }

        // 4. Verify all 4 Go Academy halls, 23 entries (incl. 11 complete 19x19 historic masterpieces), highlights, master quizzes & counter-examples replay legally
        #expect(GoAcademyLibrary.allEntries.count == 23)
        for hall in AcademyHall.allCases {
            #expect(!GoAcademyLibrary.entries(in: hall, level: .all).isEmpty, "Academy hall \(hall.rawValue) should not be empty")
        }
        #expect(Set(GoAcademyLibrary.allEntries.map(\.id)).count == GoAcademyLibrary.allEntries.count)
        #expect(Set(GoAcademyLibrary.allEntries.map(\.recordId)).count == GoAcademyLibrary.allEntries.count)

        for entry in GoAcademyLibrary.allEntries {
            for sgf in [entry.sgfZh, entry.sgfEn, entry.counterExampleSgfZh, entry.counterExampleSgfEn].compactMap({ $0 }) {
                let root = try #require(SGFParser.parse(sgf), "Failed to parse Academy SGF in \(entry.id)")
                var state = root.initialBoard(size: entry.boardSize, komi: entry.komi, handicap: 0)
                var moveCount = 0
                var node = root.children.first
                while let n = node {
                    if let mv = n.move {
                        guard case .success(let out) = state.applying(action: mv.action, color: mv.color) else {
                            Issue.record("Illegal move \(mv) in Academy entry \(entry.id)")
                            break
                        }
                        state = out.nextState
                        moveCount += 1
                    }
                    node = n.children.first
                }
                #expect(moveCount >= 2, "Academy entry \(entry.id) should have at least 2 moves")
                if entry.hall == .masterpieces && entry.boardSize == 19 && sgf == entry.sgfZh {
                    #expect(moveCount >= 150, "19x19 masterpiece \(entry.id) must be a complete full-length game, got \(moveCount) moves")
                    #expect(entry.moveCount == moveCount, "Cached moveCount mismatch for \(entry.id)")
                }
                if sgf == entry.sgfZh {
                    for h in entry.highlights {
                        #expect(h.moveIndex >= 1 && h.moveIndex <= moveCount, "Out-of-bounds highlight in \(entry.id)")
                    }
                    if let quiz = entry.quizStep {
                        #expect(quiz.beforeMoveIndex >= 0 && quiz.beforeMoveIndex < moveCount, "Out-of-bounds quizStep in \(entry.id)")
                    }
                }
            }
        }
    }

    @Test func twoEyeLivingAnalysisAndDeadStoneScoring() throws {
        // Straight Three on 5x5 -> playing ca creates 2 true eyes at ba and da
        let boot4 = StarterBootcamp.puzzles[3]
        let initial = boot4.initialBoardState()
        guard case .success(let out) = initial.applying(action: .place(BoardPoint(row: 0, col: 2)), color: .black) else {
            Issue.record("Expected legal two-eye move")
            return
        }
        let analysis = out.nextState.twoEyeAliveAnalysis()
        #expect(analysis.eyePoints.contains(BoardPoint(row: 0, col: 1)))
        #expect(analysis.eyePoints.contains(BoardPoint(row: 0, col: 3)))
        #expect(!analysis.aliveStoneIndices.isEmpty)

        // Dead-stone removal in Chinese Area Scoring: a trapped white stone inside Black territory
        var board = GoBoardState(size: 5, komi: 2.5)
        for r in 0..<5 {
            board.setSetupStone(.black, at: BoardPoint(row: r, col: 2))
        }
        let deadWhitePt = BoardPoint(row: 2, col: 0)
        board.setSetupStone(.white, at: deadWhitePt)
        let deadIdx = board.index(row: 2, col: 0)

        let rawScore = GoScoring.chineseAreaScore(state: board)
        let cleanScore = GoScoring.chineseAreaScore(state: board, deadStoneIndices: [deadIdx])
        #expect(cleanScore.blackScore > rawScore.blackScore)
        #expect(cleanScore.blackScore == 25.0)
    }

    @Test func captureGoRuleSetAndStarterBoardSizes() async throws {
        #expect(BoardSize.five.rawValue == 5)
        #expect(BoardSize.seven.rawValue == 7)
        #expect(BoardSize.five.starPoints.count == 1)
        #expect(BoardSize.seven.starPoints.count == 5)

        // AI plays immediate winning capture in Capture Go
        var state = GoBoardState(size: 5)
        state.setSetupStone(.white, at: BoardPoint(row: 2, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 1, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 3, col: 2))
        state.setSetupStone(.black, at: BoardPoint(row: 2, col: 1))
        state.resetPositionHistoryToCurrent()

        let engine = LocalMCTSGoEngine()
        let move = await engine.selectMove(for: state, color: .black, level: .fox, ruleSet: .captureRace(target: 1))
        #expect(move == .place(BoardPoint(row: 2, col: 3)))
    }

    // MARK: - P0 Tests: Dual Scoring, Dame, Seki, Unsealed Boundaries & Fixed SGFs

    @Test func p0DualScoringSekiAndEndgameReadiness() throws {
        // 1. Chinese vs Japanese scoring with neutral dame (must NOT give dame to one side by influence!)
        var board = GoBoardState(size: 5, komi: 2.5)
        for r in 0..<5 { board.setSetupStone(.black, at: BoardPoint(row: r, col: 1)) }
        for r in 0..<5 { board.setSetupStone(.white, at: BoardPoint(row: r, col: 3)) }
        board.resetPositionHistoryToCurrent()

        let cn = GoScoring.score(state: board, rule: .chinese)
        let jp = GoScoring.score(state: board, rule: .japanese)
        #expect(cn.dameCount == 5)
        #expect(cn.blackScore == 12.5)
        #expect(cn.whiteScore == 15.0)
        #expect(jp.blackScore == 5.0)
        #expect(jp.whiteScore == 7.5)

        // 2. Unsealed boundary warning detection
        let readiness = GoScoring.analyzeEndgameReadiness(state: board)
        #expect(!readiness.isReadyToScore)
        #expect(!readiness.unsealedBoundaryPoints.isEmpty)

        // 3. Genuine Seki detection (from the fixed GoTermCodex Seki demo!)
        let sekiEntry = try #require(GoTermCodex.entry(withId: "seki"))
        let root = try #require(SGFParser.parse(sekiEntry.demoSGF))
        var sekiState = GoBoardState(size: sekiEntry.demoBoardSize, komi: 0)
        for pt in root.addedBlackPoints { sekiState.setSetupStone(.black, at: pt) }
        for pt in root.addedWhitePoints { sekiState.setSetupStone(.white, at: pt) }
        sekiState.resetPositionHistoryToCurrent()
        var n = root.children.first
        while let cur = n {
            if let mv = cur.move, case .success(let out) = sekiState.applying(action: mv.action, color: mv.color) {
                sekiState = out.nextState
            }
            n = cur.children.first
        }
        let seki = GoScoring.detectSeki(state: sekiState)
        #expect(seki.sekiPairCount >= 1)
        #expect(seki.sekiSharedLiberties.count == 2)
    }

    @Test func p0Fixed33JosekiCoordinatesAreAuthentic() throws {
        let entry = try #require(GoTermCodex.entry(withId: "sanSanJoseki"))
        let root = try #require(SGFParser.parse(entry.demoSGF))
        var state = GoBoardState(size: 19, komi: 7.5)
        var node = root.children.first
        while let cur = node {
            if let mv = cur.move, case .success(let out) = state.applying(action: mv.action, color: mv.color) {
                state = out.nextState
            } else {
                Issue.record("Illegal move in sanSanJoseki")
            }
            node = cur.children.first
        }
        // Move 6 must be W[oc] and Move 7 must be B[nc] (fixed from previous coordinate swap!)
        #expect(state.stone(at: BoardPoint(sgf: "oc")!) == .white)
        #expect(state.stone(at: BoardPoint(sgf: "nc")!) == .black)
    }

    // MARK: - P1 Tests: Tactical Ladder Solver, CoreML Tensor, AI Game Review & 320 Dojo Puzzles

    @Test func p1TacticalLadderCoreMLTensorAndGameReview() async throws {
        // 1. Working 45° diagonal ladder vs distant ladder breaker
        let workingDrill = GoMiniDrillsLibrary.ladderDrills[2]
        let brokenDrill = GoMiniDrillsLibrary.ladderDrills[3]
        #expect(workingDrill.evaluate().works == true)
        #expect(brokenDrill.evaluate().works == false)

        // 2. CoreML 18-plane spatial tensor encoding
        let st = workingDrill.makeState()
        let tensor = CoreMLGoAIEngine.encodeSpatialTensor(state: st, color: .black, targetSize: 19)
        #expect(tensor != nil)

        // 3. Multi-ply MCTS position analysis & game review
        let engine = LocalMCTSGoEngine()
        let pos = await engine.analyzePosition(for: st, color: .black, maxVariations: 3)
        #expect(!pos.topVariations.isEmpty)
        #expect(pos.blackWinrate > 0.0 && pos.blackWinrate < 1.0)

        let moves = [
            GoMove(moveNumber: 1, color: .black, action: .place(BoardPoint(row: 4, col: 4))),
            GoMove(moveNumber: 2, color: .white, action: .place(BoardPoint(row: 2, col: 2))),
            GoMove(moveNumber: 3, color: .black, action: .place(BoardPoint(row: 6, col: 6)))
        ]
        let report = await engine.analyzeGame(initialState: GoBoardState(size: 9), moves: moves)
        #expect(report.winrateHistory.count == 4)
        #expect(report.reviewedMoves.count == 3)
    }

    @Test func p1All320DojoPuzzlesAndSRSMistakeProgression() throws {
        let all = DojoPuzzleBank.allDojoPuzzles
        #expect(all.count == 320)
        #expect(Set(all.map(\.id)).count == 320)

        for puzzle in all {
            let root = try #require(SGFParser.parse(puzzle.sgf))
            let initial = puzzle.initialBoardState()
            for g in initial.allGroups() {
                #expect(!g.liberties.isEmpty, "Setup group 0 liberties in \(puzzle.id)")
            }
            #expect(GoPuzzle.firstCorrectMove(from: root) != nil)
            var foundCorrect = false
            func walk(_ node: SGFNode, _ state: GoBoardState) {
                if let c = node.comment?.uppercased(), c.contains("CORRECT") { foundCorrect = true }
                for ch in node.children {
                    guard let mv = ch.move else { continue }
                    guard case .success(let out) = state.applying(action: mv.action, color: mv.color) else {
                        Issue.record("Illegal move in \(puzzle.id)")
                        return
                    }
                    walk(ch, out.nextState)
                }
            }
            walk(root, initial)
            #expect(foundCorrect, "Missing CORRECT leaf in \(puzzle.id)")
        }

        // Verify SRS spaced repetition schedule: 1d -> 3d -> mastered (nil)
        let item0 = SRSMistakeItem.initial(puzzleId: "cap-01")
        let item1 = try #require(item0.advancingOnCorrect())
        #expect(item1.intervalDays == 1)
        let item2 = try #require(item1.advancingOnCorrect())
        #expect(item2.intervalDays == 3)
        let graduated = item2.advancingOnCorrect()
        #expect(graduated == nil)
    }

    // MARK: - P2 Tests: Go Clock Byoyomi, Joseki Trees, Mini-Drills & Rank Exams

    @Test func p2GoClockJosekiTreesAndRankExams() throws {
        // 1. Go Clock Byoyomi mechanics
        var clock = GoClock(timeControl: .byoyomi(mainMinutes: 0, periodSeconds: 10, periods: 2))
        var lastEvent: ClockTickEvent = .normal
        for _ in 0..<10 { lastEvent = clock.tick(activeColor: .black) }
        #expect(lastEvent == .periodConsumed(remainingPeriods: 1))
        clock.completeMove(for: .black)
        #expect(clock.black.byoyomiSecondsRemaining == 10)

        // 2. All 5 multi-branch Joseki trees parse & replay legally
        #expect(JosekiLibrary.allCourses.count == 5)
        for course in JosekiLibrary.allCourses {
            for sgf in [course.sgfZh, course.sgfEn] {
                let root = try #require(SGFParser.parse(sgf))
                var st = GoBoardState(size: course.boardSize, komi: 7.5, startingTurn: course.playerColor)
                for pt in root.addedBlackPoints { st.setSetupStone(.black, at: pt) }
                for pt in root.addedWhitePoints { st.setSetupStone(.white, at: pt) }
                st.resetPositionHistoryToCurrent()
                func walkJ(_ node: SGFNode, _ s: GoBoardState) {
                    for ch in node.children {
                        guard let mv = ch.move else { continue }
                        guard case .success(let out) = s.applying(action: mv.action, color: mv.color) else {
                            Issue.record("Illegal Joseki move in \(course.id)")
                            return
                        }
                        walkJ(ch, out.nextState)
                    }
                }
                walkJ(root, st)
            }
        }

        // 3. All 7 Dual-Requirement Rank Exams reference valid Dojo puzzles
        #expect(RankExamSystem.allExams.count == 7)
        for spec in RankExamSystem.allExams {
            #expect(spec.examPuzzleIds.count == 5)
            for pid in spec.examPuzzleIds {
                #expect(DojoPuzzleBank.findPuzzle(withId: pid) != nil)
            }
        }
    }

    // MARK: - Campaign Overhaul Tests (Phases 1 + 2 + 3: 4 Seas, 20 Islands, 1,100+ JSON Pack, Scenarios, Rush & Ghosts)

    @Test func immediateCaptureLessonsMeetTheirGoalsInEveryPackOrientation() throws {
        // The expected captures and size of the friendly chain to rescue come from the lesson prompts.
        let lessons: [(id: String, captures: Int, rescueSize: Int?)] = [
            ("pk-cap-01", 1, nil), ("pk-cap-02", 2, nil), ("pk-cap-03", 3, nil),
            ("pk-cap-05", 1, 1), ("pk-cap-15", 1, 3), ("pk-ex-01", 2, nil),
            ("pk-ex-02", 1, 1), ("pk-ex-04", 3, nil), ("pk-ex-10", 1, 1)
        ]
        for lesson in lessons {
            let variants = PuzzlePackLoader.expandedPackPuzzles.filter { $0.id == lesson.id || $0.id.hasPrefix(lesson.id + "-") }
            #expect(variants.count == 6)
            for puzzle in variants {
                let board = puzzle.initialBoardState()
                let root = try #require(puzzle.parsedRoot())
                let answers = root.children.filter { GoPuzzle.isCorrectBranch($0) }
                #expect(!answers.isEmpty)
                for answer in answers {
                    let move = try #require(answer.move)
                    #expect(move.color == board.currentTurn)
                    let outcome = try board.applying(action: move.action).get()
                    #expect(outcome.capturedPoints.count == lesson.captures, "\(puzzle.id)")
                    if let size = lesson.rescueSize {
                        let rescued = board.allGroups().contains { group in
                            guard group.color == move.color, group.stones.count == size,
                                  group.liberties.count == 1, let anchor = group.stones.first,
                                  let after = outcome.nextState.groupAndLiberties(at: anchor) else { return false }
                            return after.color == move.color && after.liberties.count >= 2
                        }
                        #expect(rescued, "\(puzzle.id)")
                    }
                }
            }
        }
    }

    @Test func reviewSupportsLegacyHandicapAndExplicitSetup() throws {
        let standard = GoBoardState(size: 9, komi: 0.5, handicap: 2)
        let legacy = try #require(SGFParser.parse("(;SZ[9]HA[2])"))
        #expect(legacy.initialBoard(size: 9, komi: 0.5, handicap: 2) == standard)
        let saved = SGFParser.export(initialState: standard, blackName: "B", whiteName: "W",
                                     result: nil, date: Date(), moves: [])
        let root = try #require(SGFParser.parse(saved))
        #expect(root.addedBlackPoints.count == 2)
        #expect(root.initialBoard(size: 9, komi: 0.5, handicap: 2) == standard)
        let custom = try #require(SGFParser.parse("(;SZ[9]HA[2]PL[B]AB[aa][ab]AW[hh])"))
        let board = custom.initialBoard(size: 9, komi: 0.5, handicap: 2)
        #expect(board.grid.compactMap { $0 }.count == 3)
        #expect(board.currentTurn == .black)
        #expect(board.stone(at: BoardPoint(row: 7, col: 7)) == .white)
    }

    @Test func campaignFourSeasTwentyIslandsAndJsonPackAreValid() throws {
        // 1. External JSON pack loads and expands into 1,000+ mathematically valid puzzles (30K -> 5D)
        let templates = PuzzlePackLoader.jsonTemplates
        #expect(templates.count >= 130, "Expected 130+ verified JSON templates, got \(templates.count)")
        let catalog = PuzzlePackLoader.fullCatalog
        #expect(catalog.count >= 1000, "Expected 1,000+ expanded puzzles, got \(catalog.count)")
        #expect(Set(catalog.map(\.id)).count == catalog.count)

        for puzzle in templates {
            let root = try #require(SGFParser.parse(puzzle.sgf))
            let initial = puzzle.initialBoardState()
            for g in initial.allGroups() {
                #expect(!g.liberties.isEmpty, "Setup group 0 liberties in \(puzzle.id)")
            }
            #expect(GoPuzzle.firstCorrectMove(from: root) != nil, "No hint in \(puzzle.id)")
            var foundCorrect = false
            func walk(_ node: SGFNode, _ state: GoBoardState) {
                if let c = node.comment?.uppercased(), c.contains("CORRECT") { foundCorrect = true }
                for ch in node.children {
                    guard let mv = ch.move else { continue }
                    guard case .success(let out) = state.applying(action: mv.action, color: mv.color) else {
                        Issue.record("Illegal JSON puzzle move in \(puzzle.id)")
                        return
                    }
                    walk(ch, out.nextState)
                }
            }
            walk(root, initial)
            #expect(foundCorrect, "Missing CORRECT leaf in \(puzzle.id)")
        }

        // 2. Verify 5 Regions × 5 Stages = 25 Stages, 125 Campaign Nodes + 25 Bosses reference valid assets
        #expect(StarYiCampaign.allSeas.count == 5)
        #expect(Set(StarYiCampaign.allSeas.map(\.mapImageName)).count == 5, "Every Region must use its own unique map artwork")
        #expect(StarYiCampaign.allIslands.count == 25)
        #expect(StarYiCampaign.allNodes.count == 125)
        #expect(Set(StarYiCampaign.allNodes.map(\.id)).count == 125)

        for sea in StarYiCampaign.allSeas {
            #expect(sea.islands.count == 5)
            #expect(sea.skipGatePuzzleIds.count == 5)
            for gateId in sea.skipGatePuzzleIds {
                #expect(DojoPuzzleBank.findPuzzle(withId: gateId) != nil, "Invalid Skip Gate puzzle \(gateId)")
            }
            for island in sea.islands {
                #expect(island.nodes.count == 5)
                for node in island.nodes {
                    switch node.kind {
                    case .puzzleGauntlet(let pids, _):
                        #expect(pids.count >= 3, "Node \(node.id) should have a multi-puzzle gauntlet")
                        for pid in pids {
                            #expect(DojoPuzzleBank.findPuzzle(withId: pid) != nil, "Missing puzzle \(pid) in \(node.id)")
                        }
                    case .josekiTrial(let courseId):
                        #expect(JosekiLibrary.course(withId: courseId) != nil, "Missing joseki \(courseId) in \(node.id)")
                    case .tacticalScenario(let scenarioId):
                        #expect(TacticalScenariosLibrary.scenario(withId: scenarioId) != nil, "Missing scenario \(scenarioId) in \(node.id)")
                    case .miniDrill(_, _, let count):
                        #expect(count >= 2)
                    }
                }
            }
        }

        // 3. Verify all 12 Preset SGF Tactical Scenarios have legal initial setups (>= 1 liberty) & marked stones
        #expect(TacticalScenariosLibrary.allScenarios.count == 12)
        for scenario in TacticalScenariosLibrary.allScenarios {
            let state = scenario.makeInitialState()
            for g in state.allGroups() {
                #expect(!g.liberties.isEmpty, "Scenario \(scenario.id) setup has 0-liberty group")
            }
            if let marked = scenario.markedPoint {
                #expect(state.stone(at: marked) != nil, "Scenario \(scenario.id) marked point has no stone")
            }
        }

        // 4. Verify Blunder Spotter mini-drill & Anti-Trick Joseki courses
        #expect(GoMiniDrillsLibrary.blunderDrills.count == 6)
        for item in GoMiniDrillsLibrary.blunderDrills {
            let st = item.makeState()
            #expect(item.blunderPoint != nil)
            #expect(!item.correctPoints.isEmpty)
            for cp in item.correctPoints {
                guard case .success = st.applying(action: .place(cp), color: .black) else {
                    Issue.record("Blunder fix \(cp) is illegal in \(item.id)")
                    continue
                }
            }
        }
        #expect(JosekiLibrary.trickMoveCourses.count == 2)
        for course in JosekiLibrary.trickMoveCourses {
            let root = try #require(SGFParser.parse(course.sgfZh))
            var st = GoBoardState(size: course.boardSize, komi: 7.5, startingTurn: course.playerColor)
            for pt in root.addedBlackPoints { st.setSetupStone(.black, at: pt) }
            for pt in root.addedWhitePoints { st.setSetupStone(.white, at: pt) }
            st.resetPositionHistoryToCurrent()
            func walkT(_ n: SGFNode, _ s: GoBoardState) {
                for ch in n.children {
                    guard let mv = ch.move else { continue }
                    guard case .success(let out) = s.applying(action: mv.action, color: mv.color) else {
                        Issue.record("Illegal trick-move Joseki move in \(course.id)")
                        return
                    }
                    walkT(ch, out.nextState)
                }
            }
            walkT(root, st)
        }

        // 5. Verify Sea Skip Gate, Boss Unlocking, SRS Ghost Mapping, Puzzle Rush & 10 AI Tiers
        #expect(AIDifficulty.allCases.count == 10)
        var progress = PuzzleProgressStore()
        let sea1 = StarYiCampaign.allSeas[0]
        let sea2 = StarYiCampaign.allSeas[1]
        #expect(StarYiCampaign.isSeaUnlocked(sea1, progress: progress))
        #expect(!StarYiCampaign.isSeaUnlocked(sea2, progress: progress))

        // Unlocking Sea 2 via Skip Gate opens Sea 2 immediately
        progress.unlockedSeaIds.insert(sea2.id)
        #expect(StarYiCampaign.isSeaUnlocked(sea2, progress: progress))
        #expect(StarYiCampaign.unlockState(for: sea2.islands[0], progress: progress) == .active)

        // SRS due mistake maps as a Ghost onto the matching island
        let sampleNode = sea2.islands[0].nodes[0]
        let samplePuzzleId = try #require(sampleNode.puzzleIds.first)
        progress.srsMistakeItems.append(SRSMistakeItem.initial(puzzleId: samplePuzzleId))
        let ghosts = StarYiCampaign.dueMistakeGhosts(for: sea2.islands[0], progress: progress)
        #expect(!ghosts.isEmpty)

        // Puzzle Rush monotonically climbs from easier (higher rankOrderValue) to harder (lower rankOrderValue)
        let rushSeq = PuzzlePackLoader.generatePuzzleRushSequence()
        #expect(rushSeq.count >= 190)
        #expect(rushSeq.first!.rankOrderValue >= 25)
        #expect(rushSeq.last!.rankOrderValue <= -3)
    }

    @Test func nintendoGlobalFlagshipFeaturesAreValid() throws {
        // 1. Stone Styles & Boss Rewards + 5-Language Localization
        #expect(StoneStyle.allCases.count == 4)
        let allLangs: [AppLanguage] = [.zhHans, .zhHant, .en, .ja, .ko]
        for lang in allLangs {
            let l10n = L10n(language: lang)
            for style in StoneStyle.allCases {
                #expect(!style.displayName(l10n).isEmpty)
                #expect(!style.unlockHint(l10n).isEmpty)
            }
            for sea in StarYiCampaign.allSeas {
                #expect(!sea.localizedName(l10n).isEmpty)
                for island in sea.islands {
                    #expect(!island.localizedName(l10n).isEmpty)
                }
            }
            for category in PuzzleCategory.allCases {
                #expect(!category.localizedTitle(l10n).isEmpty)
            }
            for sticker in GoSticker.allStickers {
                #expect(!sticker.text(l10n).isEmpty)
            }
        }

        // 2. All 20 Island Silent Visual Micro-Demos parse and execute legally
        for island in StarYiCampaign.allIslands {
            let spec = IslandMicroDemos.spec(for: island.id)
            let root = try #require(SGFParser.parse(spec.sgf))
            var st = GoBoardState(size: spec.boardSize, komi: 7.5, startingTurn: .black)
            for pt in root.addedBlackPoints { st.setSetupStone(.black, at: pt) }
            for pt in root.addedWhitePoints { st.setSetupStone(.white, at: pt) }
            st.resetPositionHistoryToCurrent()

            var node = root
            var moveCount = 0
            while let next = node.children.first, let mv = next.move {
                let res = st.applying(action: mv.action, color: mv.color)
                guard case .success(let out) = res else {
                    Issue.record("Illegal micro-demo move in \(island.id)")
                    break
                }
                st = out.nextState
                node = next
                moveCount += 1
            }
            #expect(moveCount >= 1)
        }

        // 3. Built-in Offline Spatial Neural Policy-Value Net produces normalized policy & bounded winrate
        var board = GoBoardState(size: 9)
        board.setSetupStone(.black, at: BoardPoint(row: 2, col: 2))
        board.setSetupStone(.white, at: BoardPoint(row: 6, col: 6))
        board.setSetupStone(.black, at: BoardPoint(row: 2, col: 6))
        board.setSetupStone(.white, at: BoardPoint(row: 6, col: 2))
        board.resetPositionHistoryToCurrent()

        let eval = StarYiNeuralPolicyValueNet.evaluate(state: board, mover: .black)
        #expect(eval.blackWinrate >= 0.02 && eval.blackWinrate <= 0.98)
        #expect(eval.moverWinrate >= 0.02 && eval.moverWinrate <= 0.98)
        #expect(!eval.topPriors.isEmpty)
        let probSum = eval.policy.reduce(0, +)
        #expect(abs(probSum - 1.0) < 0.01)

        // 4. Living Room Handicap Balance Scale across 30K -> 5D
        let r30k = try #require(GoRankOption.presets.first { $0.id == "30K" })
        let r15k = try #require(GoRankOption.presets.first { $0.id == "15K" })
        let r1d = try #require(GoRankOption.presets.first { $0.id == "1D" })
        let evenRec = HandicapBalanceCalculator.recommend(player1: r15k, player2: r15k, preferredBoardSize: .nineteen)
        #expect(evenRec.handicapStones == 0)
        let mismatchRec = HandicapBalanceCalculator.recommend(player1: r15k, player2: r1d, preferredBoardSize: .nineteen)
        #expect(mismatchRec.handicapStones >= 4)
        #expect(mismatchRec.blackIsPlayer1 == true)
        let starterRec = HandicapBalanceCalculator.recommend(player1: r30k, player2: r15k, preferredBoardSize: .seven)
        #expect(starterRec.ruleSet.isCaptureRace)

        // 5. Go Sailor Passport 6-Axis Radar Calculator
        let axes = GoRadarCalculator.computeAxes(progress: PuzzleProgressStore())
        #expect(axes.count == PuzzleCategory.allCases.count)
        for axis in axes {
            #expect(axis.value >= 0.15 && axis.value <= 1.0)
        }
    }

    @Test func campaignSequentialIslandAndSeaUnlockProgression() throws {
        var progress = PuzzleProgressStore()
        let allIslands = StarYiCampaign.allIslands
        #expect(allIslands.count == 25)

        // Initially only Island 1 (s1-reef) is active; all subsequent islands are locked
        #expect(StarYiCampaign.unlockState(for: allIslands[0], progress: progress) == .active)
        for island in allIslands.dropFirst() {
            #expect(StarYiCampaign.unlockState(for: island, progress: progress) == .locked)
        }

        // Walk through all 20 islands across all 4 seas, clearing each stage with just 1 star (no boss defeat required)
        for (idx, island) in allIslands.enumerated() {
            #expect(StarYiCampaign.unlockState(for: island, progress: progress) == .active, "Island \(island.id) should be active")
            #expect(!StarYiCampaign.isBossUnlocked(for: island, progress: progress))

            for (nodeIdx, node) in island.nodes.enumerated() {
                #expect(StarYiCampaign.nodeState(at: nodeIdx, in: island, progress: progress) == .active)
                progress.campaignNodeStars[node.id] = 1
                #expect(StarYiCampaign.nodeState(at: nodeIdx, in: island, progress: progress) == .cleared(stars: 1))

                if nodeIdx + 1 < island.nodes.count {
                    #expect(StarYiCampaign.nodeState(at: nodeIdx + 1, in: island, progress: progress) == .active)
                    #expect(!StarYiCampaign.isIslandCleared(island, progress: progress))
                }
            }

            // Clearing all 5 stages automatically clears the island, unlocks its Boss, and unlocks the next island & sea
            #expect(StarYiCampaign.isIslandCleared(island, progress: progress))
            #expect(StarYiCampaign.unlockState(for: island, progress: progress) == .cleared)
            #expect(StarYiCampaign.isBossUnlocked(for: island, progress: progress))

            if idx + 1 < allIslands.count {
                let next = allIslands[idx + 1]
                let nextSea = try #require(StarYiCampaign.sea(withId: next.seaId))
                #expect(StarYiCampaign.isSeaUnlocked(nextSea, progress: progress), "Sea \(nextSea.id) should auto-unlock after clearing \(island.id)")
                #expect(StarYiCampaign.unlockState(for: next, progress: progress) == .active, "Island \(next.id) should auto-unlock after clearing \(island.id)")
            }
        }
    }

    @Test func aiDeepReviewOpeningSymmetryAndScoreCalibration() async throws {
        let engine = LocalMCTSGoEngine()
        let initial = GoBoardState(size: 19, komi: 7.5)
        let q16 = BoardPoint(row: 3, col: 15)
        let d4 = BoardPoint(row: 15, col: 3)
        let moves = [
            GoMove(moveNumber: 1, color: .black, action: .place(q16), capturedPoints: []),
            GoMove(moveNumber: 2, color: .white, action: .place(d4), capturedPoints: [])
        ]

        let report = await engine.analyzeGame(initialState: initial, moves: moves)
        #expect(report.reviewedMoves.count == 2)
        let move1 = try #require(report.reviewedMoves.first)
        // Move 1 on an empty 19x19 board at Q16 must never produce +353.5 pts or be diagnosed as a mistake vs symmetric D4
        #expect(abs(move1.blackScoreLeadAfter) < 15.0, "Move 1 scoreLead should be calibrated, got \(move1.blackScoreLeadAfter)")
        #expect(move1.quality == .good || move1.quality == .brilliant, "Empty-board star point Q16 must not be marked as a mistake")
        #expect(move1.moverScoreDrop == 0.0)
        for lead in report.scoreLeadHistory {
            #expect(abs(lead) < 25.0, "Opening score lead should stay realistic, got \(lead)")
        }
    }

    @Test func aiAvoidsThrowingIntoSealedTwoLineOpponentStrip() async {
        var state = GoBoardState(size: 9, komi: 6.5)
        // Black builds a solid vertical wall on col 2, completely sealing cols 0..1 (a 2-line dead strip).
        for r in 0..<9 {
            state.grid[state.index(row: r, col: 2)] = .black
        }
        // White has a group on col 6 with open playable territory on cols 3..8.
        for r in 2...6 {
            state.grid[state.index(row: r, col: 6)] = .white
        }
        state.moveCount = 24
        state.currentTurn = .white
        // Simulate Black having just played on the wall (e.g. finishing a capture inside cols 0..1).
        state.lastMove = .place(BoardPoint(row: 4, col: 2))

        let groups = state.allGroups()
        var groupIndexAt = Array(repeating: -1, count: 81)
        for (gIdx, g) in groups.enumerated() {
            for s in g.stones { groupIndexAt[s] = gIdx }
        }
        let mask = LocalMCTSGoEngine.computeHopelessOpponentPocketMask(
            state: state,
            for: .white,
            groups: groups,
            groupIndexAt: groupIndexAt
        )
        for r in 0..<9 {
            for c in 0...1 {
                #expect(mask[state.index(row: r, col: c)], "Cell (\(r),\(c)) in sealed 2-line Black strip should be marked hopeless for White")
            }
        }
        #expect(!mask[state.index(row: 4, col: 4)], "Open center cell should not be marked hopeless")

        let engine = LocalMCTSGoEngine()
        for level in [AIDifficulty.sprout, .rabbit, .fox] {
            let move = await engine.selectMove(for: state, color: .white, level: level, ruleSet: .standard)
            if case .place(let pt) = move {
                #expect(pt.col > 1, "\(level) AI should not throw a stone into sealed 2-line Black strip, got \(pt)")
            }
        }
    }

    @Test func aiPassesWhenOnlyHopelessOpponentPocketAndOwnTerritoryRemain() async {
        var state = GoBoardState(size: 9, komi: 6.5)
        // Cols 0..1: empty 2-line strip sealed by Black on cols 2..4.
        for r in 0..<9 {
            state.grid[state.index(row: r, col: 2)] = .black
            state.grid[state.index(row: r, col: 3)] = .black
            state.grid[state.index(row: r, col: 4)] = .black
            // Cols 5..7: White solid block with two secure single-point eyes on col 8 (rows 1 and 7).
            state.grid[state.index(row: r, col: 5)] = .white
            state.grid[state.index(row: r, col: 6)] = .white
            state.grid[state.index(row: r, col: 7)] = .white
            if r != 1 && r != 7 {
                state.grid[state.index(row: r, col: 8)] = .white
            }
        }
        state.moveCount = 60
        state.currentTurn = .white
        state.lastMove = .place(BoardPoint(row: 4, col: 2))

        let engine = LocalMCTSGoEngine()
        let move = await engine.selectMove(for: state, color: .white, level: .rabbit, ruleSet: .standard)
        #expect(move == .pass, "AI should pass when only sealed opponent dead strip and own eyes remain, got \(move)")
    }

    @Test func aiStillAllowsPlayingInsidePocketWhenOpponentWallIsInDanger() {
        var state = GoBoardState(size: 9, komi: 6.5)
        // Small 2-point Black eye on (0,0) and (0,1), surrounded by Black on (1,0), (1,1), (0,2),
        // and White completely enclosing the outside so Black's wall has only 2 liberties!
        state.grid[state.index(row: 1, col: 0)] = .black
        state.grid[state.index(row: 1, col: 1)] = .black
        state.grid[state.index(row: 0, col: 2)] = .black
        state.grid[state.index(row: 1, col: 2)] = .black

        state.grid[state.index(row: 2, col: 0)] = .white
        state.grid[state.index(row: 2, col: 1)] = .white
        state.grid[state.index(row: 2, col: 2)] = .white
        state.grid[state.index(row: 0, col: 3)] = .white
        state.grid[state.index(row: 1, col: 3)] = .white

        let groups = state.allGroups()
        var groupIndexAt = Array(repeating: -1, count: 81)
        for (gIdx, g) in groups.enumerated() {
            for s in g.stones { groupIndexAt[s] = gIdx }
        }
        let mask = LocalMCTSGoEngine.computeHopelessOpponentPocketMask(
            state: state,
            for: .white,
            groups: groups,
            groupIndexAt: groupIndexAt
        )
        #expect(!mask[state.index(row: 0, col: 0)], "Pocket bordering a 2-liberty opponent group must NOT be suppressed")
        #expect(!mask[state.index(row: 0, col: 1)], "Pocket bordering a 2-liberty opponent group must NOT be suppressed")
    }

    @Test func hopelessPocketMaskSuppressesSealed2x6PocketEvenWithTrappedOwnStone() {
        var state = GoBoardState(size: 9, komi: 6.5)
        // Black seals rows 0..5, cols 0..1 (a 2x6 pocket) with solid walls on col 2 and row 6.
        for r in 0...6 {
            state.grid[state.index(row: r, col: 2)] = .black
        }
        state.grid[state.index(row: 6, col: 0)] = .black
        state.grid[state.index(row: 6, col: 1)] = .black
        // One doomed White remnant stone sits inside the 2x6 pocket at (2, 0).
        state.grid[state.index(row: 2, col: 0)] = .white
        // White has an open living group elsewhere so the board isn't trivial.
        for r in 2...6 {
            state.grid[state.index(row: r, col: 6)] = .white
        }

        let groups = state.allGroups()
        var groupIndexAt = Array(repeating: -1, count: 81)
        for (gIdx, g) in groups.enumerated() {
            for s in g.stones { groupIndexAt[s] = gIdx }
        }
        let mask = LocalMCTSGoEngine.computeHopelessOpponentPocketMask(
            state: state,
            for: .white,
            groups: groups,
            groupIndexAt: groupIndexAt
        )

        for r in 0...5 {
            for c in 0...1 {
                let idx = state.index(row: r, col: c)
                if state.grid[idx] == nil {
                    #expect(mask[idx], "Empty cell (\(r),\(c)) in sealed 2x6 pocket with trapped stone should be marked hopeless")
                }
            }
        }
        #expect(!mask[state.index(row: 4, col: 4)], "Open center cell must not be marked hopeless")
    }

    @Test func aiResignationEvaluatorRespectsGuardsAndConsecutiveStreak() {
        var state = GoBoardState(size: 9, komi: 5.5)
        state.moveCount = 30
        // Settled 9x9 ownership map from White (AI)'s perspective: Black solidly owns 52 points, White owns 24, 5 unsettled.
        var settledOwnership = Array(repeating: 0.0, count: 81)
        for i in 0..<52 { settledOwnership[i] = -0.95 }
        for i in 52..<76 { settledOwnership[i] = 0.90 }

        // 1. Capture Race and Tactical Scenarios never trigger resignation.
        let capEval = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            ruleSet: .captureRace(target: 3),
            isTacticalScenario: false,
            consecutiveHopelessTurns: 5,
            neuralWinrateForAI: 0.005,
            neuralScoreLeadForAI: -40.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(!capEval.shouldOfferResign)

        let scenarioEval = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            ruleSet: .standard,
            isTacticalScenario: true,
            consecutiveHopelessTurns: 5,
            neuralWinrateForAI: 0.005,
            neuralScoreLeadForAI: -40.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(!scenarioEval.shouldOfferResign)

        // 2. Neural winrate + score lead + settled ownership requires 3 consecutive hopeless turns
        //    when AI still has a non-pass move to play.
        let samplePlace = MoveAction.place(BoardPoint(row: 4, col: 4))
        let turn1 = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .panda,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 0,
            chosenAction: samplePlace,
            neuralWinrateForAI: 0.02,
            neuralScoreLeadForAI: -22.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(turn1.isPositionHopeless)
        #expect(!turn1.shouldOfferResign)
        #expect(turn1.nextConsecutiveHopelessTurns == 1)

        let turn2 = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .panda,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: turn1.nextConsecutiveHopelessTurns,
            chosenAction: samplePlace,
            neuralWinrateForAI: 0.02,
            neuralScoreLeadForAI: -22.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(!turn2.shouldOfferResign)
        #expect(turn2.nextConsecutiveHopelessTurns == 2)

        let turn3 = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .panda,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: turn2.nextConsecutiveHopelessTurns,
            chosenAction: samplePlace,
            neuralWinrateForAI: 0.02,
            neuralScoreLeadForAI: -22.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(turn3.shouldOfferResign)
        #expect(turn3.estimatedHumanLead == 22.0)

        // 3. Move exhaustion (.pass) with large deficit offers resignation immediately,
        //    while close endgame (.pass with small deficit) does NOT resign.
        let exhaustedLoss = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .panda,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 0,
            chosenAction: .pass,
            neuralWinrateForAI: 0.01,
            neuralScoreLeadForAI: -18.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(exhaustedLoss.shouldOfferResign, "Passing while hopelessly behind should offer resignation immediately")

        let closeEndgamePass = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .panda,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 0,
            chosenAction: .pass,
            neuralWinrateForAI: 0.04,
            neuralScoreLeadForAI: -5.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(!closeEndgamePass.shouldOfferResign, "Close endgame pass should go to normal scoring, not resign")

        // 4. Recent major capture (>= 5 stones on 9x9) accelerates resignation on settled board to streak 2.
        let majorCaptureTurn2 = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .panda,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 1,
            chosenAction: samplePlace,
            recentMaxCaptureAgainstAI: 6,
            neuralWinrateForAI: 0.02,
            neuralScoreLeadForAI: -22.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(majorCaptureTurn2.shouldOfferResign, "Major capture on a settled board should accelerate resignation to 2 consecutive turns")

        // 5. Rank calibration: 15K Fox is more resilient than 3D Phoenix at the same borderline deficit.
        let foxEval = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .fox,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 2,
            chosenAction: samplePlace,
            neuralWinrateForAI: 0.02,
            neuralScoreLeadForAI: -14.0,
            neuralOwnershipForAI: settledOwnership
        )
        let phoenixEval = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            difficulty: .phoenix,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 2,
            chosenAction: samplePlace,
            neuralWinrateForAI: 0.02,
            neuralScoreLeadForAI: -14.0,
            neuralOwnershipForAI: settledOwnership
        )
        #expect(!foxEval.shouldOfferResign, "15K Fox should keep fighting at -14 pts on 9x9")
        #expect(phoenixEval.shouldOfferResign, "3D Phoenix should offer resignation at -14 pts on settled 9x9")
    }

    @Test func aiDoesNotResignEarlyWhenTopHalfOf19x19BoardIsStillWideOpen() {
        var state = GoBoardState(size: 19, komi: 7.5)
        state.moveCount = 121
        // Mirror the real midgame scenario: Black dominates a big fight in the bottom half,
        // while the top half (rows 0..8) is still wide open with only scattered stones.
        for r in 11...17 {
            for c in 2...14 {
                if (r + c) % 2 == 0 {
                    state.grid[state.index(row: r, col: c)] = .black
                }
            }
        }
        // Scattered White stones in the bottom and top half
        state.grid[state.index(row: 12, col: 1)] = .white
        state.grid[state.index(row: 13, col: 1)] = .white
        state.grid[state.index(row: 5, col: 1)] = .white
        state.grid[state.index(row: 4, col: 15)] = .white
        state.grid[state.index(row: 3, col: 3)] = .black
        state.grid[state.index(row: 3, col: 9)] = .black

        let eval = AIResignationEvaluator.evaluate(
            state: state,
            aiColor: .white,
            ruleSet: .standard,
            isTacticalScenario: false,
            consecutiveHopelessTurns: 5
        )
        #expect(eval.unsettledRatio > 0.30, "Top half of 19x19 board should be recognized as wide-open unsettled space")
        #expect(eval.solidOpponentPoints < AIResignationEvaluator.guaranteedMajorityThreshold(for: 19))
        #expect(!eval.shouldOfferResign, "AI must NOT offer resignation while half the 19x19 board is still open for a comeback")
    }

    @Test @MainActor func gameViewModelSoftResignAcceptAndDeclineFlow() async throws {
        final class ResigningStubAI: GoAIEngine, @unchecked Sendable {
            let engineName = "ResigningStubAI"
            func selectMove(for state: GoBoardState, color: StoneColor, level: AIDifficulty) async -> MoveAction { .resign }
            func selectMoveDecision(
                for state: GoBoardState,
                color: StoneColor,
                level: AIDifficulty,
                ruleSet: GameRuleSet,
                coachingStyle: AICoachingStyle
            ) async -> AIMoveDecision {
                AIMoveDecision(action: .resign, moverWinrate: 0.01, moverScoreLead: -35.0)
            }
            func suggestMoves(for state: GoBoardState, color: StoneColor, count: Int) async -> [MoveSuggestion] { [] }
            func analyzePosition(for state: GoBoardState, color: StoneColor, maxVariations: Int) async -> PositionAnalysis {
                PositionAnalysis(blackWinrate: 0.99, blackScoreLead: 35.0, topVariations: [])
            }
            func analyzeGame(initialState: GoBoardState, moves: [GoMove]) async -> GameReviewReport {
                GameReviewReport(initialBlackWinrate: 0.5, winrateHistory: [0.5], scoreLeadHistory: [0.0], reviewedMoves: [])
            }
        }

        // Case 1: Human accepts AI resignation -> Black wins by resignation (B+R).
        let vmAccept = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .rabbit, playerColor: .black),
            aiEngine: ResigningStubAI(),
            simulateHumanThinkingPacing: false
        )
        vmAccept.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        try await Task.sleep(nanoseconds: 450_000_000)

        #expect(vmAccept.showAIResignOfferDialog, "AI should present soft resign offer dialog")
        #expect(!vmAccept.isGameOver, "Game should wait for player choice before ending")

        vmAccept.acceptAIResignation()
        #expect(!vmAccept.showAIResignOfferDialog)
        #expect(vmAccept.isGameOver)
        #expect(vmAccept.gameResult?.winner == .black)
        #expect(vmAccept.gameResult?.byResignation == true)
        #expect(vmAccept.gameResult?.sgfResultString == "B+R")

        // Case 2: Human declines AI resignation -> game continues and AI does not re-offer.
        let vmDecline = GameViewModel(
            boardSize: .nine,
            mode: .vsAI(difficulty: .rabbit, playerColor: .black),
            aiEngine: ResigningStubAI(),
            simulateHumanThinkingPacing: false
        )
        vmDecline.handleBoardTap(at: BoardPoint(row: 4, col: 4))
        try await Task.sleep(nanoseconds: 450_000_000)
        #expect(vmDecline.showAIResignOfferDialog)

        vmDecline.declineAIResignation()
        #expect(!vmDecline.showAIResignOfferDialog)
        #expect(!vmDecline.isGameOver)
        #expect(vmDecline.moves.last?.action == .pass)

        // Next human move triggers AI again; AI must NOT pop up resign dialog a second time.
        vmDecline.handleBoardTap(at: BoardPoint(row: 2, col: 2))
        try await Task.sleep(nanoseconds: 450_000_000)
        #expect(!vmDecline.showAIResignOfferDialog, "AI must not nag with resign offer after player chose Keep Playing")
    }

    @Test @MainActor func persistentGauntletHeartsRegenAndMistakeReviewRecovery() throws {
        let suite = "StarYiGoTests.GauntletHearts.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let t0 = Date()
        let storage = StorageService(defaults: defaults)
        let app = AppState(storage: storage)

        #expect(app.currentGauntletHearts == 3)
        #expect(app.secondsUntilNextGauntletHeart(now: t0) == nil)

        // Losing 3 hearts persists across app relaunch (cannot be bypassed by backing out to Island)
        #expect(app.consumeGauntletHeart(forPuzzleId: "cap-01", now: t0) == 2)
        #expect(app.consumeGauntletHeart(forPuzzleId: "cap-02", now: t0.addingTimeInterval(10)) == 1)
        #expect(app.consumeGauntletHeart(forPuzzleId: "cap-01", now: t0.addingTimeInterval(20)) == 0)

        let reopened = AppState(storage: StorageService(defaults: defaults))
        #expect(reopened.puzzleProgress.effectiveGauntletHearts(now: t0.addingTimeInterval(30)) == 0)
        #expect(reopened.puzzleProgress.pendingReviewPuzzleIds == ["cap-01", "cap-02"])

        // 4m59s after first loss: still 0 hearts, 1s remaining
        let almostOneRegen = t0.addingTimeInterval(PuzzleProgressStore.heartRegenIntervalSeconds - 1)
        #expect(reopened.puzzleProgress.effectiveGauntletHearts(now: almostOneRegen) == 0)
        #expect(reopened.secondsUntilNextGauntletHeart(now: almostOneRegen) == 1)

        // 5m00s after first loss: 1 heart recovered automatically
        let oneRegen = t0.addingTimeInterval(PuzzleProgressStore.heartRegenIntervalSeconds)
        #expect(reopened.puzzleProgress.effectiveGauntletHearts(now: oneRegen) == 1)

        // 15m00s after first loss: capped at max 3 hearts
        let fullRegen = t0.addingTimeInterval(PuzzleProgressStore.heartRegenIntervalSeconds * 4)
        #expect(reopened.puzzleProgress.effectiveGauntletHearts(now: fullRegen) == 3)
        #expect(reopened.secondsUntilNextGauntletHeart(now: fullRegen) == nil)

        // Mistake review immediately restores full hearts and clears reviewed puzzle IDs
        reopened.restoreGauntletHeartsFromMistakeReview(reviewedPuzzleIds: ["cap-01", "cap-02"], now: t0.addingTimeInterval(35))
        #expect(reopened.currentGauntletHearts == 3)
        #expect(reopened.puzzleProgress.pendingReviewPuzzleIds.isEmpty)
        #expect(reopened.puzzleProgress.gauntletHeartLastRegenDate == nil)

        // Legacy JSON without gauntletHearts decodes cleanly to full 3 hearts
        let legacyData = Data(#"{"starsByPuzzleId":{"cap-01":3}}"#.utf8)
        let decoded = try JSONDecoder().decode(PuzzleProgressStore.self, from: legacyData)
        #expect(decoded.gauntletHearts == 3)
        #expect(decoded.pendingReviewPuzzleIds.isEmpty)
    }

    @Test func allLocalizedVoicePacksAreBundled() throws {
        let bundle = Bundle.main
        let expectedLanguages = ["zh", "en", "ja", "ko"]

        for lang in expectedLanguages {
            var count = 0
            for cue in VoiceCue.allCases {
                for variant in 1...cue.variantCount {
                    let name = "voice_\(lang)_\(cue.filePrefix)_\(variant)"
                    let url =
                        bundle.url(forResource: name, withExtension: "m4a", subdirectory: "Resources/Voice/\(lang)") ??
                        bundle.url(forResource: name, withExtension: "m4a", subdirectory: "Voice/\(lang)") ??
                        bundle.url(forResource: name, withExtension: "m4a", subdirectory: lang) ??
                        bundle.url(forResource: name, withExtension: "m4a")
                    #expect(url != nil, "Missing bundled voice asset: \(name).m4a")
                    count += 1
                }
            }
            #expect(count == 40)
        }

        // Verify language -> voiceLanguageCode mapping for all AppLanguage cases
        #expect((AppLanguage.zhHans.isChinese ? "zh" : AppLanguage.zhHans.resolvedCode) == "zh")
        #expect((AppLanguage.zhHant.isChinese ? "zh" : AppLanguage.zhHant.resolvedCode) == "zh")
        #expect((AppLanguage.en.isChinese ? "zh" : AppLanguage.en.resolvedCode) == "en")
        #expect((AppLanguage.ja.isChinese ? "zh" : AppLanguage.ja.resolvedCode) == "ja")
        #expect((AppLanguage.ko.isChinese ? "zh" : AppLanguage.ko.resolvedCode) == "ko")
    }

    @Test func allThreeKataGoCoreMLModelsAreBundledAndDefaultIsB10C128() async throws {
        // Default preset in AppSettings must be kata1-b10c128
        let defaults = AppSettings()
        #expect(defaults.aiModelPreset == .b10c128)
        let legacyDecoded = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        #expect(legacyDecoded.aiModelPreset == .b10c128)

        // All 3 models must be runnable via CoreMLGoAIEngine:
        // b6c96 & b10c128 are bundled in the main app; b18c384nbt is packaged via On-Demand Resources (ODR).
        let odrRequest = NSBundleResourceRequest(tags: [KataGoProModelODRManager.odrTag])
        try await odrRequest.beginAccessingResources()
        defer { odrRequest.endAccessingResources() }

        let engine = CoreMLGoAIEngine(bundle: .main, supportedBoardSize: 19, initialPreset: .b10c128)
        let board = GoBoardState(size: 9)
        for preset in KataGoModelPreset.allCases {
            engine.setActiveModelPreset(preset)
            let loaded = engine.loadModel(for: preset)
            #expect(loaded != nil, "Missing bundled CoreML model for \(preset.rawValue) (\(preset.resourceName).mlmodelc)")
            #expect(engine.engineName.contains(preset.technicalName))

            let decision = await engine.selectMoveDecision(
                for: board,
                color: .black,
                level: .deer,
                ruleSet: .standard,
                coachingStyle: .standard
            )
            if case .place(let pt) = decision.action {
                #expect(board.isLegal(point: pt, for: .black))
            } else {
                Issue.record("Expected board move from \(preset.rawValue) on empty 9x9 board")
            }
        }
    }

    @MainActor
    @Test func familyProfileEditDeleteAndNicknameClamp() throws {
        // Weighted nickname clamp: max 10 CJK chars (20 units) or 20 ASCII chars
        #expect(UserProfile.clampedNickname("一二三四五六七八九十十一十二") == "一二三四五六七八九十")
        #expect(UserProfile.clampedNickname("ABCDEFGHIJKLMNOPQRSTUVWXYZ") == "ABCDEFGHIJKLMNOPQRST")
        #expect(UserProfile.clampedNickname("小明12345678901234567890") == "小明1234567890123456")

        let suiteName = "StarYiGoTests.FamilyProfile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let storage = StorageService(defaults: defaults)
        let appState = AppState(storage: storage)
        #expect(appState.familyProfiles.count == 1)
        let firstProfile = appState.familyProfiles[0]

        // Add second & third profiles
        appState.addFamilyProfile(nickname: "小熊猫", avatarEmoji: "🐼")
        appState.addFamilyProfile(nickname: "小兔子", avatarEmoji: "🐰")
        #expect(appState.familyProfiles.count == 3)
        let rabbit = appState.profile
        #expect(rabbit.nickname == "小兔子")

        // Edit a non-active profile
        let panda = try #require(appState.familyProfiles.first { $0.nickname == "小熊猫" })
        appState.editFamilyProfile(panda, nickname: "大熊猫", avatarEmoji: "🐯")
        #expect(appState.familyProfiles.contains { $0.id == panda.id && $0.nickname == "大熊猫" && $0.avatarEmoji == "🐯" })

        // Delete the currently active profile (rabbit) -> switches active profile and persists removal
        appState.deleteFamilyProfile(rabbit)
        #expect(appState.familyProfiles.count == 2)
        #expect(!appState.familyProfiles.contains { $0.id == rabbit.id })
        #expect(appState.profile.id != rabbit.id)

        // Delete a non-active profile -> persists removal
        let remainingOther = try #require(appState.familyProfiles.first { $0.id != appState.profile.id })
        appState.deleteFamilyProfile(remainingOther)
        #expect(appState.familyProfiles.count == 1)
        #expect(!appState.familyProfiles.contains { $0.id == remainingOther.id })

        // Cannot delete the last remaining profile
        let lastProfile = appState.familyProfiles[0]
        appState.deleteFamilyProfile(lastProfile)
        #expect(appState.familyProfiles.count == 1)
        #expect(appState.familyProfiles[0].id == firstProfile.id || appState.familyProfiles[0].id == lastProfile.id)

        // Reloading AppState from storage confirms deleted profiles do not come back
        let reloaded = AppState(storage: StorageService(defaults: defaults))
        #expect(reloaded.familyProfiles.count == 1)
        #expect(reloaded.familyProfiles[0].id == lastProfile.id)
        #expect(!reloaded.familyProfiles.contains { $0.id == rabbit.id })
    }

    @Test func bundledRoundedFontsSupportChineseJapaneseAndKorean() throws {
        AppFont.registerBundledFonts()

        // All 6 bundled rounded fonts must resolve cleanly
        let expectedNames = [
            AppFont.mediumPostScriptName,
            AppFont.boldPostScriptName,
            AppFont.jpMediumPostScriptName,
            AppFont.jpBoldPostScriptName,
            AppFont.krMediumPostScriptName,
            AppFont.krBoldPostScriptName,
        ]
        for psName in expectedNames {
            #expect(UIFont(name: psName, size: 16) != nil, "Missing bundled font \(psName)")
        }

        // Language-specific routing
        #expect(AppFont.postScriptName(for: .medium, languageCode: "ja") == AppFont.jpMediumPostScriptName)
        #expect(AppFont.postScriptName(for: .bold, languageCode: "ja") == AppFont.jpBoldPostScriptName)
        #expect(AppFont.postScriptName(for: .medium, languageCode: "ko") == AppFont.krMediumPostScriptName)
        #expect(AppFont.postScriptName(for: .black, languageCode: "ko") == AppFont.krBoldPostScriptName)
        #expect(AppFont.postScriptName(for: .semibold, languageCode: "zh-Hans") == AppFont.mediumPostScriptName)
        #expect(AppFont.postScriptName(for: .heavy, languageCode: "en") == AppFont.boldPostScriptName)

        // Primary font + rounded CJK cascade list
        let jaFont = try #require(AppFont.uiFont(size: 18, weight: .bold, languageCode: "ja"))
        #expect(jaFont.fontName == AppFont.jpBoldPostScriptName)
        let jaCascade = jaFont.fontDescriptor.object(forKey: .cascadeList) as? [UIFontDescriptor]
        #expect(jaCascade?.count == 2)

        let koFont = try #require(AppFont.uiFont(size: 18, weight: .medium, languageCode: "ko"))
        #expect(koFont.fontName == AppFont.krMediumPostScriptName)
        let koCascade = koFont.fontDescriptor.object(forKey: .cascadeList) as? [UIFontDescriptor]
        #expect(koCascade?.count == 2)
    }

    @Test func unsupportedLanguagesFallbackToEnglishForUIAndVoice() throws {
        // Unsupported locales (Spanish, French, German, Portuguese, empty) must resolve to English
        for unsupported in [["es-ES"], ["es-MX"], ["fr-FR"], ["de-DE"], ["pt-BR"], ["ar-SA"], []] {
            let code = AppLanguage.resolvedCode(forPreferredLanguages: unsupported)
            #expect(code == "en", "Expected 'en' for \(unsupported), got \(code)")
            #expect(AppLanguage.voiceLanguageCode(forResolvedCode: code) == "en")
        }

        // Unsupported primary locale still defaults to English even if secondary is another language
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["es-ES", "zh-Hans-CN"]) == "en")

        // Supported locales map to their native UI & voice packs
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["en-US"]) == "en")
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["zh-Hans-CN"]) == "zh-Hans")
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["zh-Hant-TW"]) == "zh-Hant")
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["zh-HK"]) == "zh-Hant")
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["ja-JP"]) == "ja")
        #expect(AppLanguage.resolvedCode(forPreferredLanguages: ["ko-KR"]) == "ko")

        #expect(AppLanguage.en.voiceLanguageCode == "en")
        #expect(AppLanguage.zhHans.voiceLanguageCode == "zh")
        #expect(AppLanguage.zhHant.voiceLanguageCode == "zh")
        #expect(AppLanguage.ja.voiceLanguageCode == "ja")
        #expect(AppLanguage.ko.voiceLanguageCode == "ko")

        // Arbitrary unsupported voice codes normalize cleanly to English
        #expect(AppLanguage.voiceLanguageCode(forResolvedCode: "es") == "en")
        #expect(AppLanguage.voiceLanguageCode(forResolvedCode: "fr-CA") == "en")
    }
}

private extension Result where Success == MoveOutcome, Failure == MoveError {
    static func == (lhs: Self, rhs: Self) -> Bool {
        switch (lhs, rhs) {
        case (.failure(let a), .failure(let b)):
            return a == b
        default:
            return false
        }
    }
}

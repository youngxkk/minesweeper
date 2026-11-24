//
//  StarYiGoTests.swift
//  StarYi Go Tests
//

import Foundation
import Testing
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
            size: 9,
            komi: 5.5,
            handicap: 0,
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

        // Built-in Classic Study SGF games all replay legally
        let classics = BuiltInClassicGames.records(l10n: L10n(language: .en))
        #expect(classics.count == 3)
        for rec in classics {
            guard let root = SGFParser.parse(rec.sgf) else {
                Issue.record("Failed to parse classic game \(rec.blackName)")
                continue
            }
            var state = GoBoardState(size: rec.boardSize, komi: rec.komi, handicap: rec.handicap)
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

        let classicIds = Set(BuiltInClassicGames.records(l10n: L10n(language: .en)).map(\.id))

        for entry in GoTermCodex.allEntries {
            guard let root = SGFParser.parse(entry.demoSGF) else {
                Issue.record("Failed to parse Codex demo SGF \(entry.id)")
                continue
            }
            if let pid = entry.practicePuzzleId {
                #expect(StarYiIslands.findAnyPuzzle(withId: pid) != nil, "Invalid practicePuzzleId \(pid) in Codex \(entry.id)")
            }
            if let cid = entry.practiceClassicId {
                #expect(classicIds.contains(cid), "Invalid practiceClassicId in Codex \(entry.id)")
            }

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

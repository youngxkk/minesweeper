//
//  Phase2And3VerificationTests.swift
//  StarYiGoTests — Automated Verification for Phase 0–3 Refactors, Localization Parity & Content Integrity
//

import Foundation
import Testing
@testable import StarYiGo

struct Phase2And3VerificationTests {

    // MARK: - 1. GoBoardState Fast Legality & Eye-Shape Accuracy

    @Test func fastIsLegalMatchesApplyingOnComplexPositions() throws {
        var state = GoBoardState(size: 9, komi: 5.5, handicap: 0)
        // Build a position with captures, suicide candidates, and a Ko shape
        let setupMoves: [(StoneColor, BoardPoint)] = [
            (.black, BoardPoint(row: 2, col: 2)),
            (.white, BoardPoint(row: 2, col: 3)),
            (.black, BoardPoint(row: 1, col: 3)),
            (.white, BoardPoint(row: 1, col: 4)),
            (.black, BoardPoint(row: 3, col: 3)),
            (.white, BoardPoint(row: 3, col: 4)),
            (.black, BoardPoint(row: 2, col: 4)),
            (.white, BoardPoint(row: 2, col: 5))
        ]
        for (color, pt) in setupMoves {
            state.setSetupStone(color, at: pt)
        }
        state.resetPositionHistoryToCurrent()

        for color in [StoneColor.black, .white] {
            for r in 0..<state.size {
                for c in 0..<state.size {
                    let pt = BoardPoint(row: r, col: c)
                    let fast = state.isLegal(point: pt, for: color)
                    let exact: Bool
                    if case .success = state.applying(action: .place(pt), color: color) {
                        exact = true
                    } else {
                        exact = false
                    }
                    #expect(fast == exact, "Mismatch at (\(r),\(c)) for \(color)")
                }
            }
        }
    }

    @Test func handicapOneKeepsFullKomiAndDeadSingleEyesAreNotAlive() {
        let h1 = GoBoardState(size: 19, handicap: 1)
        #expect(h1.komi == 7.5)
        let h2 = GoBoardState(size: 19, handicap: 2)
        #expect(h2.komi == 0.5)

        // Pyramid Four (丁四) enclosed in a 7x7 corner: (0,0),(0,1),(0,2),(1,1) empty, surrounded by Black
        var pyramid = GoBoardState(size: 7, komi: 0)
        let pyramidWall = [
            BoardPoint(row: 0, col: 3),
            BoardPoint(row: 1, col: 0),
            BoardPoint(row: 1, col: 2),
            BoardPoint(row: 1, col: 3),
            BoardPoint(row: 2, col: 0),
            BoardPoint(row: 2, col: 1),
            BoardPoint(row: 2, col: 2)
        ]
        for pt in pyramidWall { pyramid.setSetupStone(.black, at: pt) }
        #expect(pyramid.twoEyeAliveAnalysis().aliveStoneIndices.isEmpty, "Pyramid Four must NOT be unconditionally alive")

        // Straight Four (直四): (0,0),(0,1),(0,2),(0,3) empty, surrounded by Black
        var straight4 = GoBoardState(size: 7, komi: 0)
        for c in 0...4 { straight4.setSetupStone(.black, at: BoardPoint(row: 1, col: c)) }
        straight4.setSetupStone(.black, at: BoardPoint(row: 0, col: 4))
        #expect(!straight4.twoEyeAliveAnalysis().aliveStoneIndices.isEmpty, "Straight Four must be unconditionally alive")
    }

    // MARK: - 2. StorageService Atomic File Persistence, Legacy Migration & Corrupt Recovery

    @Test func storageServiceMigratesLegacyUserDefaultsAndRecoversFromCorruption() throws {
        let suiteName = "StarYiGoTests.AtomicFile.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("StarYiGoAtomicTest-\(UUID().uuidString)", isDirectory: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Seed legacy UserDefaults blob directly
        let sampleGame = SavedGameRecord(
            id: UUID(),
            date: Date(),
            boardSize: 9,
            komi: 5.5,
            handicap: 0,
            blackName: "Kid",
            whiteName: "Fox",
            resultString: "B+3.5",
            moveCount: 24,
            sgf: "(;GM[1]FF[4]SZ[9];B[ee])"
        )
        let legacyData = try JSONEncoder().encode([sampleGame])
        defaults.set(legacyData, forKey: "starpoint.savedGames.v1")

        let storage = StorageService(
            defaults: defaults,
            photoHistoryDirectory: tempDir.appendingPathComponent("Photos", isDirectory: true),
            dataDirectory: tempDir.appendingPathComponent("Data", isDirectory: true)
        )

        // First load migrates from UserDefaults -> atomic JSON file
        let migrated = storage.loadSavedGames()
        #expect(migrated.count == 1)
        #expect(migrated[0].id == sampleGame.id)
        #expect(defaults.data(forKey: "starpoint.savedGames.v1") == nil, "Legacy UserDefaults blob should be removed after migration")

        // Reloading reads from the atomic file on disk
        let reloaded = storage.loadSavedGames()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].resultString == "B+3.5")

        // Corrupt the JSON file and verify graceful recovery + backup creation
        let dataDir = tempDir.appendingPathComponent("Data", isDirectory: true)
        let archiveURL = dataDir.appendingPathComponent("starpoint.savedGames.v1.json")
        try Data("{corrupt json!!!".utf8).write(to: archiveURL)

        let afterCorrupt = storage.loadSavedGames()
        #expect(afterCorrupt.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: dataDir.path)
        #expect(files.contains { $0.contains(".corrupt.") }, "Corrupt file must be backed up instead of silently deleted")
    }

    // MARK: - 3. Localization Parity & Cached Bundle

    @Test func allFiveLocalesHaveIdenticalKeysAndCachedLookups() throws {
        let locales = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]
        let bundle = Bundle(for: BundleFinder.self)
        let appBundle = Bundle.main

        var keySets: [String: Set<String>] = [:]
        for code in locales {
            let url = appBundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(code).lproj")
                ?? bundle.url(forResource: "Localizable", withExtension: "strings", subdirectory: "\(code).lproj")
            guard let url, let dict = NSDictionary(contentsOf: url) as? [String: String] else {
                Issue.record("Missing Localizable.strings for \(code)")
                continue
            }
            keySets[code] = Set(dict.keys)
            #expect(dict["app.name"]?.isEmpty == false)
        }

        if let enKeys = keySets["en"] {
            for (code, keys) in keySets {
                #expect(keys == enKeys, "Locale \(code) key set diverges from en")
            }
        }

        // Verify L10n cached lookup returns localized app names
        #expect(L10n(language: .ja).t("app.name") == "星弈囲碁")
        #expect(L10n(language: .ko).t("app.name") == "별이 바둑")
    }

    // MARK: - 4. PuzzleCatalog & PuzzleSessionStore Verification

    @Test @MainActor func puzzleCatalogAndSessionStoreLifecycle() throws {
        let sample = try #require(BuiltInPuzzleLibrary.allPuzzles.first)
        let found = PuzzleCatalog.findPuzzle(withId: sample.id)
        #expect(found?.id == sample.id)

        let store = PuzzleSessionStore(puzzle: sample)
        let hint = try #require(store.computeHintPoint())
        #expect(store.hintPoint == hint)

        var lastOutcome: PuzzleSessionStore.StepOutcome?
        store.handlePlayerMove(at: hint) { outcome in
            lastOutcome = outcome
        }
        #expect(store.hintPoint == nil)
        #expect(lastOutcome != .illegal(at: hint))

        store.reset()
        #expect(!store.isSolved)
        #expect(store.mistakesCount == 0)
    }

    // MARK: - 5. Content Integrity (MiniDrills, HandicapBalanceCalculator, TacticalScenarios)

    @Test func miniDrillsHandicapAndTacticalScenariosAreValid() {
        // HandicapBalanceCalculator sanity across sizes
        let even = HandicapBalanceCalculator.recommend(
            player1: GoRankOption.presets[3],
            player2: GoRankOption.presets[3],
            preferredBoardSize: .nineteen
        )
        #expect(even.handicapStones == 0)

        let mismatched = HandicapBalanceCalculator.recommend(
            player1: GoRankOption.presets.first!,
            player2: GoRankOption.presets.last!,
            preferredBoardSize: .nineteen
        )
        #expect(mismatched.handicapStones >= 2)

        // TacticalScenariosLibrary all produce valid initial boards with in-bounds setup stones
        #expect(!TacticalScenariosLibrary.allScenarios.isEmpty)
        for scenario in TacticalScenariosLibrary.allScenarios {
            let state = scenario.makeInitialState()
            #expect(state.size == scenario.boardSize.rawValue)
            for coord in scenario.blackSetupSGF + scenario.whiteSetupSGF {
                let pt = BoardPoint(sgf: coord)
                #expect(pt != nil && state.isValid(row: pt!.row, col: pt!.col), "Invalid setup coord \(coord) in scenario \(scenario.id)")
            }
        }

        // GoMiniDrillsLibrary all have non-empty question banks
        #expect(!GoMiniDrillsLibrary.speedLibertyQuestions.isEmpty)
        #expect(!GoMiniDrillsLibrary.ladderDrills.isEmpty)
        #expect(!GoMiniDrillsLibrary.countingDrills.isEmpty)
        #expect(!GoMiniDrillsLibrary.openingDrills.isEmpty)
        #expect(!GoMiniDrillsLibrary.blunderDrills.isEmpty)

        // AppTheme unified StoneStyle palettes cover all collectible stone finishes
        for style in StoneStyle.allCases {
            let palette = AppTheme.stonePalette(for: style)
            #expect(palette.blackColors.count >= 2)
            #expect(palette.whiteColors.count >= 2)
        }
    }

    // MARK: - 6. Deep Review Regression Tests (Pass History, SGF POSIX Komi, 45° Convex Quad, Subsetted Fonts)

    @Test func passMoveUpdatesRecentMovesAndSGFExportsPOSIXKomi() throws {
        let initial = GoBoardState(size: 9, komi: 7.5)
        let passOutcome = try initial.applying(action: .pass).get()
        #expect(passOutcome.nextState.recentMoves.last == .pass)

        let sgf = SGFParser.export(
            initialState: initial,
            blackName: "B",
            whiteName: "W",
            result: nil,
            date: Date(),
            moves: []
        )
        #expect(sgf.contains("KM[7.5]"))
        let parsed = try #require(SGFParser.parse(sgf))
        #expect(parsed.komi == 7.5)
    }

    @Test func orderCornersClockwiseHandles45DegreeRotationWithoutSelfIntersection() {
        // Diamond (45-degree rotated square) around (0.5, 0.5)
        let pts = [
            CGPoint(x: 0.5, y: 0.15),
            CGPoint(x: 0.85, y: 0.5),
            CGPoint(x: 0.5, y: 0.85),
            CGPoint(x: 0.15, y: 0.5)
        ]
        let ordered = GoBoardPhotoRecognizer.orderCornersClockwise(pts.reversed())
        let ring = [ordered.topLeft, ordered.topRight, ordered.bottomRight, ordered.bottomLeft]
        var sign = 0.0
        for i in 0..<4 {
            let a = ring[i]
            let b = ring[(i + 1) % 4]
            let c = ring[(i + 2) % 4]
            let cross = Double((b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x))
            #expect(abs(cross) > 1e-6)
            if sign == 0.0 {
                sign = cross
            } else {
                #expect(cross * sign > 0, "Quad must be strictly convex without bowtie self-intersection")
            }
        }
    }

    @Test func projectiveHomographyMatchesExactCornersAndTrapezoidForeshortening() {
        // Trapezoid simulating 35° handheld perspective tilt (narrower top, wider bottom)
        let quad = BoardCornerQuad(
            topLeft: CGPoint(x: 0.25, y: 0.15),
            topRight: CGPoint(x: 0.75, y: 0.15),
            bottomRight: CGPoint(x: 0.90, y: 0.85),
            bottomLeft: CGPoint(x: 0.10, y: 0.85)
        )
        let tl = quad.projectivePoint(u: 0, v: 0)
        let tr = quad.projectivePoint(u: 1, v: 0)
        let br = quad.projectivePoint(u: 1, v: 1)
        let bl = quad.projectivePoint(u: 0, v: 1)
        #expect(hypot(tl.x - quad.topLeft.x, tl.y - quad.topLeft.y) < 1e-6)
        #expect(hypot(tr.x - quad.topRight.x, tr.y - quad.topRight.y) < 1e-6)
        #expect(hypot(br.x - quad.bottomRight.x, br.y - quad.bottomRight.y) < 1e-6)
        #expect(hypot(bl.x - quad.bottomLeft.x, bl.y - quad.bottomLeft.y) < 1e-6)

        // Under true perspective, the visual midpoint v=0.5 sits closer to the narrower top edge than bilinear 0.5!
        let projMid = quad.projectivePoint(u: 0.5, v: 0.5)
        let bilinMid = quad.point(u: 0.5, v: 0.5)
        #expect(projMid.y < bilinMid.y)
    }

    // MARK: - 7. Expanded Campaign Sections & Verified 1,800+ Puzzle Progression

    @Test func expandedCampaignSectionsAreUniqueAndTrackPerSectionProgress() throws {
        // 1. Expanded JSON pack & full catalog counts
        #expect(PuzzlePackLoader.jsonTemplates.count >= 260)
        #expect(PuzzlePackLoader.fullCatalog.count >= 1800)

        var totalCampaignPuzzles = 0
        for sea in StarYiCampaign.allSeas {
            for island in sea.islands {
                #expect(island.totalPuzzleCount >= 35, "Island \(island.id) should have >= 35 puzzles, got \(island.totalPuzzleCount)")
                for node in island.nodes {
                    guard case .puzzleGauntlet(let ids, _) = node.kind else { continue }
                    totalCampaignPuzzles += ids.count
                    #expect(ids.count >= 10, "Gauntlet node \(node.id) should have >= 10 puzzles")
                    #expect(node.sectionCount >= 2, "Gauntlet node \(node.id) should split into >= 2 sections of 5")
                    #expect(Set(ids).count == ids.count, "Duplicate puzzle IDs inside node \(node.id)")

                    // Verify every 5-puzzle section has no duplicate base templates and resolves in DojoPuzzleBank
                    for secIdx in 0..<node.sectionCount {
                        let slice = node.puzzleIds(forSection: secIdx)
                        #expect(!slice.isEmpty && slice.count <= StarYiCampaign.puzzlesPerSection)
                        var bases = Set<String>()
                        for pid in slice {
                            #expect(DojoPuzzleBank.findPuzzle(withId: pid) != nil, "Missing puzzle \(pid) in \(node.id) sec \(secIdx)")
                            let base = pid
                                .replacingOccurrences(of: "-r180", with: "")
                                .replacingOccurrences(of: "-r90", with: "")
                                .replacingOccurrences(of: "-wm", with: "")
                                .replacingOccurrences(of: "-w", with: "")
                                .replacingOccurrences(of: "-m", with: "")
                            #expect(bases.insert(base).inserted, "Duplicate base template \(base) in \(node.id) section \(secIdx)")
                        }
                    }
                }
            }
        }
        #expect(totalCampaignPuzzles >= 1800, "Total campaign puzzles should be >= 1800, got \(totalCampaignPuzzles)")

        // 2. Per-section progression & backwards-compatible legacy node clear
        let firstIsland = StarYiCampaign.allIslands[0]
        let firstNode = firstIsland.nodes[0]
        #expect(firstNode.sectionCount >= 2)

        var progress = PuzzleProgressStore()
        #expect(StarYiCampaign.clearedSectionCount(for: firstNode, progress: progress) == 0)
        #expect(StarYiCampaign.nextSectionIndex(for: firstNode, progress: progress) == 0)

        // Clearing section 0 advances nextSectionIndex to 1 without unlocking node 2 yet
        progress.campaignNodeClearedSections[firstNode.id] = [0]
        #expect(StarYiCampaign.clearedSectionCount(for: firstNode, progress: progress) == 1)
        #expect(StarYiCampaign.nextSectionIndex(for: firstNode, progress: progress) == 1)
        #expect(StarYiCampaign.stars(for: firstNode, progress: progress) == 0)

        // Legacy save with campaignNodeStars[node.id] > 0 treats all sections as cleared
        progress.campaignNodeStars[firstNode.id] = 2
        #expect(StarYiCampaign.clearedSectionCount(for: firstNode, progress: progress) == firstNode.sectionCount)
        #expect(StarYiCampaign.nextSectionIndex(for: firstNode, progress: progress) == 0)

        // Codable round-trip preserves campaignNodeClearedSections
        let encoded = try JSONEncoder().encode(progress)
        let decoded = try JSONDecoder().decode(PuzzleProgressStore.self, from: encoded)
        #expect(decoded.campaignNodeClearedSections[firstNode.id] == [0])
    }
}

private final class BundleFinder {}

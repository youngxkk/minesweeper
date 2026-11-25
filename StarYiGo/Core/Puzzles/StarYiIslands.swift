//
//  StarYiIslands.swift
//  StarYi Go
//

import CoreGraphics
import Foundation

struct GoIsland: Identifiable, Hashable, Sendable {
    let id: String
    let nameKey: String
    let descKey: String
    let bossDifficulty: AIDifficulty
    let puzzleIds: [String]
    /// Normalized map coordinates aligned with `IslandMapBackdrop.jpg`
    let mapX: CGFloat
    let mapY: CGFloat
    let accentHex: UInt32
}

enum IslandUnlockState: Equatable, Sendable {
    case locked
    case active
    case cleared

    var isUnlocked: Bool { self != .locked }
}

enum StageUnlockState: Equatable, Sendable {
    case locked
    case active
    case cleared(stars: Int)

    var isUnlocked: Bool { self != .locked }
}

/// Zero-friction 5×5 Starter Bootcamp ("启蒙游乐场") teaching real Go fundamentals by playing, not reading!
enum StarterBootcamp {
    static let puzzles: [GoPuzzle] = [
        GoPuzzle(
            id: "boot-01",
            category: .capture,
            rankBadge: "30K",
            titleZh: "第 1 课：认识「气」与提子",
            titleEn: "Lesson 1: Liberties & Capture",
            promptZh: "白子只剩 1 口发光的「气」啦！点在最后一口气上，把它提掉！",
            promptEn: "White has only 1 glowing Liberty left! Play on it to Capture!",
            hintZh: "看看中间白子的右边，那个空点就是它最后一口「气」。",
            hintEn: "Look right next to the white stone on the right — take its last liberty!",
            boardSize: 5,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[5]PL[B]AB[cb][cd][bc]AW[cc](;B[dc]C[CORRECT]))",
            cropRegion: BoardCropRegion.full(size: 5)
        ),
        GoPuzzle(
            id: "boot-02",
            category: .capture,
            rankBadge: "28K",
            titleZh: "第 2 课：「叫吃」快逃跑",
            titleEn: "Lesson 2: Escape from Atari!",
            promptZh: "黑子被「叫吃」冒汗了！快往空处走一步，帮它多长出几口气！",
            promptEn: "Your black stone is in Atari (1 liberty)! Extend into open space to grow more liberties!",
            hintZh: "下在黑子右边的空交叉点，两颗黑子手拉手立刻变成 3 口气！",
            hintEn: "Play right beside your black stone to jump from 1 liberty to 3 liberties!",
            boardSize: 5,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[5]PL[B]AB[cc]AW[cb][cd][bc](;B[dc]C[CORRECT])(;B[aa];W[dc]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 5)
        ),
        GoPuzzle(
            id: "boot-03",
            category: .tactics,
            rankBadge: "26K",
            titleZh: "第 3 课：棋子手拉手「连接」",
            titleEn: "Lesson 3: Connect & Save",
            promptZh: "左上角黑子危在旦夕！一子把左右黑棋连成一家吧！",
            promptEn: "Your top-left black stone is in Atari! Connect it to your friends on the right!",
            hintZh: "下在两块黑棋正中间的空点，连成一片后气数暴涨！",
            hintEn: "Play right between your endangered stone and your friendly stones on the right.",
            boardSize: 5,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[5]PL[B]AB[bb][db][dc]AW[ba][ab][bc](;B[cb]C[CORRECT])(;B[cc];W[cb]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 5)
        ),
        GoPuzzle(
            id: "boot-04",
            category: .lifeAndDeath,
            rankBadge: "25K",
            titleZh: "第 4 课：做出「两只真眼」活棋",
            titleEn: "Lesson 4: Make Two True Eyes!",
            promptZh: "黑棋被白棋包围了！下在正中央，变出两只闪闪发光的「真眼」无敌活棋！",
            promptEn: "Black is surrounded! Play in the middle to split the space into Two True Eyes!",
            hintZh: "把上面一排三个空点从正中间一分为二，就会出现两只永远吃不掉的真眼！",
            hintEn: "Divide the 3 empty spaces along the top edge right in the center!",
            boardSize: 5,
            playerColor: .black,
            sgf: "(;GM[1]FF[4]SZ[5]PL[B]AB[aa][ab][bb][cb][db][eb][ea]AW[ac][bc][cc][dc][ec](;B[ca]C[CORRECT])(;B[ba];W[ca]C[WRONG])(;B[da];W[ca]C[WRONG]))",
            cropRegion: BoardCropRegion.full(size: 5)
        )
    ]

    static func solvedCount(progress: PuzzleProgressStore) -> Int {
        puzzles.filter { (progress.starterBootcampStars[$0.id] ?? 0) > 0 }.count
    }

    static func nextUnsolved(progress: PuzzleProgressStore) -> GoPuzzle {
        puzzles.first { (progress.starterBootcampStars[$0.id] ?? 0) == 0 } ?? puzzles[0]
    }
}

enum StarYiIslands {
    /// Five Nintendo-style adventure islands grouping all 20 verified puzzles + 5 Island Boss Duels.
    static let allIslands: [GoIsland] = [
        GoIsland(
            id: "bamboo",
            nameKey: "island.bamboo.name",
            descKey: "island.bamboo.desc",
            bossDifficulty: .sprout,
            puzzleIds: ["cap-01", "cap-02", "cap-03", "cap-04"],
            mapX: 0.19,
            mapY: 0.62,
            accentHex: 0x05B06E
        ),
        GoIsland(
            id: "canyon",
            nameKey: "island.canyon.name",
            descKey: "island.canyon.desc",
            bossDifficulty: .fox,
            puzzleIds: ["cap-05", "tac-01", "tac-02", "tac-03"],
            mapX: 0.32,
            mapY: 0.29,
            accentHex: 0xF23357
        ),
        GoIsland(
            id: "lake",
            nameKey: "island.lake.name",
            descKey: "island.lake.desc",
            bossDifficulty: .panda,
            puzzleIds: ["lad-01", "lad-02", "lad-03", "lad-04"],
            mapX: 0.51,
            mapY: 0.49,
            accentHex: 0x0A7DF5
        ),
        GoIsland(
            id: "temple",
            nameKey: "island.temple.name",
            descKey: "island.temple.desc",
            bossDifficulty: .crane,
            puzzleIds: ["tac-04", "tac-05", "end-01", "end-02"],
            mapX: 0.78,
            mapY: 0.64,
            accentHex: 0xFF940F
        ),
        GoIsland(
            id: "peak",
            nameKey: "island.peak.name",
            descKey: "island.peak.desc",
            bossDifficulty: .dragon,
            puzzleIds: ["lad-05", "end-03", "end-04", "end-05"],
            mapX: 0.80,
            mapY: 0.28,
            accentHex: 0x733DF2
        )
    ]

    /// All puzzles ordered sequentially across the 5 islands.
    static var orderedPuzzles: [GoPuzzle] {
        allIslands.flatMap { puzzles(for: $0) }
    }

    static func findAnyPuzzle(withId id: String) -> GoPuzzle? {
        if let boot = StarterBootcamp.puzzles.first(where: { $0.id == id }) {
            return boot
        }
        if let codex = GoTermCodex.codexPracticePuzzles.first(where: { $0.id == id }) {
            return codex
        }
        if let builtIn = BuiltInPuzzleLibrary.allPuzzles.first(where: { $0.id == id }) {
            return builtIn
        }
        return DojoPuzzleBank.findPuzzle(withId: id)
    }

    static func island(withId id: String) -> GoIsland? {
        allIslands.first { $0.id == id }
    }

    static func islandIndex(for island: GoIsland) -> Int? {
        allIslands.firstIndex(where: { $0.id == island.id })
    }

    static func previousIsland(before island: GoIsland) -> GoIsland? {
        guard let idx = islandIndex(for: island), idx > 0 else { return nil }
        return allIslands[idx - 1]
    }

    static func nextIsland(after island: GoIsland) -> GoIsland? {
        guard let idx = islandIndex(for: island), idx + 1 < allIslands.count else { return nil }
        return allIslands[idx + 1]
    }

    static func puzzles(for island: GoIsland) -> [GoPuzzle] {
        let lookup = Dictionary(uniqueKeysWithValues: BuiltInPuzzleLibrary.allPuzzles.map { ($0.id, $0) })
        return island.puzzleIds.compactMap { lookup[$0] }
    }

    static func solvedCount(for island: GoIsland, progress: PuzzleProgressStore) -> Int {
        island.puzzleIds.filter { (progress.starsByPuzzleId[$0] ?? 0) > 0 }.count
    }

    static func earnedStars(for island: GoIsland, progress: PuzzleProgressStore) -> Int {
        island.puzzleIds.reduce(0) { $0 + (progress.starsByPuzzleId[$1] ?? 0) }
    }

    static func maxStars(for island: GoIsland) -> Int {
        island.puzzleIds.count * 3
    }

    static func isIslandCleared(_ island: GoIsland, progress: PuzzleProgressStore) -> Bool {
        !island.puzzleIds.isEmpty && island.puzzleIds.allSatisfy { (progress.starsByPuzzleId[$0] ?? 0) > 0 }
    }

    static func isBossDefeated(for island: GoIsland, progress: PuzzleProgressStore) -> Bool {
        progress.defeatedBossIslandIds.contains(island.id)
    }

    /// Nintendo-style sequential world unlocking:
    /// Only World 1 is unlocked by default; each subsequent island unlocks once all previous islands are cleared.
    static func unlockState(for island: GoIsland, progress: PuzzleProgressStore) -> IslandUnlockState {
        guard let idx = islandIndex(for: island) else { return .locked }
        if idx > 0 {
            let allPreviousCleared = allIslands[0..<idx].allSatisfy { isIslandCleared($0, progress: progress) }
            if !allPreviousCleared {
                return .locked
            }
        }
        return isIslandCleared(island, progress: progress) ? .cleared : .active
    }

    /// Nintendo-style sequential stage unlocking within an island:
    /// Only Stage 1 is unlocked when entering a new island; each stage unlocks once the previous stage is solved.
    static func stageState(at stageIndex: Int, in island: GoIsland, progress: PuzzleProgressStore) -> StageUnlockState {
        guard stageIndex >= 0, stageIndex < island.puzzleIds.count else { return .locked }
        guard unlockState(for: island, progress: progress).isUnlocked else { return .locked }

        if stageIndex > 0 {
            let allEarlierSolved = island.puzzleIds[0..<stageIndex].allSatisfy { (progress.starsByPuzzleId[$0] ?? 0) > 0 }
            if !allEarlierSolved {
                return .locked
            }
        }

        let puzzleId = island.puzzleIds[stageIndex]
        let stars = progress.starsByPuzzleId[puzzleId] ?? 0
        return stars > 0 ? .cleared(stars: stars) : .active
    }

    /// Island Master Boss Duel unlocks once all stages on the island have been cleared.
    static func isBossUnlocked(for island: GoIsland, progress: PuzzleProgressStore) -> Bool {
        unlockState(for: island, progress: progress) == .cleared
    }

    /// Returns whether a given puzzle is unlocked in the sequential island progression.
    static func isPuzzleUnlocked(puzzleId: String, progress: PuzzleProgressStore) -> Bool {
        if StarterBootcamp.puzzles.contains(where: { $0.id == puzzleId }) {
            return true
        }
        for island in allIslands {
            if let stageIdx = island.puzzleIds.firstIndex(of: puzzleId) {
                return stageState(at: stageIdx, in: island, progress: progress).isUnlocked
            }
        }
        return false
    }

    /// Deterministic puzzle of the day for the Daily Challenge module.
    static func dailyChallengePuzzle(for date: Date = Date()) -> GoPuzzle {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let list = BuiltInPuzzleLibrary.allPuzzles
        return list[(dayOfYear - 1) % list.count]
    }
}

/// Built-in classic study games delegated to the full Go Academy Library (`GoAcademyLibrary`).
enum BuiltInClassicGames {
    static func records(l10n: L10n) -> [SavedGameRecord] {
        GoAcademyLibrary.allSavedRecords(l10n: l10n)
    }
}

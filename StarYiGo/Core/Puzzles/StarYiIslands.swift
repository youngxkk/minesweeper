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
        return BuiltInPuzzleLibrary.allPuzzles.first(where: { $0.id == id })
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

/// Built-in classic study games with interactive bilingual Coach Commentary (`C[...]`) so kids learn every move!
enum BuiltInClassicGames {
    static func records(l10n: L10n) -> [SavedGameRecord] {
        let isZh = l10n.language.isChinese
        return [
            SavedGameRecord(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111101")!,
                date: Date(timeIntervalSince1970: 1_735_689_600),
                boardSize: 9,
                komi: 5.5,
                handicap: 0,
                blackName: l10n.bilingual(zh: "星位名局 · 9路攻防", en: "9×9 Classic Opening & Fight"),
                whiteName: l10n.bilingual(zh: "教学示范谱", en: "Dojo Study"),
                resultString: "B+2.5",
                moveCount: 22,
                sgf: isZh
                    ? "(;GM[1]FF[4]SZ[9]KM[5.5]C[欢迎来到 9 路实战教学！点击下方按钮，跟着小老师一步步看懂开局与接触战。];B[ee]C[第 1 手：黑棋占「天元」正中央！在 9 路小棋盘，天元能同时照顾四个方向。];W[ge]C[第 2 手：白棋守在三路边线，瞄准右边地盘。];B[ce]C[第 3 手：黑棋左右呼应，把左边和中央连成一片。];W[fc]C[第 4 手：白棋占右上星位，准备围出右上角大空。];B[cg]C[第 5 手：黑棋守住左下星位，双方先抢「大场」。];W[ec]C[第 6 手：白棋向左上扩张，压迫黑棋。];B[dc]C[第 7 手：黑棋勇敢挡住，不让白棋轻松围空！];W[dd]C[第 8 手：白棋反扳，双方进入精彩的中盘接触战！];B[cd]C[第 9 手：黑棋稳稳长出，同时瞄准白棋的断点。];W[de]C[第 10 手：白棋切断！记住：接触战里「切断」和「连接」最关键。];B[df]C[第 11 手：黑棋立刻反打，把白棋分断并巩固左下。];W[ed]C[第 12 手：白棋粘上补断，棋形更厚实。];B[ef]C[第 13 手：黑棋连片，中央黑龙气数充足！];W[fe]C[第 14 手：白棋同样补强自身断点。];B[fg]C[第 15 手：黑棋向右下扩张，开始圈定下方地盘。];W[gg]C[第 16 手：白棋挡住，守卫右侧边界。];B[gh]C[第 17 手：黑棋二路扳，漂亮的「收官」手筋！];W[hg]C[第 18 手：白棋挡住不让黑棋钻进右角。];B[fh]C[第 19 手：黑棋稳健粘回，下方成空！];W[gf]C[第 20 手：白棋补强右边，双方边界逐渐清晰。];B[db]C[第 21 手：黑棋上方二路扳，抢占最后的大官子！];W[eb]C[第 22 手：白棋挡住，一盘教科书级的 9 路攻防定型啦！试试点「从此步试下」自己变化看看吧。])"
                    : "(;GM[1]FF[4]SZ[9]KM[5.5]C[Welcome to a 9×9 guided match! Step through each move to learn opening balance and fighting.];B[ee]C[Move 1: Black claims Tengen (center)! On 9×9, the center radiates influence in all four directions.];W[ge]C[Move 2: White stakes out the right side on the 3rd line.];B[ce]C[Move 3: Black balances on the left, linking with the center stone.];W[fc]C[Move 4: White claims the upper-right star point to build corner territory.];B[cg]C[Move 5: Black guards the lower-left star point — claim big corners first!];W[ec]C[Move 6: White expands along the top edge.];B[dc]C[Move 7: Black blocks bravely to stop White from making a huge top territory.];W[dd]C[Move 8: White counter-pushes — time for an exciting local fight!];B[cd]C[Move 9: Black extends calmly while eyeing White's cutting point.];W[de]C[Move 10: White cuts! Cutting and connecting are the heart of middle-game fighting.];B[df]C[Move 11: Black fights back immediately, securing the lower-left.];W[ed]C[Move 12: White connects solidly to protect its shape.];B[ef]C[Move 13: Black links up with plenty of liberties!];W[fe]C[Move 14: White reinforces its own cutting point too.];B[fg]C[Move 15: Black expands across the bottom to enclose territory.];W[gg]C[Move 16: White blocks to defend the right side.];B[gh]C[Move 17: Black plays a sharp second-line hane — classic endgame technique!];W[hg]C[Move 18: White blocks so Black cannot slip into the right corner.];B[fh]C[Move 19: Black connects cleanly, sealing bottom territory.];W[gf]C[Move 20: White reinforces the right boundary.];B[db]C[Move 21: Black claims the last big endgame hane at the top!];W[eb]C[Move 22: White blocks — textbook 9×9 balance! Tap Try Variation to experiment yourself.])"
            ),
            SavedGameRecord(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111102")!,
                date: Date(timeIntervalSince1970: 1_735_776_000),
                boardSize: 13,
                komi: 6.5,
                handicap: 0,
                blackName: l10n.bilingual(zh: "星位布局 · 13路金角银边", en: "13×13 Corners & Sides"),
                whiteName: l10n.bilingual(zh: "教学示范谱", en: "Dojo Study"),
                resultString: "B+4.5",
                moveCount: 20,
                sgf: isZh
                    ? "(;GM[1]FF[4]SZ[13]KM[6.5]C[围棋名言「金角银边草肚皮」：在 13 路棋盘上，角上最容易用最少的棋子围出大空！];B[dd]C[第 1 手：黑占左上星位！先抢「金角」。];W[jj]C[第 2 手：白占右下星位，同样抢角。];B[dj]C[第 3 手：黑占左下星位，形成双星布局。];W[jd]C[第 4 手：白占右上星位！前 4 手一人两个角，标准开局。];B[fj]C[第 5 手：角占完后走边——黑棋向下方拆边。];W[gj]C[第 6 手：白棋针锋相对，阻止黑棋围住整个下边。];B[gk]C[第 7 手：黑棋扳起反击！];W[hk]C[第 8 手：白棋连扳守角。];B[fk]C[第 9 手：黑棋稳稳长出，保住下边根据地。];W[hj]C[第 10 手：白棋虎口补强，棋形非常漂亮。];B[cf]C[第 11 手：左边大场！黑棋把左上和左下遥相呼应。];W[kf]C[第 12 手：白棋立刻在右边对称拆边，互不相让。];B[jc]C[第 13 手：黑棋挂角！准备压缩白棋右上角的地盘。];W[kc]C[第 14 手：白棋贴住反击，守护角部。];B[ic]C[第 15 手：黑棋长出，增加气数。];W[kd]C[第 16 手：白棋立下，角地非常稳固。];B[dg]C[第 17 手：黑棋回到左边加厚阵势。];W[jg]C[第 18 手：白棋也在右边呼应补厚。];B[fd]C[第 19 手：黑棋上方展开，形成宏大外势！];W[gd]C[第 20 手：白棋逼近限制黑棋发展，精彩的布局告一段落！])"
                    : "(;GM[1]FF[4]SZ[13]KM[6.5]C[Famous Go proverb: Corners are gold, sides are silver, center is grass! Let's see why on 13×13.];B[dd]C[Move 1: Black takes the top-left star point (golden corner!).];W[jj]C[Move 2: White takes the bottom-right star point.];B[dj]C[Move 3: Black takes the bottom-left star point.];W[jd]C[Move 4: White takes the top-right — all 4 golden corners claimed first!];B[fj]C[Move 5: Now move to the silver sides! Black approaches along the bottom.];W[gj]C[Move 6: White responds actively to limit Black's bottom side.];B[gk]C[Move 7: Black turns aggressively!];W[hk]C[Move 8: White blocks to protect its corner.];B[fk]C[Move 9: Black connects and secures a solid base.];W[hj]C[Move 10: White makes a sturdy tiger's mouth shape.];B[cf]C[Move 11: Big move on the left side linking Black's two corners!];W[kf]C[Move 12: White mirrors on the right side.];B[jc]C[Move 13: Black approaches White's top-right corner!];W[kc]C[Move 14: White defends the corner firmly.];B[ic]C[Move 15: Black extends smoothly for liberties.];W[kd]C[Move 16: White stands down — rock-solid corner territory.];B[dg]C[Move 17: Black reinforces the left framework.];W[jg]C[Move 18: White strengthens the right framework.];B[fd]C[Move 19: Black expands across the top!];W[gd]C[Move 20: White checks Black's growth — a balanced textbook opening!])"
            ),
            SavedGameRecord(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111103")!,
                date: Date(timeIntervalSince1970: 1_735_862_400),
                boardSize: 19,
                komi: 7.5,
                handicap: 0,
                blackName: l10n.bilingual(zh: "经典星位定式 · 三三点角", en: "19×19 Star-Point 3-3 Joseki"),
                whiteName: l10n.bilingual(zh: "定式示范谱", en: "Joseki Study"),
                resultString: "Even",
                moveCount: 16,
                sgf: isZh
                    ? "(;GM[1]FF[4]SZ[19]KM[7.5]C[现代围棋 AI 最爱的经典「星位点三三」定式！学会这一招，19 路开局不再迷茫。];B[pd]C[第 1 手：黑棋占右上星位（4-4 点）。];W[dp]C[第 2 手：白棋占左下星位。];B[pp]C[第 3 手：黑棋占右下星位。];W[dd]C[第 4 手：白棋占左上星位。];B[fq]C[第 5 手：黑棋小飞挂角，向白棋左下角发起试探。];W[cn]C[第 6 手：白棋小飞守角，稳健回应。];B[jp]C[第 7 手：黑棋拆二，在下边建起漂亮的根据地。];W[qc]C[第 8 手：核心招式来了！白棋直接「点三三」（3-3 点），抢夺黑棋右上角实地！];B[qd]C[第 9 手：黑棋挡在宽阔的右边，准备把白棋压在角里，自己拿外势。];W[pc]C[第 10 手：白棋顺势爬出，扩大角部眼位。];B[od]C[第 11 手：黑棋长出，竖起厚实的外墙。];W[oc]C[第 12 手：白棋继续沿三路爬出，确保活角空间。];B[nc]C[第 13 手：黑棋果断三路扳头封锁，筑起厚实外势！];W[ob]C[第 14 手：白棋二路退回，稳健做活角部。];B[rc]C[第 15 手：黑棋二路扳，压缩白棋角上空间。];W[rb]C[第 16 手：白棋挡住活角！白得角地，黑得外势，这就是两分的经典「点三三定式」！])"
                    : "(;GM[1]FF[4]SZ[19]KM[7.5]C[Learn the famous modern 3-3 Invasion Joseki — loved by both Go pros and AI!];B[pd]C[Move 1: Black takes the top-right Star Point (4-4).];W[dp]C[Move 2: White takes the bottom-left Star Point.];B[pp]C[Move 3: Black takes the bottom-right Star Point.];W[dd]C[Move 4: White takes the top-left Star Point.];B[fq]C[Move 5: Black approaches White's lower-left corner.];W[cn]C[Move 6: White answers solidly with a knight's move.];B[jp]C[Move 7: Black settles comfortably on the bottom side.];W[qc]C[Move 8: The signature move! White invades directly at the 3-3 point to steal the corner!];B[qd]C[Move 9: Black blocks on the right, trading corner territory for strong outside influence.];W[pc]C[Move 10: White crawls out to build corner eye space.];B[od]C[Move 11: Black extends to build a thick outside wall.];W[oc]C[Move 12: White pushes once more along the third line to secure living space.];B[nc]C[Move 13: Black hanes cleanly on the third line to seal the outside!];W[ob]C[Move 14: White pulls back on the second line to secure corner life.];B[rc]C[Move 15: Black hanes on the second line to squeeze White's corner.];W[rb]C[Move 16: White blocks and lives! White gets corner territory while Black gets outside power — a classic balanced Joseki!])"
            )
        ]
    }
}

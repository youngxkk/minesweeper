//
//  GoMiniDrills.swift
//  StarYi Go — 4 Kid-Friendly Specialized Go Mini-Drills (P2)
//  1. Speed Liberties & Atari Flash (闪电数气与找断点)
//  2. Ladder Blind Reading (征子盲算：成不成？)
//  3. Territory & Counting Quiz (目数与形势判断小测)
//  4. Opening Big-Point Picker (布局选大场 A/B/C)
//

import Foundation

enum MiniDrillKind: String, CaseIterable, Identifiable, Sendable {
    case speedLiberties
    case ladderReading
    case countingQuiz
    case openingPicker
    case blunderSpotter

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .speedLiberties: return "bolt.circle.fill"
        case .ladderReading: return "stairs"
        case .countingQuiz: return "sum"
        case .openingPicker: return "map.fill"
        case .blunderSpotter: return "ant.fill"
        }
    }

    func title(isChinese: Bool) -> String {
        switch self {
        case .speedLiberties: return isChinese ? "闪电数气 · 找断点" : "Speed Liberties & Cuts"
        case .ladderReading: return isChinese ? "征子盲算 · 成不成？" : "Ladder Blind Reading"
        case .countingQuiz: return isChinese ? "目数与形势判断" : "Counting & Territory Quiz"
        case .openingPicker: return isChinese ? "布局选大场 A/B/C" : "Opening Big-Point Picker"
        case .blunderSpotter: return isChinese ? "棋谱捉虫 · 改恶手" : "Blunder Spotter & Fix"
        }
    }

    func subtitle(isChinese: Bool) -> String {
        switch self {
        case .speedLiberties: return isChinese ? "限时找出最少气棋块或双打吃要点，练就火眼金睛！" : "Spot endangered groups & double-atari points against the clock!"
        case .ladderReading: return isChinese ? "不落子先心算！判断征子能否成立，再看动态验证！" : "Read the ladder in your head — check for ladder breakers before playing!"
        case .countingQuiz: return isChinese ? "估算残局黑白谁领先、差几目，告别不会数子！" : "Estimate who leads on the board, then see the exact territory breakdown!"
        case .openingPicker: return isChinese ? "三选一找出金角银边大场与急所，培养大局观！" : "Pick the biggest opening move among A / B / C to build whole-board sense!"
        case .blunderSpotter: return isChinese ? "找出标红的「随手恶手」错在哪，点击棋盘下出正解妙手！" : "Spot why the marked blunder fails and tap the winning correction on the board!"
        }
    }
}

// MARK: - Drill 1: Speed Liberties & Atari Flash

struct SpeedLibertyQuestion: Identifiable, Sendable {
    let id: String
    let boardSize: Int
    let blackStones: [String]
    let whiteStones: [String]
    let promptZh: String
    let promptEn: String
    /// Acceptable target points (e.g., any stone of the 1-liberty group, or the exact double-atari intersection).
    let targetSGFPoints: Set<String>
    let explanationZh: String
    let explanationEn: String

    func makeState() -> GoBoardState {
        var s = GoBoardState(size: boardSize, komi: 0)
        for p in blackStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.black, at: pt) } }
        for p in whiteStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.white, at: pt) } }
        s.resetPositionHistoryToCurrent()
        return s
    }

    var targetPoints: Set<BoardPoint> {
        Set(targetSGFPoints.compactMap { BoardPoint(sgf: $0) })
    }
}

// MARK: - Drill 2: Ladder Blind Reading (征子盲算)

struct LadderDrillItem: Identifiable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let boardSize: Int
    let blackStones: [String]
    let whiteStones: [String]
    let targetWhiteSGF: String
    let firstAtariBlackSGF: String
    let explanationZh: String
    let explanationEn: String

    func makeState() -> GoBoardState {
        var s = GoBoardState(size: boardSize, komi: 0)
        for p in blackStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.black, at: pt) } }
        for p in whiteStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.white, at: pt) } }
        s.resetPositionHistoryToCurrent()
        return s
    }

    /// Uses our exact `GoTacticalReader` so the answer and playback sequence are 100% mathematically verified!
    func evaluate() -> (works: Bool, steps: [BoardPoint]) {
        let st = makeState()
        guard let target = BoardPoint(sgf: targetWhiteSGF),
              let first = BoardPoint(sgf: firstAtariBlackSGF) else {
            return (false, [])
        }
        switch GoTacticalReader.readLadderAttackerToMove(state: st, targetStone: target, firstAtari: first, maxDepth: 40) {
        case .captured(let steps):
            return (true, steps)
        case .escaped(let steps):
            return (false, steps)
        case .unknown:
            return (false, [])
        }
    }
}

// MARK: - Drill 3: Territory & Counting Quiz (目数与形势判断)

struct CountingDrillItem: Identifiable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let boardSize: Int
    let komi: Double
    let blackStones: [String]
    let whiteStones: [String]
    let tipZh: String
    let tipEn: String

    func makeState() -> GoBoardState {
        var s = GoBoardState(size: boardSize, komi: komi)
        for p in blackStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.black, at: pt) } }
        for p in whiteStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.white, at: pt) } }
        s.resetPositionHistoryToCurrent()
        return s
    }

    func exactResult() -> GameResult {
        GoScoring.score(state: makeState(), rule: .chinese)
    }
}

// MARK: - Drill 4: Opening Big-Point Picker (布局选大场 A/B/C)

struct OpeningChoice: Identifiable, Hashable, Sendable {
    let id: String // "A", "B", "C"
    let sgfPoint: String
    let labelZh: String
    let labelEn: String
    let isCorrect: Bool
    let feedbackZh: String
    let feedbackEn: String

    var point: BoardPoint { BoardPoint(sgf: sgfPoint) ?? BoardPoint(row: 0, col: 0) }
}

struct OpeningDrillItem: Identifiable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let promptZh: String
    let promptEn: String
    let boardSize: Int
    let blackStones: [String]
    let whiteStones: [String]
    let choices: [OpeningChoice]

    func makeState() -> GoBoardState {
        var s = GoBoardState(size: boardSize, komi: 6.5)
        for p in blackStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.black, at: pt) } }
        for p in whiteStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.white, at: pt) } }
        s.resetPositionHistoryToCurrent()
        return s
    }
}

enum GoMiniDrillsLibrary {

    // MARK: - 1. Speed Liberties & Atari Flash Questions

    static let speedLibertyQuestions: [SpeedLibertyQuestion] = [
        SpeedLibertyQuestion(
            id: "sl-01", boardSize: 7,
            blackStones: ["cb", "cc", "dc", "eb", "fd", "fe"],
            whiteStones: ["db", "bb", "bc", "ed", "ee"],
            promptZh: "快找出只剩 1 口气的「危险白子」（点击它或它最后一口气）！",
            promptEn: "Spot the White stone with only 1 liberty! Tap it or its last liberty!",
            targetSGFPoints: ["db", "da"],
            explanationZh: "上方的白子只剩一路最后 1 口气，立刻可以提掉！",
            explanationEn: "The top white stone only has 1 liberty left on the first line!"
        ),
        SpeedLibertyQuestion(
            id: "sl-02", boardSize: 7,
            blackStones: ["cd", "de", "fe", "bb"],
            whiteStones: ["dd", "ee", "cc", "ff"],
            promptZh: "一秒找出「双打吃」要点！点在同时叫吃两颗白子的交叉点上！",
            promptEn: "Find the Double Atari intersection putting TWO white stones in atari at once!",
            targetSGFPoints: ["ed"],
            explanationZh: "点在两颗白子共享的气上，一箭双雕！",
            explanationEn: "Playing on the shared liberty puts both white stones in atari simultaneously!"
        ),
        SpeedLibertyQuestion(
            id: "sl-03", boardSize: 7,
            blackStones: ["aa", "ab", "bb", "cb", "db", "eb", "ea", "dc"],
            whiteStones: ["ac", "bc", "cc", "ec", "fc", "fb", "fa"],
            promptZh: "点击能让黑棋做出「两只真眼」活棋的唯一要点！",
            promptEn: "Tap the single vital point that makes Two True Eyes for Black!",
            targetSGFPoints: ["ca"],
            explanationZh: "把直三从正中间一分为二，左右立变两只真眼！",
            explanationEn: "Dividing the Straight Three right in the middle creates two true eyes!"
        ),
        SpeedLibertyQuestion(
            id: "sl-04", boardSize: 7,
            blackStones: ["bb", "db", "dc", "ee"],
            whiteStones: ["ba", "ab", "bc", "dd"],
            promptZh: "左上角黑子快没气啦！快点击「连接救命点」把它连回家！",
            promptEn: "Your top-left black stone is in atari! Tap the connecting point to save it!",
            targetSGFPoints: ["cb"],
            explanationZh: "一子把孤单的黑子与右边连成一体，气数暴涨！",
            explanationEn: "Connecting merges the endangered stone with your strong group!"
        ),
        SpeedLibertyQuestion(
            id: "sl-05", boardSize: 7,
            blackStones: ["bc", "cd", "db", "ec", "ee"],
            whiteStones: ["cc", "dd", "ff"],
            promptZh: "点击能把中间白子「关门吃」的第一手叫吃点！",
            promptEn: "Tap the atari point that drives White straight into your Door Capture!",
            targetSGFPoints: ["cb"],
            explanationZh: "从上方叫吃，白子一钻进门里立刻被关门提光！",
            explanationEn: "Atari from above forces White straight into your two doorposts!"
        ),
        SpeedLibertyQuestion(
            id: "sl-06", boardSize: 7,
            blackStones: ["ba", "bb", "cc", "dc", "ec", "eb", "fb", "fa"],
            whiteStones: ["ab", "ac", "bc", "cb", "db", "da"],
            promptZh: "对杀时刻！记住「对杀先紧外气」，快点击正确紧气点！",
            promptEn: "Capturing Race! Remember 'outside liberties first' — tap the winning move!",
            targetSGFPoints: ["ea"],
            explanationZh: "先紧白棋右边外气，千万不要先填中间公气！",
            explanationEn: "Always fill the opponent's outside liberty before touching shared liberties!"
        )
    ]

    // MARK: - 2. Ladder Blind Reading Drills (征子盲算)

    static let ladderDrills: [LadderDrillItem] = [
        LadderDrillItem(
            id: "lad-drill-01",
            titleZh: "基础征子 · 空旷上方", titleEn: "Clean Ladder to the Edge",
            boardSize: 9,
            blackStones: ["ca", "cb", "cc", "dd"],
            whiteStones: ["dc"],
            targetWhiteSGF: "dc", firstAtariBlackSGF: "ec",
            explanationZh: "上方一路畅通无阻，黑棋一步步左右追击，白棋撞墙全军覆没！征子成立！",
            explanationEn: "The diagonal path to the top edge is wide open — the ladder works cleanly!"
        ),
        LadderDrillItem(
            id: "lad-drill-02",
            titleZh: "警惕引征！白棋接应子", titleEn: "Watch Out for the Ladder Breaker!",
            boardSize: 9,
            blackStones: ["ca", "cb", "cc", "dd"],
            whiteStones: ["dc", "eb"],
            targetWhiteSGF: "dc", firstAtariBlackSGF: "ec",
            explanationZh: "前方正好有一颗白棋「引征子」接应！一征过去白棋立刻连成三口气反杀，征子失败！",
            explanationEn: "White has a waiting ladder breaker right in the diagonal path — the ladder FAILS!"
        ),
        LadderDrillItem(
            id: "lad-drill-03",
            titleZh: "经典 45° 斜线征子", titleEn: "Classic 45° Diagonal Ladder",
            boardSize: 9,
            blackStones: ["cf", "dg", "eg"],
            whiteStones: ["df"],
            targetWhiteSGF: "df", firstAtariBlackSGF: "de",
            explanationZh: "东北方向 45° 斜线畅通无阻！黑棋像走楼梯一样左右追击，把白棋一路征到边线！征子成立！",
            explanationEn: "The 45° northeast diagonal is completely clear — Black zig-zags White all the way to the edge!"
        ),
        LadderDrillItem(
            id: "lad-drill-04",
            titleZh: "远程引征 · 仔细瞄准斜线！", titleEn: "Distant Ladder Breaker",
            boardSize: 9,
            blackStones: ["cf", "dg", "eg"],
            whiteStones: ["df", "gc"],
            targetWhiteSGF: "df", firstAtariBlackSGF: "de",
            explanationZh: "别被远处的白子骗了！它正好落在征子 45° 斜线上，追到半路白棋立刻接应反杀！征子失败！",
            explanationEn: "That distant white stone sits squarely on the 45° diagonal and breaks the ladder!"
        ),
        LadderDrillItem(
            id: "lad-drill-05",
            titleZh: "假引征 · 歪了一路救不了！", titleEn: "False Ladder Breaker (Off-Line!)",
            boardSize: 9,
            blackStones: ["cf", "dg", "eg"],
            whiteStones: ["df", "ie"],
            targetWhiteSGF: "df", firstAtariBlackSGF: "de",
            explanationZh: "右边那颗白子偏离斜线太远，根本接应不到逃跑的白棋！认真算清每一拐：征子依然成立！",
            explanationEn: "Check the exact staircase — that white stone is off the ladder line, so the ladder STILL works!"
        ),
        LadderDrillItem(
            id: "lad-drill-06",
            titleZh: "己方接应 · 提前撞黑墙！", titleEn: "Friendly Wall Stops White Early",
            boardSize: 9,
            blackStones: ["cf", "dg", "eg", "fd"],
            whiteStones: ["df", "gc"],
            targetWhiteSGF: "df", firstAtariBlackSGF: "de",
            explanationZh: "虽然远处有白棋引征，但半路上黑棋已有友军拦截，白棋提前撞进黑墙被吃！征子成立！",
            explanationEn: "Even with a distant white stone, Black's friendly stone intercepts earlier — ladder works!"
        )
    ]

    // MARK: - 3. Territory & Counting Quiz (目数与形势判断)

    static let countingDrills: [CountingDrillItem] = [
        CountingDrillItem(
            id: "cnt-01",
            titleZh: "7路清晰对围 · 谁领先？", titleEn: "7×7 Split Board — Who Leads?",
            boardSize: 7, komi: 3.5,
            blackStones: ["da", "db", "dc", "dd", "de", "df", "dg"],
            whiteStones: ["ea", "eb", "ec", "ed", "ee", "ef", "eg"],
            tipZh: "黑棋占左半边 4 列共 28 子，白棋占右半边 3 列共 21 子 + 贴目 3.5 = 24.5，黑棋领先 3.5 目！",
            tipEn: "Black owns 4 full columns (28) vs White's 3 columns (21) + 3.5 komi (24.5): Black leads by 3.5!"
        ),
        CountingDrillItem(
            id: "cnt-02",
            titleZh: "贴目的威力！看似平分谁赢？", titleEn: "The Power of Komi!",
            boardSize: 7, komi: 3.5,
            blackStones: ["ca", "cb", "cc", "cd", "ce", "cf", "cg"],
            whiteStones: ["ea", "eb", "ec", "ed", "ee", "ef", "eg"],
            tipZh: "黑白各围一样大的地盘（各 21 子 + 平分中间 7 个单官），但别忘了白棋有 3.5 贴目，白棋胜 3.5 目！",
            tipEn: "Both sides hold equal board area, so White's 3.5 komi decides the game: White leads by 3.5!"
        ),
        CountingDrillItem(
            id: "cnt-03",
            titleZh: "9路四角大比拼", titleEn: "9×9 Corner & Side Count",
            boardSize: 9, komi: 5.5,
            blackStones: ["ea", "eb", "ec", "ed", "ee", "ef", "eg", "eh", "ei"],
            whiteStones: ["fa", "fb", "fc", "fd", "fe", "ff", "fg", "fh", "fi"],
            tipZh: "黑棋拿下 5 列共 45 子，白棋 4 列共 36 子 + 5.5 贴目 = 41.5，黑棋领先 3.5 目！",
            tipEn: "Black has 5 columns (45) vs White's 4 columns (36) + 5.5 komi (41.5): Black leads by 3.5!"
        ),
        CountingDrillItem(
            id: "cnt-04",
            titleZh: "9路白棋反超局", titleEn: "White Ahead on 9×9",
            boardSize: 9, komi: 5.5,
            blackStones: ["da", "db", "dc", "dd", "de", "df", "dg", "dh", "di"],
            whiteStones: ["ea", "eb", "ec", "ed", "ee", "ef", "eg", "eh", "ei"],
            tipZh: "黑棋只围了 4 列 36 子，白棋占了 5 列 45 子加上 5.5 贴目 = 50.5，白棋大胜 14.5 目！",
            tipEn: "White controls 5 full columns (45) plus 5.5 komi = 50.5 vs Black's 36 — White leads by 14.5!"
        )
    ]

    // MARK: - 4. Opening Big-Point Picker (布局选大场 A/B/C)

    static let openingDrills: [OpeningDrillItem] = [
        OpeningDrillItem(
            id: "op-01",
            titleZh: "金角银边草肚皮", titleEn: "Corners Are Gold!",
            promptZh: "黑先：盘面上有 A / B / C 三个候选点，哪一手最符合开局「先抢金角」铁律？",
            promptEn: "Black to play: Which of A, B, or C follows the supreme opening proverb 'Corners are Gold'?",
            boardSize: 13,
            blackStones: ["dd"],
            whiteStones: ["jd", "dj"],
            choices: [
                OpeningChoice(id: "A", sgfPoint: "jj", labelZh: "A · 占右下星位角", labelEn: "A · Bottom-Right Corner", isCorrect: true,
                              feedbackZh: "完全正确！空角最大，先占第四个「金角」效率最高！",
                              feedbackEn: "Spot on! An empty corner is always the biggest point on the opening board!"),
                OpeningChoice(id: "B", sgfPoint: "gg", labelZh: "B · 走天元中腹", labelEn: "B · Center Tengen", isCorrect: false,
                              feedbackZh: "中腹四面漏风（「草肚皮」），开局放着空角不占去走中腹太亏啦！",
                              feedbackEn: "The center is hard to surround early — always claim empty corners first!"),
                OpeningChoice(id: "C", sgfPoint: "dg", labelZh: "C · 走左边边线", labelEn: "C · Left Side", isCorrect: false,
                              feedbackZh: "边线虽然是「银边」，但在还有空角时，金角永远比银边大！",
                              feedbackEn: "Sides are silver, but empty golden corners come first!")
            ]
        ),
        OpeningDrillItem(
            id: "op-02",
            titleZh: "急所先于大场", titleEn: "Urgent Moves Before Big Moves",
            promptZh: "黑先：右边已有激战断点，A / B / C 哪一手是刻不容缓的「急所」？",
            promptEn: "Black to play: There's an active cut on the board — pick the Urgent Move before quiet Big Moves!",
            boardSize: 13,
            blackStones: ["dd", "dj", "jc", "id", "jd"],
            whiteStones: ["jj", "kc", "kd", "ic", "je"],
            choices: [
                OpeningChoice(id: "A", sgfPoint: "ie", labelZh: "A · 逃出/连回危险黑子", labelEn: "A · Rescue Endangered Stones", isCorrect: true,
                              feedbackZh: "太棒了！上方黑棋处于危急接触战，救出/巩固棋块就是最关键的「急所」！",
                              feedbackEn: "Brilliant! Saving and stabilizing fighting groups always beats quiet side moves!"),
                OpeningChoice(id: "B", sgfPoint: "dg", labelZh: "B · 左边拆边大场", labelEn: "B · Quiet Left Side", isCorrect: false,
                              feedbackZh: "左边虽然是大场，但放任右上黑棋被吃损失远大于拆边，记住「急所先于大场」！",
                              feedbackEn: "The left side can wait — urgent life-and-death fighting always comes first!"),
                OpeningChoice(id: "C", sgfPoint: "aa", labelZh: "C · 一路角部缓手", labelEn: "C · 1-1 Corner Passivity", isCorrect: false,
                              feedbackZh: "开局走 1-1 一路角效率极低，属于大缓手哦。",
                              feedbackEn: "Playing on the 1-1 point in the opening is far too small and slow!")
            ]
        ),
        OpeningDrillItem(
            id: "op-03",
            titleZh: "立二拆三 · 活用厚势", titleEn: "Two-High Three-Extension",
            promptZh: "黑先：黑棋在左上已经两子并立，A / B / C 哪一手拆边步幅最舒展合理？",
            promptEn: "Black to play: From your 2-stone wall in the top-left, which extension spacing is ideal?",
            boardSize: 13,
            blackStones: ["dd", "dc", "dj"],
            whiteStones: ["jj", "jd"],
            choices: [
                OpeningChoice(id: "A", sgfPoint: "hd", labelZh: "A · 上方立二拆三", labelEn: "A · 3-Space Extension", isCorrect: true,
                              feedbackZh: "教科书级「立二拆三」！既大步围空又顺势牵制白棋右上星位！",
                              feedbackEn: "Textbook Two-High Three-Extension! Maximum efficiency while eyeing White's corner!"),
                OpeningChoice(id: "B", sgfPoint: "ed", labelZh: "B · 紧贴爬一路", labelEn: "B · Cramped 1-Space Crawl", isCorrect: false,
                              feedbackZh: "太挤啦！两子并立已经很厚实，紧挨着走效率太低。",
                              feedbackEn: "Too cramped! Your 2-stone wall is strong enough to leap much farther!"),
                OpeningChoice(id: "C", sgfPoint: "ga", labelZh: "C · 一路边线", labelEn: "C · First-Line Crawl", isCorrect: false,
                              feedbackZh: "布局阶段尽量走在三路（实地）或四路（外势），不要过早走一路哦。",
                              feedbackEn: "Stay on the 3rd or 4th line during the opening, not the 1st line!")
            ]
        ),
        OpeningDrillItem(
            id: "op-04",
            titleZh: "守角与挂角", titleEn: "Corner Enclosure vs Approach",
            promptZh: "黑先：四角各占其二，黑棋下一步在哪里能高效守角兼顾边线？",
            promptEn: "Black to play: Each side holds 2 corners — which move smoothly encloses a corner and claims a side?",
            boardSize: 13,
            blackStones: ["dd", "dj"],
            whiteStones: ["jd", "jj"],
            choices: [
                OpeningChoice(id: "A", sgfPoint: "fc", labelZh: "A · 左上小飞守角", labelEn: "A · Knight's Corner Enclosure", isCorrect: true,
                              feedbackZh: "完美！小飞守角既牢牢围住左上角地，又向上边辐射势力！",
                              feedbackEn: "Great! A Knight's Move corner enclosure locks down corner cash and radiates to the side!"),
                OpeningChoice(id: "B", sgfPoint: "bb", labelZh: "B · 二二小尖缩角", labelEn: "B · Tiny 2-2 Corner Move", isCorrect: false,
                              feedbackZh: "二二位太小太局促，白棋从外面一封，黑棋角空也没多少。",
                              feedbackEn: "Playing at 2-2 is far too small and lets White seal you in easily!"),
                OpeningChoice(id: "C", sgfPoint: "gg", labelZh: "C · 空投天元", labelEn: "C · Isolated Center Move", isCorrect: false,
                              feedbackZh: "此时两边都未定型，守角或挂角比孤零零下在天元大得多。",
                              feedbackEn: "Enclosing or approaching a corner is much bigger than an isolated center stone right now!")
            ]
        )
    ]

    // MARK: - 5. Blunder Spotter & Fix (棋谱捉虫 · 改恶手)

    static let blunderDrills: [BlunderSpotterItem] = [
        BlunderSpotterItem(
            id: "bln-01",
            rankBadge: "22K",
            titleZh: "捉虫：错过提子救命！",
            titleEn: "Fix the Blunder: Missed Counter-Capture",
            boardSize: 7,
            blackStones: ["bc", "cd", "dc"],
            whiteStones: ["cc", "bd", "ac"],
            blunderSGF: "bb",
            correctSGFPoints: ["cb"],
            promptZh: "小棋童刚才随手下在 ✕ 处，结果黑棋反而要被吃！请直接点在棋盘上，下出真正救命的一手！",
            promptEn: "Playing at ✕ was a blunder that leaves Black in trouble! Tap the real lifesaving move on the board!",
            explanationZh: "中间白子只剩上方最后 1 口气，直接提掉它既吃子又瞬间救活左侧黑子！",
            explanationEn: "The center white stone only had 1 liberty — capturing it saves your left stone immediately!"
        ),
        BlunderSpotterItem(
            id: "bln-02",
            rankBadge: "18K",
            titleZh: "捉虫：叫吃方向反啦！",
            titleEn: "Fix the Blunder: Wrong Atari Direction",
            boardSize: 9,
            blackStones: ["ca", "cc", "dc", "eb"],
            whiteStones: ["db"],
            blunderSGF: "da",
            correctSGFPoints: ["cb"],
            promptZh: "刚才从一路 ✕ 打吃，白棋立刻往中央逃跑了！该从哪个方向打吃把白棋抱向边线？",
            promptEn: "Atari from the 1st line at ✕ let White escape! Tap the correct atari direction to drive White to the edge!",
            explanationZh: "记住「往边线/往己方墙方向打吃」——从二路打吃，白棋撞到一路边线无路可逃！",
            explanationEn: "Always push the opponent toward the edge or your own wall — atari from the 2nd line!"
        ),
        BlunderSpotterItem(
            id: "bln-03",
            rankBadge: "15K",
            titleZh: "捉虫：对杀先填公气的大恶手！",
            titleEn: "Fix the Blunder: Filling Shared Liberty First",
            boardSize: 9,
            blackStones: ["ba", "bb", "cc", "dc", "ec", "eb", "fb", "fa"],
            whiteStones: ["ab", "ac", "bc", "cb", "db", "da"],
            blunderSGF: "ca",
            correctSGFPoints: ["ea"],
            promptZh: "黑棋刚才误下在中间公气 ✕，瞬间把自己气数填没了！请改出正确紧气点！",
            promptEn: "Playing on the shared liberty at ✕ loses the race immediately! Tap the winning outside liberty!",
            explanationZh: "口诀「对杀先紧外气」！先紧白棋右边外气，公气留到最后再走！",
            explanationEn: "Always take outside liberties first in a capturing race!"
        ),
        BlunderSpotterItem(
            id: "bln-04",
            rankBadge: "12K",
            titleZh: "捉虫：直三没占中心点！",
            titleEn: "Fix the Blunder: Missed Straight-Three Center",
            boardSize: 9,
            blackStones: ["aa", "ab", "bb", "cb", "db", "eb", "ea"],
            whiteStones: ["ac", "bc", "cc", "dc", "ec", "fb", "fa"],
            blunderSGF: "ba",
            correctSGFPoints: ["ca"],
            promptZh: "刚才随手下在边侧 ✕，结果白棋反手一点黑棋全死！请点击真正能做出两只真眼的要点！",
            promptEn: "Playing on the side at ✕ lets White kill your group! Tap the true center vital point to live!",
            explanationZh: "三个并排空点必须下在正中央一分为二，左右立变两只永远吃不掉的真眼！",
            explanationEn: "Split the Straight Three right down the middle to form two unkillable eyes!"
        ),
        BlunderSpotterItem(
            id: "bln-05",
            rankBadge: "8K",
            titleZh: "捉虫：直接点里面给白棋做活！",
            titleEn: "Fix the Blunder: Rushing Inside Before Reducing",
            boardSize: 9,
            blackStones: ["ac", "bc", "cc", "dc", "ec", "fc", "fb", "fa"],
            whiteStones: ["aa", "ab", "bb", "cb", "db", "eb"],
            blunderSGF: "ca",
            correctSGFPoints: ["ea"],
            promptZh: "黑棋急着往内部 ✕ 点入，白棋顺势挡住就活了！请点击先从外侧「缩小眼位」的妙手！",
            promptEn: "Rushing inside at ✕ lets White live! Tap the outside 1st-line hane to shrink the eye space first!",
            explanationZh: "杀棋黄金次序：先从外侧一路扳缩小眼位（四目变直三），再点杀必死无疑！",
            explanationEn: "Reduce from the outside first on the 1st line — shrinking 4 spaces to 3 guarantees the kill!"
        ),
        BlunderSpotterItem(
            id: "bln-06",
            rankBadge: "2K",
            titleZh: "捉虫：大伸腿前错失一路潜入！",
            titleEn: "Fix the Blunder: Passive Endgame Crawl",
            boardSize: 9,
            blackStones: ["cd", "ce", "dc", "cc"],
            whiteStones: ["gc", "gd", "ge"],
            blunderSGF: "eb",
            correctSGFPoints: ["fa"],
            promptZh: "黑棋在二路 ✕ 随手一爬被白棋稳稳挡住，白白少赚好几目！请点出经典的「大伸腿」官子手筋！",
            promptEn: "Crawling passively at ✕ gives away huge endgame points! Tap the classic Monkey Jump!",
            explanationZh: "一路小飞伸腿潜入白棋下方，白棋挡不住，一招多捞 4～5 目大官子！",
            explanationEn: "The 1st-line Monkey Jump digs deep under White's wall for massive endgame gains!"
        )
    ]
}

struct BlunderSpotterItem: Identifiable, Sendable {
    let id: String
    let rankBadge: String
    let titleZh: String
    let titleEn: String
    let boardSize: Int
    let blackStones: [String]
    let whiteStones: [String]
    let blunderSGF: String
    let correctSGFPoints: Set<String>
    let promptZh: String
    let promptEn: String
    let explanationZh: String
    let explanationEn: String

    func makeState() -> GoBoardState {
        var s = GoBoardState(size: boardSize, komi: 0)
        for p in blackStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.black, at: pt) } }
        for p in whiteStones { if let pt = BoardPoint(sgf: p) { s.setSetupStone(.white, at: pt) } }
        s.resetPositionHistoryToCurrent()
        return s
    }

    var blunderPoint: BoardPoint? { BoardPoint(sgf: blunderSGF) }
    var correctPoints: Set<BoardPoint> { Set(correctSGFPoints.compactMap { BoardPoint(sgf: $0) }) }
}

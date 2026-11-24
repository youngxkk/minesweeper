//
//  StarYiCampaign.swift
//  StarYi Go — 4-Sea × 20-Island Multi-Level Campaign (30K -> 5D) + Placement & Skip Gates (Phase 1+2+3)
//

import CoreGraphics
import Foundation

/// Three-tier mastery progression per stage (Normal ★ -> Rotated/Color-Swapped ★★ -> Exam Crown 👑).
enum StageMasteryTier: Int, Codable, Comparable, CaseIterable, Identifiable, Sendable {
    case normal = 1
    case transformed = 2
    case examCrown = 3

    var id: Int { rawValue }

    static func < (lhs: StageMasteryTier, rhs: StageMasteryTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    func title(isChinese: Bool) -> String {
        switch self {
        case .normal: return isChinese ? "普通模式" : "Standard"
        case .transformed: return isChinese ? "旋转换色（防背图）" : "Rotated & Flip"
        case .examCrown: return isChinese ? "无提示皇冠考" : "No-Hint Exam"
        }
    }

    func badge(isChinese: Bool) -> String {
        switch self {
        case .normal: return isChinese ? "★ 普通" : "★ Normal"
        case .transformed: return isChinese ? "🔄 旋转换色" : "🔄 Flip"
        case .examCrown: return isChinese ? "👑 无提示考" : "👑 No-Hint"
        }
    }

    func plainDescription(isChinese: Bool) -> String {
        switch self {
        case .normal:
            return isChinese ? "原图带提示，先看懂招式" : "Original board with helpful hints"
        case .transformed:
            return isChinese ? "棋盘旋转或黑白互换，检验是不是真学会" : "Board rotated or swapped to test true mastery"
        case .examCrown:
            return isChinese ? "关闭所有辅助提示，0 失误通关赢皇冠" : "All hints off — clear with 0 mistakes for Crown"
        }
    }
}

enum CampaignNodeKind: Hashable, Sendable {
    /// Multi-puzzle gauntlet (3-4 progressive puzzles in one continuous run with 3 hearts!)
    case puzzleGauntlet(puzzleIds: [String], forceExam: Bool)
    /// Specialized interactive mini-drill (Speed Liberties, Ladder Blind Reading, Counting, Opening, Blunder Spotter)
    case miniDrill(kind: MiniDrillKind, startOffset: Int, questionCount: Int)
    /// Interactive multi-branch Joseki or Anti-Trick-Move lesson
    case josekiTrial(courseId: String)
    /// Preset SGF tactical mini-match against live AI (Capture Race / Slay Group / Dragon Survival / Endgame Comeback)
    case tacticalScenario(scenarioId: String)

    var symbolName: String {
        switch self {
        case .puzzleGauntlet(_, let forceExam): return forceExam ? "crown.fill" : "square.grid.2x2.fill"
        case .miniDrill(let kind, _, _): return kind.symbolName
        case .josekiTrial: return "arrow.triangle.branch"
        case .tacticalScenario: return "swords"
        }
    }

    func typeTag(isChinese: Bool) -> String {
        switch self {
        case .puzzleGauntlet(let ids, let forceExam):
            if forceExam { return isChinese ? "考场连闯 · \(ids.count)题" : "Exam Set · \(ids.count)Q" }
            return isChinese ? "题组连闯 · \(ids.count)题" : "Puzzle Set · \(ids.count)Q"
        case .miniDrill(let kind, _, let count):
            return "\(kind.title(isChinese: isChinese)) · \(count)\(isChinese ? "题" : "Q")"
        case .josekiTrial:
            return isChinese ? "定式破招课" : "Joseki Trial"
        case .tacticalScenario:
            return isChinese ? "残局实战演练" : "Tactical Duel"
        }
    }
}

struct CampaignNode: Identifiable, Hashable, Sendable {
    let id: String
    let titleZh: String
    let titleEn: String
    let rankBadge: String
    let kind: CampaignNodeKind

    func title(isChinese: Bool) -> String { isChinese ? titleZh : titleEn }

    /// All puzzle IDs referenced by this node (empty for non-puzzle nodes).
    var puzzleIds: [String] {
        if case .puzzleGauntlet(let ids, _) = kind { return ids }
        return []
    }
}

struct CampaignBossConfig: Hashable, Sendable {
    let difficulty: AIDifficulty
    let boardSize: BoardSize
    let ruleSet: GameRuleSet
    let coachingStyle: AICoachingStyle
    let timeControl: TimeControl
    let titleZh: String
    let titleEn: String
    let taglineZh: String
    let taglineEn: String

    func title(isChinese: Bool) -> String { isChinese ? titleZh : titleEn }
    func tagline(isChinese: Bool) -> String { isChinese ? taglineZh : taglineEn }
}

struct CampaignIsland: Identifiable, Hashable, Sendable {
    let id: String
    let seaId: String
    let orderInSea: Int // 0...4
    let nameZh: String
    let nameEn: String
    let descZh: String
    let descEn: String
    let rankRange: String
    let nodes: [CampaignNode]
    let boss: CampaignBossConfig
    /// Normalized coordinates aligned with `IslandMapBackdrop.jpg` (5 island slots per Sea!)
    let mapX: CGFloat
    let mapY: CGFloat

    func name(isChinese: Bool) -> String { isChinese ? nameZh : nameEn }
    func desc(isChinese: Bool) -> String { isChinese ? descZh : descEn }

    var allReferencedPuzzleIds: Set<String> {
        Set(nodes.flatMap(\.puzzleIds))
    }
}

struct CampaignSea: Identifiable, Hashable, Sendable {
    let id: String
    let index: Int // 0...3
    let emoji: String
    let mapImageName: String
    let nameZh: String
    let nameEn: String
    let subtitleZh: String
    let subtitleEn: String
    let rankRange: String
    let minRankValue: Int // lower = harder (e.g. -4 = 5D)
    let maxRankValue: Int // higher = easier (e.g. 30 = 30K)
    let skipGatePuzzleIds: [String]
    let skipGatePassCount: Int
    let islands: [CampaignIsland]

    func name(isChinese: Bool) -> String { isChinese ? nameZh : nameEn }
    func subtitle(isChinese: Bool) -> String { isChinese ? subtitleZh : subtitleEn }
}

struct PlacementOption: Identifiable, Hashable, Sendable {
    let id: String
    let rankLabel: String
    let titleZh: String
    let titleEn: String
    let descZh: String
    let descEn: String
    let targetSeaId: String
    let recommendedRankTier: Int
    let emoji: String
}

enum StarYiCampaign {

    /// Coordinates matching the 5 illustrated island regions on `IslandMapBackdrop.jpg`
    private static let mapSlots: [(CGFloat, CGFloat)] = [
        (0.19, 0.62),
        (0.32, 0.29),
        (0.51, 0.49),
        (0.78, 0.64),
        (0.80, 0.28)
    ]

    static let placementOptions: [PlacementOption] = [
        PlacementOption(id: "pl-30k", rankLabel: "30K–22K", titleZh: "萌新启蒙", titleEn: "Brand New", descZh: "刚认识棋盘、气与提子，从第一区域·碧蓝海岛轻松起步", descEn: "Learning liberties & capture from Region 1 · Azure Islands", targetSeaId: "sea-1", recommendedRankTier: 0, emoji: "🏝️"),
        PlacementOption(id: "pl-18k", rankLabel: "21K–15K", titleZh: "吃子进阶（约15K）", titleEn: "Intermediate (~15K)", descZh: "已会双打吃与征子，直接飞往第二区域·翡翠森林", descEn: "Know basic captures — fly to Region 2 · Emerald Forest!", targetSeaId: "sea-2", recommendedRankTier: 3, emoji: "🌿"),
        PlacementOption(id: "pl-10k", rankLabel: "14K–8K", titleZh: "级位高手（14K–8K）", titleEn: "Solid Kyu (14K–8K)", descZh: "熟悉死活与对杀，直奔第三区域·金色沙漠", descEn: "Solid L&D & races — fly to Region 3 · Golden Desert!", targetSeaId: "sea-3", recommendedRankTier: 4, emoji: "🏜️"),
        PlacementOption(id: "pl-5k", rankLabel: "7K–1K", titleZh: "高段预备（7K–1K）", titleEn: "High Kyu (7K–1K)", descZh: "冲刺业余段位，直闯第四区域·凛冬雪山", descEn: "Approaching Dan — fly to Region 4 · Frost Peak!", targetSeaId: "sea-4", recommendedRankTier: 5, emoji: "❄️"),
        PlacementOption(id: "pl-1d", rankLabel: "1D–5D+", titleZh: "业余段位炼狱", titleEn: "Amateur Dan (1D–5D+)", descZh: "精通19路定式与精算，直闯第五区域·熔岩火山终极试炼", descEn: "Master 19×19 reading — enter Region 5 · Volcano Peak!", targetSeaId: "sea-5", recommendedRankTier: 6, emoji: "🌋")
    ]

    // MARK: - Complete 5 Regions × 5 Stages = 25 Stages, 125 Campaign Nodes + 25 Bosses!

    static let allSeas: [CampaignSea] = [

        // =========================================================================
        // REGION 1: 碧蓝海岛 (30K - 22K) — 5×5 / 7×7 Friendly Capture & Foundations
        // =========================================================================
        CampaignSea(
            id: "sea-1", index: 0, emoji: "🏝️", mapImageName: "RegionMap1",
            nameZh: "碧蓝海岛 · 启蒙浅滩", nameEn: "Region 1 · Azure Islands",
            subtitleZh: "5路/7路吃子棋与基础打吃连结，零基础轻松爱上围棋",
            subtitleEn: "5×5 & 7×7 Capture Go, liberties, escapes, and basic eyes",
            rankRange: "30K–22K", minRankValue: 22, maxRankValue: 30,
            skipGatePuzzleIds: ["cap-01", "cap-02", "cap-03", "cap-04", "pk-cap-10"],
            skipGatePassCount: 4,
            islands: [
                CampaignIsland(
                    id: "s1-reef", seaId: "sea-1", orderInSea: 0,
                    nameZh: "青芽珊瑚礁", nameEn: "Sprout Coral Reef",
                    descZh: "认识气、提子与逃跑", descEn: "Liberties, Capture & Escape",
                    rankRange: "30K–26K",
                    nodes: [
                        CampaignNode(id: "s1-reef-1", titleZh: "提子启蒙三连闯", titleEn: "First Captures Set", rankBadge: "30K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-cap-01", "pk-cap-02", "cap-01"], forceExam: false)),
                        CampaignNode(id: "s1-reef-2", titleZh: "闪电数气小游戏", titleEn: "Speed Liberties", rankBadge: "28K",
                                     kind: .miniDrill(kind: .speedLiberties, startOffset: 0, questionCount: 3)),
                        CampaignNode(id: "s1-reef-3", titleZh: "逃跑与反提解围", titleEn: "Escape & Counter-Capture", rankBadge: "27K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-cap-03", "pk-cap-04", "pk-cap-05"], forceExam: false)),
                        CampaignNode(id: "s1-reef-4", titleZh: "5路十字吃子战", titleEn: "5×5 Cross-Cut Capture", rankBadge: "26K",
                                     kind: .tacticalScenario(scenarioId: "scn-s1-cross")),
                        CampaignNode(id: "s1-reef-5", titleZh: "珊瑚礁小考", titleEn: "Reef Mastery Test", rankBadge: "25K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-ex-01", "pk-ex-02", "dojo-cap-01"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .sprout, boardSize: .five, ruleSet: .captureRace(target: 1),
                        coachingStyle: .capturePractice, timeControl: .unlimited,
                        titleZh: "萌新小芽 · 5路先吃1子", titleEn: "Sprout · 5×5 First Capture",
                        taglineZh: "在 5 路棋盘先提掉芽芽 1 颗子就通关！", taglineEn: "Capture 1 stone on 5×5 to clear!"
                    ),
                    mapX: mapSlots[0].0, mapY: mapSlots[0].1
                ),
                CampaignIsland(
                    id: "s1-shell", seaId: "sea-1", orderInSea: 1,
                    nameZh: "贝壳抱吃湾", nameEn: "Shell Hug Bay",
                    descZh: "打吃方向、边线抱吃与切断", descEn: "Atari Direction & Edge Hug",
                    rankRange: "25K–23K",
                    nodes: [
                        CampaignNode(id: "s1-shell-1", titleZh: "边线提子与切断", titleEn: "Edge Capture & Cut", rankBadge: "25K",
                                     kind: .puzzleGauntlet(puzzleIds: ["cap-02", "pk-cap-06", "pk-ex-03"], forceExam: false)),
                        CampaignNode(id: "s1-shell-2", titleZh: "棋谱捉虫 · 找错方向", titleEn: "Blunder Spotter", rankBadge: "24K",
                                     kind: .miniDrill(kind: .blunderSpotter, startOffset: 0, questionCount: 2)),
                        CampaignNode(id: "s1-shell-3", titleZh: "顺墙抱吃三连击", titleEn: "Drive to the Wall Set", rankBadge: "23K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-cap-07", "pk-cap-08", "cap-03"], forceExam: false)),
                        CampaignNode(id: "s1-shell-4", titleZh: "一路提三子挑战", titleEn: "Edge Triple Capture", rankBadge: "23K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-ex-04", "pk-ex-05", "dojo-cap-03"], forceExam: false)),
                        CampaignNode(id: "s1-shell-5", titleZh: "抱吃湾无辅助小考", titleEn: "Shell Bay Exam", rankBadge: "22K",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-cap-04", "cap-03-r90", "pk-cap-07-w"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .sprout, boardSize: .five, ruleSet: .captureRace(target: 3),
                        coachingStyle: .capturePractice, timeControl: .unlimited,
                        titleZh: "萌新小芽 · 5路先吃3子", titleEn: "Sprout · 5×5 Capture 3",
                        taglineZh: "用抱吃和切断先吃满 3 颗子！", taglineEn: "Use cuts and edge hugs to capture 3!"
                    ),
                    mapX: mapSlots[1].0, mapY: mapSlots[1].1
                ),
                CampaignIsland(
                    id: "s1-lagoon", seaId: "sea-1", orderInSea: 2,
                    nameZh: "关门泻湖", nameEn: "Door-Trap Lagoon",
                    descZh: "关门吃（门吃）与虎口逃生", descEn: "Door Captures & Escapes",
                    rankRange: "23K–21K",
                    nodes: [
                        CampaignNode(id: "s1-lagoon-1", titleZh: "请君入瓮：关门吃", titleEn: "Door Capture Basics", rankBadge: "22K",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-cap-02", "pk-cap-09", "pk-cap-10"], forceExam: false)),
                        CampaignNode(id: "s1-lagoon-2", titleZh: "7路边线围捕实战", titleEn: "7×7 Capture Sprint", rankBadge: "22K",
                                     kind: .tacticalScenario(scenarioId: "scn-s1-fence")),
                        CampaignNode(id: "s1-lagoon-3", titleZh: "虎口逃生与反击", titleEn: "Tiger Mouth Escapes", rankBadge: "21K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-ex-06", "pk-ex-08", "dojo-cap-06"], forceExam: false)),
                        CampaignNode(id: "s1-lagoon-4", titleZh: "闪电找断点", titleEn: "Speed Cut Spotter", rankBadge: "21K",
                                     kind: .miniDrill(kind: .speedLiberties, startOffset: 3, questionCount: 3)),
                        CampaignNode(id: "s1-lagoon-5", titleZh: "泻湖变向测试", titleEn: "Lagoon Flip Exam", rankBadge: "21K",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-cap-02-r90", "pk-cap-09-w", "pk-cap-10-m"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .rabbit, boardSize: .seven, ruleSet: .captureRace(target: 3),
                        coachingStyle: .capturePractice, timeControl: .unlimited,
                        titleZh: "灵巧小兔 · 7路先吃3子", titleEn: "Swift Rabbit · 7×7 Capture 3",
                        taglineZh: "小兔出招飞快，布好门吃陷阱抓住它！", taglineEn: "Trap the fast Rabbit for 3 captures!"
                    ),
                    mapX: mapSlots[2].0, mapY: mapSlots[2].1
                ),
                CampaignIsland(
                    id: "s1-harbor", seaId: "sea-1", orderInSea: 3,
                    nameZh: "双吃风车港", nameEn: "Double-Atari Harbor",
                    descZh: "一箭双雕的双打吃绝技", descEn: "Mastering Double Atari",
                    rankRange: "21K–20K",
                    nodes: [
                        CampaignNode(id: "s1-harbor-1", titleZh: "双打吃入门三连", titleEn: "Double Atari Set A", rankBadge: "21K",
                                     kind: .puzzleGauntlet(puzzleIds: ["cap-04", "pk-cap-11", "pk-ex-07"], forceExam: false)),
                        CampaignNode(id: "s1-harbor-2", titleZh: "目数与贴目初认识", titleEn: "First Territory Count", rankBadge: "21K",
                                     kind: .miniDrill(kind: .countingQuiz, startOffset: 0, questionCount: 2)),
                        CampaignNode(id: "s1-harbor-3", titleZh: "边线与大块双打吃", titleEn: "Group Double Atari", rankBadge: "20K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-cap-12", "pk-cap-13", "dojo-cap-05"], forceExam: false)),
                        CampaignNode(id: "s1-harbor-4", titleZh: "7路先吃五子快棋", titleEn: "7×7 Five-Stone Duel", rankBadge: "20K",
                                     kind: .tacticalScenario(scenarioId: "scn-s1-rescue")),
                        CampaignNode(id: "s1-harbor-5", titleZh: "风车港考场小测", titleEn: "Harbor Exam Set", rankBadge: "20K",
                                     kind: .puzzleGauntlet(puzzleIds: ["cap-04-w", "pk-cap-11-r90", "pk-cap-14"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .rabbit, boardSize: .seven, ruleSet: .captureRace(target: 5),
                        coachingStyle: .shapeAndConnect, timeControl: .unlimited,
                        titleZh: "灵巧小兔 · 7路先吃5子", titleEn: "Swift Rabbit · 7×7 Capture 5",
                        taglineZh: "瞄准双打吃，先吃满 5 颗白子！", taglineEn: "Spot double ataris to capture 5 stones!"
                    ),
                    mapX: mapSlots[3].0, mapY: mapSlots[3].1
                ),
                CampaignIsland(
                    id: "s1-lighthouse", seaId: "sea-1", orderInSea: 4,
                    nameZh: "双瞳灯塔岛", nameEn: "Twin-Eye Lighthouse",
                    descZh: "两只真眼活棋与 9 路起航", descEn: "Two True Eyes & 9×9 Debut",
                    rankRange: "21K–20K",
                    nodes: [
                        CampaignNode(id: "s1-light-1", titleZh: "做出两只真眼", titleEn: "Make Two True Eyes", rankBadge: "21K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-lad-01", "pk-lad-02", "pk-lad-03"], forceExam: false)),
                        CampaignNode(id: "s1-light-2", titleZh: "布局金角银边小测", titleEn: "Opening Big Points", rankBadge: "20K",
                                     kind: .miniDrill(kind: .openingPicker, startOffset: 0, questionCount: 2)),
                        CampaignNode(id: "s1-light-3", titleZh: "识破假眼与救命反提", titleEn: "False Eye & Rescues", rankBadge: "20K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-ex-09", "pk-cap-15", "pk-ex-10"], forceExam: false)),
                        CampaignNode(id: "s1-light-4", titleZh: "9路开局与边线守空", titleEn: "9×9 Opening & Border", rankBadge: "20K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-open-01", "pk-open-02", "pk-end-01"], forceExam: false)),
                        CampaignNode(id: "s1-light-5", titleZh: "浅滩毕业综合试炼", titleEn: "Sea 1 Graduation Exam", rankBadge: "20K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-01", "pk-lad-01-w", "dojo-cap-07", "dojo-cap-08"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .rabbit, boardSize: .nine, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .unlimited,
                        titleZh: "灯塔守卫 · 9路围空首战", titleEn: "Lighthouse Guardian · First 9×9",
                        taglineZh: "第一盘完整 9 路围空对局，征服第一海域！", taglineEn: "Win your first full 9×9 territory game!"
                    ),
                    mapX: mapSlots[4].0, mapY: mapSlots[4].1
                )
            ]
        ),

        // =========================================================================
        // REGION 2: 翡翠森林 (21K - 15K) — Ideal Home for K15 Kids!
        // =========================================================================
        CampaignSea(
            id: "sea-2", index: 1, emoji: "🌿", mapImageName: "RegionMap2",
            nameZh: "翡翠森林 · 竹林秘境", nameEn: "Region 2 · Emerald Forest",
            subtitleZh: "征子、枷吃、倒扑、接不归、常见死活与对杀（15K 孩子核心区）",
            subtitleEn: "Ladders, nets, snapbacks, connect-and-die, core L&D & races",
            rankRange: "21K–15K", minRankValue: 15, maxRankValue: 21,
            skipGatePuzzleIds: ["cap-05", "tac-01", "tac-02", "lad-01", "end-02"],
            skipGatePassCount: 4,
            islands: [
                CampaignIsland(
                    id: "s2-wind", seaId: "sea-2", orderInSea: 0,
                    nameZh: "青竹征子林", nameEn: "Bamboo Ladder Grove",
                    descZh: "征子追击、引征判断与天罗地网枷吃", descEn: "Ladders, Breakers & Nets",
                    rankRange: "19K–16K",
                    nodes: [
                        CampaignNode(id: "s2-wind-1", titleZh: "征子楼梯四连追", titleEn: "Ladder Chase Set", rankBadge: "18K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-02", "tac-03", "pk-tac-03"], forceExam: false)),
                        CampaignNode(id: "s2-wind-2", titleZh: "征子盲算：成不成？", titleEn: "Ladder Blind Reading", rankBadge: "17K",
                                     kind: .miniDrill(kind: .ladderReading, startOffset: 0, questionCount: 3)),
                        CampaignNode(id: "s2-wind-3", titleZh: "天罗地网 · 枷吃特训", titleEn: "Classic Net (Geta) Set", rankBadge: "17K",
                                     kind: .puzzleGauntlet(puzzleIds: ["cap-05", "pk-tac-04", "pk-tac-05", "pk-ex-12"], forceExam: false)),
                        CampaignNode(id: "s2-wind-4", titleZh: "围歼孤棋：实战追捕", titleEn: "Live Capture Hunt", rankBadge: "17K",
                                     kind: .tacticalScenario(scenarioId: "scn-s2-hunt")),
                        CampaignNode(id: "s2-wind-5", titleZh: "征枷考场终极测", titleEn: "Ladder & Net Exam", rankBadge: "16K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-06", "dojo-tac-01", "cap-05-w"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .fox, boardSize: .nine, ruleSet: .standard,
                        coachingStyle: .ladderAndNet, timeControl: .unlimited,
                        titleZh: "机敏狐狸 · 9路征枷战", titleEn: "Clever Fox · 9×9 Duel",
                        taglineZh: "狐狸最爱设征子陷阱，识破它赢下 9 路对局！", taglineEn: "Outread the Fox's ladders and nets!"
                    ),
                    mapX: mapSlots[0].0, mapY: mapSlots[0].1
                ),
                CampaignIsland(
                    id: "s2-canyon", seaId: "sea-2", orderInSea: 1,
                    nameZh: "枫叶倒扑谷", nameEn: "Maple Snapback Valley",
                    descZh: "绝妙倒扑、接不归与滚打包收", descEn: "Snapback, Connect & Die, Squeeze",
                    rankRange: "16K–14K",
                    nodes: [
                        CampaignNode(id: "s2-canyon-1", titleZh: "弃子反杀 · 倒扑三连", titleEn: "Snapback Mastery", rankBadge: "16K",
                                     kind: .puzzleGauntlet(puzzleIds: ["tac-01", "pk-tac-07", "pk-tac-08", "pk-ex-13"], forceExam: false)),
                        CampaignNode(id: "s2-canyon-2", titleZh: "棋谱捉虫 · 识破恶手", titleEn: "Blunder Spotter", rankBadge: "15K",
                                     kind: .miniDrill(kind: .blunderSpotter, startOffset: 1, questionCount: 3)),
                        CampaignNode(id: "s2-canyon-3", titleZh: "致命断点 · 接不归", titleEn: "Connect & Die Set", rankBadge: "15K",
                                     kind: .puzzleGauntlet(puzzleIds: ["tac-02", "pk-tac-09", "pk-tac-10", "pk-ex-11"], forceExam: false)),
                        CampaignNode(id: "s2-canyon-4", titleZh: "连环滚打包收与挖断", titleEn: "Rolling Squeeze & Wedge", rankBadge: "14K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-11", "pk-ex-14", "pk-tac-12"], forceExam: false)),
                        CampaignNode(id: "s2-canyon-5", titleZh: "峡谷手筋无辅助考场", titleEn: "Canyon Tesuji Exam", rankBadge: "14K",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-tac-02", "dojo-tac-03", "dojo-tac-04"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .fox, boardSize: .nine, ruleSet: .standard,
                        coachingStyle: .shapeAndConnect, timeControl: .suddenDeath(minutes: 10),
                        titleZh: "峡谷狐狸 · 10分钟快棋", titleEn: "Canyon Fox · 10m Match",
                        taglineZh: "首次启用围棋计时钟，用倒扑手筋击败狐狸！", taglineEn: "Beat the Fox with a 10-minute clock!"
                    ),
                    mapX: mapSlots[1].0, mapY: mapSlots[1].1
                ),
                CampaignIsland(
                    id: "s2-lake", seaId: "sea-2", orderInSea: 2,
                    nameZh: "双月灵泉湖", nameEn: "Twin-Moon Spirit Lake",
                    descZh: "直三、曲三、丁四与刀把五常形", descEn: "Core Eye Shapes & Vital Points",
                    rankRange: "16K–14K",
                    nodes: [
                        CampaignNode(id: "s2-lake-1", titleZh: "直三曲三做活点杀", titleEn: "Straight & Bent Three", rankBadge: "16K",
                                     kind: .puzzleGauntlet(puzzleIds: ["lad-01", "pk-lad-04", "lad-03", "pk-lad-05"], forceExam: false)),
                        CampaignNode(id: "s2-lake-2", titleZh: "绝境做活：保住角上黑龙", titleEn: "Live Dragon Rescue", rankBadge: "15K",
                                     kind: .tacticalScenario(scenarioId: "scn-s2-live")),
                        CampaignNode(id: "s2-lake-3", titleZh: "丁四与刀把五秘籍", titleEn: "Pyramid 4 & Bulky 5", rankBadge: "15K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-lad-06", "pk-lad-07", "pk-lad-08", "pk-lad-09"], forceExam: false)),
                        CampaignNode(id: "s2-lake-4", titleZh: "征子远程引征进阶", titleEn: "Distant Ladder Breakers", rankBadge: "14K",
                                     kind: .miniDrill(kind: .ladderReading, startOffset: 3, questionCount: 3)),
                        CampaignNode(id: "s2-lake-5", titleZh: "双月湖死活考场", titleEn: "Lake L&D Exam", rankBadge: "14K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-ex-15", "pk-ex-16", "pk-ex-17"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .deer, boardSize: .nine, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .suddenDeath(minutes: 10),
                        titleZh: "林间灵鹿 · 12K 守湖战", titleEn: "Jade Deer · 12K Guardian",
                        taglineZh: "灵鹿步法轻灵，守好自己的两眼活棋！", taglineEn: "Outplay the 12K Jade Deer on 9×9!"
                    ),
                    mapX: mapSlots[2].0, mapY: mapSlots[2].1
                ),
                CampaignIsland(
                    id: "s2-temple", seaId: "sea-2", orderInSea: 3,
                    nameZh: "巨树风车坊", nameEn: "Great Tree Mill",
                    descZh: "对杀先紧外气、夹渡联络与补断", descEn: "Capturing Races & Connections",
                    rankRange: "15K–13K",
                    nodes: [
                        CampaignNode(id: "s2-temple-1", titleZh: "对杀先紧外气三连", titleEn: "Outside Liberties Set", rankBadge: "15K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-race-01", "pk-race-02", "pk-ex-18"], forceExam: false)),
                        CampaignNode(id: "s2-temple-2", titleZh: "9路形势与目数判断", titleEn: "9×9 Counting Quiz", rankBadge: "14K",
                                     kind: .miniDrill(kind: .countingQuiz, startOffset: 2, questionCount: 2)),
                        CampaignNode(id: "s2-temple-3", titleZh: "关键补断与夹渡联络", titleEn: "Vital Connections", rankBadge: "13K",
                                     kind: .puzzleGauntlet(puzzleIds: ["end-01", "pk-tac-13", "tac-04"], forceExam: false)),
                        CampaignNode(id: "s2-temple-4", titleZh: "9路中盘激战实战", titleEn: "9×9 Capture Showdown", rankBadge: "13K",
                                     kind: .tacticalScenario(scenarioId: "scn-s2-race")),
                        CampaignNode(id: "s2-temple-5", titleZh: "古寺对杀考场测", titleEn: "Temple Race Exam", rankBadge: "13K",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-race-01", "end-02-w", "pk-end-02"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .deer, boardSize: .nine, ruleSet: .standard,
                        coachingStyle: .shapeAndConnect, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "林间灵鹿 · 读秒对杀战", titleEn: "Jade Deer · Byoyomi Match",
                        taglineZh: "体验正式围棋读秒，在对杀中冷静紧外气！", taglineEn: "Stay calm in byoyomi and win the race!"
                    ),
                    mapX: mapSlots[3].0, mapY: mapSlots[3].1
                ),
                CampaignIsland(
                    id: "s2-summit", seaId: "sea-2", orderInSea: 4,
                    nameZh: "白鹤古寺峰", nameEn: "Crane Temple Ridge",
                    descZh: "梅花五、金鸡独立与 13 路启航", descEn: "Crossed 5, Crane's Leg & 13×13",
                    rankRange: "13K–12K",
                    nodes: [
                        CampaignNode(id: "s2-summit-1", titleZh: "梅花五攻防秘境", titleEn: "Crossed Five Mastery", rankBadge: "13K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-lad-10", "pk-lad-11", "pk-tac-14"], forceExam: false)),
                        CampaignNode(id: "s2-summit-2", titleZh: "13路布局选大场", titleEn: "13×13 Opening Picker", rankBadge: "13K",
                                     kind: .miniDrill(kind: .openingPicker, startOffset: 1, questionCount: 3)),
                        CampaignNode(id: "s2-summit-3", titleZh: "立二拆三与边线收官", titleEn: "Extensions & Endgame", rankBadge: "12K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-open-03", "pk-open-04", "pk-open-03-m", "pk-ex-21"], forceExam: false)),
                        CampaignNode(id: "s2-summit-4", titleZh: "星位小飞挂定式入门", titleEn: "Star-Point Knight Joseki", rankBadge: "12K",
                                     kind: .josekiTrial(courseId: "jos-star-knight")),
                        CampaignNode(id: "s2-summit-5", titleZh: "进阶群岛毕业大考", titleEn: "Sea 2 Graduation Exam", rankBadge: "12K",
                                     kind: .puzzleGauntlet(puzzleIds: ["tac-05", "pk-ex-19", "pk-ex-20", "pk-ex-22"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .panda, boardSize: .thirteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "沉稳熊猫 · 13路晋级战", titleEn: "Wise Panda · 13×13 Boss",
                        taglineZh: "迈入 13 路棋盘，打败 10K 熊猫开启手筋秘境！", taglineEn: "Step onto 13×13 and defeat the 10K Panda!"
                    ),
                    mapX: mapSlots[4].0, mapY: mapSlots[4].1
                )
            ]
        ),

        // =========================================================================
        // REGION 3: 金色沙漠 (14K - 8K) — Single-Digit Kyu Breakthrough (9×9 & 13×13)
        // =========================================================================
        CampaignSea(
            id: "sea-3", index: 2, emoji: "🏜️", mapImageName: "RegionMap3",
            nameZh: "金色沙漠 · 古迹沙海", nameEn: "Region 3 · Golden Desert",
            subtitleZh: "缩眼破假眼、有眼杀无眼、大伸腿官子与定式破骗招（突破 8K）",
            subtitleEn: "Eye reduction, false eyes, capturing races, Monkey Jump & Joseki",
            rankRange: "14K–8K", minRankValue: 8, maxRankValue: 14,
            skipGatePuzzleIds: ["tac-05", "end-05", "dojo-lad-07", "dojo-race-02", "dojo-end-02"],
            skipGatePassCount: 4,
            islands: [
                CampaignIsland(
                    id: "s3-pine", seaId: "sea-3", orderInSea: 0,
                    nameZh: "绿洲渡沙井", nameEn: "Oasis Bridge Well",
                    descZh: "一路扳渡、封口反吃与长征子", descEn: "1st-Line Connect & Long Ladders",
                    rankRange: "11K–10K",
                    nodes: [
                        CampaignNode(id: "s3-pine-1", titleZh: "一路扳渡与跨断", titleEn: "1st-Line Connect & Cut", rankBadge: "11K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-15", "pk-ex-23", "pk-tac-16"], forceExam: false)),
                        CampaignNode(id: "s3-pine-2", titleZh: "长征子与双不入气", titleEn: "Long Ladder & Double Shortage", rankBadge: "10K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-17", "pk-tac-18", "dojo-tac-06"], forceExam: false)),
                        CampaignNode(id: "s3-pine-3", titleZh: "棋谱捉虫 · 级位防随手", titleEn: "SDK Blunder Spotter", rankBadge: "10K",
                                     kind: .miniDrill(kind: .blunderSpotter, startOffset: 3, questionCount: 3)),
                        CampaignNode(id: "s3-pine-4", titleZh: "9路官子翻盘实战", titleEn: "9×9 Endgame Comeback", rankBadge: "10K",
                                     kind: .tacticalScenario(scenarioId: "scn-s3-endgame")),
                        CampaignNode(id: "s3-pine-5", titleZh: "青松岛手筋考场", titleEn: "Pine Sanctum Exam", rankBadge: "10K",
                                     kind: .puzzleGauntlet(puzzleIds: ["end-03", "end-04", "dojo-tac-07"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .panda, boardSize: .thirteen, ruleSet: .standard,
                        coachingStyle: .shapeAndConnect, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "沉稳熊猫 · 13路联络战", titleEn: "Wise Panda · 13×13 Match",
                        taglineZh: "在 13 路边角攻防中灵活联络与封锁！", taglineEn: "Master side connections on 13×13!"
                    ),
                    mapX: mapSlots[0].0, mapY: mapSlots[0].1
                ),
                CampaignIsland(
                    id: "s3-forge", seaId: "sea-3", orderInSea: 1,
                    nameZh: "日晷石碑阵", nameEn: "Sundial Monolith Ruins",
                    descZh: "扑破假眼、缩小眼位与葡萄六", descEn: "False Eyes, Reduction & Rabbitty 6",
                    rankRange: "11K–8K",
                    nodes: [
                        CampaignNode(id: "s3-forge-1", titleZh: "扑破假眼与一路缩眼", titleEn: "False Eye & Eye Reduction", rankBadge: "10K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-lad-12", "pk-lad-13", "pk-ex-26", "pk-ex-27"], forceExam: false)),
                        CampaignNode(id: "s3-forge-2", titleZh: "葡萄六（花六）攻防", titleEn: "Rabbitty Six Vital Points", rankBadge: "9K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-lad-14", "pk-lad-15", "dojo-lad-08"], forceExam: false)),
                        CampaignNode(id: "s3-forge-3", titleZh: "闪电眼力 · 级位速判", titleEn: "Speed Tactics Flash", rankBadge: "9K",
                                     kind: .miniDrill(kind: .speedLiberties, startOffset: 2, questionCount: 4)),
                        CampaignNode(id: "s3-forge-4", titleZh: "屠龙演练：歼灭白龙", titleEn: "Slay the Invader Duel", rankBadge: "8K",
                                     kind: .tacticalScenario(scenarioId: "scn-s3-kill")),
                        CampaignNode(id: "s3-forge-5", titleZh: "熔炉死活考场", titleEn: "Forge L&D Exam", rankBadge: "8K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-19", "pk-ex-24", "end-05"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .crane, boardSize: .nine, ruleSet: .standard,
                        coachingStyle: .capturePractice, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "清风白鹤 · 9路死活快战", titleEn: "Wind Crane · 9×9 L&D Duel",
                        taglineZh: "5K 白鹤算路犀利，精准缩眼破眼取胜！", taglineEn: "Outread the 5K Crane in sharp local fights!"
                    ),
                    mapX: mapSlots[1].0, mapY: mapSlots[1].1
                ),
                CampaignIsland(
                    id: "s3-river", seaId: "sea-3", orderInSea: 2,
                    nameZh: "流沙双子塔", nameEn: "Twin Sand Towers",
                    descZh: "有眼杀无眼、一路延气与大眼杀小眼", descEn: "Eye vs No-Eye & Big-Eye Races",
                    rankRange: "11K–6K",
                    nodes: [
                        CampaignNode(id: "s3-river-1", titleZh: "有眼杀无眼专精", titleEn: "Eye Beats No-Eye", rankBadge: "10K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-race-03", "pk-ex-29", "dojo-race-02"], forceExam: false)),
                        CampaignNode(id: "s3-river-2", titleZh: "角部立下延气妙手", titleEn: "Corner Liberty Extension", rankBadge: "9K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-race-04", "pk-ex-28", "dojo-race-03"], forceExam: false)),
                        CampaignNode(id: "s3-river-3", titleZh: "扑破眼与大眼杀小眼", titleEn: "Throw-In & Big-Eye Races", rankBadge: "7K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-race-05", "pk-race-06", "dojo-race-04"], forceExam: false)),
                        CampaignNode(id: "s3-river-4", titleZh: "破骗招：点三三反击课", titleEn: "Anti-Trick: 3-3 Cut", rankBadge: "8K",
                                     kind: .josekiTrial(courseId: "jos-trick-33-cut")),
                        CampaignNode(id: "s3-river-5", titleZh: "长河对杀无辅助考场", titleEn: "River Capturing Exam", rankBadge: "6K",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-race-05", "pk-race-04-w", "pk-race-05-r90"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .crane, boardSize: .thirteen, ruleSet: .standard,
                        coachingStyle: .ladderAndNet, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "清风白鹤 · 13路对杀战", titleEn: "Wind Crane · 13×13 Match",
                        taglineZh: "在 13 路对杀中用「有眼杀无眼」压制白鹤！", taglineEn: "Outlast the 5K Crane on 13×13!"
                    ),
                    mapX: mapSlots[2].0, mapY: mapSlots[2].1
                ),
                CampaignIsland(
                    id: "s3-pagoda", seaId: "sea-3", orderInSea: 3,
                    nameZh: "黄金金字塔", nameEn: "Golden Pyramid Sanctum",
                    descZh: "星位点三三、小飞挂与 13/19 路布局", descEn: "Modern Joseki & Opening Sense",
                    rankRange: "10K–5K",
                    nodes: [
                        CampaignNode(id: "s3-pagoda-1", titleZh: "现代 AI 点三三定式", titleEn: "Modern 3-3 Joseki", rankBadge: "9K",
                                     kind: .josekiTrial(courseId: "jos-33-modern")),
                        CampaignNode(id: "s3-pagoda-2", titleZh: "挂角守角与 19 路选点", titleEn: "Corner Enclosures & 19×19", rankBadge: "8K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-open-05", "pk-open-06", "pk-ex-30", "pk-open-07"], forceExam: false)),
                        CampaignNode(id: "s3-pagoda-3", titleZh: "破骗招：小飞挂靠断反击", titleEn: "Anti-Trick: Overplay Refutation", rankBadge: "7K",
                                     kind: .josekiTrial(courseId: "jos-trick-knight-wedge")),
                        CampaignNode(id: "s3-pagoda-4", titleZh: "13路孤棋治孤实战", titleEn: "13×13 Sabaki Survival", rankBadge: "6K",
                                     kind: .tacticalScenario(scenarioId: "scn-s3-live13")),
                        CampaignNode(id: "s3-pagoda-5", titleZh: "飞檐塔布局与中盘考", titleEn: "Pagoda Exam Set", rankBadge: "5K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-ex-31", "pk-tac-20", "pk-tac-21", "pk-ex-25"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .crane, boardSize: .thirteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "清风白鹤 · 13路布局战", titleEn: "Wind Crane · 13×13 Opening",
                        taglineZh: "活用星位定式和大场意识正面击败白鹤！", taglineEn: "Apply Joseki & whole-board vision on 13×13!"
                    ),
                    mapX: mapSlots[3].0, mapY: mapSlots[3].1
                ),
                CampaignIsland(
                    id: "s3-sanctum", seaId: "sea-3", orderInSea: 4,
                    nameZh: "星砂神殿顶", nameEn: "Star-Sand Citadel",
                    descZh: "大伸腿、一路潜入与 5K 冲刺大考", descEn: "Monkey Jump & 5K Mastery",
                    rankRange: "8K–5K",
                    nodes: [
                        CampaignNode(id: "s3-sanctum-1", titleZh: "大伸腿与一路潜入", titleEn: "Monkey Jump & Edge Clamp", rankBadge: "8K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-end-03", "pk-end-04", "pk-ex-32", "pk-end-05"], forceExam: false)),
                        CampaignNode(id: "s3-sanctum-2", titleZh: "角部扩大成直四活棋", titleEn: "Corner Life Expansion", rankBadge: "7K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-lad-16", "pk-lad-17", "pk-lad-18"], forceExam: false)),
                        CampaignNode(id: "s3-sanctum-3", titleZh: "小目经典托退定式", titleEn: "Komoku Attach & Extend", rankBadge: "6K",
                                     kind: .josekiTrial(courseId: "jos-komoku-knight")),
                        CampaignNode(id: "s3-sanctum-4", titleZh: "目数与形势精准判断", titleEn: "Precise Territory Quiz", rankBadge: "6K",
                                     kind: .miniDrill(kind: .countingQuiz, startOffset: 0, questionCount: 4)),
                        CampaignNode(id: "s3-sanctum-5", titleZh: "手筋秘境 5K 毕业大考", titleEn: "Sea 3 · 5K Exam", rankBadge: "5K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-tac-22", "pk-ex-33", "dojo-lad-09", "dojo-end-03"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .tiger, boardSize: .thirteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "猛虎教头 · 3K 守关战", titleEn: "Fierce Tiger · 3K Boss",
                        taglineZh: "击败 3K 猛虎，推开冲段云海的大门！", taglineEn: "Defeat the 3K Tiger to unlock the Dan Cloud Sea!"
                    ),
                    mapX: mapSlots[4].0, mapY: mapSlots[4].1
                )
            ]
        ),

        // =========================================================================
        // REGION 4: 凛冬雪山 (7K - 1K) — High-Kyu Alpine Dojo (13×13 & 19×19)
        // =========================================================================
        CampaignSea(
            id: "sea-4", index: 3, emoji: "❄️", mapImageName: "RegionMap4",
            nameZh: "凛冬雪山 · 冰峰道场", nameEn: "Region 4 · Frost Peak",
            subtitleZh: "盘角曲四、双活、逆收大官子与19路定式精算（冲刺 1K 冲段）",
            subtitleEn: "Bent-4, Seki, reverse sente, 19×19 Joseki & High-Kyu Trials",
            rankRange: "7K–1K", minRankValue: 1, maxRankValue: 7,
            skipGatePuzzleIds: ["pk-dan-01", "pk-dan-02", "pk-dan-04", "pk-dan-07", "pk-dan-08"],
            skipGatePassCount: 4,
            islands: [
                CampaignIsland(
                    id: "s4-mist", seaId: "sea-4", orderInSea: 0,
                    nameZh: "雪松温泉村", nameEn: "Snow Pine Onsen",
                    descZh: "角部双活、二一路要点与盘角曲四", descEn: "Seki, 2-1 Vital Point & Bent Four",
                    rankRange: "4K–2K",
                    nodes: [
                        CampaignNode(id: "s4-mist-1", titleZh: "冷静求生 · 角部双活", titleEn: "Corner Seki Survival", rankBadge: "4K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-01", "pk-ex-37", "dojo-lad-10"], forceExam: false)),
                        CampaignNode(id: "s4-mist-2", titleZh: "盘角曲四与六目活形", titleEn: "Bent Four & Six-Space Life", rankBadge: "3K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-02", "pk-dan-03", "pk-ex-34"], forceExam: false)),
                        CampaignNode(id: "s4-mist-3", titleZh: "小目一间高挂定式", titleEn: "Komoku High Approach", rankBadge: "3K",
                                     kind: .josekiTrial(courseId: "jos-komoku-high")),
                        CampaignNode(id: "s4-mist-4", titleZh: "13路精算收官逆转", titleEn: "13×13 Precision Endgame", rankBadge: "3K",
                                     kind: .tacticalScenario(scenarioId: "scn-s4-endgame")),
                        CampaignNode(id: "s4-mist-5", titleZh: "云雾屿二一路考场", titleEn: "2-1 Vital Point Exam", rankBadge: "2K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-04", "pk-dan-05", "pk-ex-36"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .tiger, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "猛虎教头 · 19路冲段战", titleEn: "Fierce Tiger · 19×19 Duel",
                        taglineZh: "正式踏上 19 路全场棋盘，正面击败 3K 猛虎！", taglineEn: "Step onto full 19×19 and defeat the 3K Tiger!"
                    ),
                    mapX: mapSlots[0].0, mapY: mapSlots[0].1
                ),
                CampaignIsland(
                    id: "s4-flame", seaId: "sea-4", orderInSea: 1,
                    nameZh: "寒冰双桥谷", nameEn: "Frost Bridge Gorge",
                    descZh: "精密紧气次序、逆收官子与双挂应对", descEn: "Exact Races, Reverse Sente & Double Approach",
                    rankRange: "2K–1D",
                    nodes: [
                        CampaignNode(id: "s4-flame-1", titleZh: "冲段紧气次序与缩眼", titleEn: "1K Liberty Order & Kill", rankBadge: "1K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-06", "pk-dan-07", "pk-ex-35"], forceExam: false)),
                        CampaignNode(id: "s4-flame-2", titleZh: "逆收双倍大官子", titleEn: "Reverse Sente Mastery", rankBadge: "1K",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-08", "dojo-end-04", "pk-dan-08-w"], forceExam: false)),
                        CampaignNode(id: "s4-flame-3", titleZh: "星位双挂冷静活角", titleEn: "Defending Double Approach", rankBadge: "1D",
                                     kind: .josekiTrial(courseId: "jos-double-approach")),
                        CampaignNode(id: "s4-flame-4", titleZh: "棋谱捉虫 · 高段精算", titleEn: "High-Kyu Blunder Fix", rankBadge: "1K",
                                     kind: .miniDrill(kind: .blunderSpotter, startOffset: 4, questionCount: 2)),
                        CampaignNode(id: "s4-flame-5", titleZh: "初段准入无辅助考", titleEn: "Shodan Prep Exam", rankBadge: "1D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-09", "pk-dan-10", "pk-ex-38", "pk-ex-39"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .dragon, boardSize: .thirteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "星弈青龙 · 13路初段试炼", titleEn: "Star Dragon · 13×13 Shodan",
                        taglineZh: "迎战业余初段青龙，守住每一口关键气！", taglineEn: "Challenge the 1D Star Dragon on 13×13!"
                    ),
                    mapX: mapSlots[1].0, mapY: mapSlots[1].1
                ),
                CampaignIsland(
                    id: "s4-azure", seaId: "sea-4", orderInSea: 2,
                    nameZh: "冰晶五重塔", nameEn: "Crystal Pagoda Peak",
                    descZh: "初段到二段多分支精算与屠龙实战", descEn: "1D–2D Deep Reading & Dragon Fights",
                    rankRange: "1D–2D",
                    nodes: [
                        CampaignNode(id: "s4-azure-1", titleZh: "段位角部方四攻防", titleEn: "Dan Corner Square-Four", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-11", "pk-dan-12", "dojo-lad-11"], forceExam: false)),
                        CampaignNode(id: "s4-azure-2", titleZh: "弃子滚包与延气精算", titleEn: "Sacrifice Squeeze & Race", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-13", "pk-dan-14", "dojo-lad-12"], forceExam: false)),
                        CampaignNode(id: "s4-azure-3", titleZh: "初段中盘屠龙对杀", titleEn: "1D Midgame Capture Fight", rankBadge: "1D",
                                     kind: .tacticalScenario(scenarioId: "scn-s4-danfight")),
                        CampaignNode(id: "s4-azure-4", titleZh: "双挂守角与大局观", titleEn: "2D Opening & Balance", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-15", "pk-dan-11-w", "pk-dan-12-r90"], forceExam: false)),
                        CampaignNode(id: "s4-azure-5", titleZh: "青龙台段位考场", titleEn: "Dragon Arena Exam", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["dojo-tac-10", "dojo-race-06", "pk-dan-13-m"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .dragon, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "星弈青龙 · 19路初段决战", titleEn: "Star Dragon · 19×19 Shodan",
                        taglineZh: "在 19 路堂堂正正战胜青龙，加冕业余初段！", taglineEn: "Defeat the 1D Star Dragon on full 19×19!"
                    ),
                    mapX: mapSlots[2].0, mapY: mapSlots[2].1
                ),
                CampaignIsland(
                    id: "s4-citadel", seaId: "sea-4", orderInSea: 3,
                    nameZh: "极光剑台城", nameEn: "Aurora Watchtower",
                    descZh: "三段盘角曲四、乌龟不出头与巅峰官子", descEn: "3D Corner Reading & Master Endgame",
                    rankRange: "3D–4D",
                    nodes: [
                        CampaignNode(id: "s4-citadel-1", titleZh: "三段盘角曲四与封头", titleEn: "3D Bent-4 & Full Seal", rankBadge: "3D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-17", "pk-dan-18", "pk-dan-16"], forceExam: false)),
                        CampaignNode(id: "s4-citadel-2", titleZh: "三段收官巅峰对决", titleEn: "3D Master Endgame Duel", rankBadge: "3D",
                                     kind: .tacticalScenario(scenarioId: "scn-s4-master")),
                        CampaignNode(id: "s4-citadel-3", titleZh: "四段大眼对杀与梅花五", titleEn: "4D Races & Crossed-5", rankBadge: "4D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-19", "pk-dan-20", "pk-ex-40"], forceExam: false)),
                        CampaignNode(id: "s4-citadel-4", titleZh: "征子斜线全盘心算", titleEn: "Master Ladder Vision", rankBadge: "3D",
                                     kind: .miniDrill(kind: .ladderReading, startOffset: 2, questionCount: 4)),
                        CampaignNode(id: "s4-citadel-5", titleZh: "朱雀城无辅助大考", titleEn: "Phoenix Citadel Exam", rankBadge: "4D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-17-w", "pk-dan-18-r90", "pk-dan-19-m"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .phoenix, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "赤焰朱雀 · 19路三段战", titleEn: "Crimson Phoenix · 3D Boss",
                        taglineZh: "面对 3D 朱雀大师的凌厉攻势，展现段位计算力！", taglineEn: "Overcome the 3D Phoenix on 19×19!"
                    ),
                    mapX: mapSlots[3].0, mapY: mapSlots[3].1
                ),
                CampaignIsland(
                    id: "s4-zenith", seaId: "sea-4", orderInSea: 4,
                    nameZh: "霜龙雪巅殿", nameEn: "Frost Dragon Summit",
                    descZh: "业余五段终极死活、双不入气与收官绝杀", descEn: "5D Grandmaster Reading & Finals",
                    rankRange: "4D–5D",
                    nodes: [
                        CampaignNode(id: "s4-zenith-1", titleZh: "五段角部缩眼绝杀", titleEn: "5D Eye Collapse Set", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21", "pk-dan-22", "pk-dan-23"], forceExam: false)),
                        CampaignNode(id: "s4-zenith-2", titleZh: "五段变向镜像试炼", titleEn: "5D Mirrored Reading", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21-w", "pk-dan-22-r90", "pk-dan-23-m"], forceExam: true)),
                        CampaignNode(id: "s4-zenith-3", titleZh: "高段布局大场全览", titleEn: "Master Opening Sense", rankBadge: "4D",
                                     kind: .miniDrill(kind: .openingPicker, startOffset: 0, questionCount: 4)),
                        CampaignNode(id: "s4-zenith-4", titleZh: "全盘无辅助混合死活", titleEn: "Grandmaster Mixed Exam", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-20-wm", "pk-dan-19-r90", "pk-dan-17-r180", "pk-dan-21-r180"], forceExam: true)),
                        CampaignNode(id: "s4-zenith-5", titleZh: "星辰殿终极五段考", titleEn: "Zenith 5D Final Exam", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21", "pk-dan-22-w", "pk-dan-23-wm", "pk-dan-20-r90"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .kirin, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
                        titleZh: "玉角麒麟 · 19路五段终极战", titleEn: "Celestial Kirin · 5D Final",
                        taglineZh: "登顶冰峰雪巅，迎战 5D 麒麟的雪山试炼！", taglineEn: "Face the 5D Kirin atop Frost Peak!"
                    ),
                    mapX: mapSlots[4].0, mapY: mapSlots[4].1
                )
            ]
        ),

        // =========================================================================
        // REGION 5: 熔岩火山 (1D - 5D+) — Extreme Master Gauntlet (19×19 & No-Hint Exams)
        // =========================================================================
        CampaignSea(
            id: "sea-5", index: 4, emoji: "🌋", mapImageName: "RegionMap5",
            nameZh: "熔岩火山 · 龙焰巅峰", nameEn: "Region 5 · Volcano Peak",
            subtitleZh: "全程无辅助高压段位炼狱：变向防背图死活、19路快棋屠龙与 5D 终极决战！",
            subtitleEn: "Extreme Dan Crucible: no-hint rotated L&D exams, 19×19 blitz fights & 5D Final!",
            rankRange: "1D–5D+", minRankValue: -4, maxRankValue: 0,
            skipGatePuzzleIds: ["pk-dan-11", "pk-dan-17", "pk-dan-19", "pk-dan-21", "pk-dan-23"],
            skipGatePassCount: 5,
            islands: [
                CampaignIsland(
                    id: "s5-forge", seaId: "sea-5", orderInSea: 0,
                    nameZh: "黑曜石熔炉", nameEn: "Obsidian Forge",
                    descZh: "初段至二段无辅助死活淬炼与角部急所", descEn: "1D–2D No-Hint Corner Forging",
                    rankRange: "1D–2D",
                    nodes: [
                        CampaignNode(id: "s5-forge-1", titleZh: "熔炉淬火 · 角部方四", titleEn: "Forge Corner Square-4", rankBadge: "1D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-09", "pk-dan-10", "pk-dan-11", "pk-ex-38"], forceExam: true)),
                        CampaignNode(id: "s5-forge-2", titleZh: "黑曜变向 · 执白反杀", titleEn: "Obsidian White-to-Kill", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-11-w", "pk-dan-12-w", "pk-dan-13-w", "dojo-lad-11"], forceExam: true)),
                        CampaignNode(id: "s5-forge-3", titleZh: "星位双挂破招精解", titleEn: "Double-Approach Counter", rankBadge: "2D",
                                     kind: .josekiTrial(courseId: "jos-double-approach")),
                        CampaignNode(id: "s5-forge-4", titleZh: "19路中盘屠龙死斗", titleEn: "Midgame Dragon Slay", rankBadge: "2D",
                                     kind: .tacticalScenario(scenarioId: "scn-s4-danfight")),
                        CampaignNode(id: "s5-forge-5", titleZh: "黑曜石熔炉四题大考", titleEn: "Obsidian Forge Exam", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-12-r90", "pk-dan-14-m", "pk-dan-15-wm", "pk-ex-39"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .dragon, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "熔岩青龙 · 19路快棋试炼", titleEn: "Magma Dragon · 19×19 Fast",
                        taglineZh: "5分钟+20秒读秒！在熔炉烈焰中正面击败 1D 青龙！", taglineEn: "5m + 20s byoyomi! Defeat the 1D Dragon on 19×19!"
                    ),
                    mapX: mapSlots[0].0, mapY: mapSlots[0].1
                ),
                CampaignIsland(
                    id: "s5-bridge", seaId: "sea-5", orderInSea: 1,
                    nameZh: "烈焰断魂桥", nameEn: "Inferno Chain Bridge",
                    descZh: "二段至三段弃子滚包、延气对杀与骗招反制", descEn: "2D–3D Sacrifice Squeeze & Anti-Trick",
                    rankRange: "2D–3D",
                    nodes: [
                        CampaignNode(id: "s5-bridge-1", titleZh: "断桥弃子滚包四连", titleEn: "Inferno Squeeze Set", rankBadge: "2D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-13", "pk-dan-14", "pk-dan-15", "dojo-lad-12"], forceExam: true)),
                        CampaignNode(id: "s5-bridge-2", titleZh: "三段盘角曲四与封头", titleEn: "3D Bent-4 & Full Seal", rankBadge: "3D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-16", "pk-dan-17", "pk-dan-18", "pk-ex-40"], forceExam: true)),
                        CampaignNode(id: "s5-bridge-3", titleZh: "小飞夹击骗招反击", titleEn: "Anti-Trick Wedge Counter", rankBadge: "3D",
                                     kind: .josekiTrial(courseId: "jos-trick-knight-wedge")),
                        CampaignNode(id: "s5-bridge-4", titleZh: "高段全盘心算盲测", titleEn: "Dan Blind Ladder Vision", rankBadge: "3D",
                                     kind: .miniDrill(kind: .ladderReading, startOffset: 2, questionCount: 4)),
                        CampaignNode(id: "s5-bridge-5", titleZh: "断魂桥镜像无辅助考", titleEn: "Inferno Bridge Exam", rankBadge: "3D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-16-r90", "pk-dan-17-w", "pk-dan-18-m", "dojo-tac-10"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .phoenix, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "烈焰朱雀 · 19路三段激战", titleEn: "Inferno Phoenix · 3D Match",
                        taglineZh: "快棋读秒迎战 3D 朱雀，一步随手即坠熔岩！", taglineEn: "Face the 3D Phoenix in tight byoyomi — zero blunders!"
                    ),
                    mapX: mapSlots[1].0, mapY: mapSlots[1].1
                ),
                CampaignIsland(
                    id: "s5-altar", seaId: "sea-5", orderInSea: 2,
                    nameZh: "赤龙试炼坛", nameEn: "Crimson Dragon Altar",
                    descZh: "三段至四段大眼对杀、逆收大官子与精算残局", descEn: "3D–4D Big-Eye Races & Master Endgame",
                    rankRange: "3D–4D",
                    nodes: [
                        CampaignNode(id: "s5-altar-1", titleZh: "赤龙坛大眼杀小眼", titleEn: "Altar Big-Eye Races", rankBadge: "3D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-17-r180", "pk-dan-18-wm", "pk-dan-19", "dojo-race-06"], forceExam: true)),
                        CampaignNode(id: "s5-altar-2", titleZh: "四段梅花五与精密紧气", titleEn: "4D Crossed-5 & Tight Races", rankBadge: "4D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-19-w", "pk-dan-20", "pk-dan-20-r90", "dojo-end-04"], forceExam: true)),
                        CampaignNode(id: "s5-altar-3", titleZh: "三段收官逆转巅峰战", titleEn: "3D Master Endgame Duel", rankBadge: "4D",
                                     kind: .tacticalScenario(scenarioId: "scn-s4-master")),
                        CampaignNode(id: "s5-altar-4", titleZh: "全盘恶手秒杀捉虫", titleEn: "Master Blunder Execution", rankBadge: "4D",
                                     kind: .miniDrill(kind: .blunderSpotter, startOffset: 3, questionCount: 3)),
                        CampaignNode(id: "s5-altar-5", titleZh: "赤龙坛四段高压考场", titleEn: "Dragon Altar 4D Exam", rankBadge: "4D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-19-m", "pk-dan-20-w", "pk-dan-20-wm", "pk-dan-21"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .phoenix, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 3, periodSeconds: 15, periods: 3),
                        titleZh: "赤龙朱雀 · 19路超快棋", titleEn: "Crimson Phoenix · 19×19 Blitz",
                        taglineZh: "3分钟+15秒超快棋！在高压读秒中杀穿 3D 朱雀！", taglineEn: "3m + 15s Blitz on 19×19 against the 3D Phoenix!"
                    ),
                    mapX: mapSlots[2].0, mapY: mapSlots[2].1
                ),
                CampaignIsland(
                    id: "s5-citadel", seaId: "sea-5", orderInSea: 3,
                    nameZh: "朱雀焚天城", nameEn: "Phoenix Flame Citadel",
                    descZh: "四段至五段全变向无辅助死活与魔鬼四连考", descEn: "4D–5D Rotated No-Hint Hell Gauntlets",
                    rankRange: "4D–5D",
                    nodes: [
                        CampaignNode(id: "s5-citadel-1", titleZh: "焚天城五段缩眼绝杀", titleEn: "Citadel 5D Eye Collapse", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21", "pk-dan-22", "pk-dan-23", "pk-dan-19-r90"], forceExam: true)),
                        CampaignNode(id: "s5-citadel-2", titleZh: "全盘反转 · 执白五段考", titleEn: "Inverted 5D White Exam", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21-w", "pk-dan-22-w", "pk-dan-23-w", "pk-dan-20-r180"], forceExam: true)),
                        CampaignNode(id: "s5-citadel-3", titleZh: "旋转镜像魔鬼死活阵", titleEn: "Mirrored L&D Crucible", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21-r90", "pk-dan-22-r90", "pk-dan-23-m", "pk-dan-18-r180"], forceExam: true)),
                        CampaignNode(id: "s5-citadel-4", titleZh: "高段全局大场生死抉择", titleEn: "Grandmaster Opening Vision", rankBadge: "5D",
                                     kind: .miniDrill(kind: .openingPicker, startOffset: 0, questionCount: 4)),
                        CampaignNode(id: "s5-citadel-5", titleZh: "朱雀焚天五题生死考", titleEn: "Flame Citadel 5Q Exam", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21-wm", "pk-dan-22-m", "pk-dan-23-r90", "pk-dan-20-m", "pk-dan-17-wm"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .kirin, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
                        titleZh: "焚天麒麟 · 19路五段前哨", titleEn: "Flame Kirin · 5D Vanguard",
                        taglineZh: "直面全盛状态 5D 麒麟！用无懈可击的计算力杀出重围！", taglineEn: "Confront the 5D Kirin in a fierce 19×19 battle!"
                    ),
                    mapX: mapSlots[3].0, mapY: mapSlots[3].1
                ),
                CampaignIsland(
                    id: "s5-caldera", seaId: "sea-5", orderInSea: 4,
                    nameZh: "天元火山口", nameEn: "Tengen Caldera Zenith",
                    descZh: "终极炼狱：五关全无辅助 5D 连闯 + 19路极速麒麟决战", descEn: "Ultimate Crucible: All-Exam 5D Gauntlets + Blitz 5D Kirin",
                    rankRange: "5D+",
                    nodes: [
                        CampaignNode(id: "s5-caldera-1", titleZh: "炼狱第一试 · 绝境求生", titleEn: "Crucible I · Abyss Survival", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21-r180", "pk-dan-22-r180", "pk-dan-23-r180", "pk-dan-20-wm"], forceExam: true)),
                        CampaignNode(id: "s5-caldera-2", titleZh: "炼狱第二试 · 执白屠龙", titleEn: "Crucible II · White Slayer", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21-wm", "pk-dan-22-wm", "pk-dan-23-wm", "pk-dan-19-wm"], forceExam: true)),
                        CampaignNode(id: "s5-caldera-3", titleZh: "炼狱第三试 · 镜像迷宫", titleEn: "Crucible III · Mirror Maze", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-17-m", "pk-dan-18-m", "pk-dan-19-m", "pk-dan-21-m", "pk-dan-22-m"], forceExam: true)),
                        CampaignNode(id: "s5-caldera-4", titleZh: "炼狱第四试 · 旋风五连杀", titleEn: "Crucible IV · Cyclone 5Q", rankBadge: "5D",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-16-r90", "pk-dan-18-r90", "pk-dan-20-r90", "pk-dan-22-r90", "pk-dan-23-r90"], forceExam: true)),
                        CampaignNode(id: "s5-caldera-5", titleZh: "天元终极考 · 棋圣加冕", titleEn: "Tengen Final · Grandmaster", rankBadge: "5D+",
                                     kind: .puzzleGauntlet(puzzleIds: ["pk-dan-21", "pk-dan-22-w", "pk-dan-23-wm", "pk-dan-20-r180", "pk-dan-19-r90"], forceExam: true))
                    ],
                    boss: CampaignBossConfig(
                        difficulty: .kirin, boardSize: .nineteen, ruleSet: .standard,
                        coachingStyle: .standard, timeControl: .byoyomi(mainMinutes: 3, periodSeconds: 15, periods: 3),
                        titleZh: "天元麒麟王 · 19路极速终战", titleEn: "Tengen Kirin · 5D Blitz Final",
                        taglineZh: "3分钟+15秒读秒！登顶火山之巅，击败 5D 麒麟王加冕星弈棋圣！", taglineEn: "3m + 15s Blitz! Defeat the 5D Kirin atop the Volcano!"
                    ),
                    mapX: mapSlots[4].0, mapY: mapSlots[4].1
                )
            ]
        )
    ]

    static var allIslands: [CampaignIsland] {
        allSeas.flatMap(\.islands)
    }

    static var allNodes: [CampaignNode] {
        allIslands.flatMap(\.nodes)
    }

    static func sea(withId id: String) -> CampaignSea? {
        allSeas.first { $0.id == id }
    }

    static func island(withId id: String) -> CampaignIsland? {
        allIslands.first { $0.id == id }
    }

    static func node(withId id: String) -> CampaignNode? {
        allNodes.first { $0.id == id }
    }

    static func nextIsland(after island: CampaignIsland) -> CampaignIsland? {
        guard let idx = allIslands.firstIndex(where: { $0.id == island.id }), idx + 1 < allIslands.count else {
            return nil
        }
        return allIslands[idx + 1]
    }

    // MARK: - Progress, Stars, Mastery & Unlock Logic

    static func stars(for node: CampaignNode, progress: PuzzleProgressStore) -> Int {
        if let direct = progress.campaignNodeStars[node.id], direct > 0 {
            return direct
        }
        // Backwards-compatible migration: if all puzzles in a gauntlet were solved previously, credit its stars!
        let pids = node.puzzleIds
        if !pids.isEmpty && pids.allSatisfy({ (progress.starsByPuzzleId[$0] ?? 0) > 0 }) {
            let avg = pids.reduce(0) { $0 + (progress.starsByPuzzleId[$1] ?? 0) } / pids.count
            return max(1, min(3, avg))
        }
        if case .josekiTrial(let courseId) = node.kind, progress.completedJosekiIds.contains(courseId) {
            return 3
        }
        return 0
    }

    static func masteryTier(for node: CampaignNode, progress: PuzzleProgressStore) -> StageMasteryTier? {
        if let raw = progress.campaignNodeMasteryTier[node.id], let tier = StageMasteryTier(rawValue: raw) {
            return tier
        }
        return stars(for: node, progress: progress) > 0 ? .normal : nil
    }

    static func clearedNodeCount(for island: CampaignIsland, progress: PuzzleProgressStore) -> Int {
        island.nodes.filter { stars(for: $0, progress: progress) > 0 }.count
    }

    static func earnedStars(for island: CampaignIsland, progress: PuzzleProgressStore) -> Int {
        island.nodes.reduce(0) { $0 + stars(for: $1, progress: progress) }
    }

    static func maxStars(for island: CampaignIsland) -> Int {
        island.nodes.count * 3
    }

    static func isBossDefeated(for island: CampaignIsland, progress: PuzzleProgressStore) -> Bool {
        progress.defeatedBossIslandIds.contains(island.id)
    }

    static func isAllNodesCleared(for island: CampaignIsland, progress: PuzzleProgressStore) -> Bool {
        !island.nodes.isEmpty && island.nodes.allSatisfy { stars(for: $0, progress: progress) > 0 }
    }

    /// Island is considered cleared once all stages on the island are completed,
    /// automatically unlocking the next island (or the next Sea at the end of a Sea).
    /// Defeating the Island Master Boss remains an optional bonus challenge for the 🏆 trophy badge and rewards.
    static func isIslandCleared(_ island: CampaignIsland, progress: PuzzleProgressStore) -> Bool {
        isAllNodesCleared(for: island, progress: progress)
    }

    static func isSeaUnlocked(_ sea: CampaignSea, progress: PuzzleProgressStore) -> Bool {
        if sea.index == 0 { return true }
        if progress.unlockedSeaIds.contains(sea.id) { return true }
        // Unlocked if any later sea was explicitly unlocked via placement/skip gate
        let laterUnlocked = allSeas.contains { $0.index > sea.index && progress.unlockedSeaIds.contains($0.id) }
        if laterUnlocked { return true }
        // Sequential unlock: previous sea's final island cleared
        if let prevSea = allSeas.first(where: { $0.index == sea.index - 1 }),
           let lastIsland = prevSea.islands.last {
            return isIslandCleared(lastIsland, progress: progress)
        }
        return false
    }

    static func unlockState(for island: CampaignIsland, progress: PuzzleProgressStore) -> IslandUnlockState {
        guard let sea = sea(withId: island.seaId), isSeaUnlocked(sea, progress: progress) else {
            return .locked
        }
        if island.orderInSea > 0 {
            let earlier = sea.islands.prefix(island.orderInSea)
            // If a later sea is unlocked via placement/skip, allow free replay on earlier seas too!
            let laterSeaUnlocked = allSeas.contains { $0.index > sea.index && progress.unlockedSeaIds.contains($0.id) }
            if !laterSeaUnlocked && !earlier.allSatisfy({ isIslandCleared($0, progress: progress) }) {
                return .locked
            }
        }
        return isIslandCleared(island, progress: progress) ? .cleared : .active
    }

    static func nodeState(at index: Int, in island: CampaignIsland, progress: PuzzleProgressStore) -> StageUnlockState {
        guard index >= 0, index < island.nodes.count else { return .locked }
        guard unlockState(for: island, progress: progress).isUnlocked else { return .locked }
        if index > 0 {
            let earlierCleared = island.nodes[0..<index].allSatisfy { stars(for: $0, progress: progress) > 0 }
            if !earlierCleared { return .locked }
        }
        let s = stars(for: island.nodes[index], progress: progress)
        return s > 0 ? .cleared(stars: s) : .active
    }

    static func isBossUnlocked(for island: CampaignIsland, progress: PuzzleProgressStore) -> Bool {
        unlockState(for: island, progress: progress).isUnlocked && isAllNodesCleared(for: island, progress: progress)
    }

    /// Maps due SRS mistake items onto their matching island as gamified "👻 错题幽灵" bounties!
    static func dueMistakeGhosts(for island: CampaignIsland, progress: PuzzleProgressStore) -> [SRSMistakeItem] {
        let refs = island.allReferencedPuzzleIds
        let due = progress.srsMistakeItems.filter(\.isDueNow)
        return due.filter { item in
            let baseId = item.puzzleId
                .replacingOccurrences(of: "-r180", with: "")
                .replacingOccurrences(of: "-r90", with: "")
                .replacingOccurrences(of: "-wm", with: "")
                .replacingOccurrences(of: "-w", with: "")
                .replacingOccurrences(of: "-m", with: "")
            return refs.contains(item.puzzleId) || refs.contains(baseId)
        }
    }

    static func totalClearedNodes(progress: PuzzleProgressStore) -> Int {
        allNodes.filter { stars(for: $0, progress: progress) > 0 }.count
    }

    static func totalEarnedCampaignStars(progress: PuzzleProgressStore) -> Int {
        allNodes.reduce(0) { $0 + stars(for: $1, progress: progress) }
    }

    static func maxTotalCampaignStars() -> Int {
        allNodes.count * 3
    }
}

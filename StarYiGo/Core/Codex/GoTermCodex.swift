//
//  GoTermCodex.swift
//  StarYi Go — Full 4-Tier × 36 Authentic Go Moves Curriculum (Ages 4 to Adult / 30K to 1D+)
//

import Foundation

/// Four progressive Go growth tiers covering ages 4 to adult (30K -> 1D+).
enum CodexTier: String, CaseIterable, Identifiable, Sendable {
    case starter    // 30K–18K · Ages 4–7
    case tactics    // 17K–10K · Ages 7–10
    case fighting   // 9K–3K   · Ages 9–14
    case mastery    // 2K–1D+  · Ages 12+ & Adults

    var id: String { rawValue }

    var titleKey: String {
        "codex.tier.\(rawValue).title"
    }

    var badgeKey: String {
        "codex.tier.\(rawValue).badge"
    }

    var accentHex: UInt32 {
        switch self {
        case .starter:  return 0x05B06E // Mint
        case .tactics:  return 0xFF940F // Sun
        case .fighting: return 0xF23357 // Coral
        case .mastery:  return 0x733DF2 // Grape
        }
    }
}

struct GoCodexEntry: Identifiable, Hashable, Sendable {
    let id: String
    let tier: CodexTier
    let rankTag: String
    let symbolName: String
    let accentHex: UInt32
    /// Authentic Go terminology across global languages (never dumbed down!)
    let termZh: String
    let termEn: String
    let termJa: String
    let termKo: String
    /// Kid-friendly visual metaphor tagline so young players "get it" instantly
    let metaphorZh: String
    let metaphorEn: String
    /// Clear real-Go explanation
    let explanationZh: String
    let explanationEn: String
    /// Interactive mini-board demo SGF (mathematically verified legal)
    let demoBoardSize: Int
    let demoSGF: String
    let demoCrop: BoardCropRegion?
    /// Optional direct practice puzzle ID so players can tap "Practice This Move →" right from the Codex!
    let practicePuzzleId: String?
    let practiceIsBootcamp: Bool
    /// Optional built-in classic study game UUID for Joseki/Opening entries
    let practiceClassicId: UUID?
    /// Starter concepts already stamped "Mastered" or ready from day 1
    let unlockedByDefault: Bool

    init(
        id: String,
        tier: CodexTier,
        rankTag: String,
        symbolName: String,
        accentHex: UInt32,
        termZh: String,
        termEn: String,
        termJa: String,
        termKo: String,
        metaphorZh: String,
        metaphorEn: String,
        explanationZh: String,
        explanationEn: String,
        demoBoardSize: Int,
        demoSGF: String,
        demoCrop: BoardCropRegion? = nil,
        practicePuzzleId: String? = nil,
        practiceIsBootcamp: Bool = false,
        practiceClassicId: UUID? = nil,
        unlockedByDefault: Bool = false
    ) {
        self.id = id
        self.tier = tier
        self.rankTag = rankTag
        self.symbolName = symbolName
        self.accentHex = accentHex
        self.termZh = termZh
        self.termEn = termEn
        self.termJa = termJa
        self.termKo = termKo
        self.metaphorZh = metaphorZh
        self.metaphorEn = metaphorEn
        self.explanationZh = explanationZh
        self.explanationEn = explanationEn
        self.demoBoardSize = demoBoardSize
        self.demoSGF = demoSGF
        self.demoCrop = demoCrop
        self.practicePuzzleId = practicePuzzleId
        self.practiceIsBootcamp = practiceIsBootcamp
        self.practiceClassicId = practiceClassicId
        self.unlockedByDefault = unlockedByDefault
    }

    func term(_ l10n: L10n) -> String {
        l10n.localized(zh: termZh, en: termEn, ja: termJa, ko: termKo, zhHant: termZh)
    }

    func globalSubtitle(_ l10n: L10n) -> String {
        "\(l10n.t(tier.titleKey)) · \(rankTag)"
    }

    func metaphor(_ l10n: L10n) -> String {
        l10n.bilingual(zh: metaphorZh, en: metaphorEn)
    }

    func explanation(_ l10n: L10n) -> String {
        l10n.bilingual(zh: explanationZh, en: explanationEn)
    }
}

enum GoTermCodex {
    private static let classic9Id = UUID(uuidString: "11111111-1111-1111-1111-111111111101")!
    private static let classic13Id = UUID(uuidString: "11111111-1111-1111-1111-111111111102")!
    private static let classic19Id = UUID(uuidString: "11111111-1111-1111-1111-111111111103")!

    /// Complete 4-Tier × 36 Authentic Go Moves Curriculum (all open to learn anytime + Mastered Stamp!).
    static let allEntries: [GoCodexEntry] = [
        // =========================================================================
        // TIER 1: 启蒙乐园 (30K–18K · Ages 4–7 · 10 Essential Starter Moves)
        // =========================================================================
        GoCodexEntry(
            id: "liberty",
            tier: .starter,
            rankTag: "30K",
            symbolName: "sparkles",
            accentHex: 0x05B06E,
            termZh: "气",
            termEn: "Liberty",
            termJa: "ダメ (呼吸点)",
            termKo: "활로 (숨구멍)",
            metaphorZh: "棋子上下左右的「呼吸口」，长按棋子就能看到发光的萤火虫气！",
            metaphorEn: "A stone's breathing holes! Hold any stone to light up its firefly liberties.",
            explanationZh: "紧邻棋子上下左右的空交叉点叫做「气」。相连的同色棋子共享所有气；一旦气归零，整块棋就会被提掉。",
            explanationEn: "Empty intersections directly adjacent (up, down, left, right) to a stone or group. Connected stones share liberties; at 0 liberties, stones are captured.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[cc];W[cb];B[dc];W[bc])",
            practicePuzzleId: "boot-01",
            practiceIsBootcamp: true,
            unlockedByDefault: true
        ),
        GoCodexEntry(
            id: "atari",
            tier: .starter,
            rankTag: "28K",
            symbolName: "exclamationmark.triangle.fill",
            accentHex: 0xF23357,
            termZh: "叫吃（打吃）",
            termEn: "Atari",
            termJa: "アタリ",
            termKo: "단수",
            metaphorZh: "棋子只剩最后 1 口气，紧张得直冒汗！下一手就可能被吃掉！",
            metaphorEn: "Down to 1 last breathing hole! Save it right away or it gets captured next turn.",
            explanationZh: "当一块棋只剩下 1 口气时，就处于「叫吃」状态。轮到对方就能立刻提子，轮到自己则可以长气逃跑或反吃。",
            explanationEn: "When a stone or group has only 1 liberty left, it is in Atari. The defender must rescue it immediately or lose it on the next move.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[cb][cd]AW[cc];B[bc];W[dc])",
            practicePuzzleId: "boot-02",
            practiceIsBootcamp: true,
            unlockedByDefault: true
        ),
        GoCodexEntry(
            id: "capture",
            tier: .starter,
            rankTag: "26K",
            symbolName: "burst.fill",
            accentHex: 0xFF940F,
            termZh: "提子",
            termEn: "Capture",
            termJa: "石を取る",
            termKo: "따내기",
            metaphorZh: "堵住对手最后一口气，把它的棋子“砰”地收进自己的棋笥！",
            metaphorEn: "Fill the opponent's last liberty and scoop their stones into your bowl!",
            explanationZh: "落子后如果令对方一块棋的气归零，就能把这块棋从棋盘上提走。被提掉的空地也常常变成你的地盘。",
            explanationEn: "When your move removes the last liberty of an opponent's group, those stones are removed from the board and placed into your capture bowl.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[cb][cd][bc]AW[cc];B[dc])",
            practicePuzzleId: "cap-01",
            unlockedByDefault: true
        ),
        GoCodexEntry(
            id: "hugCapture",
            tier: .starter,
            rankTag: "24K",
            symbolName: "arrow.up.to.line",
            accentHex: 0x05B06E,
            termZh: "抱吃（逼向边线）",
            termEn: "Hug Capture (Drive to Edge)",
            termJa: "抱え込み",
            termKo: "몰아떨구기",
            metaphorZh: "千万别把对手往宽敞的中间赶！从二路轻轻一抱，把它逼到边线墙角吃掉！",
            metaphorEn: "Don't push them into open space! Hug from the inside to trap them against the edge!",
            explanationZh: "棋盘边线是天然墙壁（边上棋子最多只有 3 口气，角上只有 2 口气）。打吃时要选对方向，把对手逼往边角或己方铜墙铁壁。",
            explanationEn: "The edge of the board acts like a free wall! Always choose the Atari direction that drives opponent stones toward the edge or into your own wall.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[ca][cc][dc][eb]AW[db];B[cb];W[da];B[ea])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "cap-03"
        ),
        GoCodexEntry(
            id: "doorCapture",
            tier: .starter,
            rankTag: "23K",
            symbolName: "door.left.hand.closed",
            accentHex: 0x0A7DF5,
            termZh: "门吃（关门吃）",
            termEn: "Door Capture",
            termJa: "門封じ",
            termKo: "문닫기",
            metaphorZh: "就像悄悄设好一扇小门，等白子钻进来逃跑时，“啪”一下关上门全吃光！",
            metaphorEn: "Lure them straight into a tiny doorway, then slam the door shut to capture them all!",
            explanationZh: "当对方棋子逃跑方向正好撞向己方两颗像门柱一样的棋子时，从反方向叫吃，待其长出一步后立刻封口关门提子。",
            explanationEn: "When your stones form two doorposts around an opponent's only escape path, Atari from behind and slam the door shut as soon as they step inside.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[bc][cd][db][ec]AW[cc];B[cb];W[dc];B[dd])",
            practicePuzzleId: "cap-02"
        ),
        GoCodexEntry(
            id: "doubleAtari",
            tier: .starter,
            rankTag: "20K",
            symbolName: "bolt.fill",
            accentHex: 0xFF940F,
            termZh: "双打吃",
            termEn: "Double Atari",
            termJa: "両アタリ",
            termKo: "양단수",
            metaphorZh: "一箭双雕！落下一颗子同时叫吃两块棋，对手顾得了左边就救不了右边！",
            metaphorEn: "One stone puts TWO enemy groups in Atari at once — they can only save one!",
            explanationZh: "寻找对方两块气紧棋子共用的交叉点，一子同时叫吃两块。对手只能补救一边，另一边必被吃掉。",
            explanationEn: "Play on the shared liberty of two opponent groups to threaten both at once. Since the opponent only gets one move, you are guaranteed a capture.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[cd][de][fe]AW[dd][ee];B[ed];W[dc];B[ef])",
            demoCrop: BoardCropRegion(minRow: 1, maxRow: 7, minCol: 1, maxCol: 7),
            practicePuzzleId: "cap-04"
        ),
        GoCodexEntry(
            id: "tigersMouth",
            tier: .starter,
            rankTag: "22K",
            symbolName: "shield.lefthalf.filled",
            accentHex: 0xFF940F,
            termZh: "虎口",
            termEn: "Tiger's Mouth",
            termJa: "カケツギ / 虎口",
            termKo: "호구",
            metaphorZh: "三颗棋子围成一张威风的「老虎嘴」，对手一跳进去就会被一口吃掉！",
            metaphorEn: "Three stones forming a fierce Tiger's Mouth — any enemy stone stepping inside gets eaten!",
            explanationZh: "三颗己方棋子围住一个空交叉点形成的形状叫「虎口」。虎口既能高效补断、增加气数，又是做眼的极佳好形；记住绝不要往对手虎口送吃。",
            explanationEn: "Three stones surrounding one empty point form a Tiger's Mouth. It is a super efficient defensive shape that protects cuts and helps make eyes.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[bc][cd]AW[dd][bd];B[cb];W[db];B[dc])",
            practicePuzzleId: "boot-03",
            practiceIsBootcamp: true
        ),
        GoCodexEntry(
            id: "cutAndConnect",
            tier: .starter,
            rankTag: "21K",
            symbolName: "link",
            accentHex: 0x05B06E,
            termZh: "断与连接",
            termEn: "Cut & Connect",
            termJa: "切りとツギ",
            termKo: "끊기와 잇기",
            metaphorZh: "好朋友手拉手「连接」就超级强壮；把对手「切断」就能各个击破！",
            metaphorEn: "Hold hands to Connect and stay strong — Cut your opponent apart to attack weak pieces!",
            explanationZh: "斜角相邻的棋子之间存在「断点」。连接可以把孤立的棋子合并成共享气数的大块，而切断则能分裂对手让其首尾难顾。",
            explanationEn: "Diagonal stones have cutting points between them. Connecting merges stones into one strong group with shared liberties; cutting splits the opponent into weak pieces.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[bb][db][dc]AW[ba][ab][bc];B[cb])",
            practicePuzzleId: "end-01"
        ),
        GoCodexEntry(
            id: "twoEyes",
            tier: .starter,
            rankTag: "20K",
            symbolName: "eye.fill",
            accentHex: 0x0A7DF5,
            termZh: "真眼与假眼（两眼活棋）",
            termEn: "True Eye vs False Eye",
            termJa: "二眼生き・欠け目",
            termKo: "두 집 살기 · 옥집",
            metaphorZh: "围出两只四角稳固的「真眼」就无敌活棋！如果虎口被破变成「假眼」，就要小心啦！",
            metaphorEn: "Two solid True Eyes make you invincible forever — watch out for cracked False Eyes!",
            explanationZh: "对手一次只能落一子，无法同时填满两只独立的「真眼」（单独填哪一只都是禁入点）。但若眼位斜角被对手占掉大半，就可能沦为会被叫吃填平的「假眼」。",
            explanationEn: "A group with two separate True Eyes can never be captured because filling either is illegal suicide. If opponent stones control the diagonal corners of an eye, it becomes a False Eye that can be destroyed!",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[aa][ab][bb][cb][db][eb][ea]AW[ac][bc][cc][dc][ec];B[ca])",
            practicePuzzleId: "boot-04",
            practiceIsBootcamp: true,
            unlockedByDefault: true
        ),
        GoCodexEntry(
            id: "suicide",
            tier: .starter,
            rankTag: "24K",
            symbolName: "nosign",
            accentHex: 0xF23357,
            termZh: "禁入点（自杀手）",
            termEn: "Suicide Rule",
            termJa: "着手禁止点",
            termKo: "착수금지",
            metaphorZh: "落下去自己一口气都没有的地方是禁止进入的——除非能立刻反吃对手！",
            metaphorEn: "You can't jump into a spot with 0 liberties — unless you capture enemy stones doing it!",
            explanationZh: "围棋禁止下完后令己方棋块气数为 0 且未提掉对方棋子的着法。但如果落子瞬间能把对手提掉，则完全合法！",
            explanationEn: "Playing a stone that leaves your own group with 0 liberties is forbidden, unless that exact move captures opponent stones first.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AW[ba][ab]AB[ca][bb][ac];B[aa])"
        ),

        // =========================================================================
        // TIER 2: 步法与手筋 (17K–10K · Ages 7–10 · 10 Core Shapes & Tesuji)
        // =========================================================================
        GoCodexEntry(
            id: "basicSteps",
            tier: .tactics,
            rankTag: "17K",
            symbolName: "figure.walk",
            accentHex: 0x0A7DF5,
            termZh: "行棋步法（长/跳/飞/尖/扳）",
            termEn: "Basic Steps (Jump, Knight, Hane)",
            termJa: "基本の打ち方（ノビ・トビ・ケイマ）",
            termKo: "기본 행마 (늘기·날일자·한칸뛰기)",
            metaphorZh: "棋子不只是贴身肉搏！学会「跳、小飞、小尖、扳」，你的棋就能像武林高手一样轻盈走路！",
            metaphorEn: "Move gracefully across the board with Jumps, Knight's Moves, Diagonals, and Hanes!",
            explanationZh: "「长」最厚实、「单关跳」向中央轻快出头、「小飞」像马走日快速围空、「小尖」扎实稳健、「扳」在接触战中转弯拦住对手。掌握步法是从乱下到会下棋的关键跨越。",
            explanationEn: "Extend for solidity, One-Space Jump to escape smoothly, Knight's Move to claim territory swiftly, Diagonal to stay connected, and Hane to turn around enemy stones.",
            demoBoardSize: 7,
            demoSGF: "(;GM[1]FF[4]SZ[7];B[cc];W[ee];B[ce];W[ec];B[dc];W[ed];B[fd])",
            practiceClassicId: classic9Id
        ),
        GoCodexEntry(
            id: "baseTwoSpace",
            tier: .tactics,
            rankTag: "16K",
            symbolName: "house.fill",
            accentHex: 0x05B06E,
            termZh: "拆二与根据地",
            termEn: "Two-Space Extension (Base)",
            termJa: "二間ビラキ（根拠）",
            termKo: "두 칸 벌림 (근거)",
            metaphorZh: "在三路边线隔两格摆两颗棋子，就像给自己建起一栋宽敞又安稳的「海边小屋」！",
            metaphorEn: "Space two stones 2 intersections apart along the 3rd line to build a cozy safe house!",
            explanationZh: "在边线三路隔两路落子称为「拆二」。拆二正好容易做出两只眼，是边上最稳定、最不容易被对手打入破坏的根据地。",
            explanationEn: "Extending two intersections along the third line creates a sturdy living base on the side — wide enough for territory yet tight enough to make two eyes easily.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9];B[cc];W[gg];B[fc];W[cg];B[gc];W[dc];B[dd])",
            practiceClassicId: classic13Id
        ),
        GoCodexEntry(
            id: "ladder",
            tier: .tactics,
            rankTag: "15K",
            symbolName: "stairs",
            accentHex: 0x0A7DF5,
            termZh: "征子",
            termEn: "Ladder (Shicho)",
            termJa: "シチョウ",
            termKo: "축",
            metaphorZh: "像走楼梯一样左右紧追不舍，一路把对手赶到棋盘边线吃光！",
            metaphorEn: "Zig-zag chase like climbing stairs all the way until they hit the edge of the board!",
            explanationZh: "连续不断从两侧交替叫吃，迫使对方每步只能长成两口气，一直追击到棋盘边缘无路可逃（出招前记得先看远方有没有对手的「引征」接应子哦）。",
            explanationEn: "A continuous zig-zag sequence of Ataris forcing the opponent to run in a diagonal staircase until they crash into the edge. Always check for ladder breakers first!",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[ca][cb][cc][dd]AW[dc];B[ec];W[db];B[eb];W[da];B[ea])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 1, maxCol: 6),
            practicePuzzleId: "tac-03"
        ),
        GoCodexEntry(
            id: "net",
            tier: .tactics,
            rankTag: "16K",
            symbolName: "square.grid.2x2.fill",
            accentHex: 0x05B06E,
            termZh: "枷吃",
            termEn: "Net (Geta)",
            termJa: "ゲタ",
            termKo: "장문",
            metaphorZh: "像张开一张天罗地网轻轻一罩，白子往哪冲都撞墙！",
            metaphorEn: "Throw a loose magical net from a distance — whichever way they run, they're trapped!",
            explanationZh: "不直接紧贴叫吃，而是隔一路斜罩住对方的逃跑方向。对手无论从哪一侧冲出，都会立刻陷入一口气的绝境，比征子更不怕远方接应子。",
            explanationEn: "Instead of direct Atari, place a loose diagonal stone blocking all escape lanes. Whichever side the opponent pushes, you capture cleanly without worrying about ladder breakers.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[ed][de][fd][df][eg][ge]AW[ee];B[ff];W[fe];B[ef])",
            demoCrop: BoardCropRegion(minRow: 1, maxRow: 8, minCol: 1, maxCol: 8),
            practicePuzzleId: "cap-05"
        ),
        GoCodexEntry(
            id: "snapback",
            tier: .tactics,
            rankTag: "15K",
            symbolName: "arrow.uturn.left.circle.fill",
            accentHex: 0xF23357,
            termZh: "倒扑",
            termEn: "Snapback",
            termJa: "ウッテガエシ",
            termKo: "환격",
            metaphorZh: "先大方送对手一颗“糖”，等它一口吞下自己气紧时，瞬间把整块全提光！",
            metaphorEn: "Offer 1 bait stone — when they greedily eat it, snap right back and capture the whole group!",
            explanationZh: "故意送吃一子让对方提子后反而只剩 1 口气，并且因为不是单子互提（不构成打劫），己方可以立刻回提整块大龙！",
            explanationEn: "Sacrifice a single stone so that capturing it leaves the opponent's whole group with 1 liberty. Because more than 1 stone is recaptured, Ko does not apply!",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AW[aa][ab][ba][cb][db][eb][ea]AB[bb][bc][cc][dc][ec][fb][fa];B[ca];W[da];B[ca])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7),
            practicePuzzleId: "tac-01"
        ),
        GoCodexEntry(
            id: "connectAndDie",
            tier: .tactics,
            rankTag: "14K",
            symbolName: "link.circle.fill",
            accentHex: 0x733DF2,
            termZh: "接不归",
            termEn: "Connect & Die",
            termJa: "オイオトシ",
            termKo: "촉촉수",
            metaphorZh: "看起来连起来就安全？其实一连反而堵死自己的气，全军覆没！",
            metaphorEn: "Looks like connecting saves them — but connecting actually traps the whole group at 1 liberty!",
            explanationZh: "叫吃对方一部分棋子，如果对手试图连回大部队，合并后的整块棋反而只剩 1 口气，会被一网打尽。",
            explanationEn: "Put a stone in Atari so that if the opponent connects it to their neighboring group, the combined group drops to 1 liberty and is captured.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[aa][ab][bc][dc][ec][eb][fb][ga]AW[ba][bb][db][da][ea];B[cb];W[ca];B[fa])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 7),
            practicePuzzleId: "tac-02"
        ),
        GoCodexEntry(
            id: "squeeze",
            tier: .tactics,
            rankTag: "13K",
            symbolName: "tornado",
            accentHex: 0xFF940F,
            termZh: "滚打包收",
            termEn: "Rolling Squeeze (Shibori)",
            termJa: "シボリ（石の下）",
            termKo: "조이기 (먹여치기)",
            metaphorZh: "像揉面团一样连续叫吃，把对手拧成一团动弹不得的「大汤圆」再一口气拿下！",
            metaphorEn: "Chain Atari after Atari to roll your opponent into a clumsy, breathless dumpling!",
            explanationZh: "通过连续不断的正手叫吃甚至弃子扑吃，迫使对方棋子挤成没有效率的愚形（气紧、无眼），从而轻松提子或竖起铁厚外势。",
            explanationEn: "A thrilling chain of consecutive Ataris that forces the opponent's stones into a heavy, gasping clump — either capturing them outright or building a mighty wall.",
            demoBoardSize: 7,
            demoSGF: "(;GM[1]FF[4]SZ[7]AB[bc][bd][dc][eb][ec]AW[cc][cd][db][dd][de];B[cb];W[da];B[ca];W[ea];B[fa])"
        ),
        GoCodexEntry(
            id: "cranesLeg",
            tier: .tactics,
            rankTag: "12K",
            symbolName: "crown.fill",
            accentHex: 0xFF940F,
            termZh: "金鸡独立",
            termEn: "Crane's Leg Tesuji",
            termJa: "両側のダメヅマリ",
            termKo: "양자충",
            metaphorZh: "一子稳稳立在正中央，左右两边对手都气紧不敢入子，帅呆了！",
            metaphorEn: "Stand tall in the middle so BOTH enemy sides suffer shortage of liberties and can't play!",
            explanationZh: "利用双方气紧的绝妙手筋：在中间轻轻立下一子，使左右两块敌棋都陷入自杀禁入点或一入即被提的窘境。",
            explanationEn: "A famous classic tesuji: one calm move in the center creates a shortage of liberties on both left and right, making both sides unplayable for the opponent.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AW[aa][ab][bb][db][eb][ea]AB[ca][ac][bc][cc][dc][ec][fb][fa];B[cb])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "tac-05"
        ),
        GoCodexEntry(
            id: "basicLifeDeathShapes",
            tier: .tactics,
            rankTag: "12K",
            symbolName: "sparkles.rectangle.stack.fill",
            accentHex: 0x0A7DF5,
            termZh: "死活常形（直三/直四/曲四/刀把五/丁四）",
            termEn: "Classic Eye Shapes",
            termJa: "基本死活形（三目・四目・五目）",
            termKo: "기본 사활형 (직삼·직사·오궁도화)",
            metaphorZh: "记住口诀：「直三曲三点中间，直四曲四是活棋，方四天然是死形，刀把丁四找中心」！",
            metaphorEn: "Vital point rule: Straight/Bent Three -> center! Straight/Bent Four -> alive! Square Four -> dead!",
            explanationZh: "围棋死活有经典形状规律：直三、曲三、刀把五、丁四都只有一个核心「要点」，先占要点者胜（「敌之要点即我之要点」）；直四、曲四天然活棋，方四天然死棋。",
            explanationEn: "Classic eye spaces follow universal laws: Straight Three, Bent Three, Bulky Five, and Pyramid Four all hinge on one single vital point ('my opponent's vital point is my vital point').",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AW[aa][ab][ac][bc][cc][dc][db][eb][ea]AB[ad][bd][cd][dd][ed][ec][fc][fb][fa];B[ca];W[ba];B[cb])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "lad-04"
        ),
        GoCodexEntry(
            id: "seki",
            tier: .tactics,
            rankTag: "10K",
            symbolName: "hands.clap.fill",
            accentHex: 0x05B06E,
            termZh: "双活",
            termEn: "Seki (Mutual Life)",
            termJa: "セキ（活き）",
            termKo: "빅 (상생)",
            metaphorZh: "两块棋共享最后两口气——谁先动手咬对方，自己反而先被吃！于是双方和平共处一起活！",
            metaphorEn: "Two rival groups share 2 last liberties: whoever attacks first gets captured! So both live in peace!",
            explanationZh: "当黑白两块棋互相包围且都做不出两眼，却共同拥有公气，任何一方先紧气都会立刻陷入叫吃而被对方提掉。此时谁都不动，双方共同存活，称为「双活」。",
            explanationEn: "An extraordinary Go standoff where neither black nor white has two eyes, yet neither can attack without committing suicide. Both groups survive peacefully together!",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[aa][ab][ac][bc][cc][dc][ec][eb]AW[ca][da][cb][ad][bd][cd][dd][ed][be][de];B[ea];W[db])"
        ),

        // =========================================================================
        // TIER 3: 战斗与对杀 (9K–3K · Ages 9–14 · 8 Sharp Fighting Techniques)
        // =========================================================================
        GoCodexEntry(
            id: "ko",
            tier: .fighting,
            rankTag: "9K",
            symbolName: "hourglass",
            accentHex: 0xFF940F,
            termZh: "打劫与寻劫",
            termEn: "Ko & Ko Threats",
            termJa: "コウとコウ材",
            termKo: "패와 팻감",
            metaphorZh: "不能立刻回提怎么办？去棋盘别处大喊“看这里！”逼对手应付，再转身赢下打劫！",
            metaphorEn: "Spot locked for 1 turn? Make a huge threat elsewhere (a Ko Threat), then dash back to recapture!",
            explanationZh: "单子互提触发打劫规则：不能立刻回提还原局面。必须先在别处寻找「劫材」（对手不得不应的严厉威胁），等对方应后再回提，是围棋最具戏剧性的心理战。",
            explanationEn: "You cannot immediately recapture a Ko. Play a forcing threat elsewhere (a Ko threat); if your opponent answers it, you may return and recapture the Ko!",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5]AB[cb][cd][bc]AW[cc][db][dd][ec];B[dc];W[aa];B[ab];W[cc])"
        ),
        GoCodexEntry(
            id: "capturingRace",
            tier: .fighting,
            rankTag: "9K",
            symbolName: "flame.fill",
            accentHex: 0x0A7DF5,
            termZh: "对杀先紧外气",
            termEn: "Capturing Race: Outside Liberties",
            termJa: "攻め合い（外ダメから）",
            termKo: "수상전 (바깥수 먼저)",
            metaphorZh: "两块棋赛跑比谁先没气时，先把对手外面的气堵死，千万别先填中间的公气！",
            metaphorEn: "In a liberty race, fill the opponent's outside liberties first — never fill shared liberties too early!",
            explanationZh: "双方互相包围、都没做活时称为「对杀」。黄金铁律是「对杀先紧外气」，把公气留到最后，先填公气会反过来缩减自己的气数。",
            explanationEn: "When two surrounded groups race to capture each other, always take the opponent's outside liberties before touching shared liberties (dame).",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[ba][bb][cc][dc][ec][eb][fb][fa]AW[ab][ac][bc][cb][db][da];B[ea];W[aa];B[ca])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "end-02"
        ),
        GoCodexEntry(
            id: "eyeVsNoEye",
            tier: .fighting,
            rankTag: "8K",
            symbolName: "eye.circle.fill",
            accentHex: 0xF23357,
            termZh: "有眼杀无眼",
            termEn: "Eye Beats No-Eye",
            termJa: "目あり目なし",
            termKo: "유가무가",
            metaphorZh: "哪怕只有 1 只真眼，对手根本不敢踏进去！所以「有眼」的棋在对杀中拥有绝对特权！",
            metaphorEn: "Even ONE true eye acts like a secret bunker — the opponent can't enter until all other liberties vanish!",
            explanationZh: "对杀中，如果己方拥有 1 只真眼而对手无眼，则双方的公气会全部变成己方的「专属气」（对手无法先入眼位），这就是著名的「有眼杀无眼」。",
            explanationEn: "In a capturing race where you have 1 true eye and your opponent has none, all shared liberties belong solely to you because your opponent cannot enter your eye first!",
            demoBoardSize: 7,
            demoSGF: "(;GM[1]FF[4]SZ[7]AB[ba][bb][ab][ea][eb][ec][dc][dd][cd][bd][ad]AW[ca][cb][cc][bc][ac];B[da];W[fe];B[db])"
        ),
        GoCodexEntry(
            id: "bigEyeVsSmallEye",
            tier: .fighting,
            rankTag: "7K",
            symbolName: "plus.magnifyingglass",
            accentHex: 0x733DF2,
            termZh: "大眼杀小眼",
            termEn: "Big Eye Beats Small Eye",
            termJa: "大目殺小目",
            termKo: "대안살소안",
            metaphorZh: "大家都有一只眼？那眼位更大的那一边暗藏超多口气（直三=3气、直四=5气、梅花五=8气）！",
            metaphorEn: "Both sides have an eye? Bigger eye spaces secretly hold way more liberties (3-space=3, 4-space=5, 5-space=8)!",
            explanationZh: "大眼内部需要对手花好几手才能破掉，因此拥有极多隐藏气数（俗称「大眼气数歌：三三、四五、五八、六十二」）。实战对杀时要努力做大己方眼位、缩小对手眼位。",
            explanationEn: "Larger eye spaces take many moves for the opponent to fill in, granting huge hidden liberties (3-space = 3, 4-space = 5, 5-space = 8, 6-space = 12 liberties!).",
            demoBoardSize: 7,
            demoSGF: "(;GM[1]FF[4]SZ[7]AB[ca][cb][bb][ab][da][db][dc][dd][ed][fd][gd]AW[ea][eb][ec][fc][gc][ga];B[fb];W[gb];B[fa])"
        ),
        GoCodexEntry(
            id: "throwIn",
            tier: .fighting,
            rankTag: "7K",
            symbolName: "arrow.down.to.line.compact",
            accentHex: 0xF23357,
            termZh: "扑与缩小眼位",
            termEn: "Throw-In & Eye Reduction",
            termJa: "ホウリコミと狭め",
            termKo: "먹여치기와 궁도 좁히기",
            metaphorZh: "杀棋别着急乱点里面！先从外侧扳进去把对手房子「挤小」，再用「扑」破掉假眼！",
            metaphorEn: "Don't rush inside blindly! Shrink their room from the outside first, then strike the vital point!",
            explanationZh: "杀棋的标准次序是「先缩小眼位，再点杀要点」。从外侧一路扳或向眼位内「扑」送一子，常能把活形直四缩成死形直三，或把真眼变成假眼。",
            explanationEn: "The golden rule of killing groups: reduce the eye space from the outside first (turning a living 4 into a dead 3), or throw in a sacrifice stone to turn a true eye into a false eye.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AW[aa][ab][bb][cb][db][eb]AB[ac][bc][cc][dc][ec][fc][fb][fa];B[ea];W[ca];B[da])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "end-05"
        ),
        GoCodexEntry(
            id: "firstLineConnect",
            tier: .fighting,
            rankTag: "6K",
            symbolName: "bridge",
            accentHex: 0x05B06E,
            termZh: "一路扳渡",
            termEn: "First-Line Connection (Watari)",
            termJa: "ワタリ（渡り）",
            termKo: "넘어가기 (건너붙임)",
            metaphorZh: "正面被挡住？悄悄贴着海边「一路」钻过去，左右两队棋子瞬间悄悄会师！",
            metaphorEn: "Blocked in front? Slip stealthily along the 1st-line shoreline to unite your two groups!",
            explanationZh: "利用对手在边线气紧的弱点，沿一路巧妙潜行渡过，使原本分裂的两块孤棋连成一片，是中盘联络与收官的利器。",
            explanationEn: "Sneak underneath opponent stones along the 1st line, exploiting their shortage of liberties so they cannot cut you off. Essential for saving weak groups!",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[ba][bb][bc][db][dc][eb][ec]AW[ab][ac][bd][cb][cc][cd][dd];B[ca];W[da];B[ea])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "end-03"
        ),
        GoCodexEntry(
            id: "wedgeAndClamp",
            tier: .fighting,
            rankTag: "5K",
            symbolName: "scissors",
            accentHex: 0xFF940F,
            termZh: "挖断与夹击",
            termEn: "Wedge & Clamp (Warikomi)",
            termJa: "ワリコミ・ハサミツケ",
            termKo: "끼우기 · 젖혀끊기",
            metaphorZh: "像一根锋利的小楔子直接插进对手薄弱缝隙，逼它左右顾此失彼！",
            metaphorEn: "Drive a sharp wedge straight into the opponent's seam so they can't keep both sides intact!",
            explanationZh: "「挖」是直接楔入对方两颗间隔一格的棋子正中，制造双打吃或分断；「夹」则是对挂角或孤棋形成左右包夹，是中盘反击的锐利手筋。",
            explanationEn: "Wedging directly between two opponent stones splits their shape and forces awkward responses — one of the sharpest fighting tesujis in Go.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[ba][bb][cc][dc][ec][fb][fa]AW[cb][da][eb];B[db];W[ca];B[ea])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 6),
            practicePuzzleId: "tac-04"
        ),
        GoCodexEntry(
            id: "cranesNest",
            tier: .fighting,
            rankTag: "4K",
            symbolName: "tortoise.fill",
            accentHex: 0x0A7DF5,
            termZh: "乌龟不出头",
            termEn: "Sealing the Escape (Turtle Shell)",
            termJa: "封鎖（頭を止める）",
            termKo: "봉쇄 (거북등)",
            metaphorZh: "牢牢按住对手伸出来的“小脑袋”，把它关进没有出路的小黑屋里！",
            metaphorEn: "Keep capping their head so they can never poke out into the open center!",
            explanationZh: "封锁对手向中央逃跑的「出头」方向，使其被迫在狭小空间苦苦求活，同时自己顺势筑起辐射全盘的强大外势。",
            explanationEn: "Relentlessly seal an opponent group's escape toward the center. Even if they barely live inside, your surrounding wall dominates the entire board.",
            demoBoardSize: 7,
            demoSGF: "(;GM[1]FF[4]SZ[7]AW[cc][dc]AB[cb][db][bc][ec][cd];W[dd];B[ed];W[de];B[ee];W[ce];B[df])"
        ),

        // =========================================================================
        // TIER 4: 布局与段位 (2K–1D+ · Ages 12+ & Adults · 8 Strategy, Joseki & Endgame)
        // =========================================================================
        GoCodexEntry(
            id: "komi",
            tier: .mastery,
            rankTag: "ALL",
            symbolName: "scale.3d",
            accentHex: 0x733DF2,
            termZh: "贴目与胜负计算",
            termEn: "Komi & Area Scoring",
            termJa: "コミと地合い計算",
            termKo: "덤과 계가",
            metaphorZh: "黑棋先走占了小小便宜，所以终局要给白棋补上一点分数才公平，带 .5 还永不平局！",
            metaphorEn: "Black moves first for a tiny edge, so White gets Komi points for fairness — and .5 prevents ties!",
            explanationZh: "中国规则采用「数子法」（活子 + 围住的空交叉点），终局给白方加上贴目（9路 5.5、13路 6.5、19路 7.5）。对局中善用形势判断，才能决定该稳守还是强攻。",
            explanationEn: "Chinese Area Scoring counts living stones plus surrounded empty territory, adding Komi to White (5.5 on 9×9, 6.5 on 13×13, 7.5 on 19×19) to balance Black's first-move advantage.",
            demoBoardSize: 5,
            demoSGF: "(;GM[1]FF[4]SZ[5];B[cc];W[bb];B[dd];W[bd])",
            unlockedByDefault: true
        ),
        GoCodexEntry(
            id: "cornersSidesCenter",
            tier: .mastery,
            rankTag: "2K",
            symbolName: "map.fill",
            accentHex: 0x05B06E,
            termZh: "金角银边草肚皮",
            termEn: "Golden Corners, Silver Sides",
            termJa: "金角銀辺草肚皮（布石）",
            termKo: "금각은변초두피 (포석)",
            metaphorZh: "角上有两面天然墙壁最省子，边上有一面墙，中央四面漏风！开局先抢角、再占边、最后走中腹！",
            metaphorEn: "Corners have 2 free walls (gold!), sides have 1 (silver!), center has 0 — claim corners first!",
            explanationZh: "围棋布局第一铁律：围同样大的空，角部所需棋子最少、效率最高，其次是边线，中央最难围空。开局顺序通常是「占角 → 守角/挂角 → 拆边 → 进军中腹」。",
            explanationEn: "The supreme opening principle of Go: corners require the fewest stones to secure territory, sides second, center most. Opening flow: claim corners -> approach/enclose -> extend on sides -> center.",
            demoBoardSize: 13,
            demoSGF: "(;GM[1]FF[4]SZ[13];B[dd];W[jj];B[dj];W[jd];B[fj];W[jf])",
            practiceClassicId: classic13Id
        ),
        GoCodexEntry(
            id: "sanSanJoseki",
            tier: .mastery,
            rankTag: "1K",
            symbolName: "star.circle.fill",
            accentHex: 0x733DF2,
            termZh: "星位点三三定式",
            termEn: "3-3 Invasion Joseki",
            termJa: "星への三々入り定石",
            termKo: "화점 삼삼 침입 정석",
            metaphorZh: "现代 AI 与世界冠军最爱的招牌定式！白棋钻角拿实地，黑棋筑墙得外势，两全其美！",
            metaphorEn: "The favorite modern Joseki of pros & AI: White steals the corner cash while Black builds a mighty outer wall!",
            explanationZh: "面对星位（4-4），直接点在三三（3-3）抢占角部实地，对方从宽阔一侧挡住并筑起厚实外势。这是 19 路对局出场率最高、最均衡的现代经典定式。",
            explanationEn: "Invading directly at the 3-3 point under an opponent's 4-4 Star Point gives the invader solid corner territory while the defender gets a powerful, flexible outside wall.",
            demoBoardSize: 19,
            demoSGF: "(;GM[1]FF[4]SZ[19];B[pd];W[qc];B[qd];W[pc];B[od];W[oc];B[nc];W[ob];B[rc];W[rb])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 8, minCol: 10, maxCol: 18),
            practiceClassicId: classic19Id
        ),
        GoCodexEntry(
            id: "knightApproachJoseki",
            tier: .mastery,
            rankTag: "1K",
            symbolName: "arrow.up.right.circle.fill",
            accentHex: 0x0A7DF5,
            termZh: "星位小飞挂定式",
            termEn: "Star-Point Knight Approach",
            termJa: "星の小ゲイマ掛かり定石",
            termKo: "화점 날일자 걸침 정석",
            metaphorZh: "礼貌地从侧面小飞靠近对手星位，一个守角、一个拆边，双方优雅展开全盘布局！",
            metaphorEn: "Approach the Star Point smoothly with a Knight's Move — one guards the corner, the other claims the side!",
            explanationZh: "对星位下「小飞挂」，守方「小飞应」稳固角部与一边，挂角方顺势「拆二/拆三」在另一边建立根据地。棋形舒展大方，是最经典的入门大局定式。",
            explanationEn: "When an opponent approaches your 4-4 corner with a Knight's Move, answering with a Knight's Move protects your corner while they settle calmly along the side.",
            demoBoardSize: 19,
            demoSGF: "(;GM[1]FF[4]SZ[19];B[pd];W[nc];B[qf];W[kc])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 8, minCol: 9, maxCol: 18),
            practiceClassicId: classic19Id
        ),
        GoCodexEntry(
            id: "wallExtension",
            tier: .mastery,
            rankTag: "1D",
            symbolName: "building.columns.fill",
            accentHex: 0xFF940F,
            termZh: "立二拆三与厚势",
            termEn: "Two-High Three-Extension & Thickness",
            termJa: "立二拆三・厚みの活用",
            termKo: "입이탁삼 · 두터움 활용",
            metaphorZh: "「立二拆三，立三拆四」：自己的墙越厚越强，往外迈出的步子就能跨得越大！",
            metaphorEn: "Stronger walls let you leap farther! A 2-stone wall extends 3 spaces; a 3-stone wall extends 4!",
            explanationZh: "单子在边上宜「拆二」，两子并立（厚实一倍）即可放心「拆三」，三子并立可「拆四」。厚势不仅用来围空，更重要的是用来攻击对手弱棋并辐射全局。",
            explanationEn: "A classic structural proverb: extend 2 spaces from 1 stone, 3 spaces from a 2-stone wall, and 4 spaces from a 3-stone wall. Use thickness boldly to attack!",
            demoBoardSize: 13,
            demoSGF: "(;GM[1]FF[4]SZ[13];B[dd];W[jj];B[dc];W[jd];B[hd])",
            practiceClassicId: classic13Id
        ),
        GoCodexEntry(
            id: "invasionAndSabaki",
            tier: .mastery,
            rankTag: "1D",
            symbolName: "wind",
            accentHex: 0x05B06E,
            termZh: "打入与腾挪治孤",
            termEn: "Invasion & Sabaki",
            termJa: "打ち込みとサバキ",
            termKo: "침투와 타개 (사바키)",
            metaphorZh: "对手围出超大空地？派一颗灵巧的“小侦察兵”空降进去，借力打力轻松做活破空！",
            metaphorEn: "Opponent building a giant empire? Parachute a nimble scout inside and dance lightly to live!",
            explanationZh: "当对手阵势过大时，主动深入敌阵称为「打入」。在敌方势力圈内通过轻灵的碰、靠、弃子迅速整形做活或脱身，称为「腾挪」，是高段棋手的艺术。",
            explanationEn: "Invading a massive enemy framework and using light, flexible contact moves (Sabaki) to settle quickly or escape is the hallmark of Dan-level play.",
            demoBoardSize: 13,
            demoSGF: "(;GM[1]FF[4]SZ[13]AW[dd][jd];B[gd];W[gc];B[fc];W[fd];B[ec];W[ed];B[hc])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 7, minCol: 0, maxCol: 12)
        ),
        GoCodexEntry(
            id: "sacrificeShape",
            tier: .mastery,
            rankTag: "1D",
            symbolName: "gift.fill",
            accentHex: 0xF23357,
            termZh: "弃子整形",
            termEn: "Sacrifice for Shape",
            termJa: "捨て石の妙手",
            termKo: "사석 작전",
            metaphorZh: "真正的围棋高手舍得「丢小捡大」：主动放弃几颗残子，换来铁板外势和先手主导权！",
            metaphorEn: "True masters gladly trade 1–2 small stones to build an unstoppable wall and seize initiative!",
            explanationZh: "「棋逢难处小弃子」。当几颗子陷入重围、强救反而拖累全局时，果断将其作为弃子，利用对手吃子的机会在外部封锁整形并抢得先手，是迈入段位的关键思维。",
            explanationEn: "Rather than dragging heavy, dying stones across the board, willingly sacrifice them to squeeze from the outside, fix your shape, and take Sente (initiative) elsewhere.",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AB[dd][ed][ec]AW[dc][cd][de][ee];B[fd];W[cc];B[ef];W[df];B[dg])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 6, minCol: 0, maxCol: 8)
        ),
        GoCodexEntry(
            id: "monkeyJumpEndgame",
            tier: .mastery,
            rankTag: "1D",
            symbolName: "flag.checkered.2.crossed",
            accentHex: 0x733DF2,
            termZh: "先手官子与大伸腿（猴脸）",
            termEn: "Sente Endgame & Monkey Jump",
            termJa: "先手ヨセ・大サルすべり",
            termKo: "선수 끝내기 · 원숭이 발",
            metaphorZh: "收官阶段，小猴子沿着一路“嗖”地伸腿钻进对手边空，白白捞走好几目大官子！",
            metaphorEn: "In the endgame, leap like a clever monkey along the 1st line to scoop huge territory right under their nose!",
            explanationZh: "收官遵循「双先 > 单先 > 后手」原则（先手代表走完对手必须应，自己还能继续抢下一个大官子）。经典的「大伸腿（一路小飞潜入）」是最华丽高效的收官绝技之一。",
            explanationEn: "Endgame priority: Double Sente > Sente > Gote. The famous Monkey Jump leaps deep along the 1st line under an enemy side stone, slashing up to 8–9 points in one stroke!",
            demoBoardSize: 9,
            demoSGF: "(;GM[1]FF[4]SZ[9]AW[gc][gd][ge]AB[cd][ce][dc];B[fa];W[fb];B[ea];W[eb];B[da])",
            demoCrop: BoardCropRegion(minRow: 0, maxRow: 5, minCol: 0, maxCol: 8)
        )
    ]

    static func entry(withId id: String) -> GoCodexEntry? {
        allEntries.first { $0.id == id }
    }

    static var defaultUnlockedIds: Set<String> {
        Set(allEntries.filter(\.unlockedByDefault).map(\.id))
    }

    /// Maps each puzzle ID to the authentic Go term it certifies as "Mastered ★" in the Codex!
    static func codexTermId(forPuzzleId puzzleId: String) -> String? {
        switch puzzleId {
        case "boot-01", "cap-01": return "capture"
        case "cap-02": return "doorCapture"
        case "boot-02", "end-04": return "atari"
        case "cap-03": return "hugCapture"
        case "boot-03", "end-01": return "cutAndConnect"
        case "boot-04", "lad-01", "lad-02", "lad-03": return "twoEyes"
        case "lad-04", "lad-05": return "basicLifeDeathShapes"
        case "cap-04": return "doubleAtari"
        case "cap-05": return "net"
        case "tac-01": return "snapback"
        case "tac-02": return "connectAndDie"
        case "tac-03": return "ladder"
        case "tac-04": return "wedgeAndClamp"
        case "tac-05": return "cranesLeg"
        case "end-02": return "capturingRace"
        case "end-03": return "firstLineConnect"
        case "end-05": return "throwIn"
        default: return nil
        }
    }
}

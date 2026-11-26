//
//  GoAcademyLibrary.swift
//  StarYi Go — Nintendo-Style Go Knowledge & Masterpieces Academy (棋谱书院)
//  4 Pure Halls: 传奇名局 · 棋理十诀 · 布局流派 · 奇局趣史
//

import Foundation

enum AcademyHall: String, CaseIterable, Identifiable, Sendable {
    case masterpieces  // 传奇名局
    case principles    // 棋理十诀
    case openings      // 布局流派
    case curiosities   // 奇局趣史

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .masterpieces: return "trophy.fill"
        case .principles: return "lightbulb.fill"
        case .openings: return "map.fill"
        case .curiosities: return "sparkles"
        }
    }

    var accentHex: UInt32 {
        switch self {
        case .masterpieces: return 0x733DF2 // Grape
        case .principles: return 0xFF940F   // Sun
        case .openings: return 0x05B06E     // Mint
        case .curiosities: return 0xF23357  // Coral
        }
    }

    func title(_ l10n: L10n) -> String {
        switch self {
        case .masterpieces:
            return l10n.localized(zh: "传奇名局", en: "Masterpieces", ja: "伝説の名局", ko: "전설의 명국", zhHant: "傳奇名局")
        case .principles:
            return l10n.localized(zh: "棋理十诀", en: "Go Principles", ja: "囲碁十訣", ko: "위기십결", zhHant: "棋理十訣")
        case .openings:
            return l10n.localized(zh: "布局流派", en: "Openings", ja: "布石・定石", ko: "포석 유파", zhHant: "佈局流派")
        case .curiosities:
            return l10n.localized(zh: "奇局趣史", en: "Lore & Wonders", ja: "奇局と逸話", ko: "기국과 일화", zhHant: "奇局趣史")
        }
    }

    func subtitle(_ l10n: L10n) -> String {
        switch self {
        case .masterpieces:
            return l10n.localized(
                zh: "中外大赛经典对决 · 高光跳转与猜大师下一手",
                en: "Historic title matches with highlights & master move quiz",
                ja: "歴史的名局の見どころ解説＆次の一手クイズ",
                ko: "세계 대회 명국 하이라이트 및 다음 수 퀴즈",
                zhHant: "中外大賽經典對決 · 高光跳轉與猜大師下一手"
            )
        case .principles:
            return l10n.localized(
                zh: "围棋十诀与黄金格言 · 正着与贪心错着一键对比",
                en: "Ten Golden Rules & proverbs with Good vs Mistake comparison",
                ja: "囲碁十訣と格言・正解と失敗のワンタップ比較",
                ko: "위기십결과 격언 · 정수 vs 실수 한눈에 비교",
                zhHant: "圍棋十訣與黃金格言 · 正著與貪心錯著一鍵對比"
            )
        case .openings:
            return l10n.localized(
                zh: "9路到19路经典开局蓝图 · 看完马上能在实战中用",
                en: "9×9 to 19×19 opening blueprints you can play right away",
                ja: "9路〜19路の定番布石・すぐ実戦で使える設計図",
                ko: "9줄~19줄 대표 포석 · 바로 실전에 써먹는 전략",
                zhHant: "9路到19路經典開局藍圖 · 看完馬上能在實戰中用"
            )
        case .curiosities:
            return l10n.localized(
                zh: "古代棋经奇形与围棋典故 · 像脑筋急转弯一样好玩",
                en: "Classic puzzles, legends & Go wonders across millennia",
                ja: "古典棋書の奇形と囲碁トリビア",
                ko: "고전 기서의 기묘한 형태와 바둑 이야기",
                zhHant: "古代棋經奇形與圍棋典故 · 像腦筋急轉彎一樣好玩"
            )
        }
    }
}

enum AcademyLevel: String, CaseIterable, Identifiable, Sendable {
    case all
    case starter       // 启蒙 30K–18K
    case intermediate  // 进阶 17K–10K
    case advanced      // 高阶 9K–1K
    case dan           // 段位 1D+

    var id: String { rawValue }

    func title(_ l10n: L10n) -> String {
        switch self {
        case .all: return l10n.localized(zh: "全部", en: "All", ja: "すべて", ko: "전체", zhHant: "全部")
        case .starter: return l10n.localized(zh: "启蒙", en: "Starter", ja: "入門", ko: "입문", zhHant: "啟蒙")
        case .intermediate: return l10n.localized(zh: "进阶", en: "Intermediate", ja: "中級", ko: "중급", zhHant: "進階")
        case .advanced: return l10n.localized(zh: "高阶", en: "Advanced", ja: "上級", ko: "고급", zhHant: "高階")
        case .dan: return l10n.localized(zh: "段位", en: "Dan", ja: "有段", ko: "유단", zhHant: "段位")
        }
    }
}

struct AcademyHighlight: Identifiable, Hashable, Sendable {
    let moveIndex: Int
    let labelZh: String
    let labelEn: String

    var id: Int { moveIndex }

    func label(_ l10n: L10n) -> String {
        l10n.bilingual(zh: labelZh, en: labelEn)
    }
}

struct AcademyQuizStep: Hashable, Sendable {
    /// Step index right BEFORE the target master move (so target move is `mainLineMoves[beforeMoveIndex]`).
    let beforeMoveIndex: Int
    let promptZh: String
    let promptEn: String

    func prompt(_ l10n: L10n) -> String {
        l10n.bilingual(zh: promptZh, en: promptEn)
    }
}

struct AcademyEntry: Identifiable, Hashable, Sendable {
    let id: String
    let recordId: UUID
    let hall: AcademyHall
    let level: AcademyLevel
    let rankTag: String
    let eraOrTagZh: String
    let eraOrTagEn: String
    let titleZh: String
    let titleEn: String
    let hookZh: String
    let hookEn: String
    let blackPlayerZh: String
    let blackPlayerEn: String
    let whitePlayerZh: String
    let whitePlayerEn: String
    let resultString: String
    let boardSize: Int
    let komi: Double
    let sgfZh: String
    let sgfEn: String
    let highlights: [AcademyHighlight]
    let quizStep: AcademyQuizStep?
    /// Optional counter-example SGF ("贪心/俗手反面教材") for one-tap Good vs Mistake comparison!
    let counterExampleSgfZh: String?
    let counterExampleSgfEn: String?

    func title(_ l10n: L10n) -> String { l10n.bilingual(zh: titleZh, en: titleEn) }
    func hook(_ l10n: L10n) -> String { l10n.bilingual(zh: hookZh, en: hookEn) }
    func eraOrTag(_ l10n: L10n) -> String { l10n.bilingual(zh: eraOrTagZh, en: eraOrTagEn) }
    func sgf(_ l10n: L10n) -> String { l10n.language.isChinese ? sgfZh : sgfEn }
    func counterExampleSgf(_ l10n: L10n) -> String? {
        l10n.language.isChinese ? counterExampleSgfZh : counterExampleSgfEn
    }

    var hasCounterExample: Bool { counterExampleSgfZh != nil }
    var hasQuiz: Bool { quizStep != nil }

    /// Total main-line moves in this study record.
    var moveCount: Int {
        var count = 0
        var i = sgfZh.startIndex
        while i < sgfZh.endIndex {
            if sgfZh[i] == ";" {
                let next = sgfZh.index(after: i)
                if next < sgfZh.endIndex && (sgfZh[next] == "B" || sgfZh[next] == "W") {
                    let afterColor = sgfZh.index(after: next)
                    if afterColor < sgfZh.endIndex && sgfZh[afterColor] == "[" {
                        count += 1
                    }
                }
            }
            i = sgfZh.index(after: i)
        }
        return count
    }

    func toSavedGameRecord(l10n: L10n) -> SavedGameRecord {
        let sgfText = sgf(l10n)
        let moveCount: Int = {
            guard let root = SGFParser.parse(sgfText) else { return 0 }
            var count = 0
            var node = root.children.first
            while let n = node {
                if n.move != nil { count += 1 }
                node = n.children.first
            }
            return count
        }()
        return SavedGameRecord(
            id: recordId,
            date: Date(timeIntervalSince1970: 1_735_689_600),
            boardSize: boardSize,
            komi: komi,
            handicap: 0,
            blackName: l10n.bilingual(zh: blackPlayerZh, en: blackPlayerEn),
            whiteName: l10n.bilingual(zh: whitePlayerZh, en: whitePlayerEn),
            resultString: resultString,
            moveCount: moveCount,
            sgf: sgfText
        )
    }
}

enum GoAcademyLibrary {
    static let allEntries: [AcademyEntry] = [
        // =========================================================================
        // HALL 1: 传奇名局 (1 Starter 9x9 + 11 Complete Authentic 19x19 Masterpieces!)
        // =========================================================================
        AcademyEntry(
            id: "master-9x9-classic",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111101")!,
            hall: .masterpieces,
            level: .starter,
            rankTag: "启蒙 25K",
            eraOrTagZh: "9路短局精讲",
            eraOrTagEn: "9×9 Guided Match",
            titleZh: "9路天元攻防 · 启蒙第一盘",
            titleEn: "9×9 Tengen Opening & Fight",
            hookZh: "只需 22 手看完一盘完整 9 路胜负！从天元出发，学懂占地、切断与收官。",
            hookEn: "A complete 22-move 9×9 battle from Tengen — learn territory, cutting, and endgame!",
            blackPlayerZh: "星弈小老师（黑）",
            blackPlayerEn: "StarYi Coach (Black)",
            whitePlayerZh: "教学示范谱（白）",
            whitePlayerEn: "Dojo Study (White)",
            resultString: "B+2.5",
            boardSize: 9,
            komi: 5.5,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]C[欢迎来到 9 路实战教学！跟着小老师一步步看懂开局与接触战。];B[ee]C[第 1 手：黑棋占「天元」正中央！在 9 路小棋盘，天元能同时照顾四个方向。];W[ge]C[第 2 手：白棋守在三路边线，瞄准右边地盘。];B[ce]C[第 3 手：黑棋左右呼应，把左边和中央连成一片。];W[fc]C[第 4 手：白棋占右上星位，准备围出右上角大空。];B[cg]C[第 5 手：黑棋守住左下星位，双方先抢「大场」。];W[ec]C[第 6 手：白棋向左上扩张，压迫黑棋。];B[dc]C[第 7 手：黑棋勇敢挡住，不让白棋轻松围空！];W[dd]C[第 8 手：白棋反扳，双方进入精彩的中盘接触战！];B[cd]C[第 9 手：黑棋稳稳长出，同时瞄准白棋的断点。];W[de]C[第 10 手：白棋切断！记住：接触战里「切断」和「连接」最关键。];B[df]C[第 11 手：黑棋立刻反打，把白棋分断并巩固左下。];W[ed]C[第 12 手：白棋粘上补断，棋形更厚实。];B[ef]C[第 13 手：黑棋连片，中央黑龙气数充足！];W[fe]C[第 14 手：白棋同样补强自身断点。];B[fg]C[第 15 手：黑棋向右下扩张，开始圈定下方地盘。];W[gg]C[第 16 手：白棋挡住，守卫右侧边界。];B[gh]C[第 17 手：黑棋二路扳，漂亮的「收官」手筋！];W[hg]C[第 18 手：白棋挡住不让黑棋钻进右角。];B[fh]C[第 19 手：黑棋稳健粘回，下方成空！];W[gf]C[第 20 手：白棋补强右边，双方边界逐渐清晰。];B[db]C[第 21 手：黑棋上方二路扳，抢占最后的大官子！];W[eb]C[第 22 手：白棋挡住，一盘教科书级的 9 路攻防定型啦！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]C[Welcome to a 9×9 guided match! Step through each move to learn opening balance and fighting.];B[ee]C[Move 1: Black claims Tengen (center)! On 9×9, the center radiates influence in all four directions.];W[ge]C[Move 2: White stakes out the right side on the 3rd line.];B[ce]C[Move 3: Black balances on the left, linking with the center stone.];W[fc]C[Move 4: White claims the upper-right star point to build corner territory.];B[cg]C[Move 5: Black guards the lower-left star point — claim big corners first!];W[ec]C[Move 6: White expands along the top edge.];B[dc]C[Move 7: Black blocks bravely to stop White from making a huge top territory.];W[dd]C[Move 8: White counter-pushes — time for an exciting local fight!];B[cd]C[Move 9: Black extends calmly while eyeing White's cutting point.];W[de]C[Move 10: White cuts! Cutting and connecting are the heart of middle-game fighting.];B[df]C[Move 11: Black fights back immediately, securing the lower-left.];W[ed]C[Move 12: White connects solidly to protect its shape.];B[ef]C[Move 13: Black links up with plenty of liberties!];W[fe]C[Move 14: White reinforces its own cutting point too.];B[fg]C[Move 15: Black expands across the bottom to enclose territory.];W[gg]C[Move 16: White blocks to defend the right side.];B[gh]C[Move 17: Black plays a sharp second-line hane — classic endgame technique!];W[hg]C[Move 18: White blocks so Black cannot slip into the right corner.];B[fh]C[Move 19: Black connects cleanly, sealing bottom territory.];W[gf]C[Move 20: White reinforces the right boundary.];B[db]C[Move 21: Black claims the last big endgame hane at the top!];W[eb]C[Move 22: White blocks — textbook 9×9 balance!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "天元开局", labelEn: "Tengen"),
                AcademyHighlight(moveIndex: 10, labelZh: "中盘切断", labelEn: "Middle Cut"),
                AcademyHighlight(moveIndex: 17, labelZh: "二路收官扳", labelEn: "Endgame Hane")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 10,
                promptZh: "白棋第 10 手刚刚切断！轮到黑棋反击，既要保护左下又要反打白子，你下哪里？",
                promptEn: "White just cut on Move 10! How does Black counter-attack while protecting the bottom-left?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-ear-reddening",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111104")!,
            hall: .masterpieces,
            level: .intermediate,
            rankTag: "进阶 12K",
            eraOrTagZh: "1846 · 325手完整原谱",
            eraOrTagEn: "1846 · Full 325 Moves",
            titleZh: "本因坊秀策《耳赤之局》",
            titleEn: "Shusaku's Ear-Reddening Game",
            hookZh: "完整收录 325 手历史原谱！17 岁天才少年秀策对阵大前辈幻庵因硕，第 127 手中腹一尖照耀全盘，令对手双耳通红！",
            hookEn: "Complete 325-move authentic record! 17-year-old Shusaku's immortal Move 127 turned Grandmaster Inseki's ears bright red!",
            blackPlayerZh: "本因坊秀策（黑）",
            blackPlayerEn: "Honinbo Shusaku (Black)",
            whitePlayerZh: "井上幻庵因硕（白）",
            whitePlayerEn: "Inoue Gennan Inseki (White)",
            resultString: "B+2",
            boardSize: 19,
            komi: 0,
            sgfZh: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.earReddening,
                intro: "【完整 325 手原谱】1846年7月21日，17岁的桑原秀策执黑迎战大前辈井上幻庵因硕。你可以逐手研究秀策如何从布局的「秀策小尖」、应对大雪崩新型，一直下到震惊千古的第 127 手「耳赤之妙手」与精密官子！",
                notes: [
                    1: "第 1 手（R16）：黑占右上小目，开启经典的「秀策流」序幕。",
                    2: "第 2 手（D17）：白占左上小目，针锋相对。",
                    3: "第 3 手（Q3）：黑占右下小目，稳扎稳打先拿实地。",
                    4: "第 4 手（P17）：白棋小飞挂右上角，主动挑起节奏。",
                    5: "第 5 手（C4）：黑棋脱先占左下小目！大局观第一课：空角比局部应手更大。",
                    6: "第 6 手（C14）：白棋大飞守左上角。",
                    7: "第 7 手（E4）：黑棋大飞守左下角，阵形对称稳固。",
                    8: "第 8 手（R5）：白棋高挂右下角，准备祭出精心研究的「大雪崩」新型！",
                    9: "第 9 手（Q15）：著名的「秀策小尖」！扎实、厚实、几乎没有破绽。",
                    10: "第 10 手（O4）：白棋下方夹击，大雪崩定式激战一触即发！",
                    33: "第 33 手（R2）：右下角进入复杂劫争，幻庵因硕祭出秘密武器，初期一度占优。",
                    61: "第 61 手（K6）：右下大规模定型后，黑棋转向中腹，开始漫长而冷静的追赶。",
                    127: "第 127 手（K11）——千古绝唱「耳赤之妙手」！这一手轻轻一尖，同时限制白棋左方大空、扩张黑棋上方厚势、兼顾中央联络。旁观的一位医生虽不懂棋，却看见幻庵因硕双耳瞬间涨红，断定黑棋必胜！",
                    180: "第 180 手（M13）：中盘激战进入白热化，双方在中腹与上方展开寸土必争的劫争。",
                    250: "第 250 手（D11）：官子阶段秀策滴水不漏，牢牢守住微弱优势。",
                    325: "第 325 手（T2）：终局！黑棋以 2 目险胜，成就围棋史上最脍炙人口的传奇名局！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.earReddening,
                intro: "Full 325-move historical game record (July 21, 1846)! Study every single move from Shusaku's Kosumi through the Taisha fight to the immortal Move 127 Ear-Reddening Move and endgame.",
                notes: [
                    1: "Move 1 (R16): Black takes the upper-right 3-4 Komoku — hallmark of the Shusaku Opening.",
                    5: "Move 5 (C4): Tenuki! Claiming the last empty corner is bigger than answering locally.",
                    9: "Move 9 (Q15): The famous 'Shusaku Kosumi' (diagonal) — solid, balanced, and flexible.",
                    10: "Move 10 (O4): White pincers, launching a fierce early Taisha/Avalanche battle.",
                    61: "Move 61 (K6): After the huge lower-right exchange, Shusaku stays calm and builds central influence.",
                    127: "Move 127 (K11) — THE EAR-REDDENING MOVE! One serene central play that simultaneously reduces White's left, expands Black's top, and unites the whole board. A watching doctor saw Inseki's ears turn bright red and knew Black had won!",
                    325: "Move 325 (T2): Game over — Shusaku wins by 2 points in Go's most famous classical masterpiece!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 5, labelZh: "脱先占空角", labelEn: "Tenuki Corner"),
                AcademyHighlight(moveIndex: 9, labelZh: "秀策小尖", labelEn: "Shusaku Kosumi"),
                AcademyHighlight(moveIndex: 127, labelZh: "耳赤之妙手", labelEn: "Ear-Reddening Move"),
                AcademyHighlight(moveIndex: 325, labelZh: "终局两目胜", labelEn: "Final B+2")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 126,
                promptZh: "实战第 127 手！白棋刚在下方收兵，秀策在中腹点出照耀全盘、令对手双耳通红的「耳赤之妙手」——你能找到这颗传奇点位吗？",
                promptEn: "Real Move 127! Can you find Shusaku's immortal central 'Ear-Reddening Move' that radiates across the whole board?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-new-fuseki",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111105")!,
            hall: .masterpieces,
            level: .advanced,
            rankTag: "高阶 5K",
            eraOrTagZh: "1933 · 252手完整原谱",
            eraOrTagEn: "1933 · Full 252 Moves",
            titleZh: "吴清源《三三·星·天元》",
            titleEn: "Go Seigen: 3-3, Star & Tengen",
            hookZh: "完整收录 252 手世纪名局！19 岁吴清源挑战日本最后一位世袭名人秀哉，开局打破 300 年禁忌，与秀哉第 160 手妙手交相辉映！",
            hookEn: "Full 252-move Game of the Century! 19-year-old Go Seigen's 3-3, Star & Tengen opening vs Honinbo Shusai's famous Move 160!",
            blackPlayerZh: "吴清源五段（黑）",
            blackPlayerEn: "Go Seigen 5p (Black)",
            whitePlayerZh: "本因坊秀哉名人（白）",
            whitePlayerEn: "Honinbo Shusai Meijin (White)",
            resultString: "W+2",
            boardSize: 19,
            komi: 0,
            sgfZh: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.newFuseki,
                intro: "【完整 252 手原谱】1933年10月16日至1934年1月29日，历时三个多月、14次打挂的世纪名局！19岁的吴清源执黑迎战本因坊秀哉名人，前三手「三三·星·天元」宣告现代「新布局时代」诞生。",
                notes: [
                    1: "第 1 手（R17）：黑占右上「三三」！在当时三三被视为本因坊门派禁手，吴清源第一手就打破三百年禁忌！",
                    2: "第 2 手（C16）：秀哉名人冷静占左上小目。",
                    3: "第 3 手（D4）：黑占左下「星位」！",
                    4: "第 4 手（Q3）：白占右下小目。",
                    5: "第 5 手（K10）：惊世骇俗的「天元」！三三、星位、天元排成斜线，震动整个日本棋坛！",
                    6: "第 6 手（Q16）：秀哉立即在右上镇压三三，展开激烈攻防。",
                    41: "第 41 手（P7）：黑棋灵活腾挪，处处与天元遥相呼应，新布局威力初显！",
                    100: "第 100 手（B4）：双方在左边与右下展开大规模攻杀，吴清源中盘一度明显占优。",
                    160: "第 160 手（H8）——闻名棋史的「白 160 妙手」！经过多次打挂后，秀哉阵营在中腹点出这一石破天惊的妙手，巧妙联络白棋大龙并反攻黑棋，瞬间逆转局势！",
                    252: "第 252 手（M9）：历时百日终局，白棋以 2 目险胜。此局虽败犹荣，彻底开启了现代围棋新纪元！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.newFuseki,
                intro: "Full 252-move Game of the Century (Oct 1933 – Jan 1934)! 19-year-old Go Seigen shattered 300 years of tradition against the last hereditary Meijin, Honinbo Shusai.",
                notes: [
                    1: "Move 1 (R17): The 3-3 point! Taboo for centuries, Go Seigen played it on Move 1!",
                    3: "Move 3 (D4): Lower-left Star Point!",
                    5: "Move 5 (K10): TENGEN! 3-3, Star Point, and Tengen — the birth of the New Fuseki!",
                    100: "Move 100 (B4): Go Seigen commands the middle game with fluid, modern speed.",
                    160: "Move 160 (H8): The legendary White 160 tesuji — a stunning central blow that turned the entire game around for Shusai!",
                    252: "Move 252 (M9): After 14 sessions over 3 months, White wins by 2 points — forever changing Go history."
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "打破禁忌：三三", labelEn: "Taboo 3-3"),
                AcademyHighlight(moveIndex: 5, labelZh: "惊世天元", labelEn: "Shocking Tengen"),
                AcademyHighlight(moveIndex: 160, labelZh: "秀哉160妙手", labelEn: "Famous Move 160"),
                AcademyHighlight(moveIndex: 252, labelZh: "终局两目胜负", labelEn: "Final W+2")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "黑棋已经占了「三三」和「星位」，第 5 手吴清源下出了震惊全世界的创造性一手——你知道下在棋盘哪里吗？",
                promptEn: "Black has played 3-3 and Star Point. Where did Go Seigen play Move 5 to shock the entire Go world?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-alphago-g4",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111106")!,
            hall: .masterpieces,
            level: .dan,
            rankTag: "段位 1D+",
            eraOrTagZh: "2016 · 180手完整原谱",
            eraOrTagEn: "2016 · Full 180 Moves",
            titleZh: "AlphaGo vs 李世石 · 第78手神之一手",
            titleEn: "AlphaGo vs Lee Sedol: Game 4",
            hookZh: "完整收录 180 手历史原谱！0 比 3 绝境之下，李世石第 78 手在中央凌空一「挖」，令最强 AI 陷入混乱，赢下人类唯一一胜！",
            hookEn: "Complete 180-move record! Down 0–3, Lee Sedol's immortal Move 78 Wedge stunned AlphaGo for humanity's lone victory!",
            blackPlayerZh: "AlphaGo（黑）",
            blackPlayerEn: "AlphaGo (Black)",
            whitePlayerZh: "李世石九段（白）",
            whitePlayerEn: "Lee Sedol 9p (White)",
            resultString: "W+R",
            boardSize: 19,
            komi: 7.5,
            sgfZh: annotatedSGF(
                komi: 7.5,
                rawMoves: FullGameMoves.alphaGoLeeG4,
                intro: "【完整 180 手原谱】2016年3月13日首尔，人机五番棋第四局。前面已 0:3 落后的李世石背水一战，用最具人类想象力的第 78 手「神之一手」撕开 AlphaGo 的天罗地网！",
                notes: [
                    1: "第 1 手（Q16）：AlphaGo 执黑占右上星位。",
                    2: "第 2 手（D4）：李世石执白占左下星位。",
                    6: "第 6 手（P3）：面对黑 5 高挂，李世石直接靠起求战，主动挑起复杂局面！",
                    28: "第 28 手（D10）：双方在左边展开接触战，AlphaGo 构建起厚实的中腹大模样。",
                    50: "第 50 手（P11）：李世石打入右边并向中腹突围，形势一度非常危急。",
                    78: "第 78 手（L11）——永载史册的「神之一手」！在黑棋铁桶般的中腹大网里，李世石凌空一「挖」！这手棋在 AlphaGo 的计算里概率不到万分之一，彻底打乱了 AI 的局势判断！",
                    87: "第 87 手（T10）：受第 78 手冲击，AlphaGo 价值网络出现严重误判，开始下出令人震惊的「昏招」。",
                    102: "第 102 手（G12）：白棋稳稳掌控中央与左边，人类冠军已确立胜势！",
                    180: "第 180 手（M15）：AlphaGo 中盘认输！人类棋手在正式赛场上赢得了对巅峰 AlphaGo 唯一的一场胜利！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 7.5,
                rawMoves: FullGameMoves.alphaGoLeeG4,
                intro: "Full 180-move official record (Seoul, March 13, 2016)! Down 0–3, Lee Sedol unleashed Move 78 — 'God's Move' — to defeat AlphaGo.",
                notes: [
                    1: "Move 1 (Q16): AlphaGo opens at the upper-right Star Point.",
                    6: "Move 6 (P3): Lee Sedol attaches directly to spark a complex fighting game.",
                    50: "Move 50 (P11): AlphaGo builds a daunting central framework while Lee looks for counterplay.",
                    78: "Move 78 (L11) — GOD'S MOVE! A breathtaking central wedge that AlphaGo gave less than a 1-in-10,000 chance of being played, shattering the AI's evaluation!",
                    87: "Move 87 (T10): Disoriented by Move 78, AlphaGo begins making uncharacteristic blunders.",
                    180: "Move 180 (M15): AlphaGo resigns! Lee Sedol claims humanity's unforgettable victory!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 6, labelZh: "李世石靠起求战", labelEn: "Fighting Attach"),
                AcademyHighlight(moveIndex: 78, labelZh: "第78手神之一手", labelEn: "Move 78 Wedge"),
                AcademyHighlight(moveIndex: 87, labelZh: "AI 陷入混乱", labelEn: "AI Collapse"),
                AcademyHighlight(moveIndex: 180, labelZh: "人类唯一胜利", labelEn: "Humanity Wins")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 77,
                promptZh: "历史性的第 78 手来了！面对 AlphaGo 铜墙铁壁般的中腹黑网，李世石凌空一「挖」震惊世界——请点出「神之一手」！",
                promptEn: "The historic Move 78! Can you find Lee Sedol's immortal central wedge inside AlphaGo's framework?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-nie-arena",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111107")!,
            hall: .masterpieces,
            level: .advanced,
            rankTag: "高阶 4K",
            eraOrTagZh: "1985 · 245手完整原谱",
            eraOrTagEn: "1985 · Full 245 Moves",
            titleZh: "聂卫平 · 首届中日擂台赛决胜局",
            titleEn: "Nie Weiping: 1985 Supermatch Final",
            hookZh: "完整收录 245 手热血决战！1985 年北京体育馆，主将聂卫平力克日本「名誉棋圣」藤泽秀行，为中国捧回首届擂台赛冠军，掀起全国围棋热潮！",
            hookEn: "Full 245-move deciding game! On Nov 20, 1985 in Beijing, Nie Weiping defeated Fujisawa Shuko to win the historic 1st China–Japan Supermatch!",
            blackPlayerZh: "聂卫平九段（黑）",
            blackPlayerEn: "Nie Weiping 9p (Black)",
            whitePlayerZh: "藤泽秀行九段（白）",
            whitePlayerEn: "Fujisawa Shuko 9p (White)",
            resultString: "B+3.5",
            boardSize: 19,
            komi: 5.5,
            sgfZh: annotatedSGF(
                komi: 5.5,
                rawMoves: FullGameMoves.nieFujisawa1985,
                intro: "【完整 245 手原谱】1985年11月20日北京体育馆，第一届中日围棋擂台赛最终决胜局！此前聂卫平已连胜小林光一、加藤正夫两位日本超一流，本局再克日本主将藤泽秀行，铸就「棋圣」传奇！",
                notes: [
                    1: "第 1 手（R16）：聂卫平执黑占右上小目。",
                    2: "第 2 手（C17）：藤泽秀行执白占左上三三，展现华丽独特的棋风。",
                    5: "第 5 手（P17）：黑棋小飞守右上「无忧角」，稳健大气！",
                    12: "第 12 手（R11）：双方在右边与右下展开宏大布局，两位大局观宗师针锋相对。",
                    50: "第 50 手（K4）：前五十手布局堪称经典，聂卫平以深厚的大局观牢牢把控全盘节奏。",
                    100: "第 100 手（K15）：中盘激战，双方在上方与中腹展开惊心动魄的攻防转换。",
                    180: "第 180 手（S15）：进入精细官子阶段，黑棋牢牢守住实地优势。",
                    245: "第 245 手（Q7）：终局！黑棋以 3.5 目（中国规则一又四分之三子）获胜，中国队以 8:7 奇迹般夺得首届中日围棋擂台赛冠军！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 5.5,
                rawMoves: FullGameMoves.nieFujisawa1985,
                intro: "Full 245-move decider of the 1st China–Japan Supermatch (Nov 20, 1985, Beijing)! Nie Weiping beat Fujisawa Shuko to ignite Go fever across China.",
                notes: [
                    1: "Move 1 (R16): Nie Weiping opens with the upper-right Komoku.",
                    2: "Move 2 (C17): Fujisawa Shuko plays an unconventional early 3-3.",
                    5: "Move 5 (P17): Solid Knight's enclosure in the upper-right.",
                    50: "Move 50 (K4): Classic clash of two grandmasters renowned for their first-50-move opening brilliance.",
                    100: "Move 100 (K15): Fierce middle-game maneuvering across the top and center.",
                    245: "Move 245 (Q7): Black wins by 3.5 points — securing a historic 8–7 team victory for China!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 5, labelZh: "无忧角守势", labelEn: "Solid Enclosure"),
                AcademyHighlight(moveIndex: 50, labelZh: "前五十手布局", labelEn: "Opening Mastery"),
                AcademyHighlight(moveIndex: 100, labelZh: "中腹大决战", labelEn: "Central Clash"),
                AcademyHighlight(moveIndex: 245, labelZh: "擂台赛夺冠", labelEn: "Historic Victory")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "四角各占两角后，聂卫平第 5 手在右上角抢先「小飞守角」（无忧角），先巩固根据地——请点出这一手！",
                promptEn: "All four corners are claimed! Where does Nie Weiping play Move 5 to enclose the upper-right corner solidly?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-blood-vomiting",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111117")!,
            hall: .masterpieces,
            level: .dan,
            rankTag: "段位 1D+",
            eraOrTagZh: "1835 · 246手完整原谱",
            eraOrTagEn: "1835 · Full 246 Moves",
            titleZh: "本因坊丈和《吐血之局》",
            titleEn: "Honinbo Jowa: Blood-Vomiting Game",
            hookZh: "完整收录 246 手古棋巅峰！井上门下天才赤星因彻摆出新招挑战本因坊丈和，丈和以流传千古的「三妙手」（第 68、70、78 手）惊天逆转！",
            hookEn: "Full 246-move classical epic! Honinbo Jowa unleashed his immortal 'Three Brilliant Moves' (68, 70, 78) to defeat challenger Akaboshi Intetsu!",
            blackPlayerZh: "赤星因彻七段（黑）",
            blackPlayerEn: "Akaboshi Intetsu 7d (Black)",
            whitePlayerZh: "本因坊丈和名人（白）",
            whitePlayerEn: "Honinbo Jowa Meijin (White)",
            resultString: "W+R",
            boardSize: 19,
            komi: 0,
            sgfZh: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.jowaBloodVomiting,
                intro: "【完整 246 手原谱】1835年天保六年，日本围棋史上最惨烈、最富戏剧性的对决！赤星因彻携门派秘招挑战「力战之神」本因坊丈和，历时四天，丈和连下三手鬼神莫测的妙手反败为胜！",
                notes: [
                    1: "第 1 手（C4）：赤星因彻执黑小目开局，志在必得。",
                    5: "第 5 手（P17）：黑棋守角，布局紧凑严密。",
                    50: "第 50 手（C16）：前五十手黑棋凭借精心准备的新招取得明显优势，丈和陷入绝境。",
                    68: "第 68 手（B11）——「丈和三妙手」第一手！在左边看似绝望的局面下，白棋于二路凌空一夹，鬼手惊现！",
                    70: "第 70 手（E12）——「丈和三妙手」第二手！紧接着中央一靠，声东击西，让黑棋首尾不能相顾！",
                    78: "第 78 手（Q9）——「丈和三妙手」第三手！右边凌空一碰，全局如行云流水般瞬间翻转！",
                    150: "第 150 手（G16）：丈和步步紧逼，展现出「古今第一力战家」的恐怖算路。",
                    246: "第 246 手（S15）：赤星因彻耗尽心血投子认负。此局三妙手成为后世棋手必学的中盘腾挪教科书！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.jowaBloodVomiting,
                intro: "Full 246-move record (1835)! One of Go history's most dramatic battles, famed for Honinbo Jowa's legendary 'Three Brilliant Moves' (68, 70, 78).",
                notes: [
                    1: "Move 1 (C4): Challenger Akaboshi Intetsu opens sharply as Black.",
                    50: "Move 50 (C16): Intetsu's secret opening preparation puts Jowa under severe pressure.",
                    68: "Move 68 (B11): Brilliant Move #1! A jaw-dropping 2nd-line clamp on the left.",
                    70: "Move 70 (E12): Brilliant Move #2! A razor-sharp central attachment linking the fight.",
                    78: "Move 78 (Q9): Brilliant Move #3! A dynamic right-side touch that flips the entire game!",
                    246: "Move 246 (S15): White wins by resignation — an immortal masterpiece of fighting tesuji!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 68, labelZh: "三妙手之一", labelEn: "Brilliant Move #1"),
                AcademyHighlight(moveIndex: 70, labelZh: "三妙手之二", labelEn: "Brilliant Move #2"),
                AcademyHighlight(moveIndex: 78, labelZh: "三妙手之三", labelEn: "Brilliant Move #3"),
                AcademyHighlight(moveIndex: 246, labelZh: "终局力战完胜", labelEn: "Final W+R")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 67,
                promptZh: "第 68 手！面对黑棋严密包围，本因坊丈和在左边二路下出流传百世的「三妙手」第一手——请点出这一妙手！",
                promptEn: "Move 68! Find Honinbo Jowa's first of the legendary 'Three Brilliant Moves' on the left side!"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-dosaku-1683",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111118")!,
            hall: .masterpieces,
            level: .intermediate,
            rankTag: "进阶 10K",
            eraOrTagZh: "1683 · 258手完整原谱",
            eraOrTagEn: "1683 · Full 258 Moves",
            titleZh: "棋圣本因坊道策 · 生涯杰作",
            titleEn: "Kisei Honinbo Dosaku's Masterpiece",
            hookZh: "完整收录 258 手「前圣」名局！被誉为现代围棋理论之父的本因坊道策，用轻灵弃子与全局手割思想，上演 15 目完胜教科书！",
            hookEn: "Full 258-move Castle Game (1683)! Honinbo Dosaku, founder of modern Go theory, demonstrates sublime light shape and whole-board harmony!",
            blackPlayerZh: "安井算哲七段（黑）",
            blackPlayerEn: "Yasui Santetsu II 7p (Black)",
            whitePlayerZh: "本因坊道策名人（白）",
            whitePlayerEn: "Honinbo Dosaku Meijin (White)",
            resultString: "W+15",
            boardSize: 19,
            komi: 0,
            sgfZh: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.dosaku1683,
                intro: "【完整 258 手原谱】1683年御城棋名局！本因坊道策创立了现代「手割」分析法与全局平衡理论，被尊为「前圣」。看他执白无贴目如何以行云流水的弃子整形完胜强敌！",
                notes: [
                    1: "第 1 手（R16）：安井算哲执黑占右上小目。",
                    2: "第 2 手（P17）：道策直接小飞挂角，节奏明快，毫不停滞！",
                    10: "第 10 手（R4）：白棋占右下小目，全盘布局均衡舒展。",
                    30: "第 30 手（R12）：道策在右边轻灵腾挪，宁舍小子、必争大局先手。",
                    80: "第 80 手（H15）：中盘作战中道策展现惊人的「手割」效率，每一颗白子都发挥最大价值。",
                    160: "第 160 手（M2）：白棋在四面八方都抢占了先机，优势不断扩大。",
                    258: "第 258 手（F2）：终局白棋大胜 15 目！在无贴目的时代执白完胜，堪称古棋大局观巅峰！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 0,
                rawMoves: FullGameMoves.dosaku1683,
                intro: "Full 258-move Castle Game (Jan 17, 1683)! Honinbo Dosaku — revered as the father of modern Go theory — wins by 15 points with White and zero komi!",
                notes: [
                    1: "Move 1 (R16): Yasui Santetsu opens with upper-right Komoku.",
                    2: "Move 2 (P17): Dosaku immediately approaches — fast, modern, and proactive!",
                    30: "Move 30 (R12): Dosaku plays light, flexible sabaki, trading small stones for whole-board initiative.",
                    80: "Move 80 (H15): Peak efficiency — every white stone works harmoniously across the board.",
                    258: "Move 258 (F2): White wins by 15 points with zero komi — a timeless lesson in balance!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 2, labelZh: "积极挂角", labelEn: "Fast Approach"),
                AcademyHighlight(moveIndex: 30, labelZh: "轻灵弃子整形", labelEn: "Light Sabaki"),
                AcademyHighlight(moveIndex: 80, labelZh: "手割效率巅峰", labelEn: "Peak Efficiency"),
                AcademyHighlight(moveIndex: 258, labelZh: "无贴目大胜", labelEn: "W+15 Masterclass")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 1,
                promptZh: "黑棋第 1 手占右上小目后，道策没有按常规占空角，而是第 2 手直接「小飞挂角」抢攻——请点出这一手！",
                promptEn: "After Black's Move 1 Komoku, Dosaku immediately approaches on Move 2 with a Knight's Move — where is it?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-takemiya-cosmic",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111119")!,
            hall: .masterpieces,
            level: .intermediate,
            rankTag: "进阶 10K",
            eraOrTagZh: "1989 · 209手完整原谱",
            eraOrTagEn: "1989 · Full 209 Moves",
            titleZh: "武宫正树《宇宙流》富士通杯夺冠局",
            titleEn: "Takemiya's Cosmic Style World Final",
            hookZh: "完整收录 209 手世界冠军决赛！武宫正树摆出最纯正的「三连星宇宙流」迎战林海峰，亲眼看大师如何把中腹围成浩瀚星海！",
            hookEn: "Full 209-move 2nd Fujitsu Cup Final (1989)! Watch Takemiya Masaki unleash pure Sanrensei Cosmic Style to win the world title!",
            blackPlayerZh: "武宫正树九段（黑）",
            blackPlayerEn: "Takemiya Masaki 9p (Black)",
            whitePlayerZh: "林海峰九段（白）",
            whitePlayerEn: "Rin Kaiho 9p (White)",
            resultString: "B+R",
            boardSize: 19,
            komi: 5.5,
            sgfZh: annotatedSGF(
                komi: 5.5,
                rawMoves: FullGameMoves.takemiyaCosmic1989,
                intro: "【完整 209 手原谱】1989年8月5日第二届富士通杯世界围棋锦标赛决赛！武宫正树执黑摆出招牌「三连星宇宙流」，与「二枚腰」林海峰展开外势与实地的终极碰撞，最适合新手体会中腹大模样的魅力！",
                notes: [
                    1: "第 1 手（Q16）：黑占右上星位，宇宙流启航！",
                    3: "第 3 手（Q4）：黑占右下星位，双星闪耀。",
                    5: "第 5 手（Q10）：正中右边星位！经典「三连星宇宙流」在世界大赛决赛堂堂登场！",
                    7: "第 7 手（Q14）：黑棋小飞应，把右边织成一片浩瀚的厚势星海。",
                    9: "第 9 手（C10）：左边星位！武宫正树把「大模样」美学发挥到极致。",
                    40: "第 40 手（F17）：面对白棋掏空，黑棋毫不吝惜边角，一心经营气吞山河的中腹大空！",
                    100: "第 100 手（S5）：白棋深入黑棋阵地求活，黑棋趁势筑起铜墙铁壁般的中央大模样！",
                    209: "第 209 手（R7）：黑棋中盘完胜！武宫正树蝉联世界冠军，宇宙流名扬天下！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 5.5,
                rawMoves: FullGameMoves.takemiyaCosmic1989,
                intro: "Full 209-move 2nd Fujitsu Cup World Final (Aug 5, 1989)! Pure Sanrensei Cosmic Style in action as Takemiya Masaki builds a breathtaking central moyo.",
                notes: [
                    1: "Move 1 (Q16): Upper-right Star Point — the Cosmic Style begins!",
                    5: "Move 5 (Q10): SANRENSEI! Three Star Points aligned on the right in a World Championship Final!",
                    9: "Move 9 (C10): Left-side Star Point — embracing the entire center of the board.",
                    100: "Move 100 (S5): White fights for corner cash while Black seals off a gigantic central empire!",
                    209: "Move 209 (R7): Black wins by resignation — Takemiya captures his 2nd straight World Title!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 5, labelZh: "三连星宇宙流", labelEn: "Sanrensei Formed"),
                AcademyHighlight(moveIndex: 9, labelZh: "左右星位呼应", labelEn: "Cosmic Balance"),
                AcademyHighlight(moveIndex: 100, labelZh: "中腹大模样", labelEn: "Vast Center Moyo"),
                AcademyHighlight(moveIndex: 209, labelZh: "蝉联世界冠军", labelEn: "World Title B+R")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "世界大赛决赛第 5 手！右上和右下星位已就位，请点出武宫正树最著名的「三连星」第三颗星位！",
                promptEn: "World Championship Final Move 5! Light up the middle right-side Star Point to complete Takemiya's Sanrensei!"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-lee-changho-fujitsu",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111120")!,
            hall: .masterpieces,
            level: .advanced,
            rankTag: "高阶 5K",
            eraOrTagZh: "1998 · 275手完整原谱",
            eraOrTagEn: "1998 · Full 275 Moves",
            titleZh: "李昌镐《石佛神算》富士通杯决赛",
            titleEn: "Lee Chang-ho: Stone Buddha's Endgame",
            hookZh: "完整收录 275 手经典决赛！也是动漫《棋魂》中致敬的名局！看「石佛」李昌镐如何不急不躁，凭厚实步调与精准官子半目级逆转常昊！",
            hookEn: "Full 275-move 11th Fujitsu Cup Final (1998) — featured in Hikaru no Go! Watch the 'Stone Buddha' win by 1.5 points with ice-cold endgame mastery!",
            blackPlayerZh: "常昊八段（黑）",
            blackPlayerEn: "Chang Hao 8p (Black)",
            whitePlayerZh: "李昌镐九段（白）",
            whitePlayerEn: "Lee Chang-ho 9p (White)",
            resultString: "W+1.5",
            boardSize: 19,
            komi: 5.5,
            sgfZh: annotatedSGF(
                komi: 5.5,
                rawMoves: FullGameMoves.leeChangho1998,
                intro: "【完整 275 手原谱】1998年8月1日第11届富士通杯决赛（亦被《棋魂》漫画收录致敬）。年仅23岁的「石佛」李昌镐对阵中国新锐常昊，展现「不战而屈人之兵」的极致厚味与官子神算！",
                notes: [
                    1: "第 1 手（Q16）：常昊执黑星位开局，充满青春锐气。",
                    4: "第 4 手（D16）：李昌镐双星对峙，稳如磐石。",
                    10: "第 10 手（E17）：李昌镐极少贪图小利，处处追求棋形厚实、毫无弱点。",
                    68: "第 68 手（R18）：双方在右上展开细腻定型，局势胶着难分。",
                    140: "第 140 手（F15）：中盘李昌镐冷静把控全局厚薄，将胜负平稳导向自己最擅长的官子战。",
                    200: "第 200 手（O8）：进入「神算子」李昌镐的官子表演时间！每一手收官都精确到半目。",
                    275: "第 275 手（E8）：终局！白棋以 1.5 目微弱优势精准撞线，这就是令人叹服的「石佛赢棋美学」！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 5.5,
                rawMoves: FullGameMoves.leeChangho1998,
                intro: "Full 275-move 11th Fujitsu Cup Final (Aug 1, 1998), famously referenced in Hikaru no Go! Study Lee Chang-ho's calm thickness and surgical endgame.",
                notes: [
                    1: "Move 1 (Q16): Chang Hao opens briskly as Black.",
                    10: "Move 10 (E17): Lee Chang-ho prioritizes solid, unassailable shape over flashy tactics.",
                    140: "Move 140 (F15): The Stone Buddha calmly steers the game into his legendary endgame arena.",
                    200: "Move 200 (O8): Surgical yose — every endgame move is calculated to half-point precision.",
                    275: "Move 275 (E8): White wins by 1.5 points — peak Lee Chang-ho control!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 10, labelZh: "厚实开局", labelEn: "Solid Opening"),
                AcademyHighlight(moveIndex: 140, labelZh: "平稳导入官子", labelEn: "Endgame Transition"),
                AcademyHighlight(moveIndex: 200, labelZh: "石佛神算收官", labelEn: "Stone Buddha Yose"),
                AcademyHighlight(moveIndex: 275, labelZh: "精准1.5目胜", labelEn: "Exact W+1.5")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 5,
                promptZh: "面对黑 5 挂左下角，李昌镐第 6 手在左边一间高关守角，既护角又兼顾左边发展——请点出这一稳健好手！",
                promptEn: "Black approached the lower-left on Move 5. Where does Lee Chang-ho play Move 6 to guard the corner calmly?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-changhao-ing",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111121")!,
            hall: .masterpieces,
            level: .advanced,
            rankTag: "高阶 3K",
            eraOrTagZh: "2005 · 314手完整原谱",
            eraOrTagEn: "2005 · Full 314 Moves",
            titleZh: "常昊 · 应氏杯世界冠军决胜局",
            titleEn: "Chang Hao: 2005 Ing Cup Title Game",
            hookZh: "完整收录 314 手史诗夺冠局！16 年等待终于圆梦，常昊在北京力克韩国「毒蛇」崔哲瀚，为中国捧回第一座「围棋奥运会」应氏杯冠军奖杯！",
            hookEn: "Full 314-move epic! On March 5, 2005, Chang Hao defeated Choi Cheol-han to win China's first-ever Ing Cup — the 'Olympics of Go'!",
            blackPlayerZh: "常昊九段（黑）",
            blackPlayerEn: "Chang Hao 9p (Black)",
            whitePlayerZh: "崔哲瀚九段（白）",
            whitePlayerEn: "Choi Cheol-han 9p (White)",
            resultString: "B+3",
            boardSize: 19,
            komi: 8.0,
            sgfZh: annotatedSGF(
                komi: 8.0,
                rawMoves: FullGameMoves.changHaoIng2005,
                intro: "【完整 314 手原谱】2005年3月5日第五届应氏杯决赛第四局！应氏杯每四年举办一次，被称为「围棋奥运会」。常昊在本局顶住强攻、收官滴水不漏，以 3 点优势勇夺中国首座应氏杯！",
                notes: [
                    1: "第 1 手（Q16）：常昊执黑星位开局，心态沉稳。",
                    5: "第 5 手（E3）：黑棋小飞挂左下，主动展开布局。",
                    21: "第 21 手（C9）：左边爆发激烈接触战，崔哲瀚以凶狠力战著称，常昊寸步不让！",
                    80: "第 80 手（M16）：中盘大战波澜壮阔，双方在全盘四个角落与中腹来回拉锯。",
                    160: "第 160 手（J9）：黑棋在中腹厚实定型，逐渐建立起胜势。",
                    250: "第 250 手（L11）：漫长而精细的官子拉锯战，每一目都关乎冠军归属！",
                    314: "第 314 手（Q11）：314 手终局！常昊黑棋胜 3 点，圆梦世界冠军，令无数中国棋迷热泪盈眶！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 8.0,
                rawMoves: FullGameMoves.changHaoIng2005,
                intro: "Full 314-move 5th Ing Cup Final Game 4 (March 5, 2005)! Chang Hao outlasts fierce fighter Choi Cheol-han to bring home China's first Ing Cup trophy.",
                notes: [
                    1: "Move 1 (Q16): Chang Hao opens calmly in the deciding title match.",
                    21: "Move 21 (C9): Sparks fly early on the left against Choi Cheol-han's ferocious fighting style.",
                    160: "Move 160 (J9): Black consolidates the center and takes a steady lead.",
                    314: "Move 314 (Q11): After an epic 314-move battle, Chang Hao wins by 3 points to claim the Ing Cup!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 21, labelZh: "左边激战", labelEn: "Left-Side Fight"),
                AcademyHighlight(moveIndex: 80, labelZh: "中盘攻防", labelEn: "Middle-Game Battle"),
                AcademyHighlight(moveIndex: 160, labelZh: "中腹定型", labelEn: "Central Control"),
                AcademyHighlight(moveIndex: 314, labelZh: "圆梦应氏杯", labelEn: "Ing Cup Champion")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "四角占完后，常昊第 5 手在左下角外侧小飞挂角，率先发起进攻——请点出这一手！",
                promptEn: "All four corners are taken! Where does Chang Hao play Move 5 to approach White's lower-left corner?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-guli-leesedol-lg",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111122")!,
            hall: .masterpieces,
            level: .dan,
            rankTag: "段位 1D+",
            eraOrTagZh: "2009 · 163手完整原谱",
            eraOrTagEn: "2009 · Full 163 Moves",
            titleZh: "古力 vs 李世石 · LG杯绝代双骄决赛",
            titleEn: "Gu Li vs Lee Sedol: LG Cup Final",
            hookZh: "完整收录 163 手「暴力美学」巅峰对决！21 世纪最具观赏性的「绝代双骄」古力与李世石正面交锋，从头杀到尾，招招见血！",
            hookEn: "Full 163-move fireworks! Modern Go's two greatest attacking titans, Gu Li and Lee Sedol, clash head-on in the 13th LG Cup Final!",
            blackPlayerZh: "古力九段（黑）",
            blackPlayerEn: "Gu Li 9p (Black)",
            whitePlayerZh: "李世石九段（白）",
            whitePlayerEn: "Lee Sedol 9p (White)",
            resultString: "B+R",
            boardSize: 19,
            komi: 6.5,
            sgfZh: annotatedSGF(
                komi: 6.5,
                rawMoves: FullGameMoves.guLiLeeSedol2009,
                intro: "【完整 163 手原谱】2009年2月23日第13届LG杯世界棋王战决赛第一局！被棋迷誉为「绝代双骄」的古力与李世石迎来首次世界大赛决赛番棋对决，全盘充满凌厉的攻杀与力战美学！",
                notes: [
                    1: "第 1 手（Q16）：古力执黑占右上星位，气势如虹。",
                    5: "第 5 手（P3）：黑棋小飞守右下角，准备展开全场力战。",
                    7: "第 7 手（D15）：古力在左上果断挂角，双方立刻短兵相接！",
                    25: "第 25 手（Q15）：右上角激烈交锋，双方寸土不让。",
                    65: "第 65 手（M12）：中腹大龙纠缠！古力「大力金刚掌」正面硬撼李世石「僵尸流」！",
                    115: "第 115 手（H10）：双方在中腹展开生死对杀，计算深度令人窒息！",
                    163: "第 163 手（N7）：古力屠龙大胜！紧接着第二局古力再胜，以 2:0 零封李世石夺得LG杯冠军！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 6.5,
                rawMoves: FullGameMoves.guLiLeeSedol2009,
                intro: "Full 163-move 13th LG Cup Final Game 1 (Feb 23, 2009)! The ultimate fighting showdown between twin legends Gu Li and Lee Sedol.",
                notes: [
                    1: "Move 1 (Q16): Gu Li opens boldly at the upper-right Star Point.",
                    7: "Move 7 (D15): Immediate clash in the upper-left — neither fighter backs down!",
                    65: "Move 65 (M12): Dragons collide in the center in pure attacking brilliance!",
                    163: "Move 163 (N7): Gu Li wins by resignation in 163 electrifying moves!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 7, labelZh: "左上短兵相接", labelEn: "Early Clash"),
                AcademyHighlight(moveIndex: 65, labelZh: "中腹大龙交锋", labelEn: "Dragon Clash"),
                AcademyHighlight(moveIndex: 115, labelZh: "生死大对杀", labelEn: "Capturing Race"),
                AcademyHighlight(moveIndex: 163, labelZh: "力战中盘胜", labelEn: "Knockout B+R")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "前 4 手四角占完！古力第 5 手在右下角抢先「小飞守角」，兼顾下边与角地——请点出这一手！",
                promptEn: "All four corners are claimed! Where does Gu Li play Move 5 to enclose the lower-right corner?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "master-alphago-kejie-g1",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111123")!,
            hall: .masterpieces,
            level: .dan,
            rankTag: "段位 2D+",
            eraOrTagZh: "2017 · 289手完整原谱",
            eraOrTagEn: "2017 · Full 289 Moves",
            titleZh: "AlphaGo vs 柯洁 · 乌镇人机大战第一局",
            titleEn: "Ke Jie vs AlphaGo: Wuzhen Game 1",
            hookZh: "完整收录 289 手巅峰人机战！世界第一人柯洁开局第 7 手直接「点三三」以彼之道还施彼身，与进化版 AlphaGo 激战至最后仅差四分之一子！",
            hookEn: "Full 289-move Wuzhen Summit Game 1 (May 23, 2017)! World #1 Ke Jie uses AI's own early 3-3 invasion and battles AlphaGo down to a half-point finish!",
            blackPlayerZh: "柯洁九段（黑）",
            blackPlayerEn: "Ke Jie 9p (Black)",
            whitePlayerZh: "AlphaGo（白）",
            whitePlayerEn: "AlphaGo (White)",
            resultString: "W+0.5",
            boardSize: 19,
            komi: 7.5,
            sgfZh: annotatedSGF(
                komi: 7.5,
                rawMoves: FullGameMoves.alphaGoKeJieG1,
                intro: "【完整 289 手原谱】2017年5月23日浙江乌镇围棋峰会第一局！人类等级分第一人柯洁迎战终极进化版 AlphaGo Master。柯洁开局即大胆采用 AI 招牌点三三战术，奉献了一场载入现代围棋史册的精彩大战！",
                notes: [
                    1: "第 1 手（R16）：柯洁执黑占右上小目。",
                    2: "第 2 手（Q4）：AlphaGo 占右下星位。",
                    3: "第 3 手（C17）：柯洁大胆在左上直接占「三三」，展现迎接 AI 时代的开放心态！",
                    7: "第 7 手（R3）：惊艳全场！柯洁第 7 手直接对 AlphaGo 的右下星位「点三三」，以 AI 之道还施彼身！",
                    40: "第 40 手（F17）：双方在上方与右边展开高速现代定型，节奏极其紧凑。",
                    90: "第 90 手（C12）：AlphaGo 展现出令人惊叹的「退让控局」美学——只要胜率领先，宁可稳健简明收束，绝不冒进。",
                    180: "第 180 手（M15）：进入大官子阶段，柯洁顽强追赶，将差距一步步缩小。",
                    289: "第 289 手（N13）：289 手终局！AlphaGo 以最微弱的 1/4 子（半目）险胜，展现了超越时代的控盘精度！"
                ]
            ),
            sgfEn: annotatedSGF(
                komi: 7.5,
                rawMoves: FullGameMoves.alphaGoKeJieG1,
                intro: "Full 289-move Future of Go Summit Game 1 (May 23, 2017, Wuzhen)! World #1 Ke Jie adopts AI's own early 3-3 invasion against AlphaGo Master.",
                notes: [
                    1: "Move 1 (R16): Ke Jie opens with upper-right Komoku.",
                    3: "Move 3 (C17): Ke Jie plays an early 3-3 in the upper-left!",
                    7: "Move 7 (R3): Direct 3-3 Invasion on Move 7 — Ke Jie turns AlphaGo's signature weapon right back on it!",
                    90: "Move 90 (C12): AlphaGo demonstrates its calm, winrate-maximizing control once ahead.",
                    289: "Move 289 (N13): AlphaGo wins by the slimmest possible margin — 0.5 points (1/4 stone)!"
                ]
            ),
            highlights: [
                AcademyHighlight(moveIndex: 3, labelZh: "开局占三三", labelEn: "Early 3-3"),
                AcademyHighlight(moveIndex: 7, labelZh: "第7手点三三", labelEn: "Move 7 Invasion"),
                AcademyHighlight(moveIndex: 90, labelZh: "AI 控盘美学", labelEn: "AI Control"),
                AcademyHighlight(moveIndex: 289, labelZh: "四分之一子胜负", labelEn: "Half-Point Finish")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 6,
                promptZh: "乌镇人机大战第 7 手！面对 AlphaGo 的右下星位，柯洁「以彼之道还施彼身」直接点入角内哪一个点位？",
                promptEn: "Wuzhen Game 1 Move 7! Where did Ke Jie invade AlphaGo's lower-right Star Point using AI's own favorite move?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),

        // =========================================================================
        // HALL 2: 棋理十诀 (4 Interactive Good vs Mistake Principles!)
        // =========================================================================
        AcademyEntry(
            id: "principle-no-greed",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111108")!,
            hall: .principles,
            level: .starter,
            rankTag: "启蒙 20K",
            eraOrTagZh: "围棋十诀 · 第一诀",
            eraOrTagEn: "Rule #1 · No Greed",
            titleZh: "不得贪胜 · 见好就收",
            titleEn: "Don't Be Greedy for Victory",
            hookZh: "小朋友输棋头号原因就是「贪心」！点开「正着 vs 错着对比」，亲眼看看贪吃一子如何把大好优势送光！",
            hookEn: "The #1 reason kids lose winning games is greed! Toggle Good vs Mistake to see why calm defense wins!",
            blackPlayerZh: "正着：稳守大局",
            blackPlayerEn: "Good: Calm Defense",
            whitePlayerZh: "反击方（白）",
            whitePlayerEn: "Counterattack (White)",
            resultString: "正着胜",
            boardSize: 9,
            komi: 5.5,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][cd][de][df][ef]AW[dd][ed][ee][fd]C[【围棋十诀 · 不得贪胜】黑棋左上与下方已经占尽先机，但中间两块棋只靠斜对角联系，留着一个明显的断点！];B[ce]C[第 1 手（正着！）：黑棋果断在断点粘住连成铁板一块，绝不贪图去啃白棋右上！];W[fe]C[第 2 手：白棋见黑棋毫无破绽，只好乖乖补厚右边。];B[cf]C[第 3 手：黑棋顺势巩固左边大空，稳稳赢下对局！切换上方「贪心错着」看看如果贪吃会怎样！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][cd][de][df][ef]AW[dd][ed][ee][fd]C[Rule #1: Don't Be Greedy! Black is comfortably ahead, but Black's upper-left and bottom groups only meet diagonally with a clear cutting point!];B[ce]C[Move 1 (Good!): Black connects solidly at the cutting point instead of greedily attacking White on top!];W[fe]C[Move 2: Finding no weakness, White can only defend quietly on the right.];B[cf]C[Move 3: Black secures the entire left side effortlessly! Tap 'Mistake' above to see what greed causes!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "冷静粘住补断", labelEn: "Calm Connection"),
                AcademyHighlight(moveIndex: 3, labelZh: "稳稳扩大优势", labelEn: "Safe Victory")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "黑棋已经领先，现在把中间两块棋稳稳粘成一体、不给白棋任何切断机会的一手在哪里？",
                promptEn: "Black is ahead! Which solid connection links Black's two groups and denies White any cut?"
            ),
            counterExampleSgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][cd][de][df][ef]AW[dd][ed][ee][fd]C[【反面教材 · 贪心下法】如果黑棋不补自己的断点，贪心地去进攻白棋上方会怎样？];B[fc]C[第 1 手（贪心错着！）：黑棋想贪吃白棋上方，却漏看了自己中间的断点！];W[ce]C[第 2 手：白棋立刻一断！黑棋中间被撕开一道大口子！];B[bd]C[第 3 手：黑棋慌忙补救左上，已经彻底失去主动权。];W[cf]C[第 4 手：白棋顺势冲下，黑棋上下两块被劈成两半——这就是「贪胜反败」！])",
            counterExampleSgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][cd][de][df][ef]AW[dd][ed][ee][fd]C[Mistake Demo: What happens if Black gets greedy on the top edge instead of connecting the cutting point?];B[fc]C[Move 1 (Greedy!): Black chases extra points on top and ignores the cutting point!];W[ce]C[Move 2: White slices straight through the cut!];B[bd]C[Move 3: Black scrambles to save the upper-left, already on the back foot.];W[cf]C[Move 4: White pushes through and splits Black in two — greed turns victory into defeat!])"
        ),
        AcademyEntry(
            id: "principle-sacrifice-sente",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111109")!,
            hall: .principles,
            level: .intermediate,
            rankTag: "进阶 14K",
            eraOrTagZh: "围棋十诀 · 第四诀",
            eraOrTagEn: "Rule #4 · Sacrifice for Sente",
            titleZh: "弃子争先 · 舍小就大",
            titleEn: "Sacrifice Small Stones for Sente",
            hookZh: "真正的高手不怕丢掉一两颗残子！把没用的小棋送给对手，换来抢先占大场的主动权！",
            hookEn: "True masters gladly let 1–2 heavy stones go in order to seize initiative (Sente) across the board!",
            blackPlayerZh: "正着：弃子争先",
            blackPlayerEn: "Good: Sacrifice for Sente",
            whitePlayerZh: "对手（白）",
            whitePlayerEn: "Opponent (White)",
            resultString: "正着胜",
            boardSize: 9,
            komi: 5.5,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[dd][ed][ec]AW[dc][cd][de][ee]C[【围棋十诀 · 弃子争先】黑棋中间这颗残子已经被白棋团团围住，该硬救还是果断弃子整形？];B[fd]C[第 1 手（妙手！）：黑棋不在里面挣扎，而是从外侧厚实长出！];W[cc]C[第 2 手：白棋趁机在左上吃掉或加固角部。];B[ef]C[第 3 手：黑棋外侧顺势封锁！白棋只赚了个小角，黑棋却筑起辐射全盘的万里长城，大获成功！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[dd][ed][ec]AW[dc][cd][de][ee]C[Rule #4: Sacrifice for Sente! Black's inner stone is heavily surrounded. Fight to save it or build outside?];B[fd]C[Move 1 (Brilliant!): Instead of crawling inside, Black extends strongly on the outside!];W[cc]C[Move 2: White settles for the small corner.];B[ef]C[Move 3: Black seals from the outside, trading a tiny stone for a dominant whole-board wall!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "果断走外侧", labelEn: "Play Outside"),
                AcademyHighlight(moveIndex: 3, labelZh: "筑起外势长城", labelEn: "Build Great Wall")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "不要去角里硬拼！从外侧厚实长出、顺势封锁白棋的好手在哪里？",
                promptEn: "Don't crawl inside the corner! Where should Black extend outside to build thickness?"
            ),
            counterExampleSgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[dd][ed][ec]AW[dc][cd][de][ee]C[【反面教材 · 恋子不舍】如果舍不得丢小棋，硬往角里钻会怎样？];B[cc]C[第 1 手（俗手！）：黑棋恋恋不舍想从角里硬钻出去。];W[fd]C[第 2 手：白棋立刻从外侧封锁！];B[cb]C[第 3 手：黑棋被压在二路苦苦爬行，不但没占便宜，反而帮白棋筑起了超厚外势！])",
            counterExampleSgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[dd][ed][ec]AW[dc][cd][de][ee]C[Mistake Demo: What happens if Black stubbornly tries to save every stone?];B[cc]C[Move 1 (Heavy!): Black clings to the corner.];W[fd]C[Move 2: White immediately seals from the outside!];B[cb]C[Move 3: Black is forced to crawl miserably on the 2nd line while White gets a massive outer wall!])"
        ),
        AcademyEntry(
            id: "principle-attack-defend",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111110")!,
            hall: .principles,
            level: .advanced,
            rankTag: "高阶 8K",
            eraOrTagZh: "围棋十诀 · 第三诀",
            eraOrTagEn: "Rule #3 · Mind Yourself",
            titleZh: "攻彼顾我 · 先补断再进攻",
            titleEn: "Attack While Guarding Yourself",
            hookZh: "想吃别人之前，先摸摸自己有没有漏洞！否则刚冲出去，自己家里先起火了。",
            hookEn: "Check your own cutting points before attacking — or your own stones will fall apart first!",
            blackPlayerZh: "正着：先固本后攻",
            blackPlayerEn: "Good: Defend Then Attack",
            whitePlayerZh: "反击方（白）",
            whitePlayerEn: "Counter (White)",
            resultString: "正着胜",
            boardSize: 9,
            komi: 5.5,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][dc][ce][df]AW[cd][dd][ed][ec]C[【围棋十诀 · 攻彼顾我】黑棋看着白棋很诱人，但自己左边上下两块之间有个大缺口，随时会被白棋冲断！];B[bd]C[第 1 手（正着！）：先把自己左边的虎口补牢，连成一体毫无后顾之忧！];W[eb]C[第 2 手：白棋找不到反击点，只好回头补上方。];B[ee]C[第 3 手：现在自身铁厚，黑棋可以放手猛攻中央白棋啦！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][dc][ce][df]AW[cd][dd][ed][ec]C[Rule #3: Attack While Guarding Yourself! Before chasing White, notice Black's own cutting point on the left!];B[bd]C[Move 1 (Good!): Connect your own left side first so White has zero counterplay!];W[eb]C[Move 2: With no weakness to exploit, White must defend passively.];B[ee]C[Move 3: Now rock-solid, Black launches an unstoppable attack on White!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "先补自身漏洞", labelEn: "Fix Own Weakness"),
                AcademyHighlight(moveIndex: 3, labelZh: "放心发起总攻", labelEn: "Launch Attack")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "进攻之前先护住自己！哪一手能把黑棋左边两块连成铜墙铁壁？",
                promptEn: "Protect your own shape before attacking! Which move links Black's left stones solidly?"
            ),
            counterExampleSgfZh: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][dc][ce][df]AW[cd][dd][ed][ec]C[【反面教材 · 只顾进攻】如果黑棋不管自己漏洞，直接去冲白棋会怎样？];B[ee]C[第 1 手（鲁莽！）：黑棋一心想杀白棋，忘了自己左边薄如纸！];W[bd]C[第 2 手：白棋反手一断，黑棋左边两块瞬间被劈成两半，攻守彻底逆转！])",
            counterExampleSgfEn: "(;GM[1]FF[4]SZ[9]KM[5.5]AB[cc][dc][ce][df]AW[cd][dd][ed][ec]C[Mistake Demo: What if Black attacks blindly without checking its own shape?];B[ee]C[Move 1 (Reckless!): Black charges forward while leaving the left side wide open!];W[bd]C[Move 2: White slices Black in two — the attacker suddenly becomes the hunted!])"
        ),
        AcademyEntry(
            id: "principle-vital-point",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            hall: .principles,
            level: .intermediate,
            rankTag: "进阶 12K",
            eraOrTagZh: "围棋黄金格言",
            eraOrTagEn: "Golden Proverb",
            titleZh: "左右同形走中央 · 敌之要点",
            titleEn: "Symmetrical Shape: Play the Center",
            hookZh: "棋盘上最神奇的万能口诀：只要看到左右对称的棋形，99% 的答案都在正中间！",
            hookEn: "Go's most magical shortcut: whenever a shape is symmetrical, the vital point is almost always dead center!",
            blackPlayerZh: "正着：一击点中心",
            blackPlayerEn: "Good: Strike Center",
            whitePlayerZh: "防守方（白）",
            whitePlayerEn: "Defender (White)",
            resultString: "正着胜",
            boardSize: 9,
            komi: 0,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[0]AW[ba][bb][cb][db][eb][fb][fa]AB[aa][ab][ac][bc][cc][dc][ec][fc][gc][gb][ga]C[【围棋格言 · 左右同形走中央】白棋在边上围出一个左右完全对称的三目「直三」空间，黑棋要怎么一击破眼？];B[da]C[第 1 手（正着！）：直点三目正中央！左右两只眼瞬间无法分开，白棋彻底绝望！];W[ca]C[第 2 手：白棋紧气反抗，想在左边挣扎。];B[ea]C[第 3 手：黑棋冷静一紧，白棋 8 颗子瞬间全部被提光，干脆净杀！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[0]AW[ba][bb][cb][db][eb][fb][fa]AB[aa][ab][ac][bc][cc][dc][ec][fc][gc][gb][ga]C[Golden Proverb: Play the Center of Symmetry! White has a perfectly symmetrical 3-space Straight Three. Where is the vital point?];B[da]C[Move 1 (Spot on!): Right in the exact center! White can no longer split the space into two eyes!];W[ca]C[Move 2: White tries to resist on the left.];B[ea]C[Move 3: Black takes the last liberty and captures all 8 white stones cleanly!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "一击点中央", labelEn: "Center Vital Point")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "记住口诀「左右同形走中央」！点在哪个位置能一招破掉白棋两眼？",
                promptEn: "Remember: 'Play the center of symmetry!' Which single point destroys White's two eyes?"
            ),
            counterExampleSgfZh: "(;GM[1]FF[4]SZ[9]KM[0]AW[ba][bb][cb][db][eb][fb][fa]AB[aa][ab][ac][bc][cc][dc][ec][fc][gc][gb][ga]C[【反面教材 · 错失中心】如果黑棋先下在旁边而不是正中间呢？];B[ca]C[第 1 手（错着！）：没抢占正中央要点！];W[da]C[第 2 手：白棋立刻反占中心提掉黑子！记住「敌之要点即我之要点」，白棋瞬间左右两只真眼活棋！])",
            counterExampleSgfEn: "(;GM[1]FF[4]SZ[9]KM[0]AW[ba][bb][cb][db][eb][fb][fa]AB[aa][ab][ac][bc][cc][dc][ec][fc][gc][gb][ga]C[Mistake Demo: What if Black plays off-center first?];B[ca]C[Move 1 (Wrong!): Missing the center vital point!];W[da]C[Move 2: White captures and grabs the center instead ('my opponent's vital point is my vital point'), living cleanly with two true eyes!])"
        ),

        // =========================================================================
        // HALL 3: 布局流派 (4 Opening Blueprints spanning 13x13 & 19x19)
        // =========================================================================
        AcademyEntry(
            id: "opening-13x13-corners",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111102")!,
            hall: .openings,
            level: .starter,
            rankTag: "启蒙 20K",
            eraOrTagZh: "13路标准开局",
            eraOrTagEn: "13×13 Blueprint",
            titleZh: "13路金角银边 · 开局第一步",
            titleEn: "13×13 Golden Corners & Silver Sides",
            hookZh: "刚上 13 路棋盘不知道第一步下哪？记住「占角 → 拆边 → 挂角」，20 手学会标准布局！",
            hookEn: "New to 13×13? Follow 'Corners -> Sides -> Approaches' in 20 crystal-clear moves!",
            blackPlayerZh: "金角示范（黑）",
            blackPlayerEn: "Corner Study (Black)",
            whitePlayerZh: "标准应对（白）",
            whitePlayerEn: "Balanced Reply (White)",
            resultString: "B+4.5",
            boardSize: 13,
            komi: 6.5,
            sgfZh: "(;GM[1]FF[4]SZ[13]KM[6.5]C[围棋名言「金角银边草肚皮」：在 13 路棋盘上，角上最容易用最少的棋子围出大空！];B[dd]C[第 1 手：黑占左上星位！先抢「金角」。];W[jj]C[第 2 手：白占右下星位，同样抢角。];B[dj]C[第 3 手：黑占左下星位，形成双星布局。];W[jd]C[第 4 手：白占右上星位！前 4 手一人两个角，标准开局。];B[fj]C[第 5 手：角占完后走边——黑棋向下方拆边。];W[gj]C[第 6 手：白棋针锋相对，阻止黑棋围住整个下边。];B[gk]C[第 7 手：黑棋扳起反击！];W[hk]C[第 8 手：白棋连扳守角。];B[fk]C[第 9 手：黑棋稳稳长出，保住下边根据地。];W[hj]C[第 10 手：白棋虎口补强，棋形非常漂亮。];B[cf]C[第 11 手：左边大场！黑棋把左上和左下遥相呼应。];W[kf]C[第 12 手：白棋立刻在右边对称拆边，互不相让。];B[jc]C[第 13 手：黑棋挂角！准备压缩白棋右上角的地盘。];W[kc]C[第 14 手：白棋贴住反击，守护角部。];B[ic]C[第 15 手：黑棋长出，增加气数。];W[kd]C[第 16 手：白棋立下，角地非常稳固。];B[dg]C[第 17 手：黑棋回到左边加厚阵势。];W[jg]C[第 18 手：白棋也在右边呼应补厚。];B[fd]C[第 19 手：黑棋上方展开，形成宏大外势！];W[gd]C[第 20 手：白棋逼近限制黑棋发展，精彩的布局告一段落！])",
            sgfEn: "(;GM[1]FF[4]SZ[13]KM[6.5]C[Famous Go proverb: Corners are gold, sides are silver, center is grass! Let's see why on 13×13.];B[dd]C[Move 1: Black takes the top-left star point (golden corner!).];W[jj]C[Move 2: White takes the bottom-right star point.];B[dj]C[Move 3: Black takes the bottom-left star point.];W[jd]C[Move 4: White takes the top-right — all 4 golden corners claimed first!];B[fj]C[Move 5: Now move to the silver sides! Black approaches along the bottom.];W[gj]C[Move 6: White responds actively to limit Black's bottom side.];B[gk]C[Move 7: Black turns aggressively!];W[hk]C[Move 8: White blocks to protect its corner.];B[fk]C[Move 9: Black connects and secures a solid base.];W[hj]C[Move 10: White makes a sturdy tiger's mouth shape.];B[cf]C[Move 11: Big move on the left side linking Black's two corners!];W[kf]C[Move 12: White mirrors on the right side.];B[jc]C[Move 13: Black approaches White's top-right corner!];W[kc]C[Move 14: White defends the corner firmly.];B[ic]C[Move 15: Black extends smoothly for liberties.];W[kd]C[Move 16: White stands down — rock-solid corner territory.];B[dg]C[Move 17: Black reinforces the left framework.];W[jg]C[Move 18: White strengthens the right framework.];B[fd]C[Move 19: Black expands across the top!];W[gd]C[Move 20: White checks Black's growth — a balanced textbook opening!])",
            highlights: [
                AcademyHighlight(moveIndex: 4, labelZh: "四角占完", labelEn: "4 Corners"),
                AcademyHighlight(moveIndex: 11, labelZh: "抢占边线大场", labelEn: "Big Side"),
                AcademyHighlight(moveIndex: 13, labelZh: "挂角进攻", labelEn: "Corner Approach")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 10,
                promptZh: "下边定型完毕！现在左侧两个黑角之间空荡荡的，请抢占左边大场把两角连起来！",
                promptEn: "The bottom is settled! Claim the big point on the left side to link your two corners!"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "opening-chinese-fuseki",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111112")!,
            hall: .openings,
            level: .intermediate,
            rankTag: "进阶 12K",
            eraOrTagZh: "中国流布局",
            eraOrTagEn: "Chinese Opening",
            titleZh: "经典「中国流」布局蓝图",
            titleEn: "The Classic Chinese Opening",
            hookZh: "中国棋手发扬光大的世界级名阵！星位 + 小目 + 边星，实地与外势兼得，最适合实战上手！",
            hookEn: "Popularized by Chinese masters — blending Star Point, Komoku, and side expansion for balanced speed!",
            blackPlayerZh: "中国流（黑）",
            blackPlayerEn: "Chinese Opening (Black)",
            whitePlayerZh: "应对演示（白）",
            whitePlayerEn: "Standard Reply (White)",
            resultString: "两分",
            boardSize: 19,
            komi: 7.5,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[7.5]C[「中国流」是围棋史上最受欢迎的现代布局之一！特点是速度快、攻防兼备。];B[pd]C[第 1 手：黑占右上星位。];W[dd]C[第 2 手：白占左上星位。];B[qp]C[第 3 手：黑占右下小目（面向右边），准备布阵！];W[dq]C[第 4 手：白占左下小目。];B[qj]C[第 5 手：这就是标志性的「低中国流」！一子把右上星位和右下小目完美联结，随时瞄准右下大空或攻击打入白子！];W[fq]C[第 6 手：白棋小飞守左下角。];B[cf]C[第 7 手：黑棋顺势挂左上白星位，全盘步调极其舒展！];W[fc]C[第 8 手：白棋小飞应守角。];B[dj]C[第 9 手：黑棋左边拆三建根据地。];W[nq]C[第 10 手：白棋挂右下黑角，试探中国流阵势。];B[pn]C[第 11 手：黑棋一间高关稳守右边大空！];W[jq]C[第 12 手：白棋下方拆边，经典中国流布局圆满成形！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[7.5]C[The Chinese Opening is one of Go's most beloved blueprints — fast, flexible, and great for both territory and fighting!];B[pd]C[Move 1: Black takes the upper-right Star Point.];W[dd]C[Move 2: White takes the upper-left Star Point.];B[qp]C[Move 3: Black plays Komoku in the lower-right facing the right side.];W[dq]C[Move 4: White claims the lower-left Komoku.];B[qj]C[Move 5: The signature 'Low Chinese Opening'! One stone unites both right corners into a dynamic framework!];W[fq]C[Move 6: White encloses the lower-left corner.];B[cf]C[Move 7: Black approaches the upper-left swiftly.];W[fc]C[Move 8: White answers calmly with a Knight's Move.];B[dj]C[Move 9: Black settles cleanly along the left side.];W[nq]C[Move 10: White approaches the lower-right to challenge the Chinese Opening.];B[pn]C[Move 11: Black defends smoothly to keep the right side unified!];W[jq]C[Move 12: White extends on the bottom — textbook Chinese Opening!])",
            highlights: [
                AcademyHighlight(moveIndex: 5, labelZh: "中国流成形", labelEn: "Chinese Opening"),
                AcademyHighlight(moveIndex: 9, labelZh: "左边拆边", labelEn: "Left Extension"),
                AcademyHighlight(moveIndex: 11, labelZh: "守住右边大空", labelEn: "Guard Right Side")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "右上星位 + 右下小目已经就位！第 5 手落在右边哪一个星位下方，就能摆出大名鼎鼎的「低中国流」？",
                promptEn: "Upper-right Star Point + lower-right Komoku are ready! Where does Move 5 go to complete the Low Chinese Opening?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "opening-sanrensei",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111113")!,
            hall: .openings,
            level: .advanced,
            rankTag: "高阶 6K",
            eraOrTagZh: "宇宙流 · 三连星",
            eraOrTagEn: "Cosmic Style",
            titleZh: "武宫正树 · 三连星宇宙流",
            titleEn: "Sanrensei: The Cosmic Opening",
            hookZh: "小朋友最爱学的酷炫布局！三颗黑子排成一排直指中腹，把半个棋盘都变成你的宇宙星海！",
            hookEn: "Kids' favorite bold opening! Three star points in a row aiming straight at the vast center!",
            blackPlayerZh: "三连星（黑）",
            blackPlayerEn: "Sanrensei (Black)",
            whitePlayerZh: "应对演示（白）",
            whitePlayerEn: "Opponent (White)",
            resultString: "气势局",
            boardSize: 19,
            komi: 7.5,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[7.5]C[日本棋圣武宫正树以宏大华丽的「三连星宇宙流」闻名天下！适合喜欢进攻和大格局的棋手。];B[pd]C[第 1 手：右上星位！];W[dd]C[第 2 手：白占左上星位。];B[pp]C[第 3 手：右下星位，双星闪耀！];W[dp]C[第 4 手：白占左下星位，双方四角全占星位。];B[pj]C[第 5 手：正中右边星位！「三连星」正式亮相——三颗星位连成一线，光芒直指中央！];W[nc]C[第 6 手：白棋上方挂角。];B[pf]C[第 7 手：黑棋小飞应，顺势把右上角和右边三连星织成一张大网！];W[jd]C[第 8 手：白棋上方拆边。];B[np]C[第 9 手：黑棋右下也往下方大步迈出，半壁江山气势逼人！];W[fq]C[第 10 手：白棋护住左下角，准备随时打入中央决战！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[7.5]C[Takemiya Masaki made 'Sanrensei' (Three Star Points) famous worldwide for its breathtaking Cosmic Style!];B[pd]C[Move 1: Upper-right Star Point!];W[dd]C[Move 2: White claims the upper-left Star Point.];B[pp]C[Move 3: Lower-right Star Point — double stars shining!];W[dp]C[Move 4: White claims the lower-left Star Point.];B[pj]C[Move 5: The right-side Star Point! Three stars aligned — 'Sanrensei' aims straight at the vast center!];W[nc]C[Move 6: White approaches the upper-right.];B[pf]C[Move 7: Knight's defense — weaving the entire right side into a cosmic framework!];W[jd]C[Move 8: White settles along the top.];B[np]C[Move 9: Black expands along the bottom too, radiating power toward the middle!];W[fq]C[Move 10: White guards the lower-left, preparing for a central showdown!])",
            highlights: [
                AcademyHighlight(moveIndex: 5, labelZh: "三连星亮相", labelEn: "Sanrensei Formed"),
                AcademyHighlight(moveIndex: 7, labelZh: "宇宙大模样", labelEn: "Cosmic Framework")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 4,
                promptZh: "右上和右下两个星位已经亮起！点亮右边正中的第三颗星位，召唤「三连星宇宙流」吧！",
                promptEn: "Two star points are shining on the right! Light up the middle star point to summon Sanrensei!"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "opening-ai-sansan",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111103")!,
            hall: .openings,
            level: .dan,
            rankTag: "段位 1D+",
            eraOrTagZh: "AI 现代招牌定式",
            eraOrTagEn: "Modern AI Joseki",
            titleZh: "19路 · AI 时代星位点三三",
            titleEn: "19×19 Modern AI 3-3 Invasion",
            hookZh: "AlphaGo 之后全世界职业棋手每盘必下的招牌定式：实地与外势的完美平衡。",
            hookEn: "The #1 signature Joseki of the AI era — balancing corner territory against a mighty outside wall!",
            blackPlayerZh: "现代定式（黑）",
            blackPlayerEn: "Modern Joseki (Black)",
            whitePlayerZh: "AI 点三三（白）",
            whitePlayerEn: "AI 3-3 Invasion (White)",
            resultString: "两分",
            boardSize: 19,
            komi: 7.5,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[7.5]C[现代围棋最著名的「星位点三三定式」！只需 16 手看懂职业棋手和 AI 每天都在下的经典变化。];B[pd]C[第 1 手：黑占右上星位（4-4）。];W[dd]C[第 2 手：白占左上星位。];B[dp]C[第 3 手：黑占左下星位。];W[pp]C[第 4 手：白占右下星位。];B[qf]C[第 5 手：黑棋小飞守角，准备经营右边。];W[qc]C[第 6 手：白棋直接「点三三」抢角！AI 时代最流行的一招。];B[qd]C[第 7 手：黑棋挡在宽阔一侧，准备取外势。];W[pc]C[第 8 手：白棋向三路长出。];B[od]C[第 9 手：黑棋顺势长出筑墙！];W[oc]C[第 10 手：白棋再长一步，扩大角地。];B[nc]C[第 11 手：黑棋三路扳头！封锁白棋并获得铁厚外势。];W[ob]C[第 12 手：白棋二路退回活角。];B[rc]C[第 13 手：黑棋二路扳缩角，漂亮先手！];W[rb]C[第 14 手：白棋挡住，角部两眼稳活。];B[rd]C[第 15 手：黑棋粘上补厚，厚势照耀全盘！];W[sb]C[第 16 手：白棋补活角部，双方实地与外势两分，经典定式完成！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[7.5]C[The most famous Joseki of modern Go: the 3-3 Invasion! Master the balance of territory vs thickness in 16 moves.];B[pd]C[Move 1: Black takes the upper-right 4-4 Star Point.];W[dd]C[Move 2: White takes the upper-left Star Point.];B[dp]C[Move 3: Black claims the lower-left Star Point.];W[pp]C[Move 4: White claims the lower-right Star Point.];B[qf]C[Move 5: Black reinforces the right side with a Knight's Move.];W[qc]C[Move 6: Direct 3-3 Invasion! The signature move of modern AI Go.];B[qd]C[Move 7: Black blocks on the wide side to build an outer wall.];W[pc]C[Move 8: White extends along the 3rd line.];B[od]C[Move 9: Black extends smoothly to build thickness!];W[oc]C[Move 10: White pushes once more for corner space.];B[nc]C[Move 11: Hane on the 3rd line! Black seals White in with a mighty wall.];W[ob]C[Move 12: White pulls back on the 2nd line to live.];B[rc]C[Move 13: Sharp 2nd-line hane in sente!];W[rb]C[Move 14: White blocks to secure corner life.];B[rd]C[Move 15: Black connects solidly — radiant outside influence!];W[sb]C[Move 16: White secures the corner — textbook balanced Joseki!])",
            highlights: [
                AcademyHighlight(moveIndex: 6, labelZh: "AI 点三三", labelEn: "3-3 Invasion"),
                AcademyHighlight(moveIndex: 11, labelZh: "三路扳头筑墙", labelEn: "3rd-Line Hane"),
                AcademyHighlight(moveIndex: 15, labelZh: "厚势定型", labelEn: "Wall Complete")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 10,
                promptZh: "白棋在三路长出后，黑棋第 11 手果断在三路「扳头」封锁白棋并筑起铁墙——请点出这一手！",
                promptEn: "White just extended on the 3rd line. Where does Black play the 3rd-line Hane on Move 11 to seal White in?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),

        // =========================================================================
        // HALL 4: 奇局趣史 (3 Legendary Wonders & Stories!)
        // =========================================================================
        AcademyEntry(
            id: "curiosity-lanke-corner",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111114")!,
            hall: .curiosities,
            level: .starter,
            rankTag: "启蒙 18K",
            eraOrTagZh: "围棋神话 · 烂柯与珍珑",
            eraOrTagEn: "Legend · Lanke & Snapback",
            titleZh: "烂柯仙局 · 倒扑破珍珑",
            titleEn: "Mount Lanke & The Snapback Wonder",
            hookZh: "相传樵夫王质上山看仙童下棋，一局未终斧柄已经烂掉——这就是围棋别称「烂柯」的由来！看看仙童最爱的「倒扑」奇招。",
            hookEn: "Legend says woodcutter Wang Zhi watched two immortals play Go — by the end, his axe handle had rotted away! Watch their favorite Snapback trick!",
            blackPlayerZh: "山中仙童（黑）",
            blackPlayerEn: "Mountain Immortal (Black)",
            whitePlayerZh: "奇局阵形（白）",
            whitePlayerEn: "Puzzle Fortress (White)",
            resultString: "仙招破局",
            boardSize: 9,
            komi: 0,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[0]AW[aa][ab][ba][cb][db][eb][ea]AB[bb][bc][cc][dc][ec][fb][fa]C[【围棋趣史 · 烂柯山】古代把围棋称为「烂柯」「手谈」「坐隐」。这盘角上奇形看似白棋稳如泰山，却暗藏「仙人倒扑」妙手！];B[ca]C[第 1 手（先送一颗糖！）：黑棋大胆送入一路切断！看起来像送吃，其实是绝妙陷阱！];W[da]C[第 2 手：白棋一口提掉黑子，却发现自己整块 5 颗子反而只剩 1 口气！];B[ca]C[第 3 手（倒扑提光！）：因为提掉的是 5 颗子而不是单子，不构成打劫——黑棋瞬间回提全歼！是不是像变魔术一样神奇？])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[0]AW[aa][ab][ba][cb][db][eb][ea]AB[bb][bc][cc][dc][ec][fb][fa]C[Go Legend: Mount Lanke! Go is poetically called 'Hand Talk' (Shutan). This corner fortress looks invincible — until a magical Snapback appears!];B[ca]C[Move 1 (The Bait!): Black boldly throws in a single sacrifice stone!];W[da]C[Move 2: White greedily captures it — dropping White's own 5-stone group to 1 single liberty!];B[ca]C[Move 3 (Snapback!): Capturing 5 stones isn't a Ko — Black scoops up the entire group like magic!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "大胆送吃", labelEn: "The Bait"),
                AcademyHighlight(moveIndex: 3, labelZh: "倒扑全歼", labelEn: "Magic Snapback")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "白棋角上看似固若金汤，仙童先送出一颗诱饵子就能倒扑全吃——请点出第 1 手！",
                promptEn: "White's corner looks solid — which 1st-line bait move triggers the magical Snapback?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        ),
        AcademyEntry(
            id: "curiosity-pig-snout",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111115")!,
            hall: .curiosities,
            level: .advanced,
            rankTag: "高阶 6K",
            eraOrTagZh: "1347 · 《玄玄棋经》",
            eraOrTagEn: "1347 · Xuanxuan Qijing",
            titleZh: "古谱杀棋次序 · 先缩小再点杀",
            titleEn: "Ancient Classic: Reduce First, Then Strike",
            hookZh: "元代围棋宝典《玄玄棋经》最核心的杀棋心法！面对宽敞的角部直四空间，急着往里点就会放活——记住「先缩小，再点杀」！",
            hookEn: "A golden killing principle from the 1347 classic Xuanxuan Qijing! Against a 4-space corner room, rushing inside lets White live — reduce from outside first!",
            blackPlayerZh: "玄玄棋经（黑）",
            blackPlayerEn: "Xuanxuan Qijing (Black)",
            whitePlayerZh: "角上直四（白）",
            whitePlayerEn: "Corner Straight-4 (White)",
            resultString: "黑杀白",
            boardSize: 9,
            komi: 0,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[0]AW[aa][ab][bb][cb][db][eb]AB[fa][fb][fc][ac][bc][cc][dc][ec]C[【古谱心法 · 先缩小再点杀】1347年《玄玄棋经》记载了无数精妙杀棋次序。这盘角部白棋有四目直四空间，直接往里乱点会放活白棋！];B[ea]C[第 1 手（先缩小眼位！）：沿着一路轻轻一扳，把白棋原本宽敞的直四空间压缩成直三！];W[ca]C[第 2 手：白棋赶紧在正中抢占眼位。];B[da]C[第 3 手（一剑封喉！）：顺势破掉右眼，白棋只剩左边一只单眼，干脆净杀！记住古人名言：杀棋先缩小，再点杀！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[0]AW[aa][ab][bb][cb][db][eb]AB[fa][fb][fc][ac][bc][cc][dc][ec]C[From the 1347 classic Xuanxuan Qijing! White's corner has 4 open spaces — rushing inside carelessly lets White live!];B[ea]C[Move 1 (Shrink First!): Hane on the 1st line from outside, shrinking White's 4-space room down to 3!];W[ca]C[Move 2: White tries desperately to claim the middle eye point.];B[da]C[Move 3 (Checkmate!): Black destroys the right eye, leaving White with only one eye — dead! Golden rule: Reduce first, then strike!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "一路先缩小", labelEn: "Shrink Outside"),
                AcademyHighlight(moveIndex: 3, labelZh: "破眼净杀", labelEn: "Destroy Second Eye")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "记住古谱口诀「先缩小，再点杀」！黑棋第 1 手应该从外侧哪一个一路交叉点扳进去？",
                promptEn: "Remember: 'Reduce from outside first!' Which 1st-line move shrinks White's eye space?"
            ),
            counterExampleSgfZh: "(;GM[1]FF[4]SZ[9]KM[0]AW[aa][ab][bb][cb][db][eb]AB[fa][fb][fc][ac][bc][cc][dc][ec]C[【反面教材 · 急着往里点】如果不先从外侧缩小，急着往角里点会怎样？];B[ba]C[第 1 手（太心急！）：直接往里面点，却忘了外面一路还敞开着！];W[ca]C[第 2 手：白棋顺势一提！左边变出一只真眼，右边还有宽敞眼位，瞬间两眼活棋！])",
            counterExampleSgfEn: "(;GM[1]FF[4]SZ[9]KM[0]AW[aa][ab][bb][cb][db][eb]AB[fa][fb][fc][ac][bc][cc][dc][ec]C[Mistake Demo: What if Black rushes inside without shrinking from outside first?];B[ba]C[Move 1 (Too Hasty!): Diving inside leaves the outer 1st line wide open!];W[ca]C[Move 2: White captures immediately — forming a true eye on the left plus spacious room on the right to live easily!])"
        ),
        AcademyEntry(
            id: "curiosity-bent-four",
            recordId: UUID(uuidString: "11111111-1111-1111-1111-111111111116")!,
            hall: .curiosities,
            level: .dan,
            rankTag: "段位 1D+",
            eraOrTagZh: "清代 · 《官子谱》传奇",
            eraOrTagEn: "Classic · Guanzipu",
            titleZh: "围棋头号奇形 · 盘角曲四",
            titleEn: "The Legendary Bent Four in the Corner",
            hookZh: "明明是「曲四」活形，偏偏长在棋盘角落里就变成「劫尽棋亡」的死棋！每个冲段少年必知的围棋传奇。",
            hookEn: "A Bent Four normally lives — yet tucked into the corner it becomes famous 'Bent Four in the Corner'!",
            blackPlayerZh: "点杀方（黑）",
            blackPlayerEn: "Attacker (Black)",
            whitePlayerZh: "盘角曲四（白）",
            whitePlayerEn: "Bent Four (White)",
            resultString: "劫杀白",
            boardSize: 9,
            komi: 0,
            sgfZh: "(;GM[1]FF[4]SZ[9]KM[0]AW[da][db][cb][bb][bc][ac]AB[ea][eb][ec][dc][cc][cd][bd][ad]C[【围棋传奇 · 盘角曲四】在边上，「曲四」天然是活棋；可一旦贴在角上，就成了围棋界最有名的特殊死形「盘角曲四」！];B[ba]C[第 1 手（犀利要点！）：抢占角上拐弯处，逼迫白棋表态！];W[ca]C[第 2 手：白棋无奈挡住，想保留做眼希望。];B[aa]C[第 3 手（形成打劫！）：黑棋在 1-1 角点立下！由于白棋外气最终会被消光，盘角曲四在规则中直接判白棋净死——太神奇了！])",
            sgfEn: "(;GM[1]FF[4]SZ[9]KM[0]AW[da][db][cb][bb][bc][ac]AB[ea][eb][ec][dc][cc][cd][bd][ad]C[Go's Most Famous Rule Wonder: Bent Four in the Corner! On the side it lives, but in the corner it dies by Ko!];B[ba]C[Move 1 (The Vital Point!): Strike the corner bend to force White's hand!];W[ca]C[Move 2: White blocks to hold onto hope.];B[aa]C[Move 3 (Corner Ko!): Black drops into 1-1! Because White can never eliminate all external Ko threats, Bent Four in the Corner is dead under Go rules!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "拐弯要点", labelEn: "Corner Bend"),
                AcademyHighlight(moveIndex: 3, labelZh: "1-1 绝妙立下", labelEn: "1-1 Ko Strike")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 0,
                promptZh: "面对传说中的「盘角曲四」，黑棋第 1 手该点在角上哪个要点才能迫使白棋陷入绝境？",
                promptEn: "Facing the legendary Bent Four in the Corner, which vital point starts the killing sequence?"
            ),
            counterExampleSgfZh: nil,
            counterExampleSgfEn: nil
        )
    ]

    static func entry(withId id: String) -> AcademyEntry? {
        allEntries.first { $0.id == id }
    }

    static func entry(forRecordId recordId: UUID) -> AcademyEntry? {
        allEntries.first { $0.recordId == recordId }
    }

    static func entries(in hall: AcademyHall, level: AcademyLevel) -> [AcademyEntry] {
        allEntries.filter { entry in
            entry.hall == hall && (level == .all || entry.level == level)
        }
    }

    static func allSavedRecords(l10n: L10n) -> [SavedGameRecord] {
        allEntries.map { $0.toSavedGameRecord(l10n: l10n) }
    }

    // MARK: - Complete Historical Game Builder & Verified Authentic Move Records

    /// Builds a valid FF[4] SGF by injecting bilingual commentary onto a verified full-game move stream.
    private static func annotatedSGF(
        boardSize: Int = 19,
        komi: Double,
        rawMoves: String,
        intro: String,
        notes: [Int: String]
    ) -> String {
        func escape(_ text: String) -> String {
            text.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "]", with: "\\]")
        }
        let komiStr = komi.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(komi))" : String(format: "%.1f", komi)
        var out = "(;GM[1]FF[4]SZ[\(boardSize)]KM[\(komiStr)]C[\(escape(intro))]"
        let tokens = rawMoves.split(separator: ";")
        for (idx, token) in tokens.enumerated() {
            let moveNum = idx + 1
            out.append(";")
            out.append(contentsOf: token)
            if let note = notes[moveNum] {
                out.append("C[\(escape(note))]")
            }
        }
        out.append(")")
        return out
    }

    private enum FullGameMoves {
        /// 1846-07-21 Honinbo Shusaku vs Inoue Gennan Inseki (325 moves, B+2)
        static let earReddening = ";B[qd];W[dc];B[pq];W[oc];B[cp];W[cf];B[ep];W[qo];B[pe];W[np];B[po];W[pp];B[op];W[qp];B[oq];W[oo];B[pn];W[qq];B[nq];W[on];B[pm];W[mp];B[mq];W[om];B[pl];W[ol];B[pk];W[lq];B[lr];W[kr];B[lp];W[kq];B[qr];W[rr];B[rs];W[mr];B[nr];W[pr];B[ps];W[qs];B[no];W[mo];B[qr];W[rm];B[rl];W[qs];B[lo];W[mn];B[qr];W[qm];B[or];W[ql];B[qj];W[rj];B[ri];W[rk];B[ln];W[mm];B[qi];W[rq];B[jn];W[ls];B[ns];W[gq];B[go];W[ck];B[kc];W[ic];B[pc];W[nj];B[ke];W[og];B[oh];W[pb];B[qb];W[ng];B[mi];W[mj];B[nd];W[ph];B[qg];W[pg];B[hq];W[hr];B[ir];W[iq];B[hp];W[jr];B[fc];W[lc];B[ld];W[mc];B[lb];W[mb];B[md];W[qf];B[pf];W[qh];B[rg];W[rh];B[sh];W[rf];B[sg];W[pj];B[pi];W[oi];B[oj];W[ni];B[qk];W[ok];B[qe];W[kb];B[jb];W[la];B[jc];W[ob];B[ja];W[ka];B[db];W[cc];B[fe];W[cn];B[gr];W[is];B[fq];W[io];B[ji];W[eb];B[fb];W[eg];B[dj];W[dk];B[ej];W[cj];B[dh];W[ij];B[hm];W[gj];B[eh];W[fl];B[fg];W[er];B[dm];W[fn];B[dn];W[gn];B[jj];W[jk];B[kk];W[ii];B[ik];W[jl];B[kl];W[il];B[jh];W[co];B[do];W[ih];B[hn];W[hl];B[bl];W[dg];B[gh];W[ch];B[ig];W[ec];B[cr];W[fd];B[gd];W[ed];B[gc];W[bk];B[cm];W[gs];B[gp];W[li];B[kg];W[in];B[lj];W[lg];B[gm];W[jf];B[jg];W[im];B[fm];W[kf];B[lf];W[mf];B[le];W[gf];B[hf];W[ff];B[gg];W[lk];B[kj];W[km];B[lm];W[ll];B[jm];W[ge];B[he];W[ef];B[ea];W[cb];B[fr];W[fs];B[dr];W[qa];B[ra];W[pa];B[rb];W[da];B[gi];W[fj];B[fi];W[fa];B[ga];W[gl];B[ek];W[em];B[ho];W[el];B[en];W[jo];B[kn];W[ci];B[lh];W[mh];B[mg];W[di];B[ei];W[lg];B[qn];W[rn];B[re];W[sl];B[mg];W[bm];B[am];W[lg];B[eq];W[es];B[mg];W[ha];B[gb];W[lg];B[ds];W[hs];B[mg];W[sj];B[si];W[lg];B[sr];W[sq];B[mg];W[hd];B[hb];W[lg];B[ro];W[so];B[mg];W[ss];B[qs];W[lg];B[sn];W[rp];B[mg];W[cl];B[bn];W[lg];B[ml];W[mk];B[mg];W[pj];B[sf];W[lg];B[nn];W[nl];B[mg];W[ib];B[ia];W[lg];B[nc];W[nb];B[mg];W[jd];B[kd];W[lg];B[ma];W[na];B[mg];W[qc];B[rc];W[lg];B[js];W[ks];B[mg];W[hc];B[id];W[lg];B[fk];W[hj];B[mg];W[hh];B[hg];W[lg];B[gk];W[hk];B[mg];W[ak];B[lg];W[al];B[bm];W[nf];B[od];W[ki];B[ms];W[kp];B[ip];W[jp];B[lr];W[oj];B[mr];W[ea];B[sr]"
        /// 1933-10-16 Go Seigen vs Honinbo Shusai (252 moves, W+2)
        static let newFuseki = ";B[qc];W[cd];B[dp];W[pq];B[jj];W[pd];B[qd];W[pe];B[ob];W[qn];B[jp];W[lq];B[dj];W[ed];B[lo];W[nq];B[kq];W[lp];B[ko];W[ch];B[gj];W[fq];B[fo];W[iq];B[gp];W[cq];B[cp];W[dq];B[nd];W[ph];B[pj];W[ne];B[me];W[mf];B[nf];W[ng];B[oe];W[of];B[ne];W[nj];B[om];W[mg];B[ke];W[hc];B[qm];W[rm];B[rn];W[rl];B[ro];W[pm];B[ql];W[qk];B[pl];W[pn];B[pk];W[qj];B[nl];W[pi];B[qp];W[on];B[nn];W[no];B[mo];W[op];B[qr];W[qq];B[rq];W[pr];B[rr];W[mn];B[nm];W[lm];B[ll];W[kp];B[mp];W[mq];B[ip];W[jq];B[kk];W[cn];B[ep];W[cj];B[ck];W[dk];B[cl];W[dl];B[ci];W[bj];B[bi];W[di];B[ej];W[bh];B[dm];W[ei];B[fj];W[cm];B[ak];W[ai];B[el];W[bp];B[rf];W[co];B[qg];W[rh];B[jc];W[gq];B[eq];W[en];B[fn];W[er];B[fr];W[dr];B[hq];W[hr];B[hp];W[gr];B[fc];W[ic];B[dc];W[cc];B[gd];W[he];B[ge];W[je];B[hd];W[id];B[hf];W[kd];B[le];W[kc];B[og];W[oh];B[pg];W[em];B[ek];W[fm];B[gm];W[mb];B[cb];W[ec];B[eb];W[dd];B[db];W[gb];B[bc];W[bd];B[bb];W[nb];B[oa];W[fb];B[ea];W[gh];B[jf];W[ie];B[ff];W[hi];B[hg];W[eo];B[fp];W[hl];B[il];W[jh];B[fh];W[fi];B[hj];W[if];B[ih];W[ii];B[ig];W[jg];B[ji];W[fg];B[kf];W[ij];B[ik];W[hh];B[gf];W[mk];B[df];W[ml];B[sm];W[sk];B[mm];W[dg];B[li];W[ol];B[ln];W[nk];B[km];W[fl];B[gl];W[oj];B[qh];W[ri];B[cf];W[ef];B[gi];W[eh];B[ee];W[eg];B[de];W[bf];B[bq];W[br];B[ps];W[os];B[qs];W[oq];B[bo];W[aq];B[an];W[bn];B[am];W[ao];B[rg];W[mi];B[qi];W[lh];B[kh];W[lj];B[rj];W[rk];B[sh];W[sj];B[bg];W[ae];B[cg];W[ag];B[fe];W[gc];B[fd];W[ce];B[kg];W[mc];B[ki];W[fk];B[ld];W[lc];B[gk];W[bk];B[bl];W[na];B[nc];W[gg];B[fa];W[ga];B[ac];W[ad];B[lg];W[mh];B[qo];W[lk]"
        /// 2016-03-13 AlphaGo vs Lee Sedol Game 4 (180 moves, W+R)
        static let alphaGoLeeG4 = ";B[pd];W[dp];B[cd];W[qp];B[op];W[oq];B[nq];W[pq];B[cn];W[fq];B[mp];W[po];B[iq];W[ec];B[hd];W[cg];B[ed];W[cj];B[dc];W[bp];B[nc];W[qi];B[ep];W[eo];B[dk];W[fp];B[ck];W[dj];B[ej];W[ei];B[fi];W[eh];B[fh];W[bj];B[fk];W[fg];B[gg];W[ff];B[gf];W[mc];B[md];W[lc];B[nb];W[id];B[hc];W[jg];B[pj];W[pi];B[oj];W[oi];B[ni];W[nh];B[mh];W[ng];B[mg];W[mi];B[nj];W[mf];B[li];W[ne];B[nd];W[mj];B[lf];W[mk];B[me];W[nf];B[lh];W[qj];B[kk];W[ik];B[ji];W[gh];B[hj];W[ge];B[he];W[fd];B[fc];W[ki];B[jj];W[lj];B[kh];W[jh];B[ml];W[nk];B[ol];W[ok];B[pk];W[pl];B[qk];W[nl];B[kj];W[ii];B[rk];W[om];B[pg];W[ql];B[cp];W[co];B[oe];W[rl];B[sk];W[rj];B[hg];W[ij];B[km];W[gi];B[fj];W[jl];B[kl];W[gl];B[fl];W[gm];B[ch];W[ee];B[eb];W[bg];B[dg];W[eg];B[en];W[fo];B[df];W[dh];B[im];W[hk];B[bn];W[if];B[gd];W[fe];B[hf];W[ih];B[bh];W[ci];B[ho];W[go];B[or];W[rg];B[dn];W[cq];B[pr];W[qr];B[rf];W[qg];B[qf];W[jc];B[gr];W[sf];B[se];W[sg];B[rd];W[bl];B[bk];W[ak];B[cl];W[hn];B[in];W[hp];B[fr];W[er];B[es];W[ds];B[ah];W[ai];B[kd];W[ie];B[kc];W[kb];B[gk];W[ib];B[qh];W[rh];B[qs];W[rs];B[oh];W[sl];B[of];W[sj];B[ni];W[nj];B[oo];W[jp]"
        /// 1985-11-20 Nie Weiping vs Fujisawa Shuko, 1st China-Japan Supermatch Decider (245 moves, B+3.5)
        static let nieFujisawa1985 = ";B[qd];W[cc];B[pq];W[dq];B[oc];W[po];B[qo];W[qn];B[qp];W[pm];B[nq];W[qi];B[co];W[rd];B[re];W[qe];B[qf];W[pe];B[rc];W[pd];B[qc];W[rf];B[sd];W[rg];B[cf];W[dj];B[dd];W[dc];B[fd];W[ec];B[ff];W[gc];B[cl];W[fj];B[oj];W[pj];B[oi];W[pg];B[bq];W[do];B[dn];W[eo];B[en];W[fn];B[el];W[go];B[fp];W[fo];B[gl];W[jp];B[hj];W[fg];B[eg];W[fh];B[eh];W[ei];B[gf];W[hh];B[gi];W[fi];B[hg];W[ek];B[ih];W[dl];B[dm];W[fl];B[dk];W[gk];B[fm];W[hk];B[ij];W[hl];B[fk];W[gj];B[kq];W[jq];B[jr];W[ir];B[kr];W[cd];B[kj];W[hq];B[dr];W[cq];B[cp];W[cr];B[br];W[dp];B[cs];W[fl];B[ng];W[jc];B[hc];W[gb];B[fk];W[er];B[lc];W[kc];B[ld];W[je];B[of];W[pf];B[id];W[jd];B[if];W[hd];B[gd];W[he];B[ie];W[ic];B[kf];W[fl];B[rn];W[rm];B[so];W[mk];B[nk];W[np];B[mq];W[pp];B[oq];W[lk];B[rl];W[ql];B[sm];W[qm];B[mi];W[gm];B[jl];W[lm];B[cj];W[ci];B[bj];W[bi];B[od];W[oe];B[ne];W[nb];B[mc];W[lb];B[mb];W[ma];B[kb];W[la];B[ob];W[jb];B[nm];W[rk];B[jn];W[nn];B[be];W[ce];B[dh];W[di];B[bg];W[df];B[dg];W[de];B[ef];W[aj];B[ak];W[ai];B[bk];W[bd];B[io];W[kn];B[kl];W[mm];B[om];W[on];B[ip];W[iq];B[nc];W[mj];B[nj];W[gh];B[lj];W[ke];B[le];W[og];B[nf];W[jf];B[jg];W[hb];B[ge];W[em];B[dl];W[hc];B[oh];W[hf];B[gg];W[ig];B[if];W[ds];B[na];W[ka];B[bs];W[mp];B[hp];W[gp];B[kp];W[lo];B[op];W[oo];B[lp];W[ko];B[ph];W[qh];B[pc];W[qg];B[pk];W[hi];B[ii];W[ae];B[bf];W[js];B[ks];W[is];B[qj];W[pi];B[qk];W[rj];B[pl];W[sl];B[nl];W[ie];B[ig];W[hn];B[im];W[jk];B[kk];W[km];B[in];W[ik];B[jj];W[sf];B[fc];W[fb];B[ed];W[se];B[rd];W[ee];B[ro];W[fm];B[sn]"
        /// 1835-08-13 Akaboshi Intetsu vs Honinbo Jowa, Blood-Vomiting Game (246 moves, W+R)
        static let jowaBloodVomiting = ";B[cp];W[pq];B[qd];W[ed];B[oc];W[eq];B[qo];W[qk];B[qi];W[op];B[iq];W[dn];B[ep];W[dp];B[do];W[dq];B[co];W[eo];B[fp];W[cq];B[bq];W[br];B[cm];W[gr];B[hp];W[en];B[bp];W[ck];B[dl];W[dk];B[el];W[gn];B[cr];W[dr];B[bs];W[fq];B[go];W[ar];B[hn];W[gm];B[hm];W[gl];B[ek];W[hl];B[di];W[io];B[ho];W[fo];B[ch];W[cd];B[lq];W[pn];B[gc];W[qn];B[dc];W[cc];B[ec];W[cf];B[il];W[gp];B[nq];W[ic];B[fd];W[lc];B[bg];W[bf];B[af];W[bi];B[dj];W[eh];B[fj];W[qg];B[oi];W[qe];B[pd];W[nf];B[ok];W[pk];B[ol];W[pj];B[rn];W[rm];B[qq];W[qr];B[rr];W[qp];B[rq];W[pr];B[rp];W[po];B[pp];W[mp];B[qm];W[pm];B[np];W[mq];B[mo];W[lp];B[lo];W[kp];B[no];W[nr];B[or];W[qp];B[mr];W[ro];B[pi];W[lr];B[ns];W[ip];B[jr];W[hq];B[jn];W[ko];B[kq];W[kn];B[jm];W[km];B[ik];W[mk];B[mm];W[ir];B[jq];W[kk];B[mi];W[nm];B[ml];W[ki];B[lj];W[lk];B[kj];W[jj];B[kl];W[ll];B[lm];W[oj];B[mg];W[jl];B[jk];W[nj];B[ni];W[im];B[in];W[jo];B[kl];W[js];B[ks];W[jl];B[im];W[is];B[kl];W[ei];B[ej];W[jl];B[hr];W[hs];B[kl];W[cn];B[bn];W[jl];B[gs];W[fs];B[kl];W[hi];B[ij];W[jl];B[ls];W[ji];B[hj];W[oe];B[kg];W[jg];B[gi];W[nc];B[jf];W[nb];B[re];W[if];B[je];W[hd];B[fe];W[gf];B[ff];W[fg];B[gg];W[gh];B[hg];W[fi];B[gj];W[ig];B[hh];W[hf];B[ii];W[rf];B[pe];W[pf];B[le];W[kd];B[ad];W[kh];B[qf];W[ef];B[de];W[qe];B[ld];W[lg];B[kc];W[jd];B[qf];W[db];B[eb];W[qe];B[jb];W[od];B[ib];W[mf];B[qf];W[jp];B[kr];W[qe];B[lf];W[kf];B[qf];W[hc];B[qe];W[hb];B[pg];W[og];B[of];W[cg];B[bh];W[pf];B[ph];W[bb];B[da];W[cb];B[fh];W[ac];B[eg];W[bd];B[ob];W[oa];B[of];W[mh];B[rj];W[kl]"
        /// 1683-01-17 Yasui Santetsu II vs Honinbo Dosaku (258 moves, W+15)
        static let dosaku1683 = ";B[qd];W[oc];B[mc];W[dc];B[cp];W[eq];B[ce];W[ed];B[jc];W[qp];B[oq];W[kq];B[qi];W[pq];B[np];W[pn];B[on];W[oo];B[no];W[om];B[nn];W[pl];B[ko];W[ph];B[qh];W[qf];B[od];W[pg];B[pi];W[oi];B[oj];W[nj];B[ni];W[oh];B[nk];W[pj];B[mj];W[qj];B[hq];W[do];B[co];W[dn];B[cm];W[dm];B[cl];W[ip];B[hp];W[jo];B[hn];W[kn];B[pr];W[ml];B[qm];W[pm];B[dq];W[dr];B[cr];W[dp];B[cq];W[lo];B[qq];W[pp];B[rr];W[rq];B[qr];W[fp];B[gm];W[ek];B[gk];W[ei];B[df];W[im];B[dl];W[el];B[fm];W[em];B[gi];W[eg];B[fe];W[gh];B[hh];W[gg];B[hi];W[ge];B[dh];W[eh];B[fd];W[ee];B[ef];W[ff];B[fc];W[ec];B[hd];W[cd];B[ci];W[he];B[id];W[dk];B[ck];W[ie];B[kh];W[nr];B[or];W[ij];B[ji];W[jg];B[jh];W[hj];B[gj];W[hl];B[gl];W[mh];B[kk];W[lc];B[md];W[ld];B[je];W[me];B[pc];W[mb];B[ob];W[kf];B[ke];W[le];B[kb];W[nc];B[nd];W[lb];B[gd];W[kc];B[jb];W[li];B[jl];W[il];B[mg];W[nh];B[lh];W[nb];B[pb];W[jf];B[mi];W[ok];B[ll];W[mm];B[mk];W[re];B[rd];W[bf];B[dg];W[be];B[jd];W[lg];B[eb];W[db];B[fb];W[rp];B[mr];W[mq];B[nq];W[lr];B[ns];W[iq];B[gr];W[bh];B[qe];W[rf];B[of];W[nf];B[pf];W[qg];B[bi];W[fr];B[ir];W[jr];B[go];W[oe];B[pd];W[ne];B[rb];W[is];B[hr];W[cn];B[bn];W[pe];B[ds];W[es];B[er];W[bo];B[bm];W[dr];B[cs];W[fo];B[jm];W[in];B[km];W[jn];B[er];W[fs];B[da];W[ca];B[ea];W[cb];B[lp];W[kp];B[mp];W[jj];B[kj];W[fn];B[gn];W[lm];B[jk];W[lq];B[hg];W[hf];B[sq];W[sp];B[sr];W[ii];B[ih];W[de];B[dj];W[ej];B[ch];W[bg];B[nl];W[cf];B[ah];W[ag];B[ai];W[ls];B[se];W[sf];B[sd];W[ms];B[nr];W[di];B[cj];W[ig];B[ol];W[nj];B[lf];W[mf];B[oj];W[pk];B[kg];W[ng];B[op];W[po];B[mn];W[ln];B[fi];W[fh];B[la];W[oa];B[pa];W[na];B[nj];W[dr]"
        /// 1989-08-05 Takemiya Masaki vs Rin Kaiho, 2nd Fujitsu Cup Final (209 moves, B+R)
        static let takemiyaCosmic1989 = ";B[pd];W[dd];B[pp];W[dp];B[pj];W[nc];B[pf];W[jd];B[cj];W[nq];B[pn];W[pr];B[cf];W[qq];B[fc];W[df];B[dg];W[ce];B[ef];W[de];B[cg];W[fd];B[gd];W[fe];B[eb];W[db];B[dc];W[cc];B[ec];W[fg];B[cm];W[cn];B[bn];W[bo];B[co];W[dn];B[bp];W[ib];B[ao];W[do];B[hp];W[cb];B[ie];W[je];B[if];W[kg];B[id];W[jc];B[hb];W[hc];B[gc];W[ic];B[ge];W[ff];B[ih];W[kp];B[hn];W[el];B[hk];W[cl];B[dm];W[em];B[bl];W[dl];B[bm];W[dj];B[ci];W[ck];B[bk];W[qh];B[nd];W[oc];B[ph];W[pc];B[od];W[qc];B[ld];W[qg];B[qf];W[le];B[mc];W[pi];B[oi];W[me];B[md];W[pg];B[qi];W[og];B[nf];W[ri];B[rj];W[ni];B[mg];W[oh];B[lh];W[oj];B[kb];W[pi];B[kh];W[ro];B[rn];W[qo];B[qj];W[of];B[ne];W[hg];B[ig];W[pl];B[ok];W[nk];B[ql];W[pk];B[qn];W[rh];B[pm];W[ol];B[rm];W[fq];B[gq];W[fp];B[jq];W[kq];B[jp];W[ko];B[cq];W[po];B[nn];W[sj];B[rk];W[nb];B[bf];W[rf];B[re];W[rd];B[se];W[lb];B[mb];W[ma];B[ka];W[la];B[kc];W[jr];B[ir];W[kr];B[bd];W[be];B[ae];W[bc];B[ad];W[cd];B[jn];W[gm];B[gn];W[fn];B[gl];W[ac];B[af];W[oo];B[kn];W[kk];B[gr];W[dr];B[dq];W[er];B[qd];W[rc];B[fi];W[ei];B[fh];W[eg];B[eh];W[fj];B[gj];W[hm];B[im];W[cr];B[br];W[fk];B[di];W[ej];B[eo];W[go];B[eq];W[ep];B[fr];W[ho];B[in];W[cp];B[bq];W[no];B[hl];W[is];B[fm];W[fl];B[gm];W[en];B[so];W[sp];B[sn];W[rp];B[iq];W[sf];B[lo];W[ml];B[mo];W[mp];B[jk];W[kj];B[jj]"
        /// 1998-08-01 Chang Hao vs Lee Chang-ho, 11th Fujitsu Cup Final (275 moves, W+1.5)
        static let leeChangho1998 = ";B[pd];W[dp];B[pq];W[dd];B[fq];W[cn];B[fc];W[df];B[qk];W[ec];B[kd];W[id];B[jp];W[oo];B[np];W[ok];B[qm];W[pl];B[ql];W[no];B[mp];W[qp];B[qq];W[oi];B[nl];W[ol];B[nd];W[ci];B[ce];W[cd];B[fd];W[hc];B[eb];W[db];B[he];W[ie];B[if];W[jf];B[de];W[ee];B[ed];W[be];B[dc];W[ke];B[cc];W[cf];B[ld];W[hf];B[fo];W[dr];B[em];W[mo];B[lo];W[ln];B[ko];W[fr];B[gr];W[eq];B[fp];W[qc];B[qd];W[rd];B[re];W[rb];B[pb];W[pc];B[oc];W[qb];B[ob];W[qe];B[rf];W[pe];B[od];W[qg];B[qf];W[qi];B[qo];W[pf];B[sd];W[sc];B[rc];W[bc];B[cb];W[rd];B[pg];W[og];B[rc];W[pp];B[rp];W[rd];B[ph];W[of];B[rc];W[gb];B[bb];W[rd];B[qh];W[se];B[rh];W[oh];B[km];W[qj];B[rj];W[ro];B[rn];W[po];B[so];W[kb];B[lb];W[kc];B[lc];W[hr];B[gs];W[me];B[jc];W[gm];B[do];W[co];B[fs];W[er];B[hn];W[en];B[fm];W[gq];B[hq];W[gp];B[ir];W[hp];B[hs];W[fn];B[gn];W[eo];B[gl];W[go];B[ip];W[ep];B[lg];W[le];B[lj];W[jb];B[jd];W[ig];B[nj];W[oj];B[nm];W[ic];B[ka];W[ib];B[nb];W[ri];B[si];W[rk];B[sj];W[ab];B[fb];W[nk];B[mk];W[jj];B[jk];W[om];B[ij];W[dm];B[ek];W[dj];B[mh];W[kh];B[pn];W[on];B[lh];W[ni];B[mj];W[lf];B[fi];W[ii];B[hj];W[ei];B[fh];W[ej];B[fj];W[dk];B[el];W[ho];B[io];W[kj];B[kk];W[lm];B[ll];W[in];B[hm];W[kn];B[jn];W[mn];B[kg];W[ki];B[dl];W[cl];B[es];W[ds];B[hi];W[jm];B[im];W[kl];B[jl];W[km];B[ih];W[hh];B[ji];W[jh];B[ii];W[jg];B[mg];W[ne];B[eg];W[dg];B[je];W[kf];B[ge];W[gf];B[oe];W[nf];B[fe];W[gh];B[gg];W[ef];B[ad];W[ac];B[sf];W[sh];B[sg];W[sk];B[sh];W[sd];B[rl];W[mc];B[md];W[pa];B[oa];W[ma];B[la];W[mb];B[qa];W[ra];B[ff];W[pi];B[sl];W[pk];B[eh];W[dh];B[ga];W[ha];B[fa];W[gc];B[ja];W[ia];B[gi];W[hg];B[op];W[pm];B[qn];W[fg];B[cm];W[bm];B[gg];W[mi];B[li];W[fg];B[sb];W[sa];B[gg];W[nn];B[ml];W[fg];B[pa];W[gg];B[ba]"
        /// 2005-03-05 Chang Hao vs Choi Cheol-han, 5th Ing Cup Final Game 4 (314 moves, B+3)
        static let changHaoIng2005 = ";B[pd];W[dd];B[pq];W[cp];B[eq];W[qo];B[pl];W[lp];B[po];W[iq];B[cf];W[dh];B[ef];W[fd];B[dk];W[cm];B[fh];W[ce];B[bf];W[cj];B[ck];W[dj];B[ek];W[bk];B[bl];W[bj];B[do];W[fi];B[co];W[bm];B[gi];W[fj];B[bo];W[gf];B[ge];W[fe];B[ff];W[gg];B[gh];W[he];B[eh];W[fk];B[dm];W[em];B[en];W[dl];B[el];W[dn];B[fm];W[fn];B[dm];W[dg];B[df];W[em];B[eo];W[fl];B[dm];W[ii];B[cc];W[cd];B[ed];W[ee];B[hj];W[em];B[ec];W[dc];B[dm];W[qp];B[cl];W[gm];B[hl];W[em];B[db];W[de];B[fm];W[hm];B[pp];W[em];B[jk];W[qq];B[qn];W[rn];B[qm];W[rm];B[rl];W[dl];B[fc];W[gc];B[gb];W[cb];B[hc];W[gd];B[kc];W[qk];B[ql];W[qf];B[qe];W[pf];B[nd];W[pi];B[dm];W[qc];B[re];W[oc];B[od];W[nc];B[mc];W[mb];B[lb];W[md];B[lc];W[rb];B[me];W[nj];B[jm];W[jn];B[kn];W[im];B[jo];W[jl];B[in];W[il];B[ji];W[kl];B[qr];W[rr];B[pr];W[rs];B[jq];W[mn];B[jh];W[on];B[pn];W[jp];B[kp];W[kq];B[ip];W[jr];B[lq];W[jp];B[sp];W[ko];B[ro];W[ib];B[lo];W[kp];B[nb];W[ob];B[ma];W[oa];B[hb];W[ic];B[fb];W[ij];B[ih];W[ea];B[id];W[hd];B[ia];W[ik];B[hg];W[jd];B[jb];W[ie];B[kf];W[eb];B[nh];W[nf];B[mf];W[ng];B[mh];W[oh];B[fm];W[fq];B[fp];W[gq];B[er];W[gp];B[fo];W[gn];B[al];W[mq];B[ml];W[mm];B[nm];W[nn];B[om];W[ll];B[qh];W[mg];B[lg];W[nl];B[hs];W[em];B[cn];W[ke];B[le];W[pk];B[ok];W[rk];B[sk];W[sj];B[sl];W[ri];B[rg];W[rf];B[sf];W[oj];B[ac];W[bc];B[nr];W[li];B[lh];W[rh];B[qg];W[sh];B[sg];W[fr];B[fs];W[gs];B[gr];W[hr];B[bh];W[gs];B[sc];W[sb];B[gr];W[ej];B[lr];W[mr];B[ms];W[nq];B[oq];W[gs];B[pc];W[pb];B[gr];W[ak];B[fm];W[hi];B[hh];W[em];B[am];W[gj];B[ae];W[gs];B[qa];W[ra];B[gr];W[kr];B[ls];W[gs];B[es];W[jf];B[jg];W[ab];B[gr];W[nk];B[ol];W[kd];B[ld];W[jj];B[ki];W[kj];B[mi];W[lj];B[np];W[mp];B[no];W[mo];B[go];W[ho];B[gs];W[ad];B[be];W[fa];B[jc];W[id];B[ha];W[is];B[qi];W[qj];B[pg];W[og];B[sd];W[rc];B[mj];W[mk];B[ch];W[di];B[hf];W[ks];B[ns];W[oo];B[op];W[if];B[na];W[cg];B[bg];W[ai];B[ah];W[ph];B[se];W[ni];B[bd];W[bi];B[fm];W[ne];B[pe];W[of];B[ja];W[ac];B[ga];W[da]"
        /// 2009-02-23 Gu Li vs Lee Sedol, 13th LG Cup Final Game 1 (163 moves, B+R)
        static let guLiLeeSedol2009 = ";B[pd];W[dp];B[qp];W[dc];B[oq];W[qj];B[de];W[ce];B[dd];W[cd];B[ec];W[cf];B[qg];W[qm];B[db];W[cc];B[jd];W[ge];B[gc];W[pc];B[qc];W[oc];B[qb];W[ne];B[pe];W[lc];B[kb];W[kf];B[cn];W[ck];B[cq];W[cp];B[dq];W[ep];B[bp];W[bo];B[bq];W[co];B[fq];W[go];B[gq];W[io];B[jf];W[jg];B[if];W[ke];B[kd];W[ld];B[ig];W[gg];B[mf];W[kg];B[ih];W[gi];B[ki];W[mh];B[me];W[nf];B[mg];W[ng];B[lh];W[lg];B[md];W[mi];B[mc];W[ji];B[jj];W[li];B[gj];W[kj];B[fi];W[hi];B[ii];W[hj];B[jh];W[kh];B[kk];W[ji];B[fh];W[hg];B[ki];W[lj];B[en];W[dm];B[dn];W[bm];B[gn];W[hd];B[bn];W[an];B[fo];W[hc];B[le];W[hn];B[gm];W[gk];B[ek];W[fj];B[cm];W[cl];B[cj];W[bj];B[bl];W[am];B[ci];W[bk];B[dk];W[bi];B[hm];W[im];B[il];W[jm];B[jl];W[km];B[lk];W[ph];B[fb];W[fd];B[hb];W[ib];B[mm];W[kp];B[qh];W[pg];B[pf];W[je];B[nk];W[pi];B[mq];W[mp];B[np];W[mo];B[pm];W[pl];B[om];W[dl];B[lq];W[fl];B[hp];W[ip];B[jq];W[no];B[oo];W[ml];B[lm];W[fp];B[ho];W[gp];B[hq];W[ha];B[ga];W[gb];B[nd];W[qn];B[qo];W[nl];B[ol];W[nm];B[mk];W[nn];B[in];W[jn];B[pk]"
        /// 2017-05-23 Ke Jie vs AlphaGo, Future of Go Summit Game 1 (289 moves, W+0.5)
        static let alphaGoKeJieG1 = ";B[qd];W[pp];B[cc];W[cp];B[nc];W[fp];B[qq];W[pq];B[qp];W[qn];B[qo];W[po];B[rn];W[qr];B[rr];W[rm];B[pr];W[or];B[pn];W[qm];B[qs];W[on];B[dj];W[nk];B[ph];W[ch];B[cf];W[eh];B[ci];W[de];B[df];W[dc];B[cd];W[dd];B[ef];W[di];B[ei];W[dh];B[cj];W[ce];B[be];W[bf];B[bg];W[bd];B[af];W[bc];B[fi];W[cm];B[hq];W[ek];B[fh];W[gq];B[hp];W[ej];B[eq];W[gr];B[cq];W[dp];B[dq];W[ep];B[bp];W[bh];B[ah];W[bo];B[bq];W[fg];B[gg];W[kp];B[ko];W[jo];B[jn];W[in];B[jp];W[io];B[lp];W[kq];B[lq];W[kr];B[lr];W[ir];B[kn];W[il];B[oq];W[pf];B[nh];W[rf];B[od];W[qi];B[qg];W[rd];B[qf];W[qe];B[pe];W[re];B[qc];W[rg];B[kh];W[ic];B[gc];W[kc];B[jd];W[id];B[ge];W[hb];B[gb];W[jf];B[je];W[ie];B[ld];W[hg];B[eg];W[lc];B[le];W[hf];B[qh];W[rh];B[pi];W[qj];B[gk];W[fd];B[gd];W[lf];B[mf];W[lg];B[gm];W[gn];B[fn];W[go];B[dl];W[mo];B[oo];W[pm];B[op];W[mg];B[nf];W[lo];B[nn];W[lm];B[pn];W[dk];B[ck];W[cl];B[el];W[bk];B[bi];W[li];B[ii];W[ds];B[dr];W[hi];B[ik];W[jk];B[ij];W[md];B[mc];W[ke];B[me];W[kd];B[om];W[ls];B[ms];W[ks];B[nr];W[ng];B[og];W[es];B[cs];W[fr];B[er];W[fs];B[bs];W[hl];B[pl];W[ql];B[rc];W[ro];B[rp];W[sn];B[hm];W[im];B[kk];W[kj];B[lk];W[jl];B[mj];W[mi];B[nj];W[pk];B[fm];W[cn];B[ol];W[ok];B[ni];W[ih];B[ji];W[mb];B[nb];W[lb];B[fe];W[cb];B[mp];W[mm];B[eb];W[na];B[oa];W[ma];B[qb];W[bj];B[ai];W[aj];B[ag];W[gl];B[fk];W[bl];B[kg];W[kf];B[ib];W[jb];B[ga];W[ha];B[ed];W[ec];B[fc];W[gf];B[ff];W[gj];B[hk];W[hh];B[fj];W[no];B[fq];W[hr];B[kl];W[km];B[mn];W[ln];B[nl];W[db];B[da];W[ca];B[ea];W[np];B[nq];W[oj];B[oi];W[en];B[em];W[eo];B[dm];W[dn];B[sp];W[so];B[hn];W[ho];B[hc];W[ia];B[ao];W[an];B[ap];W[sc];B[sb];W[sd];B[jg];W[ad];B[gh];W[ae];B[ee];W[ml];B[mk];W[pj];B[bf];W[nm];B[on];W[he];B[ig];W[ki];B[jh];W[fl];B[jj];W[fo];B[hj];W[gi];B[ll];W[jm];B[lh];W[mh];B[lj];W[if];B[hd]"
    }
}

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
        // HALL 1: 传奇名局 (5 Masterpieces spanning Starter -> Dan)
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
            hookZh: "只需 22 手看完一盘完整胜负！从天元出发，学懂占地、切断与收官。",
            hookEn: "A complete 22-move battle from Tengen — learn territory, cutting, and endgame!",
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
            eraOrTagZh: "1846 · 日本御城棋",
            eraOrTagEn: "1846 · Historic Classic",
            titleZh: "本因坊秀策《耳赤之局》",
            titleEn: "Shusaku's Ear-Reddening Game",
            hookZh: "17 岁天才少年秀策对阵大前辈幻庵因硕！面对新招「大雪崩」，秀策用冷静大局观上演史上最传奇逆转。",
            hookEn: "17-year-old prodigy Shusaku faces Grandmaster Gennan Inseki in Go's most legendary comeback!",
            blackPlayerZh: "本因坊秀策（黑）",
            blackPlayerEn: "Honinbo Shusaku (Black)",
            whitePlayerZh: "井上幻庵因硕（白）",
            whitePlayerEn: "Inoue Gennan Inseki (White)",
            resultString: "B+2",
            boardSize: 19,
            komi: 0,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[0]C[1846年，17岁的秀策执黑迎战棋坛大前辈幻庵因硕。让我们看懂秀策标志性的「秀策流」开局与全局大势！];B[qd]C[第 1 手：黑占右上小目，开启经典的「秀策流」序幕。];W[dc]C[第 2 手：白占左上小目，针锋相对。];B[pq]C[第 3 手：黑占右下小目，黑棋稳扎稳打先拿实地。];W[oc]C[第 4 手：白棋立刻小飞挂右上角，主动挑起节奏。];B[cp]C[第 5 手：黑棋脱先占左下小目！大局观第一课：空角比局部小便宜更大！];W[cf]C[第 6 手：白棋大飞守左上角，兼顾左边。];B[ep]C[第 7 手：黑棋大飞守左下角，稳固阵地。];W[qo]C[第 8 手：白棋高挂右下角。];B[pe]C[第 9 手：这就是著名的「秀策小尖」！扎实、厚实、几乎没有破绽。];W[mp]C[第 10 手：白棋在下方夹击扩张。];B[po]C[第 11 手：黑棋贴住反击，准备在右边展开作战。];W[qp]C[第 12 手：白棋扳起，双方在右下角短兵相接。];B[oq]C[第 13 手：黑棋稳健长出，守住角地。];W[pm]C[第 14 手：白棋向右边跳出，谋求外势。];B[qi]C[第 15 手：黑棋右边大场拆边，把右上和右下遥相呼应！];W[kq]C[第 16 手：白棋下方拆边，双方进入宏大中盘。];B[jj]C[第 17 手（大局意象）：真实名局中著名的「耳赤之妙手」出现在第 127 手中腹；这里借天元一带体会秀策照耀全盘、同时牵制四方的大局观——当年连旁观医生都发现对手耳朵急得通红！];W[dj]C[第 18 手：白棋被迫加强左边，全盘主动权已悄悄落入秀策手中！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[0]C[In 1846, 17-year-old Shusaku faced Veteran Master Gennan Inseki. Watch Shusaku's serene whole-board vision!];B[qd]C[Move 1: Black takes the upper-right 3-4 Komoku — hallmark of the Shusaku Opening.];W[dc]C[Move 2: White claims the upper-left Komoku.];B[pq]C[Move 3: Black secures the lower-right corner.];W[oc]C[Move 4: White approaches the upper-right with a Knight's Move.];B[cp]C[Move 5: Tenuki! Claiming the last empty corner is bigger than answering locally.];W[cf]C[Move 6: White encloses the upper-left corner.];B[ep]C[Move 7: Black encloses the lower-left corner symmetrically.];W[qo]C[Move 8: White approaches the lower-right.];B[pe]C[Move 9: The famous 'Shusaku Kosumi' (diagonal)! Calm, solid, and virtually invincible.];W[mp]C[Move 10: White pincers along the bottom.];B[po]C[Move 11: Black attaches firmly to contest the lower-right.];W[qp]C[Move 12: White hanes to spark a sharp corner fight.];B[oq]C[Move 13: Black extends solidly to secure corner territory.];W[pm]C[Move 14: White jumps up the right side.];B[qi]C[Move 15: Black claims the huge right-side extension, linking both corners!];W[kq]C[Move 16: White stabilizes along the bottom.];B[jj]C[Move 17 (Whole-Board Spirit): In the real game, Shusaku's immortal Ear-Reddening Move came on Move 127 in the center; this central stone captures that same whole-board radiance that famously turned Inseki's ears bright red!];W[dj]C[Move 18: White must reinforce the left while Black commands the whole board.])",
            highlights: [
                AcademyHighlight(moveIndex: 5, labelZh: "脱先占空角", labelEn: "Tenuki Corner"),
                AcademyHighlight(moveIndex: 9, labelZh: "秀策小尖", labelEn: "Shusaku Kosumi"),
                AcademyHighlight(moveIndex: 17, labelZh: "照耀全盘一子", labelEn: "Whole-Board Radiance")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 8,
                promptZh: "白棋小飞挂右上角，秀策没有直接尖顶，而是下出流传百年的「秀策小尖」护角又向中央舒展——你能找到这手吗？",
                promptEn: "White approached the upper-right corner. Can you find the legendary 'Shusaku Kosumi' (diagonal)?"
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
            eraOrTagZh: "1933 · 世纪新布局",
            eraOrTagEn: "1933 · New Fuseki",
            titleZh: "吴清源《三三·星·天元》",
            titleEn: "Go Seigen: 3-3, Star & Tengen",
            hookZh: "19 岁少年吴清源挑战日本最后一位世袭名人秀哉，开局前三手打破 300 年旧规矩，震惊整个围棋界！",
            hookEn: "19-year-old Go Seigen shattered 300 years of tradition in the first 3 moves against Honinbo Shusai!",
            blackPlayerZh: "吴清源五段（黑）",
            blackPlayerEn: "Go Seigen 5p (Black)",
            whitePlayerZh: "本因坊秀哉名人（白）",
            whitePlayerEn: "Honinbo Shusai Meijin (White)",
            resultString: "W+2",
            boardSize: 19,
            komi: 0,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[0]C[1933年，19岁的吴清源执黑对阵棋坛至尊本因坊秀哉名人。前三手成为围棋史上最敢于创新的传奇！];B[qc]C[第 1 手：黑占右上「三三」！在当时，三三被视为门派禁手，吴清源第一手就打破禁忌！];W[dd]C[第 2 手：秀哉名人稳稳占左上星位。];B[dp]C[第 3 手：黑占左下「星位」！];W[pp]C[第 4 手：白占右下星位。];B[jj]C[第 5 手：惊世骇俗的「天元」！三三、星、天元连成一条斜线，宣告「新布局时代」诞生！];W[qf]C[第 6 手：秀哉名人在右边高挂，试探黑棋阵势。];B[nc]C[第 7 手：黑棋上方小飞挂护住三三外围，步调轻快。];W[nq]C[第 8 手：白棋向下方拆边。];B[kq]C[第 9 手：黑棋下方大步扩张，与天元遥相呼应！];W[pj]C[第 10 手：白棋右边拆边，稳扎稳打。];B[cf]C[第 11 手：黑棋左上挂角，全盘行棋如行云流水！];W[fc]C[第 12 手：白棋小飞守角。];B[dj]C[第 13 手：黑棋左边拆边，把左下星位与天元连成宏伟阵势！];W[jd]C[第 14 手：白棋抢占上方星位大场，世纪名局正式进入白热化！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[0]C[In 1933, 19-year-old Go Seigen played the legendary Meijin Shusai. His first 5 moves revolutionized Go forever!];B[qc]C[Move 1: The 3-3 point! Considered taboo for centuries, Go Seigen played it on Move 1!];W[dd]C[Move 2: Shusai takes the upper-left Star Point calmly.];B[dp]C[Move 3: Black takes the lower-left Star Point!];W[pp]C[Move 4: White claims the lower-right Star Point.];B[jj]C[Move 5: TENGEN (the exact center)! 3-3, Star Point, and Tengen — the birth of the 'New Fuseki'!];W[qf]C[Move 6: Shusai stakes out the right side.];B[nc]C[Move 7: Black expands swiftly along the top.];W[nq]C[Move 8: White extends along the bottom.];B[kq]C[Move 9: Black leaps out along the bottom, harmonizing with Tengen!];W[pj]C[Move 10: White builds solidly on the right.];B[cf]C[Move 11: Black approaches the upper-left with light, flowing speed!];W[fc]C[Move 12: White defends the top-left corner.];B[dj]C[Move 13: Black links the left side with Tengen into a grand framework!];W[jd]C[Move 14: White claims the top-center — the historic battle is underway!])",
            highlights: [
                AcademyHighlight(moveIndex: 1, labelZh: "打破禁忌：三三", labelEn: "Taboo 3-3"),
                AcademyHighlight(moveIndex: 5, labelZh: "惊世天元", labelEn: "Shocking Tengen"),
                AcademyHighlight(moveIndex: 13, labelZh: "天地呼应", labelEn: "Grand Harmony")
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
            eraOrTagZh: "2016 · 人机世纪大战",
            eraOrTagEn: "2016 · Man vs AI",
            titleZh: "AlphaGo vs 李世石 · 第78手神之一手",
            titleEn: "AlphaGo vs Lee Sedol: Game 4",
            hookZh: "0 比 3 绝境之下，人类世界冠军李世石在中央凌空一「挖」，令最强 AI 陷入混乱，赢下人类唯一一胜！",
            hookEn: "Down 0–3 against AlphaGo, Lee Sedol played the immortal Move 78 Wedge — humanity's lone victory!",
            blackPlayerZh: "AlphaGo（黑）",
            blackPlayerEn: "AlphaGo (Black)",
            whitePlayerZh: "李世石九段（白）",
            whitePlayerEn: "Lee Sedol 9p (White)",
            resultString: "W+R",
            boardSize: 19,
            komi: 7.5,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[7.5]C[2016年3月13日首尔，人机五番棋第四局。我们先看本局开局布局，再直击中央震撼世界的「神之一手」主题！];B[pd]C[第 1 手：AlphaGo 执黑占右上星位。];W[dp]C[第 2 手：李世石执白占左下星位。];B[cd]C[第 3 手：AlphaGo 占左上小目。];W[qp]C[第 4 手：李世石占右下小目，双方对称开局。];B[op]C[第 5 手：黑棋高挂右下角。];W[oq]C[第 6 手：李世石主动靠起反击！面对机器必须挑起复杂战斗。];B[nq]C[第 7 手：AlphaGo 冷静扳下。];W[pq]C[第 8 手：白棋退回，守住右下角实地。];B[cn]C[第 9 手：黑棋向左下挂角。];W[fq]C[第 10 手：白棋稳稳小飞守角。];B[mp]C[第 11 手：黑棋补强下方。];W[po]C[第 12 手：白棋顺势扳出，右下棋形十分厚实。];B[iq]C[第 13 手：AlphaGo 拆在下方大场。];W[ec]C[第 14 手：李世石左上挂角，全盘节奏紧凑。];B[hd]C[第 15 手：黑棋上方夹击。];W[cg]C[第 16 手：白棋左边拆边。];B[ed]C[第 17 手：黑棋靠断左上，双方展开宏大中盘纠缠，直到第 78 手李世石凌空「挖」断黑棋大网，创造人类围棋史永恒丰碑！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[7.5]C[Seoul, March 13, 2016 — Game 4 of the historic match. Follow the real opening that set up Lee Sedol's immortal Move 78!];B[pd]C[Move 1: AlphaGo opens at the upper-right Star Point.];W[dp]C[Move 2: Lee Sedol answers at the lower-left Star Point.];B[cd]C[Move 3: AlphaGo claims the upper-left Komoku.];W[qp]C[Move 4: Lee Sedol mirrors at the lower-right Komoku.];B[op]C[Move 5: AlphaGo approaches high in the lower-right.];W[oq]C[Move 6: Lee Sedol fights back directly with an attachment!];B[nq]C[Move 7: AlphaGo hanes calmly underneath.];W[pq]C[Move 8: White pulls back solidly to claim corner cash.];B[cn]C[Move 9: Black approaches the lower-left.];W[fq]C[Move 10: Lee Sedol defends smoothly with a Knight's Move.];B[mp]C[Move 11: AlphaGo reinforces the bottom group.];W[po]C[Move 12: White pushes up to keep strong central shape.];B[iq]C[Move 13: AlphaGo claims the wide bottom extension.];W[ec]C[Move 14: Lee Sedol approaches the upper-left.];B[hd]C[Move 15: AlphaGo pincers along the top.];W[cg]C[Move 16: White builds a base on the left.];B[ed]C[Move 17: AlphaGo engages in the upper-left, launching the sprawling battle that culminated in Lee Sedol's legendary Move 78 Wedge!])",
            highlights: [
                AcademyHighlight(moveIndex: 6, labelZh: "李世石靠起求战", labelEn: "Lee's Fighting Attach"),
                AcademyHighlight(moveIndex: 12, labelZh: "右下厚势定型", labelEn: "Solid Shape"),
                AcademyHighlight(moveIndex: 17, labelZh: "中盘大战开启", labelEn: "Middle-Game Clash")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 5,
                promptZh: "面对 AlphaGo 第 5 手高挂右下角，李世石没有退让，而是直接贴身「靠」上去求战——是哪一个交叉点？",
                promptEn: "AlphaGo approached high on Move 5. Where did Lee Sedol attach directly to spark a fight?"
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
            eraOrTagZh: "1985 · 中日围棋擂台赛",
            eraOrTagEn: "1985 · Supermatch",
            titleZh: "聂卫平 · 擂台赛气势布局",
            titleEn: "Nie Weiping's Supermatch Opening",
            hookZh: "中国围棋热血传奇！「棋圣」聂卫平在背水一战的擂台赛中连克强敌，看他如何用大局观掌控全盘。",
            hookEn: "Chinese Go legend Nie Weiping's fearless whole-board style in the historic China–Japan Supermatch!",
            blackPlayerZh: "聂卫平九段（黑）",
            blackPlayerEn: "Nie Weiping 9p (Black)",
            whitePlayerZh: "日本超一流棋手（白）",
            whitePlayerEn: "Japanese Master (White)",
            resultString: "B+R",
            boardSize: 19,
            komi: 5.5,
            sgfZh: "(;GM[1]FF[4]SZ[19]KM[5.5]C[1985年首届中日围棋擂台赛点燃了全中国的围棋热潮！一起来学习聂卫平最擅长的「大气磅礴大局流」！];B[pd]C[第 1 手：黑占右上星位，开阔舒展。];W[dc]C[第 2 手：白占左上小目。];B[pp]C[第 3 手：黑占右下星位，准备构筑右边「中国流」或双星阵势！];W[cp]C[第 4 手：白占左下小目。];B[ce]C[第 5 手：黑棋左上挂角，积极抢占先机。];W[ed]C[第 6 手：白棋一间高关守角。];B[eq]C[第 7 手：黑棋左下挂角，两翼同时展开！];W[dn]C[第 8 手：白棋稳健跳守左下角。];B[qf]C[第 9 手：黑棋小飞守右上角，同时遥望右下星位。];W[nq]C[第 10 手：白棋右下挂角，试图破坏黑棋右边阵势。];B[qn]C[第 11 手：黑棋小飞应守角！右边瞬间形成宏大的「三连星/中国流」气势！];W[jp]C[第 12 手：白棋下方拆边。];B[qj]C[第 13 手：黑棋右边大场镇守！上下呼应，气吞山河，这就是「前五十手天下第一」的大局观！];W[cg]C[第 14 手：白棋补强左边，双方正式展开中盘决战！])",
            sgfEn: "(;GM[1]FF[4]SZ[19]KM[5.5]C[The 1985 China–Japan Supermatch inspired millions of young players! Study Nie Weiping's bold, sweeping opening vision!];B[pd]C[Move 1: Black opens at the upper-right Star Point.];W[dc]C[Move 2: White claims the upper-left Komoku.];B[pp]C[Move 3: Double Star Points on the right — ready to build a mighty framework!];W[cp]C[Move 4: White takes the lower-left Komoku.];B[ce]C[Move 5: Black approaches the upper-left immediately.];W[ed]C[Move 6: White guards the corner solidly.];B[eq]C[Move 7: Black approaches the lower-left too — active on every front!];W[dn]C[Move 8: White defends the lower-left smoothly.];B[qf]C[Move 9: Black encloses the upper-right, eyeing the whole right side.];W[nq]C[Move 10: White approaches the lower-right to limit Black's right-side empire.];B[qn]C[Move 11: Calm Knight's defense — keeping the entire right side connected!];W[jp]C[Move 12: White settles along the bottom.];B[qj]C[Move 13: Black anchors the right side! Both corners unite into a breathtaking moyo — trademark Nie Weiping vision!];W[cg]C[Move 14: White reinforces the left as the epic middle game begins!])",
            highlights: [
                AcademyHighlight(moveIndex: 3, labelZh: "双星大局", labelEn: "Double Star Points"),
                AcademyHighlight(moveIndex: 11, labelZh: "稳健小飞应", labelEn: "Knight's Defense"),
                AcademyHighlight(moveIndex: 13, labelZh: "右边大模样", labelEn: "Right-Side Moyo")
            ],
            quizStep: AcademyQuizStep(
                beforeMoveIndex: 12,
                promptZh: "右上和右下都已经守好，黑棋第 13 手下在右边正中间的星位大场，把上下连成一片大模样——请点出来！",
                promptEn: "Both right corners are secured! Where does Black play Move 13 on the right side to unite the whole framework?"
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
}

//
//  TacticalScenarios.swift
//  StarYi Go — Preset SGF Mini-Match Scenarios (Phase 2)
//  Players drop straight into exciting midgame fights, dragon rescues, capture races, and endgame comebacks vs live AI!
//

import Foundation

enum TacticalGoal: Hashable, Codable, Sendable {
    /// First side to capture `target` stones wins (from the preset fighting position).
    case captureRace(target: Int)
    /// Capture the opponent group anchored at `targetPointSGF` within `maxPlies` total moves.
    case captureMarkedGroup(targetPointSGF: String, maxPlies: Int)
    /// Keep your own group anchored at `anchorPointSGF` alive for `survivePlies` moves (or form 2 true eyes immediately!).
    case surviveAndLive(anchorPointSGF: String, survivePlies: Int)
    /// Play out a late-game board against AI and finish ahead on points (passes or `maxPlies` triggers exact Chinese scoring).
    case endgameComeback(maxPlies: Int)

    func goalLabel(isChinese: Bool) -> String {
        switch self {
        case .captureRace(let t):
            return isChinese ? "目标：先提掉对手 \(t) 颗子获胜！" : "Goal: First to capture \(t) stones wins!"
        case .captureMarkedGroup(_, let maxPlies):
            return isChinese ? "目标：\(maxPlies) 手内吃掉标记白棋大块！" : "Goal: Capture the marked White group within \(maxPlies) moves!"
        case .surviveAndLive(_, let plies):
            return isChinese ? "目标：做出两眼活棋或守住标记黑棋 \(plies) 手！" : "Goal: Make 2 eyes or keep your marked group alive for \(plies) moves!"
        case .endgameComeback(let maxPlies):
            return isChinese ? "目标：收官实战（\(maxPlies) 手内结算）赢下目数！" : "Goal: Outplay the endgame & win on points (\(maxPlies)-move cap)!"
        }
    }
}

struct TacticalScenario: Identifiable, Hashable, Sendable {
    let id: String
    let rankBadge: String
    let titleZh: String
    let titleEn: String
    let briefingZh: String
    let briefingEn: String
    let boardSize: BoardSize
    let komi: Double
    let playerColor: StoneColor
    let opponentDifficulty: AIDifficulty
    let coachingStyle: AICoachingStyle
    let blackSetupSGF: [String]
    let whiteSetupSGF: [String]
    let goal: TacticalGoal

    func title(isChinese: Bool) -> String { isChinese ? titleZh : titleEn }
    func briefing(isChinese: Bool) -> String { isChinese ? briefingZh : briefingEn }

    func makeInitialState() -> GoBoardState {
        var s = GoBoardState(size: boardSize.rawValue, komi: komi, handicap: 0, startingTurn: playerColor)
        for p in blackSetupSGF {
            if let pt = BoardPoint(sgf: p) { s.setSetupStone(.black, at: pt) }
        }
        for p in whiteSetupSGF {
            if let pt = BoardPoint(sgf: p) { s.setSetupStone(.white, at: pt) }
        }
        s.resetPositionHistoryToCurrent()
        return s
    }

    var markedPoint: BoardPoint? {
        switch goal {
        case .captureMarkedGroup(let sgf, _): return BoardPoint(sgf: sgf)
        case .surviveAndLive(let sgf, _): return BoardPoint(sgf: sgf)
        default: return nil
        }
    }
}

enum TacticalScenariosLibrary {
    static let allScenarios: [TacticalScenario] = [
        // Sea 1 (30K - 20K): 5x5 & 7x7 Capture Race Fights
        TacticalScenario(
            id: "scn-s1-cross",
            rankBadge: "26K",
            titleZh: "5路十字吃子战",
            titleEn: "5×5 Cross-Cut Capture",
            briefingZh: "黑白在正中央短兵相接！先提掉 1 颗白子就能赢下这场启蒙实战！",
            briefingEn: "Stones clash right at the center! Be the first to capture 1 white stone to win!",
            boardSize: .five, komi: 0, playerColor: .black,
            opponentDifficulty: .sprout, coachingStyle: .capturePractice,
            blackSetupSGF: ["cc", "db"],
            whiteSetupSGF: ["cb", "dc"],
            goal: .captureRace(target: 1)
        ),
        TacticalScenario(
            id: "scn-s1-fence",
            rankBadge: "22K",
            titleZh: "7路边线围捕战",
            titleEn: "7×7 Edge Capture Sprint",
            briefingZh: "两颗白子闯进黑棋地盘，抢先提掉 3 颗白子赢得围捕战！",
            briefingEn: "White raided your territory — capture 3 white stones first to win!",
            boardSize: .seven, komi: 0, playerColor: .black,
            opponentDifficulty: .rabbit, coachingStyle: .capturePractice,
            blackSetupSGF: ["cc", "ce", "ec", "ee"],
            whiteSetupSGF: ["cd", "de", "ed"],
            goal: .captureRace(target: 3)
        ),
        TacticalScenario(
            id: "scn-s1-rescue",
            rankBadge: "20K",
            titleZh: "7路先吃五子快棋",
            titleEn: "7×7 Five-Stone Showdown",
            briefingZh: "中盘已经展开激战！保护自己的断点，抢先吃满 5 颗白子获胜！",
            briefingEn: "The fight is already underway! Guard your cuts and capture 5 stones first!",
            boardSize: .seven, komi: 0, playerColor: .black,
            opponentDifficulty: .rabbit, coachingStyle: .shapeAndConnect,
            blackSetupSGF: ["bc", "cc", "dd", "ee"],
            whiteSetupSGF: ["cb", "dc", "ed", "de"],
            goal: .captureRace(target: 5)
        ),

        // Sea 2 (19K - 12K): 9x9 Live Hunts & Dragon Rescues
        TacticalScenario(
            id: "scn-s2-hunt",
            rankBadge: "17K",
            titleZh: "围歼孤棋：吃掉标记白块",
            titleEn: "Capture the Trapped White Group",
            briefingZh: "中央两颗标记的白棋已被包围！运用枷吃/征子/紧气，在 16 手内彻底吃掉它们！",
            briefingEn: "The marked center white stones are cut off! Capture them within 16 moves!",
            boardSize: .nine, komi: 0, playerColor: .black,
            opponentDifficulty: .fox, coachingStyle: .ladderAndNet,
            blackSetupSGF: ["cc", "ec", "fc", "cf", "ef", "gg"],
            whiteSetupSGF: ["dd", "de", "ed", "gc", "cg"],
            goal: .captureMarkedGroup(targetPointSGF: "dd", maxPlies: 16)
        ),
        TacticalScenario(
            id: "scn-s2-live",
            rankBadge: "15K",
            titleZh: "绝境做活：保住角上黑龙",
            titleEn: "Dragon Rescue: Live in the Corner",
            briefingZh: "左上角黑棋被白棋重重包围！在 AI 的疯狂进攻下做出两只真眼，或坚持 12 手不死！",
            briefingEn: "Your top-left dragon is surrounded! Make 2 true eyes or survive 12 moves against AI!",
            boardSize: .nine, komi: 0, playerColor: .black,
            opponentDifficulty: .fox, coachingStyle: .capturePractice,
            blackSetupSGF: ["ab", "bb", "cb", "db", "da", "fb"],
            whiteSetupSGF: ["ac", "bc", "cc", "dc", "ec", "fc", "gc", "gb", "ga"],
            goal: .surviveAndLive(anchorPointSGF: "bb", survivePlies: 12)
        ),
        TacticalScenario(
            id: "scn-s2-race",
            rankBadge: "13K",
            titleZh: "9路中盘激战 · 吃子制胜",
            titleEn: "9×9 Midgame Capture Duel",
            briefingZh: "双方形成乱战扭十字！运用双打吃、倒扑与接不归，先提满 4 子获胜！",
            briefingEn: "A wild cross-cut battle! Use tesuji to be the first to capture 4 stones!",
            boardSize: .nine, komi: 0, playerColor: .black,
            opponentDifficulty: .deer, coachingStyle: .shapeAndConnect,
            blackSetupSGF: ["dd", "ee", "cf", "fd", "cg"],
            whiteSetupSGF: ["de", "ed", "dc", "fe", "gc"],
            goal: .captureRace(target: 4)
        ),

        // Sea 3 (11K - 5K): 9x9 & 13x13 Endgame Comebacks & Corner Fights
        TacticalScenario(
            id: "scn-s3-endgame",
            rankBadge: "10K",
            titleZh: "9路官子翻盘战",
            titleEn: "9×9 Endgame Comeback",
            briefingZh: "大局基本定型，但边线还留着好几处大官子！用二路扳粘和大伸腿在 18 手内反超白棋！",
            briefingEn: "Territory is nearly settled, but huge endgame points remain! Outscore White within 18 moves!",
            boardSize: .nine, komi: 5.5, playerColor: .black,
            opponentDifficulty: .panda, coachingStyle: .standard,
            blackSetupSGF: ["dc", "dd", "de", "df", "dg", "cc", "cg", "ch"],
            whiteSetupSGF: ["ec", "ed", "ee", "ef", "eg", "fc", "fg", "fh"],
            goal: .endgameComeback(maxPlies: 18)
        ),
        TacticalScenario(
            id: "scn-s3-kill",
            rankBadge: "8K",
            titleZh: "屠龙演练：歼灭侵入白龙",
            titleEn: "Slay the Invading Dragon",
            briefingZh: "白棋大胆打入黑棋阵势！紧住外气、封死眼位，在 18 手内吃掉标记白龙！",
            briefingEn: "White invaded deep into your framework! Seal and capture the marked group within 18 moves!",
            boardSize: .nine, komi: 0, playerColor: .black,
            opponentDifficulty: .crane, coachingStyle: .standard,
            blackSetupSGF: ["bc", "cc", "dc", "ec", "fc", "bf", "cf", "df", "ef", "ff", "bd", "be"],
            whiteSetupSGF: ["cd", "dd", "ed", "de"],
            goal: .captureMarkedGroup(targetPointSGF: "dd", maxPlies: 18)
        ),
        TacticalScenario(
            id: "scn-s3-live13",
            rankBadge: "6K",
            titleZh: "13路孤棋治孤实战",
            titleEn: "13×13 Sabaki Survival",
            briefingZh: "右边孤军深入白阵！灵活运用做眼、联络或弃子整形，守住标记黑棋 14 手不灭！",
            briefingEn: "Your group is deep inside White's sphere! Stay alive for 14 moves or build 2 eyes!",
            boardSize: .thirteen, komi: 6.5, playerColor: .black,
            opponentDifficulty: .crane, coachingStyle: .standard,
            blackSetupSGF: ["dd", "dj", "jk", "jj", "kj"],
            whiteSetupSGF: ["jd", "jg", "gj", "hj", "ij", "ji", "ki", "li", "kh", "ih"],
            goal: .surviveAndLive(anchorPointSGF: "jj", survivePlies: 14)
        ),

        // Sea 4 (4K - 5D): High-Kyu & Dan Endgame / Life-and-Death Showdowns
        TacticalScenario(
            id: "scn-s4-endgame",
            rankBadge: "3K",
            titleZh: "13路精算收官逆转",
            titleEn: "13×13 Precision Endgame",
            briefingZh: "高段级细棋胜负！抢占先手二路扳、大伸腿和逆收官子，在 22 手内以目数取胜！",
            briefingEn: "A razor-thin game! Seize every sente hane and reverse-sente point to win within 22 moves!",
            boardSize: .thirteen, komi: 6.5, playerColor: .black,
            opponentDifficulty: .tiger, coachingStyle: .standard,
            blackSetupSGF: ["fd", "fe", "ff", "fg", "fh", "fi", "fj", "ed", "ej", "dd", "dj"],
            whiteSetupSGF: ["gd", "ge", "gf", "gg", "gh", "gi", "gj", "hd", "hj", "jd", "jj"],
            goal: .endgameComeback(maxPlies: 22)
        ),
        TacticalScenario(
            id: "scn-s4-danfight",
            rankBadge: "1D",
            titleZh: "初段中盘屠龙对杀",
            titleEn: "1D Midgame Capture Fight",
            briefingZh: "双方大龙纠缠不清！与星弈青龙展开真刀真枪的对杀，抢先提掉 5 子定胜负！",
            briefingEn: "Tangled dragons against the Star Dragon! Capture 5 stones first to claim victory!",
            boardSize: .nine, komi: 0, playerColor: .black,
            opponentDifficulty: .dragon, coachingStyle: .standard,
            blackSetupSGF: ["cc", "cd", "dc", "ee", "ef", "fe", "cg", "gc"],
            whiteSetupSGF: ["dd", "de", "ed", "ce", "ec", "fc", "cf", "gg"],
            goal: .captureRace(target: 5)
        ),
        TacticalScenario(
            id: "scn-s4-master",
            rankBadge: "3D",
            titleZh: "三段收官巅峰对决",
            titleEn: "3D Master Endgame Duel",
            briefingZh: "面对朱雀三段大师的精准收官！寸土必争，在 20 手内保住黑棋微弱优势获胜！",
            briefingEn: "Face the 3D Phoenix in a razor-close 9×9 endgame! Hold the lead and win on points!",
            boardSize: .nine, komi: 5.5, playerColor: .black,
            opponentDifficulty: .phoenix, coachingStyle: .standard,
            blackSetupSGF: ["dc", "dd", "de", "df", "cg", "dg", "cb", "db"],
            whiteSetupSGF: ["ec", "ed", "ee", "ef", "eg", "fc", "fb", "fg"],
            goal: .endgameComeback(maxPlies: 20)
        )
    ]

    static func scenario(withId id: String) -> TacticalScenario? {
        allScenarios.first { $0.id == id }
    }
}

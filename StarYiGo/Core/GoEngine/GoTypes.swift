//
//  GoTypes.swift
//  StarYi Go
//

import Foundation

enum StoneColor: Int, Codable, Hashable, Sendable {
    case black = 1
    case white = 2

    var opposite: StoneColor {
        self == .black ? .white : .black
    }

    var sgfTag: String {
        self == .black ? "B" : "W"
    }
}

enum BoardSize: Int, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case five = 5
    case seven = 7
    case nine = 9
    case thirteen = 13
    case nineteen = 19

    var id: Int { rawValue }

    var defaultKomi: Double {
        switch self {
        case .five: return 2.5
        case .seven: return 3.5
        case .nine: return 5.5
        case .thirteen: return 6.5
        case .nineteen: return 7.5
        }
    }

    var starPoints: [BoardPoint] {
        switch self {
        case .five:
            return [BoardPoint(row: 2, col: 2)]
        case .seven:
            return [
                BoardPoint(row: 2, col: 2), BoardPoint(row: 2, col: 4),
                BoardPoint(row: 3, col: 3),
                BoardPoint(row: 4, col: 2), BoardPoint(row: 4, col: 4)
            ]
        case .nine:
            return [
                BoardPoint(row: 2, col: 2), BoardPoint(row: 2, col: 6),
                BoardPoint(row: 4, col: 4),
                BoardPoint(row: 6, col: 2), BoardPoint(row: 6, col: 6)
            ]
        case .thirteen:
            return [
                BoardPoint(row: 3, col: 3), BoardPoint(row: 3, col: 9),
                BoardPoint(row: 6, col: 6),
                BoardPoint(row: 9, col: 3), BoardPoint(row: 9, col: 9)
            ]
        case .nineteen:
            let coords = [3, 9, 15]
            var points: [BoardPoint] = []
            for r in coords {
                for c in coords {
                    points.append(BoardPoint(row: r, col: c))
                }
            }
            return points
        }
    }

    var maxHandicap: Int {
        switch self {
        case .five: return 0
        case .seven: return 2
        case .nine: return 4
        case .thirteen: return 5
        case .nineteen: return 9
        }
    }

    var isStarterSize: Bool {
        rawValue <= 7
    }

    var localizationKey: String {
        "board.size.\(rawValue)"
    }

    var descLocalizationKey: String {
        "board.size.\(rawValue).desc"
    }
}

/// Standard Go scoring rulesets (Chinese Area Scoring vs Japanese/Korean Territory Scoring).
enum ScoringRule: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case chinese
    case japanese

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .chinese: return "scoring.rule.chinese"
        case .japanese: return "scoring.rule.japanese"
        }
    }

    func defaultKomi(for size: BoardSize) -> Double {
        switch self {
        case .chinese:
            return size.defaultKomi
        case .japanese:
            switch size {
            case .five: return 2.5
            case .seven: return 3.5
            case .nine: return 5.5
            case .thirteen: return 5.5
            case .nineteen: return 6.5
            }
        }
    }
}

/// Official Go time control presets (Unlimited, Sudden Death, Main + Byoyomi).
enum TimeControl: Hashable, Codable, Sendable, Identifiable {
    case unlimited
    case suddenDeath(minutes: Int)
    case byoyomi(mainMinutes: Int, periodSeconds: Int, periods: Int)

    var id: String {
        switch self {
        case .unlimited: return "unlimited"
        case .suddenDeath(let m): return "sd_\(m)"
        case .byoyomi(let m, let s, let p): return "byo_\(m)_\(s)_\(p)"
        }
    }

    var isTimed: Bool {
        if case .unlimited = self { return false }
        return true
    }

    static let standardPresets: [TimeControl] = [
        .unlimited,
        .suddenDeath(minutes: 10),
        .suddenDeath(minutes: 20),
        .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
        .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3)
    ]

    func displayLabel(isChinese: Bool) -> String {
        switch self {
        case .unlimited:
            return isChinese ? "不限时" : "No Clock"
        case .suddenDeath(let m):
            return isChinese ? "\(m)分钟包干" : "\(m)m Sudden"
        case .byoyomi(let m, let s, let p):
            return isChinese ? "\(m)分+\(s)秒\(p)次" : "\(m)m+\(s)s×\(p)"
        }
    }
}

/// Progressive visual-assist graduation tiers from Starter to Exam Simulation (脱拐阶梯).
enum AssistPreset: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case starter       // Full visual aids (liberties, atari, two-eye glow, cute faces)
    case intermediate  // Hide live liberties; keep atari warning
    case examSim       // Real wooden board simulation: zero visual crutches, no undo
    case custom

    var id: String { rawValue }
}

/// Coaching styles for kid-friendly purposeful AI sparring instead of pure random blunders.
enum AICoachingStyle: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case standard
    case capturePractice
    case shapeAndConnect
    case ladderAndNet

    var id: String { rawValue }
}

/// Move quality classification for AI game review & blunder-to-puzzle conversion.
enum MoveQuality: String, Codable, Hashable, Sendable {
    case brilliant
    case good
    case inaccuracy
    case mistake
    case blunder

    var symbol: String {
        switch self {
        case .brilliant: return "!!"
        case .good: return "✓"
        case .inaccuracy: return "?!"
        case .mistake: return "?"
        case .blunder: return "??"
        }
    }
}

/// Supports both standard territory Go and kid-friendly Capture Go (吃子棋 / Atari Go).
enum GameRuleSet: Hashable, Codable, Sendable {
    case standard
    case captureRace(target: Int)

    var isCaptureRace: Bool {
        if case .captureRace = self { return true }
        return false
    }

    var captureTarget: Int? {
        if case .captureRace(let target) = self { return target }
        return nil
    }
}

struct BoardPoint: Hashable, Codable, Comparable, Sendable {
    let row: Int // 0 = top row
    let col: Int // 0 = left col

    static func < (lhs: BoardPoint, rhs: BoardPoint) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.col < rhs.col
    }

    /// Standard Go column letters (skipping 'I')
    static let columnLetters: [Character] = Array("ABCDEFGHJKLMNOPQRST")

    func humanLabel(boardSize: Int) -> String {
        let colLetter = col >= 0 && col < Self.columnLetters.count ? String(Self.columnLetters[col]) : "?"
        let rowNumber = boardSize - row
        return "\(colLetter)\(rowNumber)"
    }

    var sgfCoordinate: String {
        guard col >= 0, col < 26, row >= 0, row < 26 else { return "" }
        let c = Character(UnicodeScalar(97 + col)!)
        let r = Character(UnicodeScalar(97 + row)!)
        return "\(c)\(r)"
    }

    init(row: Int, col: Int) {
        self.row = row
        self.col = col
    }

    init?(sgf: String) {
        let chars = Array(sgf.lowercased())
        guard chars.count == 2,
              let cVal = chars[0].asciiValue,
              let rVal = chars[1].asciiValue,
              cVal >= 97, rVal >= 97 else {
            return nil
        }
        self.col = Int(cVal - 97)
        self.row = Int(rVal - 97)
    }
}

struct BoardCropRegion: Hashable, Codable, Sendable {
    let minRow: Int
    let maxRow: Int
    let minCol: Int
    let maxCol: Int

    var rowCount: Int { maxRow - minRow + 1 }
    var colCount: Int { maxCol - minCol + 1 }

    static func full(size: Int) -> BoardCropRegion {
        BoardCropRegion(minRow: 0, maxRow: size - 1, minCol: 0, maxCol: size - 1)
    }

    static func focused(around point: BoardPoint, size: Int) -> BoardCropRegion {
        let span = min(9, size)
        let row = min(max(point.row - span / 2, 0), size - span)
        let col = min(max(point.col - span / 2, 0), size - span)
        return BoardCropRegion(minRow: row, maxRow: row + span - 1, minCol: col, maxCol: col + span - 1)
    }

    func contains(_ point: BoardPoint) -> Bool {
        point.row >= minRow && point.row <= maxRow && point.col >= minCol && point.col <= maxCol
    }
}

enum MoveAction: Hashable, Codable, Sendable {
    case place(BoardPoint)
    case pass
    case resign
}

struct GoMove: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    let moveNumber: Int
    let color: StoneColor
    let action: MoveAction
    let capturedPoints: [BoardPoint]

    init(
        id: UUID = UUID(),
        moveNumber: Int,
        color: StoneColor,
        action: MoveAction,
        capturedPoints: [BoardPoint] = []
    ) {
        self.id = id
        self.moveNumber = moveNumber
        self.color = color
        self.action = action
        self.capturedPoints = capturedPoints
    }
}

enum MoveError: Error, Equatable, Sendable {
    case outOfBounds
    case occupied
    case suicide
    case koViolation
    case gameAlreadyOver

    var localizationKey: String {
        switch self {
        case .outOfBounds: return "game.status.illegal.occupied"
        case .occupied: return "game.status.illegal.occupied"
        case .suicide: return "game.status.illegal.suicide"
        case .koViolation: return "game.status.illegal.ko"
        case .gameAlreadyOver: return "result.title"
        }
    }
}

struct GoGroup: Hashable, Sendable {
    let color: StoneColor
    let stones: Set<Int>
    let liberties: Set<Int>
}

enum BoardTheme: String, CaseIterable, Codable, Identifiable, Sendable {
    case kayaWood
    case bambooJade
    case midnightStar
    case sakuraBlossom
    case oceanCoral

    var id: String { rawValue }

    var localizationKey: String {
        switch self {
        case .kayaWood: return "settings.theme.kaya"
        case .bambooJade: return "settings.theme.bamboo"
        case .midnightStar: return "settings.theme.midnight"
        case .sakuraBlossom: return "settings.theme.sakura"
        case .oceanCoral: return "settings.theme.ocean"
        }
    }

    /// Star Coins needed to unlock premium Nintendo-style cosmetic boards (free to earn by playing!).
    var unlockCoinCost: Int {
        switch self {
        case .kayaWood, .bambooJade, .midnightStar:
            return 0
        case .sakuraBlossom:
            return 60
        case .oceanCoral:
            return 120
        }
    }
}

enum GameMode: Hashable, Codable, Sendable {
    case vsAI(difficulty: AIDifficulty, playerColor: StoneColor)
    case twoPlayer
}

struct GameResult: Hashable, Codable, Sendable {
    let winner: StoneColor
    let blackScore: Double
    let whiteScore: Double
    let komi: Double
    let byResignation: Bool
    let byCaptureRace: Bool
    let captureTarget: Int?
    let byTimeout: Bool
    let scoringRule: ScoringRule
    let blackStones: Int
    let whiteStones: Int
    let blackTerritory: Int
    let whiteTerritory: Int
    let blackCaptures: Int
    let whiteCaptures: Int
    let dameCount: Int
    let sekiGroupCount: Int
    let boardSize: Int

    init(
        winner: StoneColor,
        blackScore: Double,
        whiteScore: Double,
        komi: Double,
        byResignation: Bool,
        byCaptureRace: Bool = false,
        captureTarget: Int? = nil,
        byTimeout: Bool = false,
        scoringRule: ScoringRule = .chinese,
        blackStones: Int = 0,
        whiteStones: Int = 0,
        blackTerritory: Int = 0,
        whiteTerritory: Int = 0,
        blackCaptures: Int = 0,
        whiteCaptures: Int = 0,
        dameCount: Int = 0,
        sekiGroupCount: Int = 0,
        boardSize: Int = 19
    ) {
        self.winner = winner
        self.blackScore = blackScore
        self.whiteScore = whiteScore
        self.komi = komi
        self.byResignation = byResignation
        self.byCaptureRace = byCaptureRace
        self.captureTarget = captureTarget
        self.byTimeout = byTimeout
        self.scoringRule = scoringRule
        self.blackStones = blackStones
        self.whiteStones = whiteStones
        self.blackTerritory = blackTerritory
        self.whiteTerritory = whiteTerritory
        self.blackCaptures = blackCaptures
        self.whiteCaptures = whiteCaptures
        self.dameCount = dameCount
        self.sekiGroupCount = sekiGroupCount
        self.boardSize = boardSize
    }

    var margin: Double {
        abs(blackScore - whiteScore)
    }

    /// Traditional Chinese "子" (Zi) margin (1 Zi = 2 points in area scoring), e.g., 7.5 komi = 3¾ 子.
    var chineseZiMargin: Double {
        margin / 2.0
    }

    /// Formatted traditional Chinese Zi string (e.g. "1¾ 子", "2¼ 子", "½ 子").
    static func formatChineseZi(_ zi: Double) -> String {
        let whole = Int(zi)
        let frac = zi - Double(whole)
        let fracStr: String
        if abs(frac - 0.25) < 0.05 {
            fracStr = "¼"
        } else if abs(frac - 0.5) < 0.05 {
            fracStr = "½"
        } else if abs(frac - 0.75) < 0.05 {
            fracStr = "¾"
        } else {
            fracStr = ""
        }
        if whole == 0 && !fracStr.isEmpty {
            return "\(fracStr) 子"
        }
        return "\(whole)\(fracStr) 子"
    }

    /// Human-readable Chinese rule breakdown (e.g. "黑 44.5 子 · 黑胜 1¾ 子").
    func chineseRuleSummary(isChinese: Bool) -> String {
        let baseHalf = Double(boardSize * boardSize) / 2.0
        let blackThreshold = baseHalf + komi / 2.0
        if isChinese {
            let winnerLabel = winner == .black ? "黑胜" : "白胜"
            let ziStr = Self.formatChineseZi(chineseZiMargin)
            let blackZi = String(format: "%.1f", blackScore)
            let needZi = String(format: "%.2f", blackThreshold)
            return "数子法 · 黑 \(blackZi) 子（过 \(needZi) 胜）· \(winnerLabel) \(ziStr)"
        } else {
            let winnerLabel = winner == .black ? "Black" : "White"
            return String(format: "Chinese Area · %@ +%.1f (%.2f Zi)", winnerLabel, margin, chineseZiMargin)
        }
    }

    /// Human-readable Japanese rule breakdown (Territory + Captures + Komi).
    func japaneseRuleSummary(isChinese: Bool) -> String {
        if isChinese {
            let winnerLabel = winner == .black ? "黑胜" : "白胜"
            return String(
                format: "数目法 · 黑 %d空+%d提=%.1f · 白 %d空+%d提+%.1f贴=%.1f · %@ %.1f 目",
                blackTerritory, blackCaptures, blackScore,
                whiteTerritory, whiteCaptures, komi, whiteScore,
                winnerLabel, margin
            )
        } else {
            let winnerLabel = winner == .black ? "Black" : "White"
            return String(
                format: "Japanese · B %d+%d=%.1f · W %d+%d+%.1f=%.1f · %@ +%.1f",
                blackTerritory, blackCaptures, blackScore,
                whiteTerritory, whiteCaptures, komi, whiteScore,
                winnerLabel, margin
            )
        }
    }

    var sgfResultString: String {
        let prefix = winner == .black ? "B" : "W"
        if byTimeout {
            return "\(prefix)+T"
        }
        if byCaptureRace {
            return "\(prefix)+Cap"
        }
        if byResignation {
            return "\(prefix)+R"
        }
        return String(format: "%@+%.1f", prefix, margin)
    }
}

/// Collectible Go Stone Finishes unlocked by defeating Sea Bosses or spending Star Coins (Nintendo-style tactile rewards!).
enum StoneStyle: String, CaseIterable, Codable, Identifiable, Hashable, Sendable {
    case classicSlateShell
    case coralPearl
    case kyotoLacquer
    case starlightJade

    var id: String { rawValue }

    var unlockCoinCost: Int {
        switch self {
        case .classicSlateShell: return 0
        case .coralPearl: return 60
        case .kyotoLacquer: return 120
        case .starlightJade: return 180
        }
    }

    /// Defeating this Sea Boss unlocks the stone finish for free!
    var bossUnlockIslandId: String? {
        switch self {
        case .classicSlateShell: return nil
        case .coralPearl: return "s1-lighthouse"
        case .kyotoLacquer: return "s3-sanctum"
        case .starlightJade: return "s4-zenith"
        }
    }

    var badgeEmoji: String {
        switch self {
        case .classicSlateShell: return "⚫️"
        case .coralPearl: return "🐚"
        case .kyotoLacquer: return "🍁"
        case .starlightJade: return "💎"
        }
    }

    func displayName(_ l10n: L10n) -> String {
        switch self {
        case .classicSlateShell:
            return l10n.localized(zh: "经典云子·蛤碁石", en: "Classic Slate & Shell", ja: "本蛤・那智黒石", ko: "클래식 운자·조개돌", zhHant: "經典雲子·蛤碁石")
        case .coralPearl:
            return l10n.localized(zh: "珊瑚贝壳珍珠子", en: "Coral & Ocean Pearl", ja: "珊瑚パール碁石", ko: "산호 진주 바둑돌", zhHant: "珊瑚貝殼珍珠子")
        case .kyotoLacquer:
            return l10n.localized(zh: "京都漆黑·琥珀子", en: "Kyoto Obsidian & Amber", ja: "京都漆黒・琥珀石", ko: "교토 흑요·호박돌", zhHant: "京都漆黑·琥珀子")
        case .starlightJade:
            return l10n.localized(zh: "星辰翡翠·月光石", en: "Starlight Jade & Moonstone", ja: "星彩翡翠・月光石", ko: "별빛 비취·월장석", zhHant: "星辰翡翠·月光石")
        }
    }

    func unlockHint(_ l10n: L10n) -> String {
        switch self {
        case .classicSlateShell:
            return l10n.localized(zh: "默认拥有", en: "Included", ja: "初期開放", ko: "기본 보유", zhHant: "預設擁有")
        case .coralPearl:
            return l10n.localized(zh: "击败第一海域Boss免费解锁 / 60🪙", en: "Beat Sea 1 Boss or 60🪙", ja: "第1海域ボス撃破 / 60🪙", ko: "제1해역 보스 처치 / 60🪙", zhHant: "擊敗第一海域Boss免費解鎖 / 60🪙")
        case .kyotoLacquer:
            return l10n.localized(zh: "击败第三海域Boss免费解锁 / 120🪙", en: "Beat Sea 3 Boss or 120🪙", ja: "第3海域ボス撃破 / 120🪙", ko: "제3해역 보스 처치 / 120🪙", zhHant: "擊敗第三海域Boss免費解鎖 / 120🪙")
        case .starlightJade:
            return l10n.localized(zh: "击败第四海域Boss免费解锁 / 180🪙", en: "Beat Sea 4 Boss or 180🪙", ja: "第4海域ボス撃破 / 180🪙", ko: "제4해역 보스 처치 / 180🪙", zhHant: "擊敗第四海域Boss免費解鎖 / 180🪙")
        }
    }
}

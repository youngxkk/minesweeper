//
//  DailyDojoSystem.swift
//  StarYi Go — Nintendo-Grade Daily Dojo (每日道场) Curriculum & Stamp Calendar Engine
//
//  Design Philosophy:
//  1. Zero Hints / Zero "Play Solution" in Daily Dojo: kids think, test, see the AI's refutation, and persist!
//  2. Three Bite-Sized Daily Stations (5-8 min):
//     - Station 1: Warmup Mini-Drill (rotates by weekday across 5 Go sense drills)
//     - Station 2: 3-Puzzle Progressive Theme Gauntlet (起·入门形 -> 承·变向形 -> 合·压轴挑战 / 周末错题复仇)
//     - Station 3: Interactive Daily Go Knowledge (Academy Master Move Quiz / Ten Principles / Today's Codex Term)
//  3. Physical Monthly Stamp Calendar + Milestone Treasure Chests (3 / 7 / 15 / 30 stamps)
//

import Foundation

enum DailyDojoPuzzleStage: Int, CaseIterable, Sendable {
    case intro = 0      // 起 · 入门形
    case transform = 1  // 承 · 变向实战
    case boss = 2       // 合 · 压轴挑战

    func badge(_ l10n: L10n, isRevenge: Bool = false) -> String {
        if self == .boss && isRevenge {
            return l10n.localized(
                zh: "复仇战",
                en: "Revenge",
                ja: "リベンジ",
                ko: "복수전",
                zhHant: "復仇戰"
            )
        }
        switch self {
        case .intro:
            return l10n.localized(zh: "第 1 关 · 入门", en: "Stage 1 · Intro", ja: "第1問・基本", ko: "1단계 · 기본", zhHant: "第 1 關 · 入門")
        case .transform:
            return l10n.localized(zh: "第 2 关 · 变向", en: "Stage 2 · Twist", ja: "第2問・応用", ko: "2단계 · 변형", zhHant: "第 2 關 · 變向")
        case .boss:
            return l10n.localized(zh: "第 3 关 · 压轴", en: "Stage 3 · Boss", ja: "第3問・挑戦", ko: "3단계 · 도전", zhHant: "第 3 關 · 壓軸")
        }
    }

    var forceRandomTransform: Bool {
        self == .transform
    }
}

struct DailyDojoPuzzleSlot: Identifiable, Hashable, Sendable {
    let stage: DailyDojoPuzzleStage
    let puzzle: GoPuzzle
    let isRevenge: Bool

    var id: String { "\(stage.rawValue)-\(puzzle.id)" }
}

struct StampMilestone: Identifiable, Sendable {
    let requiredStamps: Int
    let coinReward: Int
    let titleZh: String
    let titleEn: String

    var id: Int { requiredStamps }

    func title(_ l10n: L10n) -> String {
        l10n.bilingual(zh: titleZh, en: titleEn)
    }
}

struct DailyDojoPlan: Sendable {
    let dateStamp: String
    let weekday: Int // 1 = Sun, 2 = Mon, ... 7 = Sat
    let themeCodex: GoCodexEntry
    let warmupKind: MiniDrillKind
    let warmupStartOffset: Int
    let warmupCount: Int
    let coreSlots: [DailyDojoPuzzleSlot]
    let knowledgeEntry: AcademyEntry

    var corePuzzleIds: [String] {
        coreSlots.map { $0.puzzle.id }
    }

    func weekdayThemeLabel(_ l10n: L10n) -> String {
        switch weekday {
        case 2: return l10n.localized(zh: "周一 · 闪电棋感日", en: "Mon · Speed Sense", ja: "月曜・スピード棋感", ko: "월요일 · 스피드 기감", zhHant: "週一 · 閃電棋感日")
        case 3: return l10n.localized(zh: "周二 · 征子算路日", en: "Tue · Ladder Reading", ja: "火曜・シチョウ読み", ko: "화요일 · 축 수읽기", zhHant: "週二 · 征子算路日")
        case 4: return l10n.localized(zh: "周三 · 捉虫改错日", en: "Wed · Blunder Buster", ja: "水曜・悪手発見", ko: "수요일 · 악수 찾기", zhHant: "週三 · 捉蟲改錯日")
        case 5: return l10n.localized(zh: "周四 · 气紧敏锐日", en: "Thu · Atari Vision", ja: "木曜・アタリ特訓", ko: "목요일 · 단수 특훈", zhHant: "週四 · 氣緊敏銳日")
        case 6: return l10n.localized(zh: "周五 · 深度盲算日", en: "Fri · Deep Reading", ja: "金曜・読みの特訓", ko: "금요일 · 깊은 수읽기", zhHant: "週五 · 深度盲算日")
        case 7: return l10n.localized(zh: "周六 · 大局布局日", en: "Sat · Opening Sense", ja: "土曜・布石の大局観", ko: "토요일 · 포석 대국관", zhHant: "週六 · 大局佈局日")
        default: return l10n.localized(zh: "周日 · 形势收官日", en: "Sun · Territory & Endgame", ja: "日曜・形勢判断", ko: "일요일 · 형세판단", zhHant: "週日 · 形勢收官日")
        }
    }
}

enum DailyDojoSystem {
    static let stampMilestones: [StampMilestone] = [
        StampMilestone(requiredStamps: 3, coinReward: 30, titleZh: "道场新芽", titleEn: "Dojo Sprout"),
        StampMilestone(requiredStamps: 7, coinReward: 60, titleZh: "七日精进", titleEn: "7-Day Focus"),
        StampMilestone(requiredStamps: 15, coinReward: 120, titleZh: "半月棋士", titleEn: "15-Day Tactician"),
        StampMilestone(requiredStamps: 30, coinReward: 250, titleZh: "满月宗师", titleEn: "30-Day Master")
    ]

    /// Deterministic daily plan tailored to the player's certified rank tier & mistake book.
    static func plan(
        for date: Date = Date(),
        certifiedRankTier: Int,
        mistakeBookIds: [String] = [],
        puzzleLookup: (String) -> GoPuzzle? = { id in
            GoTermCodex.codexPracticePuzzles.first(where: { $0.id == id })
                ?? DojoPuzzleBank.findPuzzle(withId: id)
                ?? PuzzlePackLoader.findPuzzle(withId: id)
                ?? StarYiIslands.findAnyPuzzle(withId: id)
        }
    ) -> DailyDojoPlan {
        let cal = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        let year = cal.component(.year, from: date)
        let weekday = cal.component(.weekday, from: date) // 1=Sun ... 7=Sat
        let seed = max(1, (year - 2024) * 366 + dayOfYear)
        let stamp = StorageService.todayStamp(date: date)

        // 1. Daily Theme Codex Term (rank-tier appropriate)
        let allowedTiers: [CodexTier] = {
            switch certifiedRankTier {
            case ...1: return [.starter, .tactics]
            case 2...3: return [.starter, .tactics, .fighting]
            case 4: return [.tactics, .fighting]
            default: return [.tactics, .fighting, .mastery]
            }
        }()
        let codexPool = GoTermCodex.allEntries.filter { allowedTiers.contains($0.tier) }
        let themeCodex = codexPool.isEmpty
            ? GoTermCodex.allEntries[0]
            : codexPool[seed % codexPool.count]

        // 2. Station 1: Weekday Warmup Drill
        let warmupKind: MiniDrillKind
        let warmupCount: Int
        switch weekday {
        case 2, 5: // Mon, Thu
            warmupKind = .speedLiberties
            warmupCount = 3
        case 3, 6: // Tue, Fri
            warmupKind = .ladderReading
            warmupCount = 2
        case 4: // Wed
            warmupKind = .blunderSpotter
            warmupCount = 2
        case 7: // Sat
            warmupKind = .openingPicker
            warmupCount = 2
        default: // Sun
            warmupKind = .countingQuiz
            warmupCount = 2
        }
        let warmupOffset = seed % 12

        // 3. Station 2: 3-Puzzle Progressive Theme Gauntlet (Intro -> Twist -> Boss/Revenge)
        let targetRange: ClosedRange<Int> = {
            switch certifiedRankTier {
            case ...1: return 18...30
            case 2:    return 14...22
            case 3:    return 10...17
            case 4:    return 6...13
            case 5:    return 1...8
            default:   return -4...2
            }
        }()
        let rankPool = PuzzlePackLoader.allUniqueTemplates
            .filter { targetRange.contains($0.rankOrderValue) }
            .sorted { $0.rankOrderValue > $1.rankOrderValue } // easier -> harder
        let fallbackPool = rankPool.isEmpty ? BuiltInPuzzleLibrary.allPuzzles : rankPool

        // Slot 1 (Intro): prefer themeCodex's direct practice puzzle if available!
        let introPuzzle: GoPuzzle = puzzleLookup(themeCodex.practicePuzzleId)
            ?? fallbackPool[seed % fallbackPool.count]

        // Slot 2 (Twist): pick a distinct puzzle from the middle of rankPool (will be rotated/flipped!)
        let midPool = fallbackPool.filter { $0.id != introPuzzle.id }
        let twistPuzzle: GoPuzzle = midPool.isEmpty
            ? fallbackPool[(seed + 1) % fallbackPool.count]
            : midPool[(seed * 3 + 1) % midPool.count]

        // Slot 3 (Boss or Weekend Revenge): on Sat/Sun if mistakeBook has a valid puzzle, make it a Revenge Battle!
        let isWeekend = (weekday == 1 || weekday == 7)
        var isRevenge = false
        var bossPuzzle: GoPuzzle? = nil
        if isWeekend, let firstMistakeId = mistakeBookIds.first(where: { $0 != introPuzzle.id && $0 != twistPuzzle.id }),
           let revenge = puzzleLookup(firstMistakeId) {
            bossPuzzle = revenge
            isRevenge = true
        }
        if bossPuzzle == nil {
            // Slightly harder puzzle in the upper half of rankPool (lower rankOrderValue = harder)
            let harderSlice = fallbackPool.filter { $0.id != introPuzzle.id && $0.id != twistPuzzle.id }
            if !harderSlice.isEmpty {
                let startIdx = harderSlice.count / 2
                let upperCount = max(1, harderSlice.count - startIdx)
                bossPuzzle = harderSlice[startIdx + (seed * 5) % upperCount]
            } else {
                bossPuzzle = fallbackPool[(seed + 2) % fallbackPool.count]
            }
        }

        let coreSlots: [DailyDojoPuzzleSlot] = [
            DailyDojoPuzzleSlot(stage: .intro, puzzle: introPuzzle, isRevenge: false),
            DailyDojoPuzzleSlot(stage: .transform, puzzle: twistPuzzle, isRevenge: false),
            DailyDojoPuzzleSlot(stage: .boss, puzzle: bossPuzzle ?? introPuzzle, isRevenge: isRevenge)
        ]

        // 4. Station 3: Interactive Knowledge Lesson (prefer entries with Quiz or Counter-Example!)
        let allowedLevels: [AcademyLevel] = {
            switch certifiedRankTier {
            case ...2: return [.starter, .intermediate]
            case 3...4: return [.starter, .intermediate, .advanced]
            default: return [.intermediate, .advanced, .dan]
            }
        }()
        let interactiveAcademy = GoAcademyLibrary.allEntries.filter {
            allowedLevels.contains($0.level) && ($0.hasQuiz || $0.hasCounterExample)
        }
        let academyPool = interactiveAcademy.isEmpty ? GoAcademyLibrary.allEntries : interactiveAcademy
        let knowledgeEntry = academyPool[seed % academyPool.count]

        return DailyDojoPlan(
            dateStamp: stamp,
            weekday: weekday,
            themeCodex: themeCodex,
            warmupKind: warmupKind,
            warmupStartOffset: warmupOffset,
            warmupCount: warmupCount,
            coreSlots: coreSlots,
            knowledgeEntry: knowledgeEntry
        )
    }

    /// Computes how many of the 3 Daily Dojo stations are complete (0...3) for a given profile & plan.
    static func completedStationsCount(profile: UserProfile, plan: DailyDojoPlan) -> Int {
        guard profile.dailyDojoDateStamp == plan.dateStamp else { return 0 }
        var count = 0
        if profile.dailyDojoWarmupDone { count += 1 }
        if isCoreStationDone(profile: profile, plan: plan) { count += 1 }
        if profile.dailyDojoKnowledgeDone { count += 1 }
        return count
    }

    static func isCoreStationDone(profile: UserProfile, plan: DailyDojoPlan) -> Bool {
        guard profile.dailyDojoDateStamp == plan.dateStamp else { return false }
        let requiredIds = Set(plan.corePuzzleIds)
        return !requiredIds.isEmpty && requiredIds.isSubset(of: profile.dailyDojoCoreSolvedIds)
    }

    static func coreSolvedCount(profile: UserProfile, plan: DailyDojoPlan) -> Int {
        guard profile.dailyDojoDateStamp == plan.dateStamp else { return 0 }
        return plan.coreSlots.filter { profile.dailyDojoCoreSolvedIds.contains($0.puzzle.id) }.count
    }
}

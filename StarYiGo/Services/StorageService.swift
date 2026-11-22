//
//  StorageService.swift
//  StarYi Go
//

import Foundation

struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    var id: UUID = UUID()
    var nickname: String = "StarPlayer"
    var avatarEmoji: String = "🦊"
    var xp: Int = 0
    var starCoins: Int = 0
    var totalWins: Int = 0
    var totalCaptures: Int = 0
    var dailyGoalTarget: Int = 5
    var dailyCompletedCount: Int = 0
    var dailyDateStamp: String = ""
    var dailyChallengeCompletedStamp: String = ""
    var dailyStreak: Int = 0
    var lastStreakDateStamp: String = ""
    /// Dual-track Go growth: real rank earned by clearing islands & defeating Island Masters (0=25K ... 6=1D).
    var certifiedRankTier: Int = 0
    /// Cosmetic unlockables earned with Star Coins
    var unlockedThemeIds: Set<String> = ["kayaWood", "bambooJade", "midnightStar"]
    /// Authentic Go Terms & Tactics collected in the Go Codex
    var unlockedCodexIds: Set<String> = GoTermCodex.defaultUnlockedIds

    /// Fun Nintendo Adventure Level (always grows with play, distinct from Certified Go Rank).
    var adventureLevel: Int {
        max(1, 1 + xp / 60)
    }

    /// Authentic Certified Go Rank earned via Island Milestones & Rank Certification Exams (not inflated by losses!).
    var rankString: String {
        switch certifiedRankTier {
        case 0: return "25K"
        case 1: return "22K"
        case 2: return "18K"
        case 3: return "15K"
        case 4: return "10K"
        case 5: return "5K"
        case 6: return "1D"
        default: return "3D"
        }
    }

    init(
        id: UUID = UUID(),
        nickname: String = "StarPlayer",
        avatarEmoji: String = "🦊",
        xp: Int = 0,
        starCoins: Int = 0,
        totalWins: Int = 0,
        totalCaptures: Int = 0,
        dailyGoalTarget: Int = 5,
        dailyCompletedCount: Int = 0,
        dailyDateStamp: String = "",
        dailyChallengeCompletedStamp: String = "",
        dailyStreak: Int = 0,
        lastStreakDateStamp: String = "",
        certifiedRankTier: Int = 0,
        unlockedThemeIds: Set<String> = ["kayaWood", "bambooJade", "midnightStar"],
        unlockedCodexIds: Set<String> = GoTermCodex.defaultUnlockedIds
    ) {
        self.id = id
        self.nickname = nickname
        self.avatarEmoji = avatarEmoji
        self.xp = xp
        self.starCoins = starCoins
        self.totalWins = totalWins
        self.totalCaptures = totalCaptures
        self.dailyGoalTarget = dailyGoalTarget
        self.dailyCompletedCount = dailyCompletedCount
        self.dailyDateStamp = dailyDateStamp
        self.dailyChallengeCompletedStamp = dailyChallengeCompletedStamp
        self.dailyStreak = dailyStreak
        self.lastStreakDateStamp = lastStreakDateStamp
        self.certifiedRankTier = certifiedRankTier
        self.unlockedThemeIds = unlockedThemeIds
        self.unlockedCodexIds = unlockedCodexIds
    }

    /// Backwards-compatible decoder so existing saved profiles migrate smoothly with zero data loss.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        nickname = try c.decodeIfPresent(String.self, forKey: .nickname) ?? "StarPlayer"
        avatarEmoji = try c.decodeIfPresent(String.self, forKey: .avatarEmoji) ?? "🦊"
        xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        starCoins = try c.decodeIfPresent(Int.self, forKey: .starCoins) ?? max(0, xp / 2)
        totalWins = try c.decodeIfPresent(Int.self, forKey: .totalWins) ?? 0
        totalCaptures = try c.decodeIfPresent(Int.self, forKey: .totalCaptures) ?? 0
        dailyGoalTarget = try c.decodeIfPresent(Int.self, forKey: .dailyGoalTarget) ?? 5
        dailyCompletedCount = try c.decodeIfPresent(Int.self, forKey: .dailyCompletedCount) ?? 0
        dailyDateStamp = try c.decodeIfPresent(String.self, forKey: .dailyDateStamp) ?? ""
        dailyChallengeCompletedStamp = try c.decodeIfPresent(String.self, forKey: .dailyChallengeCompletedStamp) ?? ""
        dailyStreak = try c.decodeIfPresent(Int.self, forKey: .dailyStreak) ?? 0
        lastStreakDateStamp = try c.decodeIfPresent(String.self, forKey: .lastStreakDateStamp) ?? ""
        certifiedRankTier = try c.decodeIfPresent(Int.self, forKey: .certifiedRankTier) ?? 0
        unlockedThemeIds = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedThemeIds) ?? ["kayaWood", "bambooJade", "midnightStar"]
        unlockedCodexIds = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedCodexIds) ?? GoTermCodex.defaultUnlockedIds
    }
}

struct PuzzleProgressStore: Codable, Equatable, Sendable {
    /// puzzleId -> best star count (1...3)
    var starsByPuzzleId: [String: Int] = [:]
    /// puzzleIds where the player made a mistake and hasn't mastered yet (kept in sync with SRS items)
    var mistakeBookIds: [String] = []
    /// Spaced-repetition mistake review schedule (1d -> 3d -> 7d -> mastered)
    var srsMistakeItems: [SRSMistakeItem] = []
    /// Custom puzzles generated from the player's own game blunders in AI Review!
    var customMistakePuzzles: [GoPuzzle] = []
    /// Completed Joseki interactive courses
    var completedJosekiIds: Set<String> = []
    /// Authentic Dual-Requirement Rank Exam records
    var rankExamRecord: RankExamRecord = RankExamRecord()
    /// Island IDs whose Island Master Boss Duel has been won
    var defeatedBossIslandIds: Set<String> = []
    /// Starter 5x5 Bootcamp lesson completion stars
    var starterBootcampStars: [String: Int] = [:]

    var totalStars: Int {
        starsByPuzzleId.values.reduce(0, +) + starterBootcampStars.values.reduce(0, +)
    }

    var solvedCount: Int {
        starsByPuzzleId.count
    }

    var dueSRSCount: Int {
        srsMistakeItems.filter(\.isDueNow).count
    }

    init(
        starsByPuzzleId: [String: Int] = [:],
        mistakeBookIds: [String] = [],
        srsMistakeItems: [SRSMistakeItem] = [],
        customMistakePuzzles: [GoPuzzle] = [],
        completedJosekiIds: Set<String> = [],
        rankExamRecord: RankExamRecord = RankExamRecord(),
        defeatedBossIslandIds: Set<String> = [],
        starterBootcampStars: [String: Int] = [:]
    ) {
        self.starsByPuzzleId = starsByPuzzleId
        self.mistakeBookIds = mistakeBookIds
        self.srsMistakeItems = srsMistakeItems
        self.customMistakePuzzles = customMistakePuzzles
        self.completedJosekiIds = completedJosekiIds
        self.rankExamRecord = rankExamRecord
        self.defeatedBossIslandIds = defeatedBossIslandIds
        self.starterBootcampStars = starterBootcampStars
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        starsByPuzzleId = try c.decodeIfPresent([String: Int].self, forKey: .starsByPuzzleId) ?? [:]
        mistakeBookIds = try c.decodeIfPresent([String].self, forKey: .mistakeBookIds) ?? []
        srsMistakeItems = try c.decodeIfPresent([SRSMistakeItem].self, forKey: .srsMistakeItems)
            ?? mistakeBookIds.map { SRSMistakeItem.initial(puzzleId: $0) }
        customMistakePuzzles = try c.decodeIfPresent([GoPuzzle].self, forKey: .customMistakePuzzles) ?? []
        completedJosekiIds = try c.decodeIfPresent(Set<String>.self, forKey: .completedJosekiIds) ?? []
        rankExamRecord = try c.decodeIfPresent(RankExamRecord.self, forKey: .rankExamRecord) ?? RankExamRecord()
        defeatedBossIslandIds = try c.decodeIfPresent(Set<String>.self, forKey: .defeatedBossIslandIds) ?? []
        starterBootcampStars = try c.decodeIfPresent([String: Int].self, forKey: .starterBootcampStars) ?? [:]
    }
}

struct SavedGameRecord: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let boardSize: Int
    let komi: Double
    let handicap: Int
    let blackName: String
    let whiteName: String
    let resultString: String
    let moveCount: Int
    let sgf: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        boardSize: Int,
        komi: Double,
        handicap: Int,
        blackName: String,
        whiteName: String,
        resultString: String,
        moveCount: Int,
        sgf: String
    ) {
        self.id = id
        self.date = date
        self.boardSize = boardSize
        self.komi = komi
        self.handicap = handicap
        self.blackName = blackName
        self.whiteName = whiteName
        self.resultString = resultString
        self.moveCount = moveCount
        self.sgf = sgf
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var language: AppLanguage = .system
    var boardTheme: BoardTheme = .kayaWood
    var scoringRule: ScoringRule = .chinese
    var assistPreset: AssistPreset = .starter
    var confirmBeforePlace: Bool = true
    var showCoordinates: Bool = true
    var showMoveNumbers: Bool = false
    var highlightAtari: Bool = true
    var expressiveStones: Bool = true
    var showLiveLiberties: Bool = true
    var zenDojoMode: Bool = false
    var antiImpulseGuard: Bool = false
    var autoTransformPuzzles: Bool = false
    var soundEnabled: Bool = true
    var bgmEnabled: Bool = true
    var hapticsEnabled: Bool = true
    var eyeCareMinutes: Int = 25 // 0 = off

    var preferredBoardSize: BoardSize = .thirteen
    var preferredDifficulty: AIDifficulty = .fox
    var preferredPlayerColor: StoneColor = .black
    var preferredHandicap: Int = 0
    var preferredRuleSet: GameRuleSet = .standard
    var preferredTimeControl: TimeControl = .unlimited
    var preferredCoachingStyle: AICoachingStyle = .standard

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        language = try c.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        boardTheme = try c.decodeIfPresent(BoardTheme.self, forKey: .boardTheme) ?? .kayaWood
        scoringRule = try c.decodeIfPresent(ScoringRule.self, forKey: .scoringRule) ?? .chinese
        assistPreset = try c.decodeIfPresent(AssistPreset.self, forKey: .assistPreset) ?? .starter
        confirmBeforePlace = try c.decodeIfPresent(Bool.self, forKey: .confirmBeforePlace) ?? true
        showCoordinates = try c.decodeIfPresent(Bool.self, forKey: .showCoordinates) ?? true
        showMoveNumbers = try c.decodeIfPresent(Bool.self, forKey: .showMoveNumbers) ?? false
        highlightAtari = try c.decodeIfPresent(Bool.self, forKey: .highlightAtari) ?? true
        expressiveStones = try c.decodeIfPresent(Bool.self, forKey: .expressiveStones) ?? true
        showLiveLiberties = try c.decodeIfPresent(Bool.self, forKey: .showLiveLiberties) ?? true
        zenDojoMode = try c.decodeIfPresent(Bool.self, forKey: .zenDojoMode) ?? false
        antiImpulseGuard = try c.decodeIfPresent(Bool.self, forKey: .antiImpulseGuard) ?? false
        autoTransformPuzzles = try c.decodeIfPresent(Bool.self, forKey: .autoTransformPuzzles) ?? false
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        bgmEnabled = try c.decodeIfPresent(Bool.self, forKey: .bgmEnabled) ?? true
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        eyeCareMinutes = try c.decodeIfPresent(Int.self, forKey: .eyeCareMinutes) ?? 25
        preferredBoardSize = try c.decodeIfPresent(BoardSize.self, forKey: .preferredBoardSize) ?? .thirteen
        preferredDifficulty = try c.decodeIfPresent(AIDifficulty.self, forKey: .preferredDifficulty) ?? .fox
        preferredPlayerColor = try c.decodeIfPresent(StoneColor.self, forKey: .preferredPlayerColor) ?? .black
        preferredHandicap = try c.decodeIfPresent(Int.self, forKey: .preferredHandicap) ?? 0
        preferredRuleSet = try c.decodeIfPresent(GameRuleSet.self, forKey: .preferredRuleSet) ?? .standard
        preferredTimeControl = try c.decodeIfPresent(TimeControl.self, forKey: .preferredTimeControl) ?? .unlimited
        preferredCoachingStyle = try c.decodeIfPresent(AICoachingStyle.self, forKey: .preferredCoachingStyle) ?? .standard
    }
}

final class StorageService {
    static let shared = StorageService()

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let profile = "starpoint.userProfile.v1"
        static let familyProfiles = "starpoint.familyProfiles.v1"
        static let puzzles = "starpoint.puzzleProgress.v1"
        static let archive = "starpoint.savedGames.v1"
        static let settings = "starpoint.appSettings.v1"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadProfile() -> UserProfile {
        var profile = load(UserProfile.self, forKey: Keys.profile) ?? defaultStarterProfile()
        normalizeDailyCounters(&profile)
        return profile
    }

    func saveProfile(_ profile: UserProfile) {
        save(profile, forKey: Keys.profile)
        var family = loadFamilyProfiles()
        if let idx = family.firstIndex(where: { $0.id == profile.id }) {
            family[idx] = profile
        } else {
            family.insert(profile, at: 0)
        }
        save(family, forKey: Keys.familyProfiles)
    }

    func loadFamilyProfiles() -> [UserProfile] {
        var list = load([UserProfile].self, forKey: Keys.familyProfiles) ?? []
        if list.isEmpty {
            let current = load(UserProfile.self, forKey: Keys.profile) ?? defaultStarterProfile()
            list = [current]
        }
        return list
    }

    func saveFamilyProfiles(_ profiles: [UserProfile]) {
        save(profiles, forKey: Keys.familyProfiles)
    }

    func loadPuzzleProgress(for profileId: UUID? = nil) -> PuzzleProgressStore {
        if let profileId,
           let perProfile = load(PuzzleProgressStore.self, forKey: "\(Keys.puzzles).\(profileId.uuidString)") {
            return perProfile
        }
        return load(PuzzleProgressStore.self, forKey: Keys.puzzles) ?? PuzzleProgressStore()
    }

    func savePuzzleProgress(_ store: PuzzleProgressStore, for profileId: UUID? = nil) {
        save(store, forKey: Keys.puzzles)
        if let profileId {
            save(store, forKey: "\(Keys.puzzles).\(profileId.uuidString)")
        }
    }

    func loadSavedGames() -> [SavedGameRecord] {
        load([SavedGameRecord].self, forKey: Keys.archive) ?? []
    }

    func saveSavedGames(_ games: [SavedGameRecord]) {
        save(games, forKey: Keys.archive)
    }

    func loadSettings() -> AppSettings {
        load(AppSettings.self, forKey: Keys.settings) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        save(settings, forKey: Keys.settings)
    }

    func defaultStarterProfile() -> UserProfile {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let name: String
        if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
            name = "星弈小棋士"
        } else if preferred.hasPrefix("zh") {
            name = "星弈小棋士"
        } else if preferred.hasPrefix("ja") {
            name = "StarYiチャレンジャー"
        } else if preferred.hasPrefix("ko") {
            name = "화점 도전자"
        } else {
            name = "Star Player"
        }
        return UserProfile(nickname: name)
    }

    private func normalizeDailyCounters(_ profile: inout UserProfile) {
        let today = Self.todayStamp()
        if profile.dailyDateStamp != today {
            profile.dailyDateStamp = today
            profile.dailyCompletedCount = 0
        }
    }

    static func todayStamp(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func yesterdayStamp(date: Date = Date()) -> String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        return todayStamp(date: yesterday)
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? encoder.encode(value) {
            defaults.set(data, forKey: key)
        }
    }
}

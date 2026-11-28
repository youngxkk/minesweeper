//
//  StorageService.swift
//  StarYi Go
//

import Foundation
import os
import UIKit

struct UserProfile: Identifiable, Codable, Equatable, Sendable {
    /// Visual-width cap for family profile nicknames:
    /// CJK / full-width / emoji characters count as 2 units (up to 10 CJK chars),
    /// ASCII / Latin characters count as 1 unit (up to 20 English chars).
    static let maxNicknameUnits: Int = 20

    static func nicknameUnitWeight(for character: Character) -> Int {
        if character.unicodeScalars.count == 1, let scalar = character.unicodeScalars.first, scalar.isASCII {
            return 1
        }
        return 2
    }

    static func clampedNickname(_ raw: String) -> String {
        var result = ""
        var usedUnits = 0
        for ch in raw {
            let weight = nicknameUnitWeight(for: ch)
            if usedUnits + weight > maxNicknameUnits {
                break
            }
            result.append(ch)
            usedUnits += weight
        }
        return result
    }

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
    /// Cosmetic unlockables earned with Star Coins or Sea Boss victories
    var unlockedThemeIds: Set<String> = ["kayaWood", "bambooJade", "midnightStar"]
    var unlockedStoneStyleIds: Set<String> = [StoneStyle.classicSlateShell.rawValue]
    /// Authentic Go Terms & Tactics collected in the Go Codex
    var unlockedCodexIds: Set<String> = GoTermCodex.defaultUnlockedIds
    /// Academy masterpieces / principles / openings / wonders stamped as "已赏析 ★"
    var studiedAcademyIds: Set<String> = []
    /// Nintendo-style Daily Dojo (每日道场) daily state & Stamp Calendar
    var dailyDojoDateStamp: String = ""
    var dailyDojoWarmupDone: Bool = false
    var dailyDojoCoreSolvedIds: Set<String> = []
    var dailyDojoCoreFirstTryIds: Set<String> = []
    var dailyDojoKnowledgeDone: Bool = false
    var dailyDojoStampClaimedToday: Bool = false
    var dailyDojoStampDates: Set<String> = []
    var claimedStampMilestones: Set<Int> = []

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
        case 7: return "3D"
        default: return "5D"
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
        unlockedStoneStyleIds: Set<String> = [StoneStyle.classicSlateShell.rawValue],
        unlockedCodexIds: Set<String> = GoTermCodex.defaultUnlockedIds,
        studiedAcademyIds: Set<String> = [],
        dailyDojoDateStamp: String = "",
        dailyDojoWarmupDone: Bool = false,
        dailyDojoCoreSolvedIds: Set<String> = [],
        dailyDojoCoreFirstTryIds: Set<String> = [],
        dailyDojoKnowledgeDone: Bool = false,
        dailyDojoStampClaimedToday: Bool = false,
        dailyDojoStampDates: Set<String> = [],
        claimedStampMilestones: Set<Int> = []
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
        self.unlockedStoneStyleIds = unlockedStoneStyleIds
        self.unlockedCodexIds = unlockedCodexIds
        self.studiedAcademyIds = studiedAcademyIds
        self.dailyDojoDateStamp = dailyDojoDateStamp
        self.dailyDojoWarmupDone = dailyDojoWarmupDone
        self.dailyDojoCoreSolvedIds = dailyDojoCoreSolvedIds
        self.dailyDojoCoreFirstTryIds = dailyDojoCoreFirstTryIds
        self.dailyDojoKnowledgeDone = dailyDojoKnowledgeDone
        self.dailyDojoStampClaimedToday = dailyDojoStampClaimedToday
        self.dailyDojoStampDates = dailyDojoStampDates
        self.claimedStampMilestones = claimedStampMilestones
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
        unlockedStoneStyleIds = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedStoneStyleIds) ?? [StoneStyle.classicSlateShell.rawValue]
        unlockedCodexIds = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedCodexIds) ?? GoTermCodex.defaultUnlockedIds
        studiedAcademyIds = try c.decodeIfPresent(Set<String>.self, forKey: .studiedAcademyIds) ?? []
        dailyDojoDateStamp = try c.decodeIfPresent(String.self, forKey: .dailyDojoDateStamp) ?? ""
        dailyDojoWarmupDone = try c.decodeIfPresent(Bool.self, forKey: .dailyDojoWarmupDone) ?? false
        dailyDojoCoreSolvedIds = try c.decodeIfPresent(Set<String>.self, forKey: .dailyDojoCoreSolvedIds) ?? []
        dailyDojoCoreFirstTryIds = try c.decodeIfPresent(Set<String>.self, forKey: .dailyDojoCoreFirstTryIds) ?? []
        dailyDojoKnowledgeDone = try c.decodeIfPresent(Bool.self, forKey: .dailyDojoKnowledgeDone) ?? false
        dailyDojoStampClaimedToday = try c.decodeIfPresent(Bool.self, forKey: .dailyDojoStampClaimedToday) ?? false
        dailyDojoStampDates = try c.decodeIfPresent(Set<String>.self, forKey: .dailyDojoStampDates) ?? []
        claimedStampMilestones = try c.decodeIfPresent(Set<Int>.self, forKey: .claimedStampMilestones) ?? []
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
    /// Campaign nodeId -> best star count (1...3) across all 5 Seas / 25 Islands / 125 Nodes
    var campaignNodeStars: [String: Int] = [:]
    /// Campaign nodeId -> highest mastery tier achieved (1 = Normal, 2 = Rotated/Flip, 3 = Exam Crown)
    var campaignNodeMasteryTier: [String: Int] = [:]
    /// Campaign nodeId -> set of cleared 5-puzzle section indices (0..<node.sectionCount)
    var campaignNodeClearedSections: [String: Set<Int>] = [:]
    /// Sea IDs unlocked via Placement Onboarding or Sea Skip Gate (e.g., "sea-2", "sea-3", "sea-4")
    var unlockedSeaIds: Set<String> = []
    /// Whether player has completed or dismissed initial placement onboarding
    var didCompletePlacement: Bool = false
    /// Endless Puzzle Rush high score (max consecutive/total solved in one 3-life run)
    var bestPuzzleRushScore: Int = 0
    /// Highest rank badge reached during Puzzle Rush (e.g. "12K", "3K", "2D")
    var bestPuzzleRushRank: String = "25K"
    /// Persistent campaign gauntlet hearts (prevents infinite retry/guessing by exiting to island)
    static let maxGauntletHearts: Int = 3
    static let heartRegenIntervalSeconds: TimeInterval = 300 // 5 minutes per heart
    var gauntletHearts: Int = 3
    var gauntletHeartLastRegenDate: Date? = nil
    /// Recently missed puzzle IDs queued for interactive mistake review to restore hearts
    var pendingReviewPuzzleIds: [String] = []

    var totalCampaignStars: Int {
        campaignNodeStars.values.reduce(0, +)
    }

    var totalStars: Int {
        starsByPuzzleId.values.reduce(0, +)
            + starterBootcampStars.values.reduce(0, +)
            + totalCampaignStars
    }

    var solvedCount: Int {
        starsByPuzzleId.count
    }

    var dueSRSCount: Int {
        srsMistakeItems.filter(\.isDueNow).count
    }

    /// Computes effective gauntlet hearts at `now` without mutating.
    func effectiveGauntletHearts(now: Date = Date()) -> Int {
        let clamped = max(0, min(Self.maxGauntletHearts, gauntletHearts))
        guard clamped < Self.maxGauntletHearts, let lastDate = gauntletHeartLastRegenDate else {
            return clamped
        }
        let elapsed = max(0, now.timeIntervalSince(lastDate))
        let recovered = Int(elapsed / Self.heartRegenIntervalSeconds)
        return min(Self.maxGauntletHearts, clamped + recovered)
    }

    /// Seconds remaining until the next heart recovers, or `nil` if already full.
    func secondsUntilNextHeart(now: Date = Date()) -> Int? {
        let effective = effectiveGauntletHearts(now: now)
        guard effective < Self.maxGauntletHearts else { return nil }
        let baseDate = gauntletHeartLastRegenDate ?? now
        let elapsed = max(0, now.timeIntervalSince(baseDate))
        let remainder = elapsed.truncatingRemainder(dividingBy: Self.heartRegenIntervalSeconds)
        let remaining = Int(ceil(Self.heartRegenIntervalSeconds - remainder))
        return max(1, remaining)
    }

    /// Applies any time-based heart regeneration up to `now`. Returns `true` if stored state changed.
    @discardableResult
    mutating func refreshGauntletHearts(now: Date = Date()) -> Bool {
        let originalHearts = gauntletHearts
        let originalDate = gauntletHeartLastRegenDate
        let clamped = max(0, min(Self.maxGauntletHearts, gauntletHearts))
        gauntletHearts = clamped

        if clamped >= Self.maxGauntletHearts {
            gauntletHeartLastRegenDate = nil
        } else if let lastDate = gauntletHeartLastRegenDate {
            // If device clock moved backward, clamp lastDate to `now` so regeneration doesn't freeze indefinitely.
            if lastDate > now {
                gauntletHeartLastRegenDate = now
            } else {
                let elapsed = now.timeIntervalSince(lastDate)
                let recovered = Int(elapsed / Self.heartRegenIntervalSeconds)
                if recovered > 0 {
                    gauntletHearts = min(Self.maxGauntletHearts, clamped + recovered)
                    if gauntletHearts >= Self.maxGauntletHearts {
                        gauntletHeartLastRegenDate = nil
                    } else {
                        gauntletHeartLastRegenDate = lastDate.addingTimeInterval(Double(recovered) * Self.heartRegenIntervalSeconds)
                    }
                }
            }
        } else {
            gauntletHeartLastRegenDate = now
        }
        return gauntletHearts != originalHearts || gauntletHeartLastRegenDate != originalDate
    }

    /// Immediately deducts 1 persistent gauntlet heart and records the missed puzzle for review recovery.
    @discardableResult
    mutating func consumeGauntletHeart(forPuzzleId puzzleId: String, now: Date = Date()) -> Int {
        refreshGauntletHearts(now: now)
        if gauntletHearts >= Self.maxGauntletHearts {
            gauntletHeartLastRegenDate = now
        }
        gauntletHearts = max(0, gauntletHearts - 1)
        if gauntletHearts < Self.maxGauntletHearts && gauntletHeartLastRegenDate == nil {
            gauntletHeartLastRegenDate = now
        }
        pendingReviewPuzzleIds.removeAll { $0 == puzzleId }
        pendingReviewPuzzleIds.insert(puzzleId, at: 0)
        if pendingReviewPuzzleIds.count > 6 {
            pendingReviewPuzzleIds = Array(pendingReviewPuzzleIds.prefix(6))
        }
        return gauntletHearts
    }

    /// Restores hearts to full after the learner completes interactive mistake review.
    mutating func restoreGauntletHeartsAfterReview(reviewedPuzzleIds: [String], now: Date = Date()) {
        refreshGauntletHearts(now: now)
        gauntletHearts = Self.maxGauntletHearts
        gauntletHeartLastRegenDate = nil
        let reviewedSet = Set(reviewedPuzzleIds)
        pendingReviewPuzzleIds.removeAll { reviewedSet.contains($0) }
    }

    init(
        starsByPuzzleId: [String: Int] = [:],
        mistakeBookIds: [String] = [],
        srsMistakeItems: [SRSMistakeItem] = [],
        customMistakePuzzles: [GoPuzzle] = [],
        completedJosekiIds: Set<String> = [],
        rankExamRecord: RankExamRecord = RankExamRecord(),
        defeatedBossIslandIds: Set<String> = [],
        starterBootcampStars: [String: Int] = [:],
        campaignNodeStars: [String: Int] = [:],
        campaignNodeMasteryTier: [String: Int] = [:],
        campaignNodeClearedSections: [String: Set<Int>] = [:],
        unlockedSeaIds: Set<String> = [],
        didCompletePlacement: Bool = false,
        bestPuzzleRushScore: Int = 0,
        bestPuzzleRushRank: String = "25K",
        gauntletHearts: Int = 3,
        gauntletHeartLastRegenDate: Date? = nil,
        pendingReviewPuzzleIds: [String] = []
    ) {
        self.starsByPuzzleId = starsByPuzzleId
        self.mistakeBookIds = mistakeBookIds
        self.srsMistakeItems = srsMistakeItems
        self.customMistakePuzzles = customMistakePuzzles
        self.completedJosekiIds = completedJosekiIds
        self.rankExamRecord = rankExamRecord
        self.defeatedBossIslandIds = defeatedBossIslandIds
        self.starterBootcampStars = starterBootcampStars
        self.campaignNodeStars = campaignNodeStars
        self.campaignNodeMasteryTier = campaignNodeMasteryTier
        self.campaignNodeClearedSections = campaignNodeClearedSections
        self.unlockedSeaIds = unlockedSeaIds
        self.didCompletePlacement = didCompletePlacement
        self.bestPuzzleRushScore = bestPuzzleRushScore
        self.bestPuzzleRushRank = bestPuzzleRushRank
        self.gauntletHearts = max(0, min(Self.maxGauntletHearts, gauntletHearts))
        self.gauntletHeartLastRegenDate = gauntletHeartLastRegenDate
        self.pendingReviewPuzzleIds = pendingReviewPuzzleIds
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
        campaignNodeStars = try c.decodeIfPresent([String: Int].self, forKey: .campaignNodeStars) ?? [:]
        campaignNodeMasteryTier = try c.decodeIfPresent([String: Int].self, forKey: .campaignNodeMasteryTier) ?? [:]
        campaignNodeClearedSections = try c.decodeIfPresent([String: Set<Int>].self, forKey: .campaignNodeClearedSections) ?? [:]
        unlockedSeaIds = try c.decodeIfPresent(Set<String>.self, forKey: .unlockedSeaIds) ?? []
        didCompletePlacement = try c.decodeIfPresent(Bool.self, forKey: .didCompletePlacement) ?? false
        bestPuzzleRushScore = try c.decodeIfPresent(Int.self, forKey: .bestPuzzleRushScore) ?? 0
        bestPuzzleRushRank = try c.decodeIfPresent(String.self, forKey: .bestPuzzleRushRank) ?? "25K"
        let decodedHearts = try c.decodeIfPresent(Int.self, forKey: .gauntletHearts) ?? Self.maxGauntletHearts
        gauntletHearts = max(0, min(Self.maxGauntletHearts, decodedHearts))
        gauntletHeartLastRegenDate = try c.decodeIfPresent(Date.self, forKey: .gauntletHeartLastRegenDate)
        pendingReviewPuzzleIds = try c.decodeIfPresent([String].self, forKey: .pendingReviewPuzzleIds) ?? []
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

struct PhotoJudgeRecord: Identifiable, Codable, Equatable, Sendable {
    static let maxStoredCount = 100

    let id: UUID
    let date: Date
    var boardSize: Int
    var scoringRule: ScoringRule
    var komi: Double
    /// Compact grid: 0 = empty, 1 = black, 2 = white (length == boardSize * boardSize).
    var grid: [Int]
    var deadStoneIndices: [Int]
    var winner: StoneColor
    var margin: Double
    var chineseZiMargin: Double
    var blackStones: Int
    var whiteStones: Int
    var blackTerritory: Int
    var whiteTerritory: Int
    var blackWinrate: Double?
    /// Filename of the JPEG-compressed warped board photo stored on disk.
    var imageFilename: String?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        boardSize: Int,
        scoringRule: ScoringRule,
        komi: Double,
        grid: [Int],
        deadStoneIndices: [Int] = [],
        winner: StoneColor,
        margin: Double,
        chineseZiMargin: Double,
        blackStones: Int,
        whiteStones: Int,
        blackTerritory: Int,
        whiteTerritory: Int,
        blackWinrate: Double? = nil,
        imageFilename: String? = nil
    ) {
        self.id = id
        self.date = date
        self.boardSize = boardSize
        self.scoringRule = scoringRule
        self.komi = komi
        self.grid = grid
        self.deadStoneIndices = deadStoneIndices
        self.winner = winner
        self.margin = margin
        self.chineseZiMargin = chineseZiMargin
        self.blackStones = blackStones
        self.whiteStones = whiteStones
        self.blackTerritory = blackTerritory
        self.whiteTerritory = whiteTerritory
        self.blackWinrate = blackWinrate
        self.imageFilename = imageFilename
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try c.decodeIfPresent(Date.self, forKey: .date) ?? Date()
        let decodedSize = try c.decodeIfPresent(Int.self, forKey: .boardSize) ?? 19
        boardSize = decodedSize
        scoringRule = try c.decodeIfPresent(ScoringRule.self, forKey: .scoringRule) ?? .chinese
        komi = try c.decodeIfPresent(Double.self, forKey: .komi) ?? 7.5
        grid = try c.decodeIfPresent([Int].self, forKey: .grid) ?? Array(repeating: 0, count: decodedSize * decodedSize)
        deadStoneIndices = try c.decodeIfPresent([Int].self, forKey: .deadStoneIndices) ?? []
        winner = try c.decodeIfPresent(StoneColor.self, forKey: .winner) ?? .black
        margin = try c.decodeIfPresent(Double.self, forKey: .margin) ?? 0
        chineseZiMargin = try c.decodeIfPresent(Double.self, forKey: .chineseZiMargin) ?? 0
        blackStones = try c.decodeIfPresent(Int.self, forKey: .blackStones) ?? 0
        whiteStones = try c.decodeIfPresent(Int.self, forKey: .whiteStones) ?? 0
        blackTerritory = try c.decodeIfPresent(Int.self, forKey: .blackTerritory) ?? 0
        whiteTerritory = try c.decodeIfPresent(Int.self, forKey: .whiteTerritory) ?? 0
        blackWinrate = try c.decodeIfPresent(Double.self, forKey: .blackWinrate)
        imageFilename = try c.decodeIfPresent(String.self, forKey: .imageFilename)
    }

    static func from(
        id: UUID = UUID(),
        date: Date = Date(),
        boardState: GoBoardState,
        scoringRule: ScoringRule,
        deadStoneIndices: Set<Int>,
        result: GameResult,
        blackWinrate: Double? = nil,
        imageFilename: String? = nil
    ) -> PhotoJudgeRecord {
        let compactGrid = boardState.grid.map { stone -> Int in
            switch stone {
            case .black: return 1
            case .white: return 2
            case nil: return 0
            }
        }
        return PhotoJudgeRecord(
            id: id,
            date: date,
            boardSize: boardState.size,
            scoringRule: scoringRule,
            komi: boardState.komi,
            grid: compactGrid,
            deadStoneIndices: deadStoneIndices.sorted(),
            winner: result.winner,
            margin: result.margin,
            chineseZiMargin: result.chineseZiMargin,
            blackStones: result.blackStones,
            whiteStones: result.whiteStones,
            blackTerritory: result.blackTerritory,
            whiteTerritory: result.whiteTerritory,
            blackWinrate: blackWinrate,
            imageFilename: imageFilename
        )
    }

    func makeBoardState() -> GoBoardState {
        var state = GoBoardState(size: boardSize, komi: komi)
        let limit = min(grid.count, state.grid.count)
        for idx in 0..<limit {
            let color: StoneColor?
            switch grid[idx] {
            case 1: color = .black
            case 2: color = .white
            default: color = nil
            }
            if let color {
                state.setSetupStone(color, at: state.point(for: idx))
            }
        }
        return state
    }
}

enum StonePlacementMode: String, Codable, CaseIterable, Equatable, Sendable {
    case doubleTap
    case confirmButton
}

struct AppSettings: Codable, Equatable, Sendable {
    var language: AppLanguage = .system
    var boardTheme: BoardTheme = .kayaWood
    var stoneStyle: StoneStyle = .classicSlateShell
    /// The single global scoring choice used by every scoring surface.
    var scoringRule: ScoringRulePreference = .automatic

    var effectiveScoringRule: ScoringRule {
        scoringRule.resolvedRule
    }

    var assistPreset: AssistPreset = .starter
    var confirmBeforePlace: Bool = true
    var stonePlacementMode: StonePlacementMode = .doubleTap
    var showCoordinates: Bool = true
    var showMoveNumbers: Bool = false
    var highlightAtari: Bool = true
    var expressiveStones: Bool = true
    var showLiveLiberties: Bool = true
    var zenDojoMode: Bool = false
    var aiSimulatedThinkingEnabled: Bool = true
    var aiThinkingPace: AIThinkingPace = .brisk
    var aiModelPreset: KataGoModelPreset = .defaultPreset
    var autoTransformPuzzles: Bool = false
    var soundEnabled: Bool = true
    var bgmEnabled: Bool = true
    var voiceEnabled: Bool = true
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
        stoneStyle = try c.decodeIfPresent(StoneStyle.self, forKey: .stoneStyle) ?? .classicSlateShell
        scoringRule = try c.decodeIfPresent(ScoringRulePreference.self, forKey: .scoringRule) ?? .automatic
        assistPreset = try c.decodeIfPresent(AssistPreset.self, forKey: .assistPreset) ?? .starter
        confirmBeforePlace = try c.decodeIfPresent(Bool.self, forKey: .confirmBeforePlace) ?? true
        stonePlacementMode = try c.decodeIfPresent(StonePlacementMode.self, forKey: .stonePlacementMode) ?? .doubleTap
        showCoordinates = try c.decodeIfPresent(Bool.self, forKey: .showCoordinates) ?? true
        showMoveNumbers = try c.decodeIfPresent(Bool.self, forKey: .showMoveNumbers) ?? false
        highlightAtari = try c.decodeIfPresent(Bool.self, forKey: .highlightAtari) ?? true
        expressiveStones = try c.decodeIfPresent(Bool.self, forKey: .expressiveStones) ?? true
        showLiveLiberties = try c.decodeIfPresent(Bool.self, forKey: .showLiveLiberties) ?? true
        zenDojoMode = try c.decodeIfPresent(Bool.self, forKey: .zenDojoMode) ?? false
        aiSimulatedThinkingEnabled = try c.decodeIfPresent(Bool.self, forKey: .aiSimulatedThinkingEnabled) ?? true
        aiThinkingPace = try c.decodeIfPresent(AIThinkingPace.self, forKey: .aiThinkingPace)
            ?? (aiSimulatedThinkingEnabled ? .brisk : .instant)
        aiModelPreset = try c.decodeIfPresent(KataGoModelPreset.self, forKey: .aiModelPreset) ?? .defaultPreset
        autoTransformPuzzles = try c.decodeIfPresent(Bool.self, forKey: .autoTransformPuzzles) ?? false
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        bgmEnabled = try c.decodeIfPresent(Bool.self, forKey: .bgmEnabled) ?? true
        voiceEnabled = try c.decodeIfPresent(Bool.self, forKey: .voiceEnabled) ?? true
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

struct PausedAIMatchSnapshot: Codable, Equatable, Sendable {
    let boardSize: BoardSize
    let difficulty: AIDifficulty
    let playerColor: StoneColor
    let handicap: Int
    let ruleSet: GameRuleSet
    let scoringRule: ScoringRule
    let timeControl: TimeControl
    let coachingStyle: AICoachingStyle
    let moves: [GoMove]
    let clock: GoClock
    let blackElapsedSeconds: Int
    let whiteElapsedSeconds: Int
    let savedAt: Date
}

private struct StorageEnvelope<Payload: Codable>: Codable {
    let schemaVersion: Int
    let payload: Payload
}

final class StorageService {
    static let shared = StorageService()

    private static let logger = Logger(subsystem: "super.ai.storm.staryigo", category: "StorageService")
    private static let currentSchemaVersion = 1
    private static let posixDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let defaults: UserDefaults
    private let photoHistoryDirectory: URL
    private let dataDirectory: URL?
    private let ioLock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let profile = "starpoint.userProfile.v1"
        static let familyProfiles = "starpoint.familyProfiles.v1"
        static let puzzles = "starpoint.puzzleProgress.v1"
        static let archive = "starpoint.savedGames.v1"
        static let pausedAIMatch = "starpoint.pausedAIMatch.v1"
        static let photoJudgeHistory = "starpoint.photoJudgeHistory.v1"
        static let hasTappedPhotoJudge = "starpoint.hasTappedPhotoJudge.v1"
        static let settings = "starpoint.appSettings.v1"
    }

    init(
        defaults: UserDefaults = .standard,
        photoHistoryDirectory: URL? = nil,
        dataDirectory: URL? = nil
    ) {
        self.defaults = defaults
        let appSupportRoot = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent("StarYiGo", isDirectory: true)
        if let photoHistoryDirectory {
            self.photoHistoryDirectory = photoHistoryDirectory
        } else {
            self.photoHistoryDirectory = appSupportRoot
                .appendingPathComponent("PhotoJudgeHistory", isDirectory: true)
        }
        if let dataDirectory {
            self.dataDirectory = dataDirectory
        } else if defaults === UserDefaults.standard {
            self.dataDirectory = appSupportRoot
                .appendingPathComponent("Data", isDirectory: true)
        } else {
            // Isolated test suites using custom UserDefaults stay self-contained in their suite.
            self.dataDirectory = nil
        }
    }

    func loadProfile() -> UserProfile {
        if var profile = load(UserProfile.self, forKey: Keys.profile) {
            normalizeDailyCounters(&profile)
            return profile
        }
        var profile: UserProfile
        if let familyMember = loadHeavy([UserProfile].self, forKey: Keys.familyProfiles)?.first {
            profile = familyMember
        } else {
            profile = defaultStarterProfile()
            // Older first launches could save placement before saving the player's identity.
            let owners = scopedPuzzleOwnerIds()
            if owners.count == 1 { profile.id = owners[0] }
        }
        normalizeDailyCounters(&profile)
        saveProfile(profile)
        return profile
    }

    func saveProfile(_ profile: UserProfile) {
        save(profile, forKey: Keys.profile)
        var family = loadHeavy([UserProfile].self, forKey: Keys.familyProfiles) ?? []
        if let idx = family.firstIndex(where: { $0.id == profile.id }) {
            family[idx] = profile
        } else {
            family.insert(profile, at: 0)
        }
        saveHeavy(family, forKey: Keys.familyProfiles)
    }

    func loadFamilyProfiles() -> [UserProfile] {
        if let list = loadHeavy([UserProfile].self, forKey: Keys.familyProfiles), !list.isEmpty { return list }
        return [loadProfile()]
    }

    func saveFamilyProfiles(_ profiles: [UserProfile]) {
        saveHeavy(profiles, forKey: Keys.familyProfiles)
    }

    func loadPausedAIMatch(for profileId: UUID) -> PausedAIMatchSnapshot? {
        loadHeavy(PausedAIMatchSnapshot.self, forKey: "\(Keys.pausedAIMatch).\(profileId.uuidString)")
    }

    func savePausedAIMatch(_ snapshot: PausedAIMatchSnapshot?, for profileId: UUID) {
        let key = "\(Keys.pausedAIMatch).\(profileId.uuidString)"
        if let snapshot {
            saveHeavy(snapshot, forKey: key)
        } else {
            removeHeavy(forKey: key)
        }
    }

    func loadPuzzleProgress(for profileId: UUID) -> PuzzleProgressStore {
        let key = "\(Keys.puzzles).\(profileId.uuidString)"
        if let progress = loadHeavy(PuzzleProgressStore.self, forKey: key) {
            return progress
        }

        // The unscoped legacy store belongs to the profile active during migration.
        let hasScopedProgress = hasAnyScopedPuzzleStore()
        guard !hasScopedProgress,
              let legacy = load(PuzzleProgressStore.self, forKey: Keys.puzzles) else {
            return PuzzleProgressStore()
        }
        saveHeavy(legacy, forKey: key)
        return legacy
    }

    func savePuzzleProgress(_ store: PuzzleProgressStore, for profileId: UUID) {
        saveHeavy(store, forKey: "\(Keys.puzzles).\(profileId.uuidString)")
    }

    func deleteProfileData(for profileId: UUID) {
        removeHeavy(forKey: "\(Keys.puzzles).\(profileId.uuidString)")
        removeHeavy(forKey: "\(Keys.pausedAIMatch).\(profileId.uuidString)")
    }

    func loadSavedGames() -> [SavedGameRecord] {
        loadHeavy([SavedGameRecord].self, forKey: Keys.archive) ?? []
    }

    func saveSavedGames(_ games: [SavedGameRecord]) {
        saveHeavy(games, forKey: Keys.archive)
    }

    func loadPhotoJudgeHistory() -> [PhotoJudgeRecord] {
        loadHeavy([PhotoJudgeRecord].self, forKey: Keys.photoJudgeHistory) ?? []
    }

    func savePhotoJudgeHistory(_ records: [PhotoJudgeRecord]) {
        saveHeavy(records, forKey: Keys.photoJudgeHistory)
    }

    func loadHasTappedPhotoJudge() -> Bool {
        ioLock.lock()
        defer { ioLock.unlock() }
        return defaults.bool(forKey: Keys.hasTappedPhotoJudge)
    }

    func saveHasTappedPhotoJudge(_ tapped: Bool) {
        ioLock.lock()
        defer { ioLock.unlock() }
        defaults.set(tapped, forKey: Keys.hasTappedPhotoJudge)
    }

    func savePhotoJudgeImage(_ image: UIImage, for recordId: UUID) -> String? {
        let filename = "\(recordId.uuidString).jpg"
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: photoHistoryDirectory, withIntermediateDirectories: true)
        } catch {
            return nil
        }

        let resized = downscaledPhotoImage(image, maxDimension: 720)
        guard let data = resized.jpegData(compressionQuality: 0.72) else { return nil }
        let fileURL = photoHistoryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: fileURL, options: [.atomic])
            return filename
        } catch {
            return nil
        }
    }

    func loadPhotoJudgeImage(filename: String?) -> UIImage? {
        guard let filename, !filename.isEmpty else { return nil }
        let fileURL = photoHistoryDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    func deletePhotoJudgeImage(filename: String?) {
        guard let filename, !filename.isEmpty else { return }
        let fileURL = photoHistoryDirectory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func downscaledPhotoImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let ratio = min(1.0, maxDimension / max(size.width, size.height))
        if ratio >= 0.999 && image.imageOrientation == .up {
            return image
        }
        let target = CGSize(
            width: max(1, (size.width * ratio).rounded()),
            height: max(1, (size.height * ratio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    func loadSettings() -> AppSettings {
        load(AppSettings.self, forKey: Keys.settings) ?? AppSettings()
    }

    func saveSettings(_ settings: AppSettings) {
        save(settings, forKey: Keys.settings)
    }

    #if DEBUG
    private static let debugSkipParentalVerificationKey = "starpoint.debug.skipParentalVerification.v1"

    func loadDebugSkipParentalVerification() -> Bool {
        ioLock.lock()
        defer { ioLock.unlock() }
        return defaults.bool(forKey: Self.debugSkipParentalVerificationKey)
    }

    func saveDebugSkipParentalVerification(_ enabled: Bool) {
        ioLock.lock()
        defer { ioLock.unlock() }
        defaults.set(enabled, forKey: Self.debugSkipParentalVerificationKey)
    }

    private static let debugModeEnabledKey = "starpoint.debug.modeEnabled.v1"

    func loadDebugModeEnabled() -> Bool {
        ioLock.lock()
        defer { ioLock.unlock() }
        return defaults.bool(forKey: Self.debugModeEnabledKey)
    }

    func saveDebugModeEnabled(_ enabled: Bool) {
        ioLock.lock()
        defer { ioLock.unlock() }
        defaults.set(enabled, forKey: Self.debugModeEnabledKey)
    }
    #endif

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
            name = "별이 도전자"
        } else {
            name = "Star Player"
        }
        return UserProfile(nickname: name)
    }

    @discardableResult
    func normalizeDailyCounters(_ profile: inout UserProfile) -> Bool {
        let today = Self.todayStamp()
        var changed = false
        if profile.dailyDateStamp != today {
            profile.dailyDateStamp = today
            profile.dailyCompletedCount = 0
            changed = true
        }
        if profile.dailyDojoDateStamp != today {
            profile.dailyDojoDateStamp = today
            profile.dailyDojoWarmupDone = false
            profile.dailyDojoCoreSolvedIds = []
            profile.dailyDojoCoreFirstTryIds = []
            profile.dailyDojoKnowledgeDone = false
            profile.dailyDojoStampClaimedToday = profile.dailyDojoStampDates.contains(today)
            changed = true
        }
        return changed
    }

    static func todayStamp(date: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .autoupdatingCurrent
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            locale: Locale(identifier: "en_US_POSIX"),
            comps.year ?? 2026,
            comps.month ?? 1,
            comps.day ?? 1
        )
    }

    static func yesterdayStamp(date: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .autoupdatingCurrent
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return todayStamp(date: yesterday)
    }

    private func fileURL(forKey key: String) -> URL? {
        dataDirectory?.appendingPathComponent("\(key).json")
    }

    private func scopedPuzzleOwnerIds() -> [UUID] {
        let prefix = Keys.puzzles + "."
        var ids = Set<UUID>()
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
            if let uuid = UUID(uuidString: String(key.dropFirst(prefix.count))) {
                ids.insert(uuid)
            }
        }
        if let dir = dataDirectory,
           let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
            for file in files where file.hasPrefix(prefix) && file.hasSuffix(".json") {
                let raw = String(file.dropFirst(prefix.count).dropLast(5))
                if let uuid = UUID(uuidString: raw) {
                    ids.insert(uuid)
                }
            }
        }
        return Array(ids)
    }

    private func hasAnyScopedPuzzleStore() -> Bool {
        !scopedPuzzleOwnerIds().isEmpty
    }

    private func loadHeavy<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let url = fileURL(forKey: key) else {
            return load(type, forKey: key)
        }
        ioLock.lock()
        defer { ioLock.unlock() }

        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            do {
                let data = try Data(contentsOf: url)
                if let envelope = try? decoder.decode(StorageEnvelope<T>.self, from: data) {
                    return envelope.payload
                }
                return try decoder.decode(type, from: data)
            } catch {
                Self.logger.error("Failed to decode storage file \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
                let backup = url.appendingPathExtension("corrupt.\(Int(Date().timeIntervalSince1970))")
                try? fm.moveItem(at: url, to: backup)
                return nil
            }
        }

        // One-time transparent migration from legacy UserDefaults blob to atomic file.
        if let legacyData = defaults.data(forKey: key) {
            do {
                let decoded = try decoder.decode(type, from: legacyData)
                if writeAtomicEnvelopeUnlocked(decoded, to: url) {
                    defaults.removeObject(forKey: key)
                }
                return decoded
            } catch {
                Self.logger.error("Failed to migrate legacy UserDefaults key \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return nil
    }

    private func saveHeavy<T: Codable>(_ value: T, forKey key: String) {
        guard let url = fileURL(forKey: key) else {
            save(value, forKey: key)
            return
        }
        ioLock.lock()
        defer { ioLock.unlock() }
        if writeAtomicEnvelopeUnlocked(value, to: url), defaults.object(forKey: key) != nil {
            defaults.removeObject(forKey: key)
        }
    }

    private func removeHeavy(forKey key: String) {
        ioLock.lock()
        defer { ioLock.unlock() }
        if let url = fileURL(forKey: key) {
            try? FileManager.default.removeItem(at: url)
        }
        defaults.removeObject(forKey: key)
    }

    @discardableResult
    private func writeAtomicEnvelopeUnlocked<T: Codable>(_ value: T, to url: URL) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let envelope = StorageEnvelope(schemaVersion: Self.currentSchemaVersion, payload: value)
            let data = try encoder.encode(envelope)
            try data.write(to: url, options: [.atomic])
            return true
        } catch {
            Self.logger.error("Failed to write atomic storage file \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func load<T: Decodable>(_ type: T.Type, forKey key: String) -> T? {
        ioLock.lock()
        defer { ioLock.unlock() }
        guard let data = defaults.data(forKey: key) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            Self.logger.error("Failed to decode UserDefaults key \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func save<T: Encodable>(_ value: T, forKey key: String) {
        ioLock.lock()
        defer { ioLock.unlock() }
        do {
            let data = try encoder.encode(value)
            defaults.set(data, forKey: key)
        } catch {
            Self.logger.error("Failed to encode UserDefaults key \(key, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}

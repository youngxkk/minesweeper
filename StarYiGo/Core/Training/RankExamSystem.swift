//
//  RankExamSystem.swift
//  StarYi Go — Dual-Requirement K-12 Go Rank Promotion Exam System (P2)
//  Each certified rank requires BOTH:
//    1. Exam-mode Tsumego / Tactics Test (5 puzzles, 0 hints, >= 4/5 to pass)
//    2. Ranked Practical Match Series (multi-game win threshold, no undo, timed)
//

import Foundation

struct RankExamSpec: Identifiable, Hashable, Sendable {
    let tier: Int // 1 = 22K ... 7 = 3D
    var id: Int { tier }
    let rankCode: String
    let titleZh: String
    let titleEn: String
    let boardSize: BoardSize
    let opponentDifficulty: AIDifficulty
    let timeControl: TimeControl
    let requiredMatchWins: Int
    let matchSeriesLength: Int
    let examPuzzleIds: [String]
    let requiredPuzzlePass: Int

    func title(isChinese: Bool) -> String { isChinese ? titleZh : titleEn }
}

struct RankExamRecord: Codable, Equatable, Sendable {
    var writtenPassedTiers: Set<Int> = []
    /// tier -> [true = win, false = loss] in current promotion series
    var matchHistoryByTier: [Int: [Bool]] = [:]
    var certifiedDateByTier: [Int: Date] = [:]

    func wins(for tier: Int) -> Int {
        (matchHistoryByTier[tier] ?? []).filter { $0 }.count
    }

    func gamesPlayed(for tier: Int) -> Int {
        (matchHistoryByTier[tier] ?? []).count
    }

    func isWrittenPassed(_ tier: Int) -> Bool {
        writtenPassedTiers.contains(tier)
    }

    func isMatchPassed(_ spec: RankExamSpec) -> Bool {
        wins(for: spec.tier) >= spec.requiredMatchWins
    }

    func isFullyCertified(_ spec: RankExamSpec) -> Bool {
        isWrittenPassed(spec.tier) && isMatchPassed(spec)
    }
}

enum RankExamSystem {
    static let allExams: [RankExamSpec] = [
        RankExamSpec(
            tier: 1, rankCode: "22K",
            titleZh: "22级 · 启蒙吃子认证", titleEn: "22K · Capture Basics Exam",
            boardSize: .nine, opponentDifficulty: .sprout,
            timeControl: .suddenDeath(minutes: 10),
            requiredMatchWins: 2, matchSeriesLength: 3,
            examPuzzleIds: ["cap-01", "cap-02", "dojo-cap-01", "dojo-cap-02", "dojo-cap-03"],
            requiredPuzzlePass: 4
        ),
        RankExamSpec(
            tier: 2, rankCode: "18K",
            titleZh: "18级 · 叫吃与连结认证", titleEn: "18K · Atari & Connection Exam",
            boardSize: .nine, opponentDifficulty: .rabbit,
            timeControl: .suddenDeath(minutes: 10),
            requiredMatchWins: 2, matchSeriesLength: 3,
            examPuzzleIds: ["cap-03", "cap-04", "cap-05", "dojo-cap-04", "dojo-cap-07"],
            requiredPuzzlePass: 4
        ),
        RankExamSpec(
            tier: 3, rankCode: "15K",
            titleZh: "15级 · 经典手筋认证", titleEn: "15K · Core Tesuji Exam",
            boardSize: .nine, opponentDifficulty: .fox,
            timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
            requiredMatchWins: 2, matchSeriesLength: 3,
            examPuzzleIds: ["tac-01", "tac-02", "tac-03", "lad-01", "dojo-tac-02"],
            requiredPuzzlePass: 4
        ),
        RankExamSpec(
            tier: 4, rankCode: "10K",
            titleZh: "10级 · 死活与对杀认证", titleEn: "10K · Life & Death Exam",
            boardSize: .thirteen, opponentDifficulty: .panda,
            timeControl: .byoyomi(mainMinutes: 5, periodSeconds: 20, periods: 3),
            requiredMatchWins: 3, matchSeriesLength: 5,
            examPuzzleIds: ["lad-02", "lad-03", "lad-04", "end-02", "dojo-race-02"],
            requiredPuzzlePass: 4
        ),
        RankExamSpec(
            tier: 5, rankCode: "5K",
            titleZh: "5级 · 进阶综合认证", titleEn: "5K · Single-Digit Kyu Exam",
            boardSize: .thirteen, opponentDifficulty: .crane,
            timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
            requiredMatchWins: 3, matchSeriesLength: 5,
            examPuzzleIds: ["tac-04", "tac-05", "lad-05", "end-05", "dojo-lad-08"],
            requiredPuzzlePass: 4
        ),
        RankExamSpec(
            tier: 6, rankCode: "1D",
            titleZh: "业余初段 · 段位晋级赛", titleEn: "1D · Shodan Certification Exam",
            boardSize: .nineteen, opponentDifficulty: .dragon,
            timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
            requiredMatchWins: 3, matchSeriesLength: 5,
            examPuzzleIds: ["dojo-lad-09", "dojo-lad-10", "dojo-lad-11", "dojo-race-05", "dojo-end-02"],
            requiredPuzzlePass: 4
        ),
        RankExamSpec(
            tier: 7, rankCode: "3D",
            titleZh: "业余三段 · 大师殿堂认证", titleEn: "3D · Master Dan Certification",
            boardSize: .nineteen, opponentDifficulty: .dragon,
            timeControl: .byoyomi(mainMinutes: 10, periodSeconds: 30, periods: 3),
            requiredMatchWins: 4, matchSeriesLength: 5,
            examPuzzleIds: ["dojo-tac-10", "dojo-lad-11", "dojo-lad-12", "dojo-race-06", "dojo-end-04"],
            requiredPuzzlePass: 4
        )
    ]

    static func spec(for tier: Int) -> RankExamSpec? {
        allExams.first { $0.tier == tier }
    }
}

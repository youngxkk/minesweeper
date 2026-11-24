//
//  HandicapBalanceCalculator.swift
//  StarYi Go — Living Room Rank-Balance Scale ("水平天平") & Kid-Safe Reaction Stickers
//

import Foundation

struct GoRankOption: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    /// Linearized Go strength scale: 30K = 0, 25K = 5, 20K = 10, 15K = 15, 10K = 20, 5K = 25, 1D = 30, 3D = 32, 5D = 34
    let strengthValue: Int
    let emoji: String

    static let presets: [GoRankOption] = [
        GoRankOption(id: "30K", label: "30K", strengthValue: 0, emoji: "🌱"),
        GoRankOption(id: "25K", label: "25K", strengthValue: 5, emoji: "🌿"),
        GoRankOption(id: "20K", label: "20K", strengthValue: 10, emoji: "🐰"),
        GoRankOption(id: "15K", label: "15K", strengthValue: 15, emoji: "🦊"),
        GoRankOption(id: "12K", label: "12K", strengthValue: 18, emoji: "🦌"),
        GoRankOption(id: "10K", label: "10K", strengthValue: 20, emoji: "🐼"),
        GoRankOption(id: "5K", label: "5K", strengthValue: 25, emoji: "🦢"),
        GoRankOption(id: "1D", label: "1D", strengthValue: 30, emoji: "🐉"),
        GoRankOption(id: "3D", label: "3D", strengthValue: 32, emoji: "🦅"),
        GoRankOption(id: "5D", label: "5D", strengthValue: 34, emoji: "🦄")
    ]
}

struct HandicapRecommendation: Equatable, Sendable {
    let boardSize: BoardSize
    let handicapStones: Int
    let ruleSet: GameRuleSet
    let blackIsPlayer1: Bool
    let gapSteps: Int

    func summary(_ l10n: L10n) -> String {
        if case .captureRace(let target) = ruleSet {
            return l10n.localized(
                zh: "推荐 \(boardSize.rawValue) 路吃子棋（先吃 \(target) 子胜），萌新与高手都能尽兴！",
                en: "Recommended: \(boardSize.rawValue)×\(boardSize.rawValue) Capture Go (First to \(target)) — fun for both!",
                ja: "おすすめ：\(boardSize.rawValue)路ポン抜き囲碁（\(target)子先取）で楽しく対局！",
                ko: "추천: \(boardSize.rawValue)줄 따내기 바둑(\(target)점 선취) — 누구나 즐겁게!",
                zhHant: "推薦 \(boardSize.rawValue) 路吃子棋（先吃 \(target) 子勝），萌新與高手都能盡興！"
            )
        }
        if handicapStones == 0 {
            return l10n.localized(
                zh: "实力旗鼓相当！推荐 \(boardSize.rawValue) 路分先公平对决！",
                en: "Evenly matched! Recommended: \(boardSize.rawValue)×\(boardSize.rawValue) Even Game!",
                ja: "実力伯仲！\(boardSize.rawValue)路の互先（コミあり）がぴったり！",
                ko: "실력이 비슷해요! \(boardSize.rawValue)줄 호선 대국을 추천합니다!",
                zhHant: "實力旗鼓相當！推薦 \(boardSize.rawValue) 路分先公平對決！"
            )
        }
        let blackLabel = blackIsPlayer1
            ? l10n.localized(zh: "玩家 1", en: "Player 1", ja: "プレイヤー1", ko: "플레이어 1", zhHant: "玩家 1")
            : l10n.localized(zh: "玩家 2", en: "Player 2", ja: "プレイヤー2", ko: "플레이어 2", zhHant: "玩家 2")
        return l10n.localized(
            zh: "水平天平推荐：\(blackLabel) 执黑受让 \(handicapStones) 子（\(boardSize.rawValue)路），双方胜率 50/50！",
            en: "Balance Scale: \(blackLabel) takes Black with \(handicapStones) handicap stones on \(boardSize.rawValue)×\(boardSize.rawValue)!",
            ja: "ハンデ天秤：\(blackLabel)が黒番 \(handicapStones)子局（\(boardSize.rawValue)路）で互角の勝負！",
            ko: "밸런스 천칭: \(blackLabel) 흑번 \(handicapStones)점 접바둑(\(boardSize.rawValue)줄)으로 박빙 승부!",
            zhHant: "水平天平推薦：\(blackLabel) 執黑受讓 \(handicapStones) 子（\(boardSize.rawValue)路），雙方勝率 50/50！"
        )
    }
}

enum HandicapBalanceCalculator {
    /// Computes an authentic, fair Nintendo couch-party handicap between any two ranks (30K -> 5D).
    static func recommend(
        player1: GoRankOption,
        player2: GoRankOption,
        preferredBoardSize: BoardSize
    ) -> HandicapRecommendation {
        let diff = abs(player1.strengthValue - player2.strengthValue)
        let blackIsPlayer1 = player1.strengthValue <= player2.strengthValue
        let weakerStrength = min(player1.strengthValue, player2.strengthValue)

        // If either player is brand new (<= 25K) and board is small, recommend joyful Capture Go!
        if weakerStrength <= 5 && preferredBoardSize.rawValue <= 7 {
            return HandicapRecommendation(
                boardSize: .seven,
                handicapStones: 0,
                ruleSet: .captureRace(target: 3),
                blackIsPlayer1: blackIsPlayer1,
                gapSteps: diff
            )
        }

        let effectiveSize: BoardSize = preferredBoardSize == .five ? .nine : preferredBoardSize
        let rawHandicap: Int
        switch effectiveSize {
        case .five:
            rawHandicap = 0
        case .seven:
            rawHandicap = diff >= 6 ? 2 : 0
        case .nine:
            if diff < 3 { rawHandicap = 0 }
            else if diff < 7 { rawHandicap = 2 }
            else if diff < 12 { rawHandicap = 3 }
            else { rawHandicap = 4 }
        case .thirteen:
            if diff < 3 { rawHandicap = 0 }
            else { rawHandicap = min(effectiveSize.maxHandicap, max(2, diff / 3)) }
        case .nineteen:
            if diff < 2 { rawHandicap = 0 }
            else { rawHandicap = min(effectiveSize.maxHandicap, max(2, (diff + 1) / 2)) }
        }

        return HandicapRecommendation(
            boardSize: effectiveSize,
            handicapStones: min(rawHandicap, effectiveSize.maxHandicap),
            ruleSet: .standard,
            blackIsPlayer1: blackIsPlayer1,
            gapSteps: diff
        )
    }
}

/// Kid-safe, zero-free-text-chat Nintendo reaction stickers for in-game fun (100% COPPA/Kids safe!).
struct GoSticker: Identifiable, Hashable, Sendable {
    let id: String
    let emoji: String
    let zh: String
    let en: String
    let ja: String
    let ko: String
    let zhHant: String

    func text(_ l10n: L10n) -> String {
        l10n.localized(zh: zh, en: en, ja: ja, ko: ko, zhHant: zhHant)
    }

    static let allStickers: [GoSticker] = [
        GoSticker(id: "greet", emoji: "🦊", zh: "请多指教！", en: "Good luck!", ja: "よろしくね！", ko: "잘 부탁해요!", zhHant: "請多指教！"),
        GoSticker(id: "nice", emoji: "🐼", zh: "好棋妙手！", en: "Nice move!", ja: "ナイス一手！", ko: "멋진 수예요!", zhHant: "好棋妙手！"),
        GoSticker(id: "wow", emoji: "🐰", zh: "惊呆了！", en: "Whoa!!", ja: "びっくり！", ko: "우와 대박!", zhHant: "驚呆了！"),
        GoSticker(id: "think", emoji: "🦢", zh: "让我算算…", en: "Thinking...", ja: "考え中…", ko: "생각 중...", zhHant: "讓我算算…"),
        GoSticker(id: "strong", emoji: "🐉", zh: "太强啦！", en: "So strong!", ja: "強いなぁ！", ko: "정말 강해요!", zhHant: "太強啦！"),
        GoSticker(id: "rematch", emoji: "🌱", zh: "再来一盘！", en: "Rematch!", ja: "もう一局！", ko: "한 판 더!", zhHant: "再來一盤！")
    ]
}

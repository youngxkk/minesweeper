//
//  HandicapScaleSheet.swift
//  StarYi Go — Living Room Couch-Party "Rank Balance Handicap Scale" (亲子/好友水平天平)
//

import SwiftUI

struct HandicapScaleSheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var player1Rank: GoRankOption = GoRankOption.presets[3] // 15K
    @State private var player2Rank: GoRankOption = GoRankOption.presets[7] // 1D
    @State private var boardSize: BoardSize = .thirteen

    private var l10n: L10n { appState.l10n }

    private var recommendation: HandicapRecommendation {
        HandicapBalanceCalculator.recommend(
            player1: player1Rank,
            player2: player2Rank,
            preferredBoardSize: boardSize
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Text("⚖️").font(.system(size: 52))
                    Text(l10n.localized(
                        zh: "客厅双人 · 水平天平让子",
                        en: "Couch Party · Rank Balance Scale",
                        ja: "みんなで対局・ハンデ天秤",
                        ko: "거실 대국 · 실력 밸런스 천칭",
                        zhHant: "客廳雙人 · 水平天平讓子"
                    ))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text(l10n.localized(
                        zh: "选出双方大概的段级位，天平自动配出最公平的让子数，爸爸和小孩也能下到最后一手！",
                        en: "Pick both players' approximate ranks — the balance scale calculates a fair handicap so parents and kids play a nail-biter!",
                        ja: "2人の棋力を選ぶだけで、親子でも接戦になるぴったりのハンデを自動計算します！",
                        ko: "두 사람의 기력을 고르면 부모와 아이도 마지막까지 박빙 승부를 즐길 수 있는 접바둑을 자동 추천해요!",
                        zhHant: "選出雙方大概的段級位，天平自動配出最公平的讓子數，爸爸和小孩也能下到最後一手！"
                    ))
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .multilineTextAlignment(.center)

                    // Player 1 & Player 2 Rank Pickers
                    HStack(spacing: 14) {
                        rankPickerCard(
                            title: l10n.localized(zh: "玩家 1（如孩子）", en: "Player 1", ja: "プレイヤー1", ko: "플레이어 1", zhHant: "玩家 1"),
                            selection: $player1Rank,
                            accent: AppTheme.skyBottom
                        )
                        rankPickerCard(
                            title: l10n.localized(zh: "玩家 2（如家长）", en: "Player 2", ja: "プレイヤー2", ko: "플레이어 2", zhHant: "玩家 2"),
                            selection: $player2Rank,
                            accent: AppTheme.coralBottom
                        )
                    }

                    // Board Size Picker
                    HStack(spacing: 8) {
                        ForEach([BoardSize.seven, .nine, .thirteen, .nineteen]) { sz in
                            let selected = boardSize == sz
                            Button {
                                boardSize = sz
                                SoundAndHapticsManager.shared.playUITap()
                            } label: {
                                Text("\(sz.rawValue)×\(sz.rawValue)")
                                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                                    .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5, playTapSound: false))
                        }
                    }

                    // Live Balance Result Card
                    VStack(spacing: 8) {
                        HStack(spacing: 10) {
                            Text(recommendation.handicapStones > 0 ? "⚫️ ×\(recommendation.handicapStones)" : "⚖️ 50 / 50")
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)))
                        }
                        Text(recommendation.summary(l10n))
                            .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .warmCard(cornerRadius: 24, padding: 16)

                    Button {
                        let rec = recommendation
                        dismiss()
                        appState.startTwoPlayerGame(
                            boardSize: rec.boardSize,
                            handicap: rec.handicapStones,
                            ruleSet: rec.ruleSet
                        )
                    } label: {
                        Label(
                            l10n.localized(zh: "公平开局！", en: "Start Balanced Match!", ja: "公平に対局開始！", ko: "공정 대국 시작!", zhHant: "公平開局！"),
                            systemImage: "play.fill"
                        )
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true))
                }
                .padding(20)
            }
            .background(AppTheme.brightArenaBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.t("common.cancel")) { dismiss() }
                }
            }
        }
    }

    private func rankPickerCard(title: String, selection: Binding<GoRankOption>, accent: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(accent)
            Text(selection.wrappedValue.emoji)
                .font(.system(size: 34))
            Menu {
                ForEach(GoRankOption.presets) { opt in
                    Button {
                        selection.wrappedValue = opt
                        SoundAndHapticsManager.shared.playUITap()
                    } label: {
                        Text("\(opt.emoji) \(opt.label)")
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selection.wrappedValue.label)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(AppTheme.inkPrimary)
                .padding(.horizontal, 14)
                .frame(minHeight: AppTheme.buttonFaceHeight)
                .background(Capsule().fill(AppTheme.canvasBackground))
            }
        }
        .frame(maxWidth: .infinity)
        .warmCard(cornerRadius: 24, padding: 14)
    }
}

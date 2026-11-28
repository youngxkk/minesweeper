//
//  SavedGamesListView.swift
//  StarYi Go — Full Saved Match History List (全部对局)
//

import SwiftUI

struct SavedGameRecordRow: View {
    let record: SavedGameRecord
    let l10n: L10n
    let onReview: () -> Void
    let onRequestDelete: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private static let cachedDateFormatters: [String: DateFormatter] = {
        var map: [String: DateFormatter] = [:]

        let cjk = DateFormatter()
        cjk.dateFormat = "yyyy年M月d日 HH:mm"
        map["zh-Hans"] = cjk
        map["zh-Hant"] = cjk
        map["ja"] = cjk

        let ko = DateFormatter()
        ko.dateFormat = "yyyy년 M월 d일 HH:mm"
        map["ko"] = ko

        let en = DateFormatter()
        en.dateStyle = .medium
        en.timeStyle = .short
        map["en"] = en

        return map
    }()

    private var formattedTimestamp: String {
        let code = l10n.language.resolvedCode
        let formatter = Self.cachedDateFormatters[code] ?? Self.cachedDateFormatters["en"]!
        return formatter.string(from: record.date)
    }

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onReview) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.grapeBottom)

                            Text(formattedTimestamp)
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .monospacedDigit()
                                .foregroundColor(AppTheme.inkPrimary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }

                        HStack(spacing: 6) {
                            Text("\(record.boardSize)×\(record.boardSize)")
                                .font(AppFont.rounded(size: 10.5, weight: .bold))
                                .foregroundColor(AppTheme.skyBottom)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(AppTheme.skyTop.opacity(0.14)))

                            Text(record.resultString)
                                .font(AppFont.rounded(size: 10.5, weight: .bold))
                                .foregroundColor(AppTheme.sunBottom)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(AppTheme.sunTop.opacity(0.18)))

                            Text("\(record.blackName) vs \(record.whiteName) · \(l10n.t("game.moveCount", record.moveCount))")
                                .font(AppFont.rounded(size: 11.5, weight: .semibold))
                                .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }

                    Spacer(minLength: 4)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 21, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.95))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(AppTheme.subtleBorder, lineWidth: 1.5))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("ArchiveGameRecord")

            Button(role: .destructive) {
                SoundAndHapticsManager.shared.playUITap(weight: .light)
                onRequestDelete()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundColor(AppTheme.coralBottom)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(AppTheme.coralTop.opacity(0.12)))
            }
            .accessibilityLabel(l10n.localized(zh: "删除棋谱", en: "Delete Saved Game", ja: "棋譜を削除", ko: "기보 삭제", zhHant: "刪除棋譜"))
            .tactileButton(scale: 0.9)
        }
    }
}

struct SavedGamesListView: View {
    @EnvironmentObject var appState: AppState
    @State private var pendingDeleteGameRecord: SavedGameRecord? = nil

    private var l10n: L10n { appState.l10n }

    var body: some View {
        ZStack {
            SceneBackdrop.recordDesk

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        if appState.savedGames.isEmpty {
                            emptyStateCard
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(appState.savedGames) { record in
                                    SavedGameRecordRow(
                                        record: record,
                                        l10n: l10n,
                                        onReview: {
                                            appState.navigationPath.append(.reviewGame(recordId: record.id))
                                        },
                                        onRequestDelete: {
                                            pendingDeleteGameRecord = record
                                        }
                                    )
                                }
                            }
                            .warmCard(cornerRadius: 24, padding: 16)
                        }
                    }
                    .frame(maxWidth: 820)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 34)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .gameDialog(
            isPresented: Binding(
                get: { pendingDeleteGameRecord != nil },
                set: { if !$0 { pendingDeleteGameRecord = nil } }
            ),
            title: l10n.localized(
                zh: "删除这局棋谱？",
                en: "Delete Saved Game?",
                ja: "この棋譜を削除しますか？",
                ko: "저장된 기보를 삭제할까요?",
                zhHant: "刪除這局棋譜？"
            ),
            message: l10n.localized(
                zh: "删除后将无法恢复这局对弈记录。",
                en: "This saved match record will be permanently removed.",
                ja: "削除するとこの対局記録は元に戻せません。",
                ko: "삭제하면 이 대국 기록은 복구할 수 없습니다.",
                zhHant: "刪除後將無法恢復這局對弈記錄。"
            ),
            icon: "trash.fill",
            accentPalette: .coral,
            actions: [
                .secondary(l10n.t("common.cancel")),
                .destructive(l10n.localized(zh: "删除", en: "Delete", ja: "削除", ko: "삭제", zhHant: "刪除")) {
                    if let target = pendingDeleteGameRecord {
                        appState.deleteSavedGame(id: target.id)
                    }
                    pendingDeleteGameRecord = nil
                }
            ]
        )
        .toolbar(.hidden, for: .navigationBar)
    }

    private var topBar: some View {
        ZStack {
            GameTitleCrest(
                title: l10n.localized(
                    zh: "全部对局",
                    en: "All Matches",
                    ja: "すべての対局",
                    ko: "전체 대국",
                    zhHant: "全部對局"
                ),
                subtitle: l10n.localized(
                    zh: "共 \(appState.savedGames.count) 局对弈记录",
                    en: "\(appState.savedGames.count) Saved Matches",
                    ja: "全 \(appState.savedGames.count) 局の対局記録",
                    ko: "총 \(appState.savedGames.count)국의 대국 기록",
                    zhHant: "共 \(appState.savedGames.count) 局對弈記錄"
                )
            )

            HStack {
                GameBackButton(title: l10n.t("common.back")) {
                    appState.popRoute()
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                    Text("\(appState.savedGames.count)")
                        .font(AppFont.rounded(size: 14, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.95)).shadow(color: AppTheme.grapeBottom.opacity(0.14), radius: 8, y: 3))
                .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var emptyStateCard: some View {
        HStack(spacing: 10) {
            Text("📜").font(AppFont.rounded(size: 26, weight: .regular))
            Text(l10n.localized(
                zh: "完成任意对局后会自动保存在这里，随时可以回看复盘！",
                en: "Finished matches are saved right here for replay and AI review!",
                ja: "対局が終わると自動的にここに保存され、いつでも見返せます！",
                ko: "대국을 마치면 자동으로 여기에 저장되어 언제든 복기할 수 있어요!",
                zhHant: "完成任意對局後會自動保存在這裡，隨時可以回看復盤！"
            ))
            .font(AppFont.rounded(size: 13, weight: .semibold))
            .foregroundColor(AppTheme.inkSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(cornerRadius: 24, padding: 12)
    }
}

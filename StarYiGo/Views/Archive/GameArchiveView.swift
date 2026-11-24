//
//  GameArchiveView.swift
//  StarYi Go — Glossy Nintendo Switch SGF Dojo
//

import SwiftUI

struct GameArchiveView: View {
    @EnvironmentObject var appState: AppState

    enum DojoTab: Hashable {
        case classics
        case myGames
    }

    @State private var selectedTab: DojoTab = .classics

    private var l10n: L10n { appState.l10n }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            VStack(spacing: 16) {
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        appState.popRoute()
                    }

                    Spacer()

                    GameTitleCrest(title: l10n.t("archive.title"))

                    Spacer()

                    HStack(spacing: 10) {
                        tabPill(title: l10n.t("archive.tab.classics"), tab: .classics)
                        tabPill(title: "\(l10n.t("archive.tab.myGames")) (\(appState.savedGames.count))", tab: .myGames)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)

                let records: [SavedGameRecord] = (selectedTab == .classics)
                    ? BuiltInClassicGames.records(l10n: l10n)
                    : appState.savedGames

                if records.isEmpty {
                    VStack(spacing: 16) {
                        Text("📜").font(.system(size: 58))
                        Text(l10n.t("archive.empty.title"))
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(l10n.t("archive.empty.subtitle"))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)

                        Button {
                            withAnimation { selectedTab = .classics }
                        } label: {
                            Label(l10n.t("archive.tab.classics"), systemImage: "scroll.fill")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 320, maximum: 440), spacing: 18)],
                            spacing: 18
                        ) {
                            ForEach(records) { record in
                                recordCard(record, canDelete: selectedTab == .myGames)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 28)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if !appState.savedGames.isEmpty {
                selectedTab = .myGames
            }
        }
    }

    private func tabPill(title: String, tab: DojoTab) -> some View {
        let active = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(active ? .white : AppTheme.inkPrimary)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: active ? .grape : .snow,
                cornerRadius: 999,
                rimHeight: 5,
                whiteBorderWidth: 3
            )
        )
        .accessibilityIdentifier(tab == .myGames ? "ArchiveMyGamesTab" : "ArchiveClassicsTab")
    }

    private func recordCard(_ record: SavedGameRecord, canDelete: Bool) -> some View {
        Button {
            appState.navigationPath.append(.reviewGame(recordId: record.id))
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("\(record.boardSize)×\(record.boardSize)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))

                    Text(record.resultString)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)))

                    Spacer()

                    if canDelete {
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                    } else {
                        Image(systemName: "scroll.fill")
                            .font(.system(size: 18))
                            .foregroundColor(AppTheme.grapeBottom)
                    }
                }

                HStack(spacing: 8) {
                    Circle().fill(Color(white: 0.14)).frame(width: 14, height: 14)
                    Text(record.blackName)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                    Text(record.whiteName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                }

                HStack {
                    Text(l10n.t("game.moveCount", record.moveCount))
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)

                    Spacer()

                    if canDelete {
                        Button(role: .destructive) {
                            appState.deleteSavedGame(id: record.id)
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 15))
                                .foregroundColor(AppTheme.coralBottom)
                                .frame(width: AppTheme.buttonFaceHeight, height: AppTheme.buttonFaceHeight)
                                .contentShape(Rectangle())
                        }
                        .tactileButton(scale: 0.9)
                    } else {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.grapeTop, AppTheme.grapeBottom], startPoint: .top, endPoint: .bottom))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 26, rimHeight: 5, whiteBorderWidth: 3, pressStyle: .card))
        .accessibilityIdentifier("ArchiveGameRecord")
    }
}

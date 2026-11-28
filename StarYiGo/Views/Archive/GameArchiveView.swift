//
//  GameArchiveView.swift
//  StarYi Go — Nintendo-Style Go Knowledge & Masterpieces Academy (棋谱书院)
//  100% Pure Knowledge & Masterpieces Hall: 传奇名局 · 棋理十诀 · 布局流派 · 奇局趣史
//

import SwiftUI

struct GameArchiveView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.zoomTransitionNamespace) private var zoomNamespace
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private enum ArchiveTab: Equatable {
        case hall(AcademyHall)
        case codex
    }

    @State private var selectedTab: ArchiveTab = .hall(.masterpieces)
    @State private var selectedLevel: AcademyLevel = .all
    @State private var showStarCoinGuide = false

    private var l10n: L10n { appState.l10n }

    private var studiedCount: Int {
        GoAcademyLibrary.allEntries.filter { appState.profile.studiedAcademyIds.contains($0.id) }.count
    }

    private var codexMasteredCount: Int {
        GoTermCodex.allEntries.filter { appState.profile.unlockedCodexIds.contains($0.id) }.count
    }

    private var selectedHall: AcademyHall {
        if case .hall(let hall) = selectedTab {
            return hall
        }
        return .masterpieces
    }

    private var filteredEntries: [AcademyEntry] {
        GoAcademyLibrary.entries(in: selectedHall, level: selectedLevel)
    }

    var body: some View {
        ZStack {
            if selectedTab == .codex {
                SceneBackdrop.termAlbum
            } else {
                SceneBackdrop.recordDesk
            }

            VStack(spacing: 14) {
                // Top Bar: Back + Academy Crest + Star Coins
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        appState.popRoute()
                    }

                    Spacer()

                    GameTitleCrest(
                        title: l10n.t("archive.title"),
                        subtitle: selectedTab == .codex
                            ? l10n.t("codex.collectedCount", codexMasteredCount, GoTermCodex.allEntries.count)
                            : l10n.localized(
                                zh: "已赏析 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) 篇 ★",
                                en: "Studied \(studiedCount) / \(GoAcademyLibrary.allEntries.count) ★",
                                ja: "鑑賞済 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) ★",
                                ko: "감상 완료 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) ★",
                                zhHant: "已賞析 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) 篇 ★"
                            )
                    )

                    Spacer()

                    Button {
                        showStarCoinGuide = true
                    } label: {
                        HStack(spacing: 5) {
                            StarCoinBadgeView(size: 17)
                            Text("\(appState.profile.starCoins)")
                                .font(AppFont.rounded(size: 14.5, weight: .black))
                                .foregroundColor(AppTheme.inkPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.95)).shadow(color: AppTheme.sunBottom.opacity(0.14), radius: 8, y: 3))
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                    .tactileButton(scale: 0.95, sound: false)
                    .accessibilityLabel(l10n.localized(
                        zh: "星币 \(appState.profile.starCoins)",
                        en: "\(appState.profile.starCoins) Star Coins",
                        ja: "星コイン \(appState.profile.starCoins)",
                        ko: "별코인 \(appState.profile.starCoins)",
                        zhHant: "星幣 \(appState.profile.starCoins)"
                    ))
                    .accessibilityHint(l10n.localized(
                        zh: "查看星币说明",
                        en: "Learn what Star Coins are for",
                        ja: "星コインの説明を見る",
                        ko: "별코인 안내 보기",
                        zhHant: "查看星幣說明"
                    ))
                    .accessibilityIdentifier("ArchiveStarCoinButton")
                    .popover(isPresented: $showStarCoinGuide, arrowEdge: .top) {
                        starCoinGuidePopover
                            .presentationCompactAdaptation(.sheet)
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                // Row 1: 4 Academy Hall Pills + Go Codex Pill
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AcademyHall.allCases) { hall in
                            let allInHall = GoAcademyLibrary.allEntries.filter { $0.hall == hall }
                            let doneInHall = allInHall.filter { appState.profile.studiedAcademyIds.contains($0.id) }.count
                            hallPill(hall: hall, done: doneInHall, total: allInHall.count)
                        }
                        codexTabPill
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                }

                if selectedTab == .codex {
                    GoCodexView(embeddedInArchive: true)
                } else {
                    // Hall Content Grid — the small rank filter pills travel with the
                    // scrolling content; only the big archive crest above stays pinned.
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            // Row 2: Level Filter Pills (全部 / 启蒙 / 进阶 / 高阶 / 段位)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(AcademyLevel.allCases) { level in
                                        levelPill(level: level)
                                    }
                                }
                            }

                            hallHeaderBanner(selectedHall)

                            if filteredEntries.isEmpty {
                                VStack(spacing: 12) {
                                    Text("✨").font(AppFont.rounded(size: 46, weight: .regular))
                                    Text(l10n.localized(
                                        zh: "该棋力分级下暂无展品，切换「全部」浏览本馆全部名篇！",
                                        en: "No entries in this rank band — tap 'All' to browse this entire hall!",
                                        ja: "この棋力帯にはまだありません。「すべて」で全作品を見られます！",
                                        ko: "이 기력대에는 아직 항목이 없어요. '전체'를 눌러 둘러보세요!",
                                        zhHant: "該棋力分級下暫無展品，切換「全部」瀏覽本館全部名篇！"
                                    ))
                                    .font(AppFont.rounded(size: 14.5, weight: .bold))
                                    .foregroundColor(AppTheme.inkSecondary)
                                    .multilineTextAlignment(.center)

                                    Button {
                                        withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                                            selectedLevel = .all
                                        }
                                    } label: {
                                        Text(l10n.localized(zh: "查看本馆全部", en: "Show All", ja: "すべて見る", ko: "전체 보기", zhHant: "查看本館全部"))
                                            .font(AppFont.rounded(size: 14, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                    }
                                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2.5))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 48)
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 310, maximum: 440), spacing: 16)],
                                    spacing: 16
                                ) {
                                    ForEach(filteredEntries) { entry in
                                        academyCard(entry)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Star Coin Guide Popover

    /// Compact explanation shown when the star-coin capsule in the top bar is tapped.
    private var starCoinGuidePopover: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                StarCoinBadgeView(size: 38)

                VStack(alignment: .leading, spacing: 2) {
                    Text(l10n.localized(
                        zh: "星币",
                        en: "Star Coins",
                        ja: "星コイン",
                        ko: "별코인",
                        zhHant: "星幣"
                    ))
                    .font(AppFont.rounded(size: 18, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text(l10n.localized(
                        zh: "当前 \(appState.profile.starCoins) 枚",
                        en: "\(appState.profile.starCoins) in hand",
                        ja: "いま \(appState.profile.starCoins) 枚",
                        ko: "현재 \(appState.profile.starCoins)개",
                        zhHant: "目前 \(appState.profile.starCoins) 枚"
                    ))
                    .font(AppFont.rounded(size: 12.5, weight: .black))
                    .foregroundColor(AppTheme.sunBottom)
                }

                Spacer(minLength: 8)

                Button {
                    showStarCoinGuide = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            Text(l10n.localized(
                zh: "做题、对局、每日道场和定式都会奖励星币。星币可以在「设置」里解锁新的棋盘和棋子外观，不兑换就不会消耗。",
                en: "Puzzles, matches, the Daily Dojo and joseki all reward Star Coins. Spend them in Settings to unlock new board and stone styles — they are only used when you redeem them.",
                ja: "問題・対局・毎日道場・定石で星コインがもらえます。設定で新しい碁盤や碁石の見た目と交換でき、交換しない限り減りません。",
                ko: "퍼즐, 대국, 매일 도장, 정석에서 별코인을 받을 수 있어요. 설정에서 새로운 바둑판과 바둑돌 모양으로 교환할 수 있으며, 교환할 때만 사용돼요.",
                zhHant: "做題、對局、每日道場和定式都會獎勵星幣。星幣可以在「設定」裡解鎖新的棋盤和棋子外觀，不兌換就不會消耗。"
            ))
            .font(AppFont.rounded(size: 13.5, weight: .semibold))
            .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
            .fixedSize(horizontal: false, vertical: true)

            Button {
                showStarCoinGuide = false
            } label: {
                Text(l10n.localized(
                    zh: "知道了",
                    en: "Got it",
                    ja: "わかった",
                    ko: "알겠어요",
                    zhHant: "知道了"
                ))
                .font(AppFont.rounded(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2.5))
        }
        .padding(18)
        .frame(minWidth: 300, idealWidth: 340, maxWidth: 380)
        .background(Color(red: 0.97, green: 0.985, blue: 1.0))
    }

    // MARK: - Hall & Level Pills

    private func hallPill(hall: AcademyHall, done: Int, total: Int) -> some View {
        let active = selectedTab == .hall(hall)
        let accent = Color(hex: hall.accentHex)
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                selectedTab = .hall(hall)
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: hall.symbolName)
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                Text("\(hall.title(l10n)) \(done)/\(total)")
                    .font(AppFont.rounded(size: 13.5, weight: .black))
            }
            .foregroundColor(active ? .white : AppTheme.inkPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(minHeight: AppTheme.buttonFaceHeight)
            .background(
                Capsule()
                    .fill(active ? accent : Color.white.opacity(0.92))
                    .shadow(color: active ? accent.opacity(0.28) : Color.black.opacity(0.06), radius: 6, y: 2)
            )
            .overlay(Capsule().strokeBorder(.white, lineWidth: active ? 2 : 1.5))
        }
        .tactileButton(scale: 0.95, sound: false)
        .accessibilityIdentifier("AcademyHall_\(hall.rawValue)")
    }

    private var codexTabPill: some View {
        let active = selectedTab == .codex
        let accent = AppTheme.skyBottom
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                selectedTab = .codex
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                Text("\(l10n.t("codex.title")) \(codexMasteredCount)/\(GoTermCodex.allEntries.count)")
                    .font(AppFont.rounded(size: 13.5, weight: .black))
            }
            .foregroundColor(active ? .white : AppTheme.inkPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(minHeight: AppTheme.buttonFaceHeight)
            .background(
                Capsule()
                    .fill(active ? accent : Color.white.opacity(0.92))
                    .shadow(color: active ? accent.opacity(0.28) : Color.black.opacity(0.06), radius: 6, y: 2)
            )
            .overlay(Capsule().strokeBorder(.white, lineWidth: active ? 2 : 1.5))
        }
        .tactileButton(scale: 0.95, sound: false)
        .accessibilityIdentifier("AcademyHall_codex")
    }

    private func levelPill(level: AcademyLevel) -> some View {
        let active = selectedLevel == level
        return Button {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.80)) {
                selectedLevel = level
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            Text(level.title(l10n))
                .font(AppFont.rounded(size: 12.5, weight: .black))
                .foregroundColor(active ? .white : AppTheme.inkSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(active ? AppTheme.skyBottom : Color.white.opacity(0.82))
                )
                .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
        }
        .tactileButton(scale: 0.95, sound: false)
    }

    private func hallHeaderBanner(_ hall: AcademyHall) -> some View {
        let accent = Color(hex: hall.accentHex)
        return HStack(spacing: 12) {
            Image(systemName: hall.symbolName)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(hall.title(l10n))
                    .font(AppFont.rounded(size: 17, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                Text(hall.subtitle(l10n))
                    .font(AppFont.rounded(size: 12.5, weight: .semibold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.86))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white, lineWidth: 2))
        )
    }

    // MARK: - Academy Exhibit Card

    private func academyCard(_ entry: AcademyEntry) -> some View {
        let isStudied = appState.profile.studiedAcademyIds.contains(entry.id)
        let accent = Color(hex: entry.hall.accentHex)

        return Button {
            appState.navigationPath.append(.reviewGame(recordId: entry.recordId))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                // Row 1: Uniform-height tag bar (26pt fixed)
                HStack(spacing: 6) {
                    Text("\(entry.boardSize)×\(entry.boardSize)")
                        .font(AppFont.rounded(size: 11.5, weight: .black))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))

                    Text(entry.rankTag)
                        .font(AppFont.rounded(size: 11, weight: .black))
                        .foregroundColor(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.opacity(0.12)))

                    if entry.hall == .masterpieces {
                        Text(l10n.localized(
                            zh: "全谱 \(entry.moveCount) 手",
                            en: "\(entry.moveCount) moves",
                            ja: "全\(entry.moveCount)手",
                            ko: "전보 \(entry.moveCount)수",
                            zhHant: "全譜 \(entry.moveCount) 手"
                        ))
                        .font(AppFont.rounded(size: 10.5, weight: .black))
                        .foregroundColor(AppTheme.mintBottom)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.mintTop.opacity(0.14)))
                    }

                    Spacer(minLength: 4)

                    if isStudied {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11.5, weight: .black, design: .rounded))
                            Text(l10n.localized(zh: "已赏析 ★", en: "Studied ★", ja: "鑑賞済 ★", ko: "감상 ★", zhHant: "已賞析 ★"))
                                .font(AppFont.rounded(size: 10.5, weight: .black))
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .foregroundColor(AppTheme.sunBottom)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.softGoldBg))
                    }
                }
                .frame(height: 26)

                // Row 2: Title (uniform 2-line space)
                Text(entry.title(l10n))
                    .font(AppFont.rounded(size: 17.5, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                // Row 3: Story Hook (uniform 3-line space)
                Text(entry.hook(l10n))
                    .font(AppFont.rounded(size: 13, weight: .semibold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2.5)
                    .lineLimit(3, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 2)

                // Row 4: Era / Tag pinned cleanly at the exact same bottom baseline
                Text(entry.eraOrTag(l10n))
                    .font(AppFont.rounded(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 224, maxHeight: 224, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, minHeight: 224, maxHeight: 224)
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 26, rimHeight: 3, whiteBorderWidth: 3, pressStyle: .card))
        .accessibilityIdentifier("AcademyEntry_\(entry.id)")
        .modifier(OptionalZoomSourceModifier(id: entry.recordId, namespace: zoomNamespace))
    }
}

private struct OptionalZoomSourceModifier<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

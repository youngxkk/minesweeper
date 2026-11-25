//
//  GameArchiveView.swift
//  StarYi Go — Nintendo-Style Go Knowledge & Masterpieces Academy (棋谱书院)
//  100% Pure Knowledge & Masterpieces Hall: 传奇名局 · 棋理十诀 · 布局流派 · 奇局趣史
//

import SwiftUI

struct GameArchiveView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedHall: AcademyHall = .masterpieces
    @State private var selectedLevel: AcademyLevel = .all

    private var l10n: L10n { appState.l10n }

    private var studiedCount: Int {
        GoAcademyLibrary.allEntries.filter { appState.profile.studiedAcademyIds.contains($0.id) }.count
    }

    private var filteredEntries: [AcademyEntry] {
        GoAcademyLibrary.entries(in: selectedHall, level: selectedLevel)
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            VStack(spacing: 14) {
                // Top Bar: Back + Academy Crest + Star Coins
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        appState.popRoute()
                    }

                    Spacer()

                    GameTitleCrest(
                        title: l10n.t("archive.title"),
                        subtitle: l10n.localized(
                            zh: "已赏析 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) 篇 ★",
                            en: "Studied \(studiedCount) / \(GoAcademyLibrary.allEntries.count) ★",
                            ja: "鑑賞済 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) ★",
                            ko: "감상 완료 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) ★",
                            zhHant: "已賞析 \(studiedCount) / \(GoAcademyLibrary.allEntries.count) 篇 ★"
                        )
                    )

                    Spacer()

                    HStack(spacing: 5) {
                        StarCoinBadgeView(size: 17)
                        Text("\(appState.profile.starCoins)")
                            .font(.system(size: 14.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.95)).shadow(color: AppTheme.sunBottom.opacity(0.14), radius: 8, y: 3))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                // Row 1: 4 Pure Academy Hall Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(AcademyHall.allCases) { hall in
                            let allInHall = GoAcademyLibrary.allEntries.filter { $0.hall == hall }
                            let doneInHall = allInHall.filter { appState.profile.studiedAcademyIds.contains($0.id) }.count
                            hallPill(hall: hall, done: doneInHall, total: allInHall.count)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 2)
                }

                // Row 2: Level Filter Pills (全部 / 启蒙 / 进阶 / 高阶 / 段位)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(AcademyLevel.allCases) { level in
                            levelPill(level: level)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // Hall Content Grid
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        hallHeaderBanner(selectedHall)

                        if filteredEntries.isEmpty {
                            VStack(spacing: 12) {
                                Text("✨").font(.system(size: 46))
                                Text(l10n.localized(
                                    zh: "该棋力分级下暂无展品，切换「全部」浏览本馆全部名篇！",
                                    en: "No entries in this rank band — tap 'All' to browse this entire hall!",
                                    ja: "この棋力帯にはまだありません。「すべて」で全作品を見られます！",
                                    ko: "이 기력대에는 아직 항목이 없어요. '전체'를 눌러 둘러보세요!",
                                    zhHant: "該棋力分級下暫無展品，切換「全部」瀏覽本館全部名篇！"
                                ))
                                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.inkSecondary)
                                .multilineTextAlignment(.center)

                                Button {
                                    withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                                        selectedLevel = .all
                                    }
                                } label: {
                                    Text(l10n.localized(zh: "查看本馆全部", en: "Show All", ja: "すべて見る", ko: "전체 보기", zhHant: "查看本館全部"))
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                }
                                .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
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
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hall & Level Pills

    private func hallPill(hall: AcademyHall, done: Int, total: Int) -> some View {
        let active = selectedHall == hall
        let accent = Color(hex: hall.accentHex)
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                selectedHall = hall
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: hall.symbolName)
                    .font(.system(size: 13.5, weight: .black))
                Text("\(hall.title(l10n)) \(done)/\(total)")
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
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

    private func levelPill(level: AcademyLevel) -> some View {
        let active = selectedLevel == level
        return Button {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.80)) {
                selectedLevel = level
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            Text(level.title(l10n))
                .font(.system(size: 12.5, weight: .black, design: .rounded))
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
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(accent))

            VStack(alignment: .leading, spacing: 2) {
                Text(hall.title(l10n))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                Text(hall.subtitle(l10n))
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
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
            VStack(alignment: .leading, spacing: 10) {
                // Row 1: Board Size + Rank Tag + Studied Stamp
                HStack(spacing: 6) {
                    Text("\(entry.boardSize)×\(entry.boardSize)")
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))

                    Text(entry.rankTag)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(accent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(accent.opacity(0.12)))

                    Spacer()

                    if isStudied {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .black))
                            Text(l10n.localized(zh: "已赏析 ★", en: "Studied ★", ja: "鑑賞済 ★", ko: "감상 ★", zhHant: "已賞析 ★"))
                                .font(.system(size: 11, weight: .black, design: .rounded))
                        }
                        .foregroundColor(AppTheme.sunBottom)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.softGoldBg))
                    } else {
                        Text(entry.eraOrTag(l10n))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                            .lineLimit(1)
                    }
                }

                // Row 2: Title
                Text(entry.title(l10n))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Row 3: Story Hook
                Text(entry.hook(l10n))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineSpacing(2.5)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                // Row 4: Interactive Feature Badges + Play Chevron
                HStack(spacing: 6) {
                    if entry.hasQuiz {
                        featureTag(
                            icon: "sparkles",
                            text: l10n.localized(zh: "猜大师下一手", en: "Master Quiz", ja: "次の一手", ko: "다음 수 퀴즈", zhHant: "猜大師下一手"),
                            color: AppTheme.grapeBottom
                        )
                    }
                    if entry.hasCounterExample {
                        featureTag(
                            icon: "arrow.left.arrow.right",
                            text: l10n.localized(zh: "正反对比", en: "Good vs Mistake", ja: "正誤比較", ko: "정수 vs 실수", zhHant: "正反對比"),
                            color: AppTheme.coralBottom
                        )
                    }
                    if !entry.highlights.isEmpty && !entry.hasCounterExample {
                        featureTag(
                            icon: "bookmark.fill",
                            text: l10n.localized(zh: "\(entry.highlights.count) 处高光", en: "\(entry.highlights.count) Highlights", ja: "\(entry.highlights.count) 見どころ", ko: "하이라이트 \(entry.highlights.count)", zhHant: "\(entry.highlights.count) 處高光"),
                            color: AppTheme.mintBottom
                        )
                    }

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(LinearGradient(colors: [accent.opacity(0.85), accent], startPoint: .top, endPoint: .bottom))
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 26, rimHeight: 5, whiteBorderWidth: 3, pressStyle: .card))
        .accessibilityIdentifier("AcademyEntry_\(entry.id)")
    }

    private func featureTag(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .black))
            Text(text)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.11)))
    }
}

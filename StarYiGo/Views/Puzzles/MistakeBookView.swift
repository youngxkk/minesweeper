//
//  MistakeBookView.swift
//  StarYi Go — Dedicated Tsumego Mistake Notebook (Standalone, Elegant Workbook UI)
//

import SwiftUI

struct MistakeBookView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedCategory: PuzzleCategory? = nil
    @State private var appeared: Bool = false

    private var l10n: L10n { appState.l10n }

    private var allMistakePuzzles: [GoPuzzle] {
        appState.puzzleProgress.mistakeBookIds.compactMap { appState.findAnyPuzzle(withId: $0) }
    }

    private var srsByPuzzleId: [String: SRSMistakeItem] {
        Dictionary(
            appState.puzzleProgress.srsMistakeItems.map { ($0.puzzleId, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private var dueCount: Int {
        allMistakePuzzles.filter { srsByPuzzleId[$0.id]?.isDueNow ?? true }.count
    }

    private var availableCategories: [PuzzleCategory] {
        let present = Set(allMistakePuzzles.map(\.category))
        return PuzzleCategory.allCases.filter { present.contains($0) }
    }

    private var filteredPuzzles: [GoPuzzle] {
        let base: [GoPuzzle]
        if let selectedCategory {
            base = allMistakePuzzles.filter { $0.category == selectedCategory }
        } else {
            base = allMistakePuzzles
        }
        // Show due-for-review items first so kids naturally tackle what needs reinforcement most
        return base.sorted { a, b in
            let aDue = srsByPuzzleId[a.id]?.isDueNow ?? true
            let bDue = srsByPuzzleId[b.id]?.isDueNow ?? true
            if aDue != bDue { return aDue }
            return a.rankOrderValue > b.rankOrderValue
        }
    }

    var body: some View {
        ZStack {
            SceneBackdrop.mistakeNotebook

            VStack(spacing: 14) {
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 12)

                if allMistakePuzzles.isEmpty {
                    emptyNotebookView
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 18) {
                            summaryHeaderBanner
                                .modifier(StaggeredEntranceModifier(appeared: appeared, delay: 0.03, reduceMotion: reduceMotion, offsetY: 14))

                            if availableCategories.count > 1 {
                                categoryFilterStrip
                                    .modifier(StaggeredEntranceModifier(appeared: appeared, delay: 0.07, reduceMotion: reduceMotion, offsetY: 12))
                            }

                            puzzleCardsGrid
                                .modifier(StaggeredEntranceModifier(appeared: appeared, delay: 0.11, reduceMotion: reduceMotion, offsetY: 16))
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            appeared = true
            if let cat = selectedCategory, !availableCategories.contains(cat) {
                selectedCategory = nil
            }
        }
    }

    // MARK: - Top Bar (Centered Title, Back Button Only — No Redundant Mistake Button)

    private var topBar: some View {
        ZStack {
            GameTitleCrest(
                title: l10n.t("puzzle.category.mistakes"),
                subtitle: allMistakePuzzles.isEmpty
                    ? l10n.localized(
                        zh: "所有错题已清空",
                        en: "All mistakes mastered",
                        ja: "間違いノートは空です",
                        ko: "모든 오답을 정복했어요",
                        zhHant: "所有錯題已清空"
                    )
                    : l10n.localized(
                        zh: "共 \(allMistakePuzzles.count) 道错题 · 攻克后自动移出",
                        en: "\(allMistakePuzzles.count) to review · Clears automatically when mastered",
                        ja: "全\(allMistakePuzzles.count)問 · 正解でクリア",
                        ko: "총 \(allMistakePuzzles.count)문제 · 마스터하면 자동 완료",
                        zhHant: "共 \(allMistakePuzzles.count) 道錯題 · 攻克後自動移出"
                    )
            )
            .accessibilityIdentifier("MistakeBookTitle")

            HStack {
                GameBackButton(title: l10n.t("common.back")) {
                    appState.popRoute()
                }
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary Banner & Quick Start CTA

    private var summaryHeaderBanner: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.00, green: 0.78, blue: 0.34), Color(red: 0.96, green: 0.54, blue: 0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .shadow(color: AppTheme.sunBottom.opacity(0.28), radius: 8, y: 4)
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(l10n.localized(
                        zh: "把错题变成你的必杀技",
                        en: "Turn Mistakes Into Strengths",
                        ja: "間違いを最強の武器にしよう",
                        ko: "오답을 나만의 필살기로!",
                        zhHant: "把錯題變成你的必殺技"
                    ))
                    .font(AppFont.rounded(size: 19, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                    if dueCount > 0 {
                        Text(l10n.localized(
                            zh: "\(dueCount) 题待复习",
                            en: "\(dueCount) Due",
                            ja: "\(dueCount)問 復習待ち",
                            ko: "\(dueCount)문제 복습 대기",
                            zhHant: "\(dueCount) 題待複習"
                        ))
                        .font(AppFont.rounded(size: 11.5, weight: .black))
                        .foregroundColor(Color(red: 0.78, green: 0.34, blue: 0.08))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color(red: 1.0, green: 0.92, blue: 0.76)))
                    }
                }

                Text(l10n.localized(
                    zh: "点击任意棋形即可重新挑战，答对后会按记忆曲线巩固并自动移出错题本。",
                    en: "Tap any board below to replay it. Mastered puzzles graduate out automatically.",
                    ja: "下の盤面をタップして再挑戦。しっかり解けるようになると自動で卒業します。",
                    ko: "아래 바둑판 카드를 눌러 다시 도전해 보세요. 완전히 익히면 자동으로 졸업합니다.",
                    zhHant: "點擊任意棋形即可重新挑戰，答對後會按記憶曲線鞏固並自動移出錯題本。"
                ))
                .font(AppFont.rounded(size: 13.5, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            if let firstPuzzle = filteredPuzzles.first {
                Button {
                    openPuzzle(firstPuzzle)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                        Text(l10n.localized(
                            zh: "开始消灭错题",
                            en: "Start Review",
                            ja: "復習をはじめる",
                            ko: "오답 복습 시작",
                            zhHant: "開始消滅錯題"
                        ))
                        .font(AppFont.rounded(size: 15.5, weight: .black))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 13)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: .sun,
                        cornerRadius: 999,
                        rimHeight: 3,
                        whiteBorderWidth: 3,
                        showStripeSheen: true
                    )
                )
                .accessibilityIdentifier("MistakeBookQuickStartButton")
            }
        }
        .warmCard(cornerRadius: 26, padding: 18)
    }

    // MARK: - Category Filter Strip

    private var categoryFilterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(
                    title: l10n.localized(zh: "全部 (\(allMistakePuzzles.count))", en: "All (\(allMistakePuzzles.count))", ja: "すべて (\(allMistakePuzzles.count))", ko: "전체 (\(allMistakePuzzles.count))", zhHant: "全部 (\(allMistakePuzzles.count))"),
                    icon: "square.grid.2x2.fill",
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        selectedCategory = nil
                    }
                }

                ForEach(availableCategories) { category in
                    let count = allMistakePuzzles.filter { $0.category == category }.count
                    filterChip(
                        title: "\(category.displayTitle(isChinese: l10n.language.isChinese)) (\(count))",
                        icon: category.symbolName,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 3)
        }
        // Keep the glossy chips' soft contact shadows from being sliced off by the
        // scroll container's tight bounds (same treatment as the Home hero cards).
        .scrollClipDisabled()
        .scrollBounceBehavior(.basedOnSize)
    }

    private func filterChip(title: String, icon: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                Text(title)
                    .font(AppFont.rounded(size: 13.5, weight: .black))
            }
            .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: isSelected ? .sky : .snow,
                cornerRadius: 999,
                rimHeight: 2.5,
                whiteBorderWidth: 2.5
            )
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Visual Tsumego Workbook Grid

    private var puzzleCardsGrid: some View {
        let columns = [
            GridItem(.adaptive(minimum: 270, maximum: 360), spacing: 16)
        ]
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(filteredPuzzles.enumerated()), id: \.element.id) { idx, puzzle in
                mistakeWorkbookCard(number: idx + 1, puzzle: puzzle)
            }
        }
    }

    private func mistakeWorkbookCard(number: Int, puzzle: GoPuzzle) -> some View {
        let srs = srsByPuzzleId[puzzle.id]
        let isDue = srs?.isDueNow ?? true
        let streak = srs?.correctStreak ?? 0

        return Button {
            openPuzzle(puzzle)
        } label: {
            HStack(spacing: 14) {
                // Live cropped miniature Go board preview
                GoBoardView(
                    boardState: puzzle.initialBoardState(),
                    theme: appState.settings.boardTheme,
                    stoneStyle: appState.settings.stoneStyle,
                    cropRegion: puzzle.cropRegion,
                    showCoordinates: false,
                    highlightAtari: false,
                    expressiveStones: false,
                    isInteractive: false
                )
                .frame(width: 116, height: 116)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(AppTheme.subtleBorder(for: colorSchemeContrast), lineWidth: 1.5)
                )
                .allowsHitTesting(false)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(puzzle.title(l10n))
                        .font(AppFont.rounded(size: 15.5, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text("#\(number)")
                            .font(AppFont.rounded(size: 10.5, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(isDue ? Color(red: 0.94, green: 0.50, blue: 0.24) : AppTheme.mintBottom))

                        Text(puzzle.rankBadge)
                            .font(AppFont.rounded(size: 10.5, weight: .black))
                            .foregroundColor(AppTheme.skyBottom)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(AppTheme.skyTop.opacity(0.14)))

                        Spacer(minLength: 0)
                    }

                    Text(puzzle.prompt(l10n))
                        .font(AppFont.rounded(size: 12, weight: .semibold))
                        .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 2)

                    HStack(spacing: 6) {
                        Text(puzzle.category.displayTitle(isChinese: l10n.language.isChinese))
                            .font(AppFont.rounded(size: 11, weight: .bold))
                            .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))

                        if streak > 0 {
                            Text("·")
                                .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                            Text(l10n.localized(
                                zh: "巩固 \(streak)/3",
                                en: "Mastery \(streak)/3",
                                ja: "定着 \(streak)/3",
                                ko: "복습 \(streak)/3",
                                zhHant: "鞏固 \(streak)/3"
                            ))
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                        }

                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .frame(minHeight: 144)
            .warmCard(cornerRadius: 22, padding: 0)
        }
        .buttonStyle(.plain)
        .tactileCard()
        .accessibilityLabel("\(puzzle.title(l10n)), \(puzzle.rankBadge), \(puzzle.prompt(l10n))")
    }

    // MARK: - Joyful Empty State

    private var emptyNotebookView: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.sunTop, AppTheme.sunBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 88, height: 88)
                        .shadow(color: AppTheme.sunBottom.opacity(0.32), radius: 14, y: 6)
                    Image(systemName: "sparkles")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                Text(l10n.t("puzzle.mistakes.empty"))
                    .font(AppFont.rounded(size: 22, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                    .multilineTextAlignment(.center)

                Text(l10n.localized(
                    zh: "闯关或每日道场里做错的题目会自动收录到这里，方便你随时集中复习！",
                    en: "Any tricky puzzles you miss in Adventure or Daily Dojo will appear here for focused review.",
                    ja: "冒険や毎日道場で間違えた問題が自動的にここへ集まり、いつでも復習できます。",
                    ko: "모험이나 매일 도장에서 틀린 문제가 자동으로 모여 언제든 집중 복습할 수 있어요.",
                    zhHant: "闖關或每日道場裡做錯的題目會自動收錄到這裡，方便你隨時集中複習！"
                ))
                .font(AppFont.rounded(size: 14.5, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)

                Button {
                    appState.navigationPath.append(.puzzleHub(initialMistakesOnly: false))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                        Text(l10n.localized(
                            zh: "去星弈大冒险闯关",
                            en: "Explore StarYi Adventure",
                            ja: "星弈アドベンチャーへ",
                            ko: "별이 모험 떠나기",
                            zhHant: "去星弈大冒險闖關"
                        ))
                        .font(AppFont.rounded(size: 16, weight: .black))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: .sun,
                        cornerRadius: 999,
                        rimHeight: 4,
                        whiteBorderWidth: 3.5,
                        showStripeSheen: true
                    )
                )
                .padding(.top, 4)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 34)
            .warmCard(cornerRadius: 32, padding: 0)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openPuzzle(_ puzzle: GoPuzzle) {
        SoundAndHapticsManager.shared.playUITap()
        appState.navigationPath.append(
            .puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false, isStarterBootcamp: false)
        )
    }
}

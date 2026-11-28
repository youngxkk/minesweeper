//
//  TrainingDojoView.swift
//  StarYi Go — Unified P1+P2 Go Training Dojo (320+ Graded Tsumego, SRS Mistakes, Joseki, 4 Mini-Drills, Rank Exams)
//

import SwiftUI

struct TrainingDojoView: View {
    @EnvironmentObject var appState: AppState

    enum DojoSection: String, CaseIterable, Identifiable {
        case tsumego
        case joseki
        case drills

        var id: String { rawValue }
    }

    @State private var selectedSection: DojoSection = .tsumego
    @State private var selectedRankBand: DojoRankBand = .all
    @State private var selectedCategory: PuzzleCategory? = nil
    @State private var showExamPortalModal: Bool = false

    private let selectionTint = AppTheme.skyBottom
    private let badgeFill = AppTheme.skyTop.opacity(0.14)

    private var l10n: L10n { appState.l10n }

    private var availableCategories: [PuzzleCategory] {
        selectedRankBand.availableCategories(includeExpandedPack: true)
    }

    private var categoryCounts: [PuzzleCategory: Int] {
        DojoPuzzleBank.categoryCounts(for: selectedRankBand, includeExpandedPack: true)
    }

    private var filteredDojoPuzzles: [GoPuzzle] {
        let effectiveCategory = selectedCategory.flatMap { availableCategories.contains($0) ? $0 : nil }
        return DojoPuzzleBank.puzzles(category: effectiveCategory, rankBand: selectedRankBand, includeExpandedPack: true)
    }

    var body: some View {
        ZStack {
            SceneBackdrop.termAlbum

            VStack(spacing: 14) {
                // Header with independent Rank Exam Hall entry in the top-right corner
                ZStack {
                    GameTitleCrest(
                        title: l10n.localized(zh: "题库考级", en: "Drills & Exams", ja: "問題集・段級位", ko: "문제집·승급시험", zhHant: "題庫考級"),
                        subtitle: l10n.localized(
                            zh: "\(DojoPuzzleBank.fullCatalog.count)+ 题库 · 定式破招 · 专项训练",
                            en: "\(DojoPuzzleBank.fullCatalog.count)+ Puzzles · Joseki · Drills",
                            ja: "\(DojoPuzzleBank.fullCatalog.count)+ 詰碁 · 定石対策 · 特訓",
                            ko: "\(DojoPuzzleBank.fullCatalog.count)+ 사활 문제 · 정석 · 특훈",
                            zhHant: "\(DojoPuzzleBank.fullCatalog.count)+ 題庫 · 定石破招 · 專項訓練"
                        )
                    )

                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        examHallTopRightButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                // Top 3 Training Section Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        sectionTab(.tsumego, title: l10n.localized(zh: "分级题库 (\(DojoPuzzleBank.fullCatalog.count))", en: "Tsumego (\(DojoPuzzleBank.fullCatalog.count))", ja: "詰碁問題集 (\(DojoPuzzleBank.fullCatalog.count))", ko: "등급별 문제집 (\(DojoPuzzleBank.fullCatalog.count))", zhHant: "分級題庫 (\(DojoPuzzleBank.fullCatalog.count))"), icon: "square.grid.2x2.fill")
                        sectionTab(.joseki, title: l10n.localized(zh: "定式与破招", en: "Joseki Tree", ja: "定石と対策", ko: "정석과 파훼", zhHant: "定石與破招"), icon: "arrow.triangle.branch")
                        sectionTab(.drills, title: l10n.localized(zh: "五大专项小练", en: "5 Mini-Drills", ja: "5大ミニ特訓", ko: "5대 미니 특훈", zhHant: "五大專項小練"), icon: "bolt.circle.fill")
                    }
                    .padding(.horizontal, 24)
                }

                // Active Section Content
                ScrollView {
                    Group {
                        switch selectedSection {
                        case .tsumego:
                            tsumegoSection
                        case .joseki:
                            josekiSection
                        case .drills:
                            drillsSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }

            if showExamPortalModal {
                examPortalModalOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(50)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: showExamPortalModal)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var examHallTopRightButton: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                showExamPortalModal = true
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "rosette")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                Text(l10n.localized(zh: "星弈考级室", en: "Exam Hall", ja: "段級位試験室", ko: "승급 시험실", zhHant: "星弈考級室"))
                    .font(AppFont.rounded(size: 13.5, weight: .black))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2.5))
    }

    private func sectionTab(_ section: DojoSection, title: String, icon: String) -> some View {
        let active = selectedSection == section
        return Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) {
                selectedSection = section
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            Label(title, systemImage: icon)
                .font(AppFont.rounded(size: 13.5, weight: .black))
                .foregroundColor(active ? .white : AppTheme.inkPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: AppTheme.buttonFaceHeight)
                .background(
                    Capsule()
                        .fill(active ? selectionTint : Color.white.opacity(0.94))
                        .shadow(color: active ? selectionTint.opacity(0.26) : Color.black.opacity(0.05), radius: 6, y: 2)
                )
                .overlay(Capsule().strokeBorder(.white, lineWidth: active ? 2 : 1.5))
        }
        .tactileButton(scale: 0.97, sound: false)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    // MARK: - 1. 320+ Graded Tsumego Bank

    private var tsumegoSection: some View {
        let bandCategories = availableCategories
        let counts = categoryCounts
        return VStack(alignment: .leading, spacing: 14) {
            // Rank Band Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DojoRankBand.allCases) { band in
                        let selected = selectedRankBand == band
                        Button {
                            selectedRankBand = band
                            if let currentCat = selectedCategory,
                               !band.availableCategories(includeExpandedPack: true).contains(currentCat) {
                                selectedCategory = nil
                            }
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            Text(band.title(l10n))
                                .font(AppFont.rounded(size: 12, weight: .black))
                                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minHeight: AppTheme.buttonFaceHeight)
                                .background(Capsule().fill(selected ? selectionTint : .white))
                        }
                        .tactileButton(scale: 0.96, sound: false)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            // Rank-Tailored Topic Filter (adapts categories & labels per selected rank band)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(
                        nil,
                        title: l10n.localized(zh: "全部题型", en: "All Topics", ja: "すべての分野", ko: "전체 유형", zhHant: "全部題型"),
                        icon: "sparkles"
                    )
                    ForEach(bandCategories) { cat in
                        let count = counts[cat] ?? 0
                        let title = selectedRankBand.categoryTitle(for: cat, l10n: l10n)
                        categoryChip(cat, title: "\(title) (\(count))", icon: cat.symbolName)
                    }
                }
            }

            Text(l10n.localized(
                zh: "共筛选出 \(filteredDojoPuzzles.count) 道精校题目（支持棋盘旋转、镜像与黑白互换防背图）",
                en: "\(filteredDojoPuzzles.count) verified puzzles (rotation, reflection & color-swap supported)",
                ja: "\(filteredDojoPuzzles.count) 問の厳選問題（回転・反転・白黒入替対応で暗記を防止）",
                ko: "엄선된 \(filteredDojoPuzzles.count)문제 (회전·반전·흑백 전환 지원으로 암기 방지)",
                zhHant: "共篩選出 \(filteredDojoPuzzles.count) 道精校題目（支援棋盤旋轉、鏡像與黑白互換防背圖）"
            ))
                .font(AppFont.rounded(size: 12.5, weight: .bold))
                .foregroundColor(AppTheme.inkSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 270), spacing: 20)], spacing: 20) {
                ForEach(filteredDojoPuzzles) { puzzle in
                    puzzleCard(puzzle)
                }
            }
        }
    }

    private func categoryChip(_ cat: PuzzleCategory?, title: String, icon: String) -> some View {
        let selected = selectedCategory == cat
        return Button {
            selectedCategory = cat
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            Label(title, systemImage: icon)
                .font(AppFont.rounded(size: 12, weight: .heavy))
                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(minHeight: AppTheme.buttonFaceHeight)
                .background(Capsule().fill(selected ? selectionTint : .white))
        }
        .tactileButton(scale: 0.96, sound: false)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func puzzleCard(_ puzzle: GoPuzzle) -> some View {
        let stars = appState.puzzleProgress.starsByPuzzleId[puzzle.id] ?? 0
        return Button {
            appState.navigationPath.append(.puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false, isStarterBootcamp: false))
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(puzzle.rankBadge)
                        .font(AppFont.rounded(size: 12, weight: .black))
                        .foregroundColor(AppTheme.skyBottom)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(badgeFill))
                    Text(selectedRankBand.categoryTitle(for: puzzle.category, l10n: l10n))
                        .font(AppFont.rounded(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                    Spacer()
                    Text(puzzle.playerColor == .black ? "⚫️" : "⚪️")
                        .font(AppFont.rounded(size: 12, weight: .regular))
                }

                Text(puzzle.title(l10n))
                    .font(AppFont.rounded(size: 17, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= stars ? "star.fill" : "star")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundColor(i <= stars ? AppTheme.sunBottom : AppTheme.inkSecondary.opacity(0.45))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 24, rimHeight: 2.5, whiteBorderWidth: 2.5, pressStyle: .card))
    }

    // MARK: - 2. Interactive Joseki Courses

    private var josekiSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 16)], spacing: 16) {
            ForEach(JosekiLibrary.allCatalogCourses) { course in
                let done = appState.puzzleProgress.completedJosekiIds.contains(course.id)
                Button {
                    appState.navigationPath.append(.josekiTrainer(courseId: course.id))
                } label: {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(course.rankBadge)
                                .font(AppFont.rounded(size: 11.5, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AppTheme.grapeBottom))
                            Spacer()
                            if done {
                                Label(l10n.localized(zh: "已通关 ★", en: "Cleared ★", ja: "クリア済 ★", ko: "클리어 ★", zhHant: "已通關 ★"), systemImage: "checkmark.seal.fill")
                                    .font(AppFont.rounded(size: 12, weight: .black))
                                    .foregroundColor(AppTheme.mintBottom)
                            }
                        }
                        Text(course.title(l10n))
                            .font(AppFont.rounded(size: 17, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(course.subtitle(l10n))
                            .font(AppFont.rounded(size: 12.5, weight: .semibold))
                            .foregroundColor(AppTheme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 24, rimHeight: 3, whiteBorderWidth: 3, pressStyle: .card))
            }
        }
    }

    // MARK: - 4. Four Kid-Friendly Mini-Drills

    private var drillsSection: some View {
        let palettes: [MiniDrillKind: GlossyPalette] = [
            .speedLiberties: .coral,
            .ladderReading: .sky,
            .countingQuiz: .sun,
            .openingPicker: .mint,
            .blunderSpotter: .grape
        ]

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 280, maximum: 440), spacing: 16)], spacing: 16) {
            ForEach(MiniDrillKind.allCases) { kind in
                let pal = palettes[kind] ?? .sky
                Button {
                    appState.navigationPath.append(.miniDrill(kind: kind))
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: kind.symbolName)
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundColor(pal.bottom)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color.white).shadow(color: pal.rim.opacity(0.28), radius: 6, y: 2))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.title(isChinese: l10n.language.isChinese))
                                .font(AppFont.rounded(size: 17, weight: .black))
                                .foregroundColor(.white)
                            Text(kind.subtitle(isChinese: l10n.language.isChinese))
                                .font(AppFont.rounded(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 28, rimHeight: 4, whiteBorderWidth: 3.5, pressStyle: .card))
            }
        }
    }

    // MARK: - 4. Rank Exam Hall Centered Modal Portal

    private var examPortalModalOverlay: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                        showExamPortalModal = false
                    }
                }

            VStack(spacing: 18) {
                // Top-right close button
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                            showExamPortalModal = false
                        }
                        SoundAndHapticsManager.shared.playUITap()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(AppTheme.skyTop.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(l10n.localized(zh: "关闭", en: "Close", ja: "閉じる", ko: "닫기", zhHant: "關閉"))
                }
                .padding(.bottom, -10)

                // Emblem Medallion
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.mintTop, AppTheme.mintBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 68, height: 68)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: AppTheme.mintBottom.opacity(0.32), radius: 10, y: 4)

                    Image(systemName: "rosette")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                // Title & Current Certified Rank Badge
                VStack(spacing: 8) {
                    Text(l10n.localized(zh: "星弈考级室", en: "StarYi Rank Exam Hall", ja: "StarYi 段級位試験室", ko: "StarYi 승급 시험실", zhHant: "星弈考級室"))
                        .font(AppFont.rounded(size: 22, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)

                    Text(l10n.localized(
                        zh: "当前官方认证：\(appState.profile.rankString)",
                        en: "Certified Rank: \(appState.profile.rankString)",
                        ja: "現在の認定段級位：\(appState.profile.rankString)",
                        ko: "현재 공식 인증: \(appState.profile.rankString)",
                        zhHant: "當前官方認證：\(appState.profile.rankString)"
                    ))
                    .font(AppFont.rounded(size: 12.5, weight: .black))
                    .foregroundColor(AppTheme.mintBottom)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppTheme.mintTop.opacity(0.16)))
                }

                // Brief Introduction
                Text(l10n.localized(
                    zh: "正规段级位双轨认证，全面检验真实棋力：",
                    en: "Official dual-track certification to verify your true Go strength:",
                    ja: "公式の2段階認定で、確かな実力を証明しましょう：",
                    ko: "공식 2단계 인증으로 진짜 바둑 실력을 검증하세요:",
                    zhHant: "正規段級位雙軌認證，全面檢驗真實棋力："
                ))
                .font(AppFont.rounded(size: 13.5, weight: .bold))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 10) {
                    examRuleRow(
                        icon: "pencil.and.list.clipboard",
                        tint: AppTheme.grapeBottom,
                        text: l10n.localized(
                            zh: "无辅助死活笔试：每级 5 题，答对 4 题即通过",
                            en: "Written Test: 5 no-hint puzzles (4/5 to pass)",
                            ja: "補助なし筆記試験：5問中4問正解で合格",
                            ko: "무보조 필기시험: 5문제 중 4문제 정답 시 합격",
                            zhHant: "無輔助死活筆試：每級 5 題，答對 4 題即通過"
                        )
                    )
                    examRuleRow(
                        icon: "flag.checkered",
                        tint: AppTheme.skyBottom,
                        text: l10n.localized(
                            zh: "定时无悔棋实战：赢得定级晋级赛，领取官方认证",
                            en: "Timed Promotion Matches: No undo, earn official rank",
                            ja: "時間制限・待ったなし昇級対局で公式認定を獲得",
                            ko: "시간제한·무르기 금지 승급 대국으로 공식 인증 획득",
                            zhHant: "定時無悔棋實戰：贏得定級晉級賽，領取官方認證"
                        )
                    )
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.skyTop.opacity(0.08))
                )

                // Centered Action Button (compact & balanced, not full-screen-wide)
                Button {
                    showExamPortalModal = false
                    appState.navigationPath.append(.rankExamHall)
                } label: {
                    Label(
                        l10n.localized(zh: "进入星弈考级室", en: "Enter Exam Hall", ja: "段級位試験室へ", ko: "승급 시험실 입장", zhHant: "進入星弈考級室"),
                        systemImage: "arrow.right.circle.fill"
                    )
                    .font(AppFont.rounded(size: 16, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 13)
                    .frame(minWidth: 220)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
                .padding(.top, 2)
            }
            .frame(maxWidth: 420)
            .warmCard(cornerRadius: 30, padding: 24)
            .padding(.horizontal, 24)
            .shadow(color: Color.black.opacity(0.22), radius: 24, y: 12)
        }
    }

    private func examRuleRow(icon: String, tint: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(text)
                .font(AppFont.rounded(size: 13, weight: .bold))
                .foregroundColor(AppTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

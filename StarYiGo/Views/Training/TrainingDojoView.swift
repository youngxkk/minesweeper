//
//  TrainingDojoView.swift
//  StarYi Go — Unified P1+P2 Go Training Dojo (320+ Graded Tsumego, SRS Mistakes, Joseki, 4 Mini-Drills, Rank Exams)
//

import SwiftUI

struct TrainingDojoView: View {
    @EnvironmentObject var appState: AppState

    enum DojoSection: String, CaseIterable, Identifiable {
        case tsumego
        case srsMistakes
        case joseki
        case drills
        case exams

        var id: String { rawValue }
    }

    @State private var selectedSection: DojoSection = .tsumego
    @State private var selectedRankBand: DojoRankBand = .all
    @State private var selectedCategory: PuzzleCategory? = nil

    private let selectionTint = Color(red: 0.24, green: 0.36, blue: 0.29)
    private let badgeFill = Color(red: 0.94, green: 0.92, blue: 0.87)
    private let paperPalette = GlossyPalette(
        top: .white,
        bottom: Color(red: 0.99, green: 0.98, blue: 0.96),
        rim: Color(red: 0.85, green: 0.82, blue: 0.75),
        glow: Color(red: 0.41, green: 0.33, blue: 0.22)
    )

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }

    private var filteredDojoPuzzles: [GoPuzzle] {
        DojoPuzzleBank.puzzles(category: selectedCategory, rankBand: selectedRankBand, includeExpandedPack: true)
    }

    var body: some View {
        ZStack {
            boardBackdrop

            VStack(spacing: 14) {
                // Header
                HStack {
                    Button {
                        appState.popRoute()
                    } label: {
                        Label(l10n.t("common.back"), systemImage: "arrow.uturn.backward")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .padding(.horizontal, 12)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: paperPalette, rimHeight: 3))

                    VStack(spacing: 3) {
                        Text(isZh ? "围棋道场" : "Go Training Dojo")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(isZh ? "\(DojoPuzzleBank.fullCatalog.count)+ 题库 · 定式破招 · 专项训练 · 考级室" : "\(DojoPuzzleBank.fullCatalog.count)+ Puzzles · Joseki · Drills · Rank Exams")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                    Color.clear
                        .frame(width: 72, height: 1)
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                // Top 5 Section Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        sectionTab(.tsumego, title: isZh ? "分级题库 (\(DojoPuzzleBank.fullCatalog.count))" : "Tsumego (\(DojoPuzzleBank.fullCatalog.count))", icon: "square.grid.2x2.fill")
                        sectionTab(.srsMistakes, title: isZh ? "SRS 错题 (\(appState.puzzleProgress.srsMistakeItems.count))" : "SRS Review (\(appState.puzzleProgress.srsMistakeItems.count))", icon: "bookmark.fill")
                        sectionTab(.joseki, title: isZh ? "定式与破招" : "Joseki Tree", icon: "arrow.triangle.branch")
                        sectionTab(.drills, title: isZh ? "五大专项小练" : "5 Mini-Drills", icon: "bolt.circle.fill")
                        sectionTab(.exams, title: isZh ? "星弈考级室" : "Rank Exams", icon: "rosette")
                    }
                    .padding(.horizontal, 24)
                }

                // Active Section Content
                ScrollView {
                    Group {
                        switch selectedSection {
                        case .tsumego:
                            tsumegoSection
                        case .srsMistakes:
                            srsMistakesSection
                        case .joseki:
                            josekiSection
                        case .drills:
                            drillsSection
                        case .exams:
                            examsPreviewSection
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var boardBackdrop: some View {
        let palette = AppTheme.palette(for: .kayaWood)

        return Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            context.fill(
                Path(bounds),
                with: .linearGradient(
                    Gradient(colors: [palette.boardBase, palette.boardGradientEnd]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: size.width, y: size.height)
                )
            )

            let cell: CGFloat = 38
            let columns = Int(size.width / (2 * cell))
            let rows = Int(size.height / (2 * cell))
            var grid = Path()
            for column in -columns...columns {
                let x = bounds.midX + CGFloat(column) * cell
                grid.move(to: CGPoint(x: x, y: 0))
                grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for row in -rows...rows {
                let y = bounds.midY + CGFloat(row) * cell
                grid.move(to: CGPoint(x: 0, y: y))
                grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(palette.gridLine.opacity(0.19)), lineWidth: 1)

            for x in [-3, 0, 3] {
                for y in [-3, 0, 3] {
                    let point = CGRect(
                        x: bounds.midX + CGFloat(x) * cell - 3,
                        y: bounds.midY + CGFloat(y) * cell - 3,
                        width: 6,
                        height: 6
                    )
                    context.fill(Path(ellipseIn: point), with: .color(palette.starPoint.opacity(0.28)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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
                .font(.system(size: 13.5, weight: .black, design: .rounded))
                .foregroundColor(active ? .white : AppTheme.inkPrimary)
                .padding(.horizontal, 16)
                .frame(minHeight: AppTheme.buttonFaceHeight)
                .background(Capsule().fill(active ? selectionTint : .white))
        }
        .tactileButton(scale: 0.97, sound: false)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    // MARK: - 1. 320+ Graded Tsumego Bank

    private var tsumegoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Rank Band Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DojoRankBand.allCases) { band in
                        let selected = selectedRankBand == band
                        Button {
                            selectedRankBand = band
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            Text(band.title(isChinese: isZh))
                                .font(.system(size: 12, weight: .black, design: .rounded))
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

            // 6-Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    categoryChip(nil, title: isZh ? "全部题型" : "All Topics", icon: "sparkles")
                    ForEach(PuzzleCategory.allCases) { cat in
                        categoryChip(cat, title: cat.displayTitle(isChinese: isZh), icon: cat.symbolName)
                    }
                }
            }

            Text(isZh ? "共筛选出 \(filteredDojoPuzzles.count) 道精校题目（支持棋盘旋转、镜像与黑白互换防背图）" : "\(filteredDojoPuzzles.count) verified puzzles (rotation, reflection & color-swap supported)")
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
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
                .font(.system(size: 12, weight: .heavy, design: .rounded))
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
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(badgeFill))
                    Text(puzzle.category.displayTitle(isChinese: isZh))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                    Spacer()
                    Text(puzzle.playerColor == .black ? "⚫️" : "⚪️")
                        .font(.system(size: 12))
                }

                Text(puzzle.title(l10n))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                HStack(spacing: 3) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= stars ? "star.fill" : "star")
                            .font(.system(size: 12))
                            .foregroundColor(i <= stars ? AppTheme.sunBottom : AppTheme.inkSecondary.opacity(0.55))
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 140, alignment: .topLeading)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: paperPalette, cornerRadius: 22, rimHeight: 3, whiteBorderWidth: 2, pressStyle: .card))
    }

    // MARK: - 2. SRS Spaced-Repetition Mistake Book + Personal Game Blunders

    private var srsMistakesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(AppTheme.coralBottom)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isZh ? "艾宾浩斯间隔重复错题本（1天 → 3天 → 7天巩固）" : "Spaced-Repetition Mistake Book (1d -> 3d -> 7d)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(isZh ? "包含刷题错题 + AI 复盘一键转化的「我的实战恶手题」，连续答对 3 轮彻底毕业！" : "Combines tsumego mistakes & your own game blunders. Pass 3 review intervals to master!")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
            }
            .warmCard(cornerRadius: 22, padding: 14)

            if appState.puzzleProgress.srsMistakeItems.isEmpty {
                VStack(spacing: 10) {
                    Text("🏆").font(.system(size: 46))
                    Text(isZh ? "目前没有待复习的错题！去刷题或用 AI 复盘收集实战恶手吧。" : "No mistakes due! Solve puzzles or convert game blunders in AI Review.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .warmCard(cornerRadius: 24, padding: 16)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250, maximum: 340), spacing: 14)], spacing: 14) {
                    ForEach(appState.puzzleProgress.srsMistakeItems) { item in
                        if let puzzle = appState.findAnyPuzzle(withId: item.puzzleId) {
                            Button {
                                appState.navigationPath.append(.puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false, isStarterBootcamp: false))
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Text(item.isDueNow ? (isZh ? "今日待复习" : "Due Now") : (isZh ? "\(item.intervalDays)天后复习" : "In \(item.intervalDays)d"))
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(item.isDueNow ? AppTheme.coralBottom : AppTheme.mintBottom))
                                        Spacer()
                                        Text(isZh ? "巩固进度 \(item.correctStreak)/3" : "Mastery \(item.correctStreak)/3")
                                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                                            .foregroundColor(AppTheme.skyBottom)
                                    }
                                    Text(puzzle.title(l10n))
                                        .font(.system(size: 15, weight: .black, design: .rounded))
                                        .foregroundColor(AppTheme.inkPrimary)
                                        .lineLimit(1)
                                    Text(puzzle.prompt(l10n))
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.inkSecondary)
                                        .lineLimit(2)
                                }
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 22, rimHeight: 4, whiteBorderWidth: 2.5, pressStyle: .card))
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3. Interactive Joseki Courses

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
                                .font(.system(size: 11.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(AppTheme.grapeBottom))
                            Spacer()
                            if done {
                                Label(isZh ? "已通关 ★" : "Cleared ★", systemImage: "checkmark.seal.fill")
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.mintBottom)
                            }
                        }
                        Text(course.title(l10n))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(course.subtitle(l10n))
                            .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 24, rimHeight: 5, whiteBorderWidth: 3, pressStyle: .card))
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
                            .font(.system(size: 26, weight: .black))
                            .foregroundColor(pal.bottom)
                            .frame(width: 54, height: 54)
                            .background(Circle().fill(Color.white).shadow(color: pal.rim.opacity(0.28), radius: 6, y: 2))

                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.title(isChinese: isZh))
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(kind.subtitle(isChinese: isZh))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 28, rimHeight: 6, whiteBorderWidth: 3.5, pressStyle: .card))
            }
        }
    }

    // MARK: - 5. Rank Exam Hall Portal

    private var examsPreviewSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isZh ? "星弈正规段级位认证体系" : "StarYi Official Rank Certification")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Spacer()
                    Text(isZh ? "当前认证：\(appState.profile.rankString)" : "Current: \(appState.profile.rankString)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.mintBottom))
                }
                Text(isZh ? "每个段级位都需要同时通过【考场无辅助笔试 5 题（对 4 题）】+【定时无悔棋晋级实战赛】，真正检验棋力！" : "Each certified rank requires BOTH an Exam-Mode 5-puzzle test (4/5+) AND a timed no-undo promotion match series!")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)

                Button {
                    appState.navigationPath.append(.rankExamHall)
                } label: {
                    Label(isZh ? "进入星弈考级室 →" : "Enter Rank Exam Hall →", systemImage: "rosette")
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
            .warmCard(cornerRadius: 26, padding: 18)
        }
    }
}

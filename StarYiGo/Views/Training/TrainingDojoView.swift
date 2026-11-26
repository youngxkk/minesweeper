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
                        Text(l10n.localized(zh: "围棋道场", en: "Go Training Dojo", ja: "囲碁道場", ko: "바둑 도장", zhHant: "圍棋道場"))
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(l10n.localized(
                            zh: "\(DojoPuzzleBank.fullCatalog.count)+ 题库 · 定式破招 · 专项训练 · 考级室",
                            en: "\(DojoPuzzleBank.fullCatalog.count)+ Puzzles · Joseki · Drills · Rank Exams",
                            ja: "\(DojoPuzzleBank.fullCatalog.count)+ 詰碁 · 定石対策 · 特訓 · 段級位試験",
                            ko: "\(DojoPuzzleBank.fullCatalog.count)+ 사활 문제 · 정석 · 특훈 · 급·단 승급 시험",
                            zhHant: "\(DojoPuzzleBank.fullCatalog.count)+ 題庫 · 定石破招 · 專項訓練 · 考級室"
                        ))
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
                        sectionTab(.tsumego, title: l10n.localized(zh: "分级题库 (\(DojoPuzzleBank.fullCatalog.count))", en: "Tsumego (\(DojoPuzzleBank.fullCatalog.count))", ja: "詰碁問題集 (\(DojoPuzzleBank.fullCatalog.count))", ko: "등급별 문제집 (\(DojoPuzzleBank.fullCatalog.count))", zhHant: "分級題庫 (\(DojoPuzzleBank.fullCatalog.count))"), icon: "square.grid.2x2.fill")
                        sectionTab(.srsMistakes, title: l10n.localized(zh: "SRS 错题 (\(appState.puzzleProgress.srsMistakeItems.count))", en: "SRS Review (\(appState.puzzleProgress.srsMistakeItems.count))", ja: "SRS 復習 (\(appState.puzzleProgress.srsMistakeItems.count))", ko: "SRS 오답 복습 (\(appState.puzzleProgress.srsMistakeItems.count))", zhHant: "SRS 錯題 (\(appState.puzzleProgress.srsMistakeItems.count))"), icon: "bookmark.fill")
                        sectionTab(.joseki, title: l10n.localized(zh: "定式与破招", en: "Joseki Tree", ja: "定石と対策", ko: "정석과 파훼", zhHant: "定石與破招"), icon: "arrow.triangle.branch")
                        sectionTab(.drills, title: l10n.localized(zh: "五大专项小练", en: "5 Mini-Drills", ja: "5大ミニ特訓", ko: "5대 미니 특훈", zhHant: "五大專項小練"), icon: "bolt.circle.fill")
                        sectionTab(.exams, title: l10n.localized(zh: "星弈考级室", en: "Rank Exams", ja: "段級位試験室", ko: "급·단 승급 시험실", zhHant: "星弈考級室"), icon: "rosette")
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
                            Text(band.title(isChinese: l10n.language.isChinese))
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
                    categoryChip(nil, title: l10n.localized(zh: "全部题型", en: "All Topics", ja: "すべての分野", ko: "전체 유형", zhHant: "全部題型"), icon: "sparkles")
                    ForEach(PuzzleCategory.allCases) { cat in
                        categoryChip(cat, title: cat.displayTitle(isChinese: l10n.language.isChinese), icon: cat.symbolName)
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
                    Text(puzzle.category.displayTitle(isChinese: l10n.language.isChinese))
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
                    Text(l10n.localized(
                        zh: "艾宾浩斯间隔重复错题本（1天 → 3天 → 7天巩固）",
                        en: "Spaced-Repetition Mistake Book (1d -> 3d -> 7d)",
                        ja: "忘却曲線・間隔反復ミスノート（1日後 → 3日後 → 7日後）",
                        ko: "에빙하우스 간격 반복 오답노트 (1일 → 3일 → 7일 복습)",
                        zhHant: "艾賓浩斯間隔重複錯題本（1天 → 3天 → 7天鞏固）"
                    ))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(l10n.localized(
                        zh: "包含刷题错题 + AI 复盘一键转化的「我的实战恶手题」，连续答对 3 轮彻底毕业！",
                        en: "Combines tsumego mistakes & your own game blunders. Pass 3 review intervals to master!",
                        ja: "詰碁のミスとAI検討から変換した実戦の悪手を収録。3回連続正解でマスター！",
                        ko: "사활 오답과 AI 복기에서 변환한 실전 악수 문제를 수록. 3회 연속 정답 시 마스터!",
                        zhHant: "包含刷題錯題 + AI 復盤一鍵轉化的「我的實戰惡手題」，連續答對 3 輪徹底畢業！"
                    ))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
            }
            .warmCard(cornerRadius: 22, padding: 14)

            if appState.puzzleProgress.srsMistakeItems.isEmpty {
                VStack(spacing: 10) {
                    Text("🏆").font(.system(size: 46))
                    Text(l10n.localized(
                        zh: "目前没有待复习的错题！去刷题或用 AI 复盘收集实战恶手吧。",
                        en: "No mistakes due! Solve puzzles or convert game blunders in AI Review.",
                        ja: "復習待ちのミスはありません！問題を解くかAI検討で実戦の悪手を登録しましょう。",
                        ko: "복습할 오답이 없습니다! 문제를 풀거나 AI 복기에서 실전 악수를 수집해 보세요.",
                        zhHant: "目前沒有待複習的錯題！去刷題或用 AI 復盤收集實戰惡手吧。"
                    ))
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
                                        Text(item.isDueNow
                                             ? l10n.localized(zh: "今日待复习", en: "Due Now", ja: "本日復習", ko: "오늘 복습", zhHant: "今日待複習")
                                             : l10n.localized(zh: "\(item.intervalDays)天后复习", en: "In \(item.intervalDays)d", ja: "\(item.intervalDays)日後に復習", ko: "\(item.intervalDays)일 후 복습", zhHant: "\(item.intervalDays)天後複習"))
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(item.isDueNow ? AppTheme.coralBottom : AppTheme.mintBottom))
                                        Spacer()
                                        Text(l10n.localized(zh: "巩固进度 \(item.correctStreak)/3", en: "Mastery \(item.correctStreak)/3", ja: "定着度 \(item.correctStreak)/3", ko: "숙달도 \(item.correctStreak)/3", zhHant: "鞏固進度 \(item.correctStreak)/3"))
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
                                Label(l10n.localized(zh: "已通关 ★", en: "Cleared ★", ja: "クリア済 ★", ko: "클리어 ★", zhHant: "已通關 ★"), systemImage: "checkmark.seal.fill")
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
                            Text(kind.title(isChinese: l10n.language.isChinese))
                                .font(.system(size: 17, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Text(kind.subtitle(isChinese: l10n.language.isChinese))
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
                    Text(l10n.localized(zh: "星弈正规段级位认证体系", en: "StarYi Official Rank Certification", ja: "StarYi 公式段級位認定システム", ko: "StarYi 공식 급·단 인증 시스템", zhHant: "星弈正規段級位認證體系"))
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Spacer()
                    Text(l10n.localized(zh: "当前认证：\(appState.profile.rankString)", en: "Current: \(appState.profile.rankString)", ja: "現在の段級位：\(appState.profile.rankString)", ko: "현재 인증: \(appState.profile.rankString)", zhHant: "當前認證：\(appState.profile.rankString)"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.mintBottom))
                }
                Text(l10n.localized(
                    zh: "每个段级位都需要同时通过【考场无辅助笔试 5 题（对 4 题）】+【定时无悔棋晋级实战赛】，真正检验棋力！",
                    en: "Each certified rank requires BOTH an Exam-Mode 5-puzzle test (4/5+) AND a timed no-undo promotion match series!",
                    ja: "各段級位の認定には【補助なし筆記試験 5問中4問正解】と【時間制限・待ったなし昇級昇段対局】の両方の合格が必要です！",
                    ko: "각 급·단 인증을 받으려면 [무보조 필기시험 5문제 중 4문제 정답]과 [시간제한·무르기 금지 승급 대국]을 모두 통과해야 합니다!",
                    zhHant: "每個段級位都需要同時通過【考場無輔助筆試 5 題（對 4 題）】+【定時無悔棋晉級實戰賽】，真正檢驗棋力！"
                ))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)

                Button {
                    appState.navigationPath.append(.rankExamHall)
                } label: {
                    Label(l10n.localized(zh: "进入星弈考级室 →", en: "Enter Rank Exam Hall →", ja: "段級位試験室へ →", ko: "승급 시험실 입장 →", zhHant: "進入星弈考級室 →"), systemImage: "rosette")
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

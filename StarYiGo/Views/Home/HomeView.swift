//
//  HomeView.swift
//  StarYi Go — Super Mario Party / Nintendo Switch Glossy Capsule Title Screen
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var selectedSize: BoardSize = .thirteen
    @State private var selectedDifficulty: AIDifficulty = .fox
    @State private var selectedColor: StoneColor = .black
    @State private var selectedHandicap: Int = 0
    @State private var selectedRuleSet: GameRuleSet = .standard
    @State private var selectedTimeControl: TimeControl = .unlimited
    @State private var selectedCoachingStyle: AICoachingStyle = .standard
    @State private var logoFloating = false
    @State private var logoBounceScale: CGFloat = 1.0
    @State private var showHandicapScale = false
    @State private var showStatusGuide = false
    @State private var showInitialPlacementSheet = false
    @State private var hasAppeared = false

    private func boardSizeDescription(_ size: BoardSize) -> String {
        if UIDevice.current.userInterfaceIdiom == .phone && (size == .nine || size == .thirteen) {
            return l10n.localized(
                zh: "适合 iPhone",
                en: "Recommended on iPhone",
                ja: "iPhoneにおすすめ",
                ko: "iPhone 추천",
                zhHant: "適合 iPhone"
            )
        }
        return l10n.t(size.descLocalizationKey)
    }

    private var l10n: L10n { appState.l10n }

    var body: some View {
        ZStack {
            // 1. Vibrant, bright Nintendo Switch Party full-bleed backdrop
            GeometryReader { fullGeo in
                Image("HomeBackdrop")
                    .resizable()
                    .scaledToFill()
                    .frame(width: fullGeo.size.width, height: fullGeo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()

            // 2. Cheerful floating sunlit bokeh star sparkles
            FloatingPartySparklesView()
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // 3. Clean luminous top/bottom subtle polish scrim
            LinearGradient(
                stops: [
                    .init(color: Color.white.opacity(0.14), location: 0.0),
                    .init(color: Color.clear, location: 0.30),
                    .init(color: Color.clear, location: 0.72),
                    .init(color: Color(red: 0.05, green: 0.25, blue: 0.45).opacity(0.22), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let halfHeight = height / 2
                let isCompact = width < 700
                let heroHeight = isCompact ? 114 : min(168, max(114, halfHeight * 0.40))
                let logoHeight = min(halfHeight * 0.78, width * 0.72)
                let horizontalPadding: CGFloat = isCompact ? 16 : 36
                let moduleSectionSpacing: CGFloat = isCompact ? 28 : min(44, max(24, height * 0.048))

                ZStack(alignment: .top) {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: isCompact ? 62 : 24)

                            homeTitleLogo(height: logoHeight)
                                .frame(maxWidth: .infinity)

                            Spacer(minLength: isCompact ? 20 : 16)

                            VStack(spacing: moduleSectionSpacing) {
                                if isCompact {
                                    VStack(spacing: 24) {
                                        aiPlayHeroColumn(height: heroHeight, isCompact: true)
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: 0, reduceMotion: reduceMotion))
                                        islandsHeroColumn(height: heroHeight, isCompact: true)
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger, reduceMotion: reduceMotion))
                                    }
                                    VStack(spacing: 20) {
                                        tabletopTwoPlayerModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2, reduceMotion: reduceMotion))
                                        dailyChallengeModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2 + MotionToken.gridStagger, reduceMotion: reduceMotion))
                                        codexModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2 + MotionToken.gridStagger * 2, reduceMotion: reduceMotion))
                                        sgfDojoModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2 + MotionToken.gridStagger * 3, reduceMotion: reduceMotion))
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 36) {
                                        aiPlayHeroColumn(height: heroHeight, isCompact: false)
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: 0, reduceMotion: reduceMotion))
                                        islandsHeroColumn(height: heroHeight, isCompact: false)
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger, reduceMotion: reduceMotion))
                                    }
                                    .zIndex(5)

                                    LazyVGrid(
                                        columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: width < 1000 ? 2 : 4),
                                        spacing: 20
                                    ) {
                                        tabletopTwoPlayerModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2, reduceMotion: reduceMotion))
                                        dailyChallengeModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2 + MotionToken.gridStagger, reduceMotion: reduceMotion))
                                        codexModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2 + MotionToken.gridStagger * 2, reduceMotion: reduceMotion))
                                        sgfDojoModuleCard
                                            .modifier(StaggeredEntranceModifier(appeared: hasAppeared, delay: MotionToken.itemStagger * 2 + MotionToken.gridStagger * 3, reduceMotion: reduceMotion))
                                    }
                                }
                            }
                            .frame(maxWidth: 1100)
                            .padding(.horizontal, horizontalPadding)

                            Spacer(minLength: isCompact ? 24 : 20)
                        }
                        .frame(width: width)
                        .frame(minHeight: height)
                    }
                    .scrollBounceBehavior(.always)
                    .scrollClipDisabled()

                    edgeTopBar(isCompact: isCompact)
                        .padding(.horizontal, isCompact ? 16 : 32)
                        .padding(.top, isCompact ? 10 : 18)
                }
                .frame(width: width, height: height)
            }
        }
        .environment(\.minimumButtonFaceHeight, 0)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showHandicapScale) {
            HandicapScaleSheet()
                .environmentObject(appState)
        }
        .sheet(isPresented: $showInitialPlacementSheet) {
            initialPlacementOnboardingSheet
        }
        .onAppear {
            selectedSize = appState.settings.preferredBoardSize
            selectedDifficulty = appState.settings.preferredDifficulty
            selectedColor = appState.settings.preferredPlayerColor
            selectedHandicap = min(appState.settings.preferredHandicap, selectedSize.maxHandicap)
            selectedRuleSet = appState.settings.preferredRuleSet
            selectedTimeControl = appState.settings.preferredTimeControl
            selectedCoachingStyle = appState.settings.preferredCoachingStyle
            if !logoFloating && !reduceMotion {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    logoFloating = true
                }
            }
            if !hasAppeared {
                hasAppeared = true
                let isUITest = ProcessInfo.processInfo.environment["STARYIGO_UI_TEST_SUITE"] != nil
                if !isUITest
                    && !appState.puzzleProgress.didCompletePlacement
                    && appState.savedGames.isEmpty
                    && appState.puzzleProgress.starsByPuzzleId.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        showInitialPlacementSheet = true
                    }
                }
            }
        }
    }

    private var initialPlacementOnboardingSheet: some View {
        let isZh = l10n.language.isChinese
        return NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("🧭").font(.system(size: 48))
                    Text(isZh ? "欢迎来到星弈围棋！选择你的棋力" : "Welcome to StarYi Go! Choose Your Level")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(isZh
                         ? "选定后将自动为你匹配最合适的默认棋盘路数、AI 陪练和闯关海域，随时可在首页或地图切换。"
                         : "We'll tailor your starting board size, AI sparring partner, and campaign Sea. You can change anytime.")
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    ForEach(StarYiCampaign.placementOptions) { opt in
                        Button {
                            appState.applyPlacementChoice(opt)
                            selectedSize = appState.settings.preferredBoardSize
                            selectedDifficulty = appState.settings.preferredDifficulty
                            showInitialPlacementSheet = false
                            SoundAndHapticsManager.shared.playSuccess()
                            SoundAndHapticsManager.shared.playVoice(.welcome, delay: 0.16)
                        } label: {
                            HStack(spacing: 14) {
                                Text(opt.emoji).font(.system(size: 32))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(isZh ? opt.titleZh : opt.titleEn)
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundColor(AppTheme.inkPrimary)
                                        Text(opt.rankLabel)
                                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(AppTheme.skyBottom))
                                    }
                                    Text(isZh ? opt.descZh : opt.descEn)
                                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(AppTheme.skyBottom)
                            }
                            .padding(16)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 24, rimHeight: 4, whiteBorderWidth: 2.5, pressStyle: .card))
                    }
                }
                .padding(20)
            }
            .background(AppTheme.brightArenaBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isZh ? "稍后再说" : "Later") {
                        appState.markPlacementDismissed()
                        showInitialPlacementSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Centered Super Mario Party-Style Localized Game Logo

    private func homeTitleLogo(height: CGFloat) -> some View {
        Image(l10n.language.isChinese ? "HomeLogoZH" : "HomeLogoEN")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(height: height)
            .shadow(color: Color(red: 0.04, green: 0.20, blue: 0.48).opacity(0.30), radius: 18, x: 0, y: 10)
            .scaleEffect((logoFloating ? 1.018 : 0.992) * logoBounceScale)
            .offset(y: logoFloating ? -4 : 4)
            .contentShape(Rectangle())
            .onTapGesture {
                SoundAndHapticsManager.shared.playUITap()
                withAnimation(.spring(response: 0.22, dampingFraction: 0.45)) {
                    logoBounceScale = 1.07
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                        logoBounceScale = 1.0
                    }
                }
            }
            .accessibilityLabel(l10n.t("app.name"))
            .accessibilityIdentifier("HomeGameLogo")
    }

    // MARK: - Top Edge Peripheral Controls (Glossy Candy Capsules)

    private func edgeTopBar(isCompact: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    appState.navigationPath.append(.passport)
                } label: {
                    HStack(spacing: 9) {
                        StarYiMascotView(
                            emojiKey: appState.profile.avatarEmoji,
                            size: isCompact ? 34 : 40,
                            mood: .happy
                        )

                        VStack(alignment: .leading, spacing: 1) {
                            Text(appState.profile.nickname)
                                .font(.system(size: isCompact ? 13 : 15, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                                .lineLimit(1)
                            HStack(spacing: 5) {
                                Text(l10n.t("rank.label", appState.profile.rankString))
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.skyBottom)
                                Text("Lv.\(appState.profile.adventureLevel)")
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.mintBottom)
                            }
                            .lineLimit(1)
                        }
                    }
                    .padding(.leading, 6)
                    .padding(.trailing, isCompact ? 12 : 16)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.97, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                            .shadow(color: AppTheme.skyBottom.opacity(0.18), radius: 12, y: 5)
                    )
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                }
                .tactileButton(scale: 0.95)
                .accessibilityLabel("\(appState.profile.nickname), \(l10n.t("rank.label", appState.profile.rankString)), Level \(appState.profile.adventureLevel)")
                .accessibilityHint(l10n.localized(zh: "打开围棋航海护照", en: "Open Go Sailor Passport", ja: "航海パスポートを開く", ko: "바둑 항해 여권 열기", zhHant: "開啟圍棋航海護照"))
                .accessibilityIdentifier("HomePassportButton")
            }

            Spacer()

            let done = min(appState.dailyDojoStationsDoneCount, 3)
            let target = 3
            let progress = Double(done) / Double(target)

            HStack(spacing: isCompact ? 8 : 10) {
                Button {
                    showStatusGuide = true
                } label: {
                    HStack(spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .black))
                                .foregroundStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                            Text("\(appState.puzzleProgress.totalStars)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundColor(AppTheme.inkPrimary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }

                        if !isCompact {
                            Divider().frame(height: 15)

                            HStack(spacing: 4) {
                                StarCoinBadgeView(size: 16)
                                Text("\(appState.profile.starCoins)")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(AppTheme.sunBottom)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            if appState.profile.dailyStreak > 0 {
                                Divider().frame(height: 15)
                                HStack(spacing: 3) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 13, weight: .black))
                                        .foregroundColor(AppTheme.coralBottom)
                                    Text("\(appState.profile.dailyStreak)")
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(AppTheme.coralBottom)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                            }

                            Divider().frame(height: 15)

                            HStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .stroke(AppTheme.skyTop.opacity(0.24), lineWidth: 3.5)
                                        .frame(width: 20, height: 20)
                                    Circle()
                                        .trim(from: 0, to: progress)
                                        .stroke(
                                            LinearGradient(colors: [AppTheme.mintTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom),
                                            style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                                        )
                                        .rotationEffect(.degrees(-90))
                                        .frame(width: 20, height: 20)
                                }
                                Text("\(done)/\(target)")
                                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundColor(AppTheme.inkPrimary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .frame(minWidth: 32, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, isCompact ? 12 : 16)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.97, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                            .shadow(color: AppTheme.skyBottom.opacity(0.18), radius: 12, y: 5)
                    )
                    .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                    .fixedSize(horizontal: true, vertical: false)
                }
                .tactileButton(scale: 0.95)
                .layoutPriority(1)
                .accessibilityLabel(l10n.localized(
                    zh: "星星 \(appState.puzzleProgress.totalStars)，星币 \(appState.profile.starCoins)，连续 \(appState.profile.dailyStreak) 天，今日目标 \(done)/\(target)",
                    en: "\(appState.puzzleProgress.totalStars) stars, \(appState.profile.starCoins) star coins, \(appState.profile.dailyStreak) day streak, daily goal \(done) of \(target)",
                    ja: "スター \(appState.puzzleProgress.totalStars)、星コイン \(appState.profile.starCoins)、連続 \(appState.profile.dailyStreak) 日、今日の目標 \(done)/\(target)",
                    ko: "별 \(appState.puzzleProgress.totalStars), 별코인 \(appState.profile.starCoins), 연속 \(appState.profile.dailyStreak)일, 오늘 목표 \(done)/\(target)",
                    zhHant: "星星 \(appState.puzzleProgress.totalStars)，星幣 \(appState.profile.starCoins)，連續 \(appState.profile.dailyStreak) 天，今日目標 \(done)/\(target)"
                ))
                .accessibilityHint(l10n.localized(
                    zh: "查看进度与奖励说明",
                    en: "View progress and rewards guide",
                    ja: "進捗と報酬の説明を見る",
                    ko: "진행도와 보상 안내 보기",
                    zhHant: "查看進度與獎勵說明"
                ))
                .accessibilityIdentifier("HomeStatusCapsuleButton")
                .popover(isPresented: $showStatusGuide, arrowEdge: .top) {
                    homeStatusGuidePopover(done: done, target: target, progress: progress)
                        .presentationCompactAdaptation(.sheet)
                        .presentationDetents([.medium])
                        .presentationDragIndicator(.visible)
                }

                if isCompact {
                    GameCircleButton(
                        icon: "camera.viewfinder",
                        palette: .grape,
                        tint: .white,
                        size: 40
                    ) {
                        appState.navigationPath.append(.photoJudge)
                    }
                    .accessibilityLabel(l10n.localized(zh: "拍照判胜负", en: "Photo Judge", ja: "写真判定", ko: "사진 판정", zhHant: "拍照判勝負"))
                    .accessibilityIdentifier("HomePhotoJudgeButton")
                } else {
                    Button {
                        appState.navigationPath.append(.photoJudge)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 15, weight: .black))
                            Text(l10n.localized(
                                zh: "拍照判胜负",
                                en: "Photo Judge",
                                ja: "写真判定",
                                ko: "사진 판정",
                                zhHant: "拍照判勝負"
                            ))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .shadow(color: AppTheme.grapeRim.opacity(0.45), radius: 1, y: 1.5)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                    .accessibilityIdentifier("HomePhotoJudgeButton")
                }

                GameCircleButton(
                    icon: appState.settings.bgmEnabled ? "music.note" : "music.note.slash",
                    palette: appState.settings.bgmEnabled ? .mint : .snow,
                    tint: appState.settings.bgmEnabled ? .white : AppTheme.inkSecondary,
                    size: isCompact ? 40 : 44
                ) {
                    appState.updateSettings { $0.bgmEnabled.toggle() }
                }

                GameCircleButton(
                    icon: appState.settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                    palette: appState.settings.soundEnabled ? .sky : .snow,
                    tint: appState.settings.soundEnabled ? .white : AppTheme.inkSecondary,
                    size: isCompact ? 40 : 44
                ) {
                    appState.updateSettings { $0.soundEnabled.toggle() }
                }

                GameCircleButton(
                    icon: "gearshape.fill",
                    palette: GlossyPalette(
                        top: Color(red: 0.23, green: 0.32, blue: 0.47),
                        bottom: Color(red: 0.12, green: 0.18, blue: 0.30),
                        rim: Color(red: 0.07, green: 0.11, blue: 0.20),
                        glow: AppTheme.inkPrimary
                    ),
                    tint: Color(red: 1.0, green: 0.87, blue: 0.56),
                    size: isCompact ? 40 : 44
                ) {
                    appState.showSettingsSheet = true
                }
                .accessibilityLabel(l10n.t("home.settings"))
            }
        }
    }

    // MARK: - Top-Right Status Capsule Guide Popover

    private func homeStatusGuidePopover(done: Int, target: Int, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(l10n.localized(
                    zh: "我的进度与奖励",
                    en: "Progress & Rewards",
                    ja: "進捗と報酬",
                    ko: "진행도와 보상",
                    zhHant: "我的進度與獎勵"
                ))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

                Spacer()

                Button {
                    showStatusGuide = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            VStack(spacing: 10) {
                // 1. Stars
                statusGuideRow(
                    title: l10n.localized(zh: "闯关星星", en: "Campaign Stars", ja: "クリアスター", ko: "스테이지 별", zhHant: "闖關星星"),
                    valueText: "\(appState.puzzleProgress.totalStars)",
                    valueColor: AppTheme.inkPrimary,
                    description: l10n.localized(
                        zh: "在星弈群岛做题获得，记录你的闯关成绩（不会消耗）。",
                        en: "Earned from island puzzles to track your mastery (never spent).",
                        ja: "群島パズルで獲得でき、クリア成績を記録します。",
                        ko: "섬 퍼즐에서 얻으며 클리어 성적을 기록해요.",
                        zhHant: "在星弈群島做題獲得，記錄你的闖關成績（不會消耗）。"
                    ),
                    actionTitle: l10n.localized(zh: "去闯关", en: "Islands", ja: "冒険へ", ko: "도전", zhHant: "去闖關"),
                    actionTint: AppTheme.skyBottom,
                    action: {
                        showStatusGuide = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            appState.navigationPath.append(.puzzleHub(initialMistakesOnly: false))
                        }
                    }
                ) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                }

                // 2. Star Coins
                statusGuideRow(
                    title: l10n.localized(zh: "星币", en: "Star Coins", ja: "星コイン", ko: "별코인", zhHant: "星幣"),
                    valueText: "\(appState.profile.starCoins)",
                    valueColor: AppTheme.sunBottom,
                    description: l10n.localized(
                        zh: "做题、对局与定式都会奖励，可在设置里解锁棋盘和棋子样式。",
                        en: "Earned from puzzles and matches. Spend in Settings to unlock boards & stones.",
                        ja: "問題や対局で貯まり、設定で碁盤や碁石の見た目を開放できます。",
                        ko: "퍼즐과 대국으로 모으며 설정에서 바둑판과 바둑돌을 잠금 해제해요.",
                        zhHant: "做題、對局與定式都會獎勵，可在設定裡解鎖棋盤和棋子樣式。"
                    ),
                    actionTitle: l10n.localized(zh: "换外观", en: "Customize", ja: "着せ替え", ko: "꾸미기", zhHant: "換外觀"),
                    actionTint: AppTheme.sunBottom,
                    action: {
                        showStatusGuide = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                            appState.showSettingsSheet = true
                        }
                    }
                ) {
                    StarCoinBadgeView(size: 22)
                }

                // 3. Daily Streak
                statusGuideRow(
                    title: l10n.localized(zh: "连续打卡", en: "Daily Streak", ja: "連続日数", ko: "연속 출석", zhHant: "連續打卡"),
                    valueText: l10n.localized(
                        zh: "\(appState.profile.dailyStreak) 天",
                        en: "\(appState.profile.dailyStreak)d",
                        ja: "\(appState.profile.dailyStreak) 日",
                        ko: "\(appState.profile.dailyStreak)일",
                        zhHant: "\(appState.profile.dailyStreak) 天"
                    ),
                    valueColor: AppTheme.coralBottom,
                    description: l10n.localized(
                        zh: "每天完成任意一次做题或对局就会 +1，坚持 7 天可解锁成就。",
                        en: "Increases by 1 each day you play or solve a puzzle. Reach 7 days for an achievement.",
                        ja: "毎日1回でも練習・対局すると増え、7日連続で実績を解除できます。",
                        ko: "매일 퍼즐이나 대국을 1회 이상 완료하면 +1 되며 7일 연속 달성 시 업적이 열려요.",
                        zhHant: "每天完成任意一次做題或對局就會 +1，堅持 7 天可解鎖成就。"
                    ),
                    actionTitle: nil,
                    actionTint: AppTheme.coralBottom,
                    action: nil
                ) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(AppTheme.coralBottom)
                }

                // 4. Daily Dojo (3 Stations + Stamp Calendar)
                statusGuideRow(
                    title: l10n.localized(zh: "每日道场", en: "Daily Dojo", ja: "毎日道場", ko: "매일 도장", zhHant: "每日道場"),
                    valueText: "\(done)/\(target)",
                    valueColor: AppTheme.mintBottom,
                    description: l10n.localized(
                        zh: "每天 3 站（热身 + 无提示三连战 + 棋道一问），完成后盖下印章领宝箱！",
                        en: "3 daily stations (Warmup + No-Hint Trial + Go Wisdom) — complete all 3 to stamp your calendar!",
                        ja: "毎日3ステージ（ウォームアップ＋ヒントなし3連戦＋囲碁クイズ）クリアでスタンプ獲得！",
                        ko: "매일 3단계(워밍업 + 힌트 없는 3연전 + 바둑 퀴즈) 완료 후 도장을 찍어 보상을 받아요!",
                        zhHant: "每天 3 站（熱身 + 無提示三連戰 + 棋道一問），完成後蓋下印章領寶箱！"
                    ),
                    actionTitle: l10n.localized(zh: "去道场", en: "Open Dojo", ja: "道場へ", ko: "도장 가기", zhHant: "去道場"),
                    actionTint: AppTheme.mintBottom,
                    action: {
                        showStatusGuide = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            appState.navigationPath.append(.dailyDojo)
                        }
                    }
                ) {
                    ZStack {
                        Circle()
                            .stroke(AppTheme.skyTop.opacity(0.24), lineWidth: 3.5)
                            .frame(width: 22, height: 22)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient(colors: [AppTheme.mintTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 22, height: 22)
                    }
                }
            }
        }
        .padding(18)
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400)
        .background(Color(red: 0.97, green: 0.985, blue: 1.0))
    }

    private func statusGuideRow<Icon: View>(
        title: String,
        valueText: String,
        valueColor: Color,
        description: String,
        actionTitle: String?,
        actionTint: Color,
        action: (() -> Void)?,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 36, height: 36)
                    .shadow(color: AppTheme.skyBottom.opacity(0.12), radius: 5, y: 2)
                icon()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)

                    Text(valueText)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(valueColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(valueColor.opacity(0.12)))

                    Spacer(minLength: 4)

                    if let actionTitle, let action {
                        Button {
                            SoundAndHapticsManager.shared.playUITap()
                            action()
                        } label: {
                            Text(actionTitle)
                                .font(.system(size: 11.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(actionTint))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(description)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
                .shadow(color: AppTheme.skyBottom.opacity(0.08), radius: 6, y: 2)
        )
    }

    // MARK: - HERO PORTAL 1: Giant Electric Sky-Blue Glossy Capsule (Play vs AI)

    private func aiPlayHeroColumn(height: CGFloat, isCompact: Bool) -> some View {
        VStack(spacing: 12) {
            Button {
                SoundAndHapticsManager.shared.playUITap()
                appState.startNewAIGame(
                    boardSize: selectedSize,
                    difficulty: selectedDifficulty,
                    playerColor: selectedColor,
                    handicap: selectedColor == .black ? selectedHandicap : 0,
                    ruleSet: selectedRuleSet,
                    timeControl: selectedTimeControl,
                    scoringRule: appState.settings.scoringRule,
                    coachingStyle: selectedCoachingStyle
                )
            } label: {
                HStack(spacing: 18) {
                    CharacterAvatarView(character: selectedDifficulty, mood: .greeting, size: height < 140 ? 60 : 76)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(l10n.t("home.aiCard.start"))
                            .font(.system(size: height < 140 ? 26 : 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.skyRim.opacity(0.55), radius: 2, y: 2)

                        Text(ruleSummarySubtitle)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.94))
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(l10n.t(selectedSize.localizationKey))
                            Text("·")
                            Text("\(l10n.t(selectedDifficulty.nameKey)) \(selectedDifficulty.rankBadge)")
                        }
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.16)))
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(height: height)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: .sky,
                    cornerRadius: 40,
                    rimHeight: 8,
                    whiteBorderWidth: 4,
                    showStripeSheen: true,
                    playTapSound: false,
                    pressStyle: .homeEntrance
                )
            )
            .accessibilityIdentifier("HomeStartMatchButton")

            // Compact glossy white option capsules using native system Menu with left-aligned inline Pickers
            HStack(spacing: isCompact ? 5 : 8) {
                Menu {
                    Picker(
                        l10n.localized(zh: "选择棋盘路数", en: "Board Size", ja: "碁盤サイズ", ko: "바둑판 크기", zhHant: "選擇棋盤路數"),
                        selection: Binding(
                            get: { selectedSize },
                            set: { size in
                                selectedSize = size
                                if selectedHandicap > size.maxHandicap { selectedHandicap = 0 }
                                if size == .five && !selectedRuleSet.isCaptureRace {
                                    selectedRuleSet = .captureRace(target: 3)
                                }
                                appState.updateSettings {
                                    $0.preferredBoardSize = size
                                    $0.preferredHandicap = selectedHandicap
                                    $0.preferredRuleSet = selectedRuleSet
                                }
                                SoundAndHapticsManager.shared.playUITap()
                            }
                        )
                    ) {
                        ForEach(BoardSize.allCases) { size in
                            Text("\(l10n.t(size.localizationKey)) · \(boardSizeDescription(size))")
                                .tag(size)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    compactGlossChip(title: l10n.t(selectedSize.localizationKey), icon: "grid", accent: AppTheme.skyBottom, isCompact: isCompact)
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("HomeBoardSizeChip")

                Menu {
                    Picker(
                        l10n.localized(zh: "选择 AI 对手", en: "AI Opponent", ja: "AI対戦相手", ko: "AI 상대", zhHant: "選擇 AI 對手"),
                        selection: Binding(
                            get: { selectedDifficulty },
                            set: { level in
                                selectedDifficulty = level
                                appState.updateSettings { $0.preferredDifficulty = level }
                                SoundAndHapticsManager.shared.playUITap()
                            }
                        )
                    ) {
                        ForEach(AIDifficulty.allCases) { level in
                            Text("\(level.avatarEmoji) \(l10n.t(level.nameKey)) (\(level.rankBadge))")
                                .tag(level)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    compactGlossChip(title: "\(selectedDifficulty.avatarEmoji) \(selectedDifficulty.rankBadge)", icon: nil, accent: AppTheme.skyBottom, isCompact: isCompact)
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("HomeDifficultyChip")

                // Rule mode menu: Standard Territory Go OR Kid-Friendly Capture Go (吃子棋)!
                Menu {
                    Section(l10n.t("home.aiCard.ruleMode")) {
                        Picker(
                            l10n.t("home.aiCard.ruleMode"),
                            selection: Binding(
                                get: { selectedRuleSet },
                                set: { rule in
                                    selectedRuleSet = rule
                                    if rule.isCaptureRace && selectedSize.rawValue > 9 {
                                        selectedSize = .seven
                                    }
                                    appState.updateSettings {
                                        $0.preferredRuleSet = rule
                                        $0.preferredBoardSize = selectedSize
                                    }
                                    SoundAndHapticsManager.shared.playUITap()
                                }
                            )
                        ) {
                            Text(l10n.t("rule.standard"))
                                .tag(GameRuleSet.standard)
                            ForEach([1, 3, 5], id: \.self) { target in
                                Text(l10n.t("rule.captureRace", target))
                                    .tag(GameRuleSet.captureRace(target: target))
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    Section(l10n.t("home.aiCard.playAs")) {
                        Picker(
                            l10n.t("home.aiCard.playAs"),
                            selection: Binding(
                                get: { selectedColor },
                                set: { color in
                                    selectedColor = color
                                    if color == .white { selectedHandicap = 0 }
                                    appState.updateSettings {
                                        $0.preferredPlayerColor = color
                                        $0.preferredHandicap = selectedHandicap
                                    }
                                    SoundAndHapticsManager.shared.playUITap()
                                }
                            )
                        ) {
                            Text(l10n.t("stone.black")).tag(StoneColor.black)
                            Text(l10n.t("stone.white")).tag(StoneColor.white)
                        }
                        .pickerStyle(.inline)
                    }

                    if selectedSize.maxHandicap >= 2 && !selectedRuleSet.isCaptureRace {
                        Section(l10n.t("home.aiCard.handicap")) {
                            Picker(
                                l10n.t("home.aiCard.handicap"),
                                selection: Binding(
                                    get: { selectedHandicap },
                                    set: { count in
                                        if count >= 2 { selectedColor = .black }
                                        selectedHandicap = count
                                        appState.updateSettings {
                                            $0.preferredPlayerColor = selectedColor
                                            $0.preferredHandicap = count
                                        }
                                        SoundAndHapticsManager.shared.playUITap()
                                    }
                                )
                            ) {
                                Text(l10n.t("handicap.none")).tag(0)
                                ForEach(2...selectedSize.maxHandicap, id: \.self) { count in
                                    Text(l10n.t("handicap.stones", count)).tag(count)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                } label: {
                    let chipTitle: String = {
                        if let target = selectedRuleSet.captureTarget {
                            return l10n.t("rule.captureShort", target)
                        }
                        let colorLabel = l10n.t(selectedColor == .black ? "stone.black" : "stone.white")
                        let hLabel = selectedHandicap >= 2 ? " · \(l10n.t("handicap.stones", selectedHandicap))" : ""
                        return colorLabel + hLabel
                    }()
                    compactGlossChip(title: chipTitle, icon: selectedRuleSet.isCaptureRace ? "flame.fill" : "slider.horizontal.3", accent: selectedRuleSet.isCaptureRace ? AppTheme.coralBottom : AppTheme.skyBottom, isCompact: isCompact)
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("HomeRulesChip")

                // Go Clock / Byoyomi & Coaching Sparring Style Menu
                Menu {
                    Section(l10n.localized(zh: "围棋计时钟与读秒", en: "Go Clock & Byoyomi", ja: "対局時計・秒読み", ko: "대국 시계·초읽기", zhHant: "圍棋計時鐘與讀秒")) {
                        Picker(
                            l10n.localized(zh: "围棋计时钟与读秒", en: "Go Clock & Byoyomi", ja: "対局時計・秒読み", ko: "대국 시계·초읽기", zhHant: "圍棋計時鐘與讀秒"),
                            selection: Binding(
                                get: { selectedTimeControl },
                                set: { tc in
                                    selectedTimeControl = tc
                                    appState.updateSettings { $0.preferredTimeControl = tc }
                                    SoundAndHapticsManager.shared.playUITap()
                                }
                            )
                        ) {
                            ForEach(TimeControl.standardPresets) { tc in
                                Text(tc.displayLabel(isChinese: l10n.language.isChinese))
                                    .tag(tc)
                            }
                        }
                        .pickerStyle(.inline)
                    }

                    Section(l10n.localized(zh: "AI 陪练主题", en: "AI Coaching Focus", ja: "AI特訓テーマ", ko: "AI 맞춤 훈련", zhHant: "AI 陪練主題")) {
                        let styles: [(AICoachingStyle, String, String, String, String, String)] = [
                            (.standard, "标准实战", "Standard Match", "標準対局", "표준 대국", "標準實戰"),
                            (.capturePractice, "吃子专项陪练", "Capture Practice", "石取り特訓", "따내기 집중", "吃子專項陪練"),
                            (.shapeAndConnect, "断连手筋陪练", "Cut & Connect", "キリ・ツギ特訓", "끊기·연결 훈련", "斷連手筋陪練"),
                            (.ladderAndNet, "征子枷吃陪练", "Ladder & Net", "シチョウ・ゲタ特訓", "축·장문 훈련", "征子枷吃陪練")
                        ]
                        Picker(
                            l10n.localized(zh: "AI 陪练主题", en: "AI Coaching Focus", ja: "AI特訓テーマ", ko: "AI 맞춤 훈련", zhHant: "AI 陪練主題"),
                            selection: Binding(
                                get: { selectedCoachingStyle },
                                set: { style in
                                    selectedCoachingStyle = style
                                    appState.updateSettings { $0.preferredCoachingStyle = style }
                                    SoundAndHapticsManager.shared.playUITap()
                                }
                            )
                        ) {
                            ForEach(styles, id: \.0) { item in
                                Text(l10n.localized(zh: item.1, en: item.2, ja: item.3, ko: item.4, zhHant: item.5))
                                    .tag(item.0)
                            }
                        }
                        .pickerStyle(.inline)
                    }
                } label: {
                    compactGlossChip(
                        title: selectedTimeControl.displayLabel(isChinese: l10n.language.isChinese),
                        icon: "timer",
                        accent: selectedTimeControl.isTimed ? AppTheme.grapeBottom : AppTheme.inkSecondary,
                        isCompact: isCompact
                    )
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("HomeClockChip")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
            .zIndex(10)
        }
        .frame(maxWidth: .infinity)
    }

    private var ruleSummarySubtitle: String {
        if let target = selectedRuleSet.captureTarget {
            return l10n.t("rule.captureRace", target)
        }
        return l10n.t("home.hero.playSubtitle")
    }

    // MARK: - HERO PORTAL 2: Giant Sunny Gold Glossy Capsule (StarYi Islands)

    private func islandsHeroColumn(height: CGFloat, isCompact: Bool) -> some View {
        let totalWorlds = StarYiCampaign.allSeas.count
        let totalStages = StarYiCampaign.allIslands.count
        let totalNodes = StarYiCampaign.allNodes.count
        let clearedNodes = StarYiCampaign.totalClearedNodes(progress: appState.puzzleProgress)
        let mistakes = appState.puzzleProgress.mistakeBookIds.count

        return VStack(spacing: 12) {
            Button {
                SoundAndHapticsManager.shared.playUITap()
                appState.navigationPath.append(.puzzleHub(initialMistakesOnly: false))
            } label: {
                HStack(spacing: 18) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: height < 140 ? 60 : 74, height: height < 140 ? 60 : 74)
                            .shadow(color: AppTheme.sunRim.opacity(0.35), radius: 8, y: 4)
                        Image(systemName: "map.fill")
                            .font(.system(size: height < 140 ? 26 : 32, weight: .black))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(l10n.t("home.puzzleCard.title"))
                            .font(.system(size: height < 140 ? 26 : 32, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.sunRim.opacity(0.55), radius: 2, y: 2)

                        Text(l10n.t("home.hero.questSubtitle"))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.95))
                            .lineLimit(1)

                        Text(l10n.localized(
                            zh: "\(totalWorlds)大世界 · \(totalStages)站 · 已通 \(clearedNodes)/\(totalNodes) 关",
                            en: "\(totalWorlds) Worlds · \(totalStages) Stages · \(clearedNodes)/\(totalNodes) Cleared",
                            ja: "\(totalWorlds)つの世界 · \(totalStages)エリア · \(clearedNodes)/\(totalNodes) クリア",
                            ko: "\(totalWorlds)대 세계 · \(totalStages)구역 · \(clearedNodes)/\(totalNodes) 클리어",
                            zhHant: "\(totalWorlds)大世界 · \(totalStages)站 · 已通 \(clearedNodes)/\(totalNodes) 關"
                        ))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.16)))
                            .padding(.top, 2)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .frame(height: height)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: .sun,
                    cornerRadius: 40,
                    rimHeight: 8,
                    whiteBorderWidth: 4,
                    showStripeSheen: true,
                    playTapSound: false,
                    pressStyle: .homeEntrance
                )
            )
            .accessibilityIdentifier("HomePuzzleQuestButton")

            HStack(spacing: isCompact ? 5 : 8) {
                Button {
                    appState.navigationPath.append(.puzzleHub(initialMistakesOnly: true))
                } label: {
                    compactGlossChip(
                        title: l10n.t("home.puzzleCard.mistakes", mistakes),
                        icon: "bookmark.fill",
                        accent: mistakes > 0 ? AppTheme.coralBottom : AppTheme.inkSecondary,
                        trailingIcon: "chevron.right",
                        isCompact: isCompact
                    )
                }
                .tactileButton(scale: 0.93)
                .accessibilityIdentifier("HomeMistakeBookButton")

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 6)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Secondary Home Modes

    private var dailyChallengeModuleCard: some View {
        let plan = appState.todayDailyDojoPlan()
        let doneStations = appState.dailyDojoStationsDoneCount
        let readyToStamp = appState.isDailyDojoReadyToStamp
        let cleared = appState.isDailyChallengeClearedToday
        let teal = GlossyPalette(
            top: Color(red: 0.02, green: 0.48, blue: 0.53),
            bottom: Color(red: 0.01, green: 0.35, blue: 0.40),
            rim: Color(red: 0.01, green: 0.25, blue: 0.29),
            glow: Color(red: 0.02, green: 0.48, blue: 0.53)
        )
        let subtitleText: String = {
            if cleared {
                return l10n.localized(
                    zh: "今日已盖章 · 累计 \(appState.profile.dailyDojoStampDates.count) 枚",
                    en: "Stamped Today · \(appState.profile.dailyDojoStampDates.count) Stamps",
                    ja: "本日スタンプ済・累計\(appState.profile.dailyDojoStampDates.count)個",
                    ko: "오늘 도장 완료 · 누적 \(appState.profile.dailyDojoStampDates.count)개",
                    zhHant: "今日已蓋章 · 累計 \(appState.profile.dailyDojoStampDates.count) 枚"
                )
            }
            if readyToStamp {
                return l10n.localized(
                    zh: "3/3 全部通关！快来盖下今日印章",
                    en: "3/3 Clear! Tap to Stamp Today",
                    ja: "3/3 クリア！スタンプを押そう",
                    ko: "3/3 완료! 오늘 도장 찍으러 가요",
                    zhHant: "3/3 全部通關！快來蓋下今日印章"
                )
            }
            return l10n.localized(
                zh: "\(plan.themeCodex.term(l10n)) · 进度 \(doneStations)/3",
                en: "\(plan.themeCodex.term(l10n)) · \(doneStations)/3 Done",
                ja: "\(plan.themeCodex.term(l10n)) · \(doneStations)/3",
                ko: "\(plan.themeCodex.term(l10n)) · \(doneStations)/3",
                zhHant: "\(plan.themeCodex.term(l10n)) · 進度 \(doneStations)/3"
            )
        }()

        return Button {
            appState.navigationPath.append(.dailyDojo)
        } label: {
            moduleCapsuleContent(
                icon: cleared ? "crown.fill" : (readyToStamp ? "seal.fill" : "sun.max.fill"),
                iconColors: (cleared || readyToStamp) ? [AppTheme.sunBottom, AppTheme.sunRim] : [teal.top, teal.bottom],
                rimColor: teal.rim,
                title: l10n.localized(
                    zh: "每日道场",
                    en: "Daily Dojo",
                    ja: "毎日道場",
                    ko: "매일 도장",
                    zhHant: "每日道場"
                ),
                subtitle: subtitleText
            )
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: teal, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, pressStyle: .card))
        .accessibilityIdentifier("HomeDailyDojoButton")
    }

    private var codexModuleCard: some View {
        let unlocked = GoTermCodex.allEntries.filter { appState.profile.unlockedCodexIds.contains($0.id) }.count

        return Button {
            appState.navigationPath.append(.codex)
        } label: {
            moduleCapsuleContent(
                icon: "book.closed.fill",
                iconColors: [AppTheme.skyTop, AppTheme.skyBottom],
                rimColor: AppTheme.skyRim,
                title: l10n.t("codex.title"),
                subtitle: l10n.t("codex.collectedCount", unlocked, GoTermCodex.allEntries.count)
            )
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, pressStyle: .card))
    }

    private var tabletopTwoPlayerModuleCard: some View {
        ZStack(alignment: .trailing) {
            // Main capsule button: tapping anywhere outside the circular arrow launches Two-Player Tabletop directly!
            Button {
                SoundAndHapticsManager.shared.playUITap()
                appState.startTwoPlayerGame(boardSize: selectedSize, ruleSet: selectedRuleSet)
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 46, height: 46)
                            .shadow(color: AppTheme.mintRim.opacity(0.30), radius: 5, y: 2)
                        Circle()
                            .fill(LinearGradient(colors: [Color(white: 0.36), Color(white: 0.10)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.22), radius: 2, y: 2)
                            .offset(x: -6, y: -5)
                        Circle()
                            .fill(LinearGradient(colors: [.white, Color(white: 0.85)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 1))
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.24), radius: 2, y: 2)
                            .offset(x: 6, y: 5)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(l10n.t("home.twoPlayerCard.title"))
                            .font(.system(size: 17, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(l10n.t("home.twoPlayerCard.subtitle"))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.92))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 34)
                }
                .padding(.horizontal, 15)
                .frame(maxWidth: .infinity)
                .frame(height: 78)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, playTapSound: false, pressStyle: .card))

            // Standalone circular dropdown button on the right: ONLY tapping this circle opens the mode menu!
            Menu {
                Section(l10n.localized(zh: "客厅亲子 / 好友派对", en: "Couch Party", ja: "リビング対局", ko: "거실 파티 대국", zhHant: "客廳親子 / 好友派對")) {
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        showHandicapScale = true
                    } label: {
                        Label(
                            l10n.localized(zh: "⚖️ 水平天平让子对战", en: "⚖️ Rank Balance Scale", ja: "⚖️ ハンデ天秤対局", ko: "⚖️ 실력 천칭 접바둑", zhHant: "⚖️ 水平天平讓子對戰"),
                            systemImage: "scalemass.fill"
                        )
                    }
                }
                Section(l10n.t("rule.captureQuickSection")) {
                    Button(l10n.t("home.twoPlayer.capture5")) {
                        SoundAndHapticsManager.shared.playUITap()
                        appState.startTwoPlayerGame(boardSize: .five, ruleSet: .captureRace(target: 3))
                    }
                    Button(l10n.t("home.twoPlayer.capture7")) {
                        SoundAndHapticsManager.shared.playUITap()
                        appState.startTwoPlayerGame(boardSize: .seven, ruleSet: .captureRace(target: 5))
                    }
                }
                Section(l10n.t("rule.standard")) {
                    ForEach([BoardSize.seven, .nine, .thirteen, .nineteen]) { size in
                        Button("\(l10n.t(size.localizationKey)) · \(l10n.t(size.descLocalizationKey))") {
                            SoundAndHapticsManager.shared.playUITap()
                            appState.startTwoPlayerGame(boardSize: size, ruleSet: .standard)
                        }
                    }
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.95))
                        .frame(width: 34, height: 34)
                        .shadow(color: AppTheme.mintRim.opacity(0.32), radius: 4, y: 2)
                        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(AppTheme.mintBottom)
                }
                .frame(width: 44, height: 44)
                .contentShape(Circle())
            }
            .accessibilityLabel(l10n.t("home.aiCard.ruleMode"))
            .padding(.trailing, 10)
            .padding(.bottom, 6)
        }
    }

    private var sgfDojoModuleCard: some View {
        Button {
            appState.navigationPath.append(.archive)
        } label: {
            moduleCapsuleContent(
                icon: "scroll.fill",
                iconColors: [AppTheme.grapeTop, AppTheme.grapeBottom],
                rimColor: AppTheme.grapeRim,
                title: l10n.t("home.archiveCard.title"),
                subtitle: l10n.t("home.archiveCard.subtitle")
            )
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, pressStyle: .card))
        .accessibilityIdentifier("HomeArchiveButton")
    }

    private func moduleCapsuleContent(
        icon: String,
        iconColors: [Color],
        rimColor: Color,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 46, height: 46)
                    .shadow(color: rimColor.opacity(0.30), radius: 5, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(LinearGradient(colors: iconColors, startPoint: .top, endPoint: .bottom))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: rimColor.opacity(0.45), radius: 1, y: 1.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.92))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity)
        .frame(height: 78)
    }

    private func compactGlossChip(
        title: String,
        icon: String?,
        accent: Color,
        trailingIcon: String = "chevron.down",
        isCompact: Bool = false
    ) -> some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(accent)
            }
            Text(title)
                .font(.system(size: isCompact ? 11.5 : 12.5, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
                .lineLimit(1)
            Image(systemName: trailingIcon)
                .font(.system(size: 9, weight: .black))
                .foregroundColor(accent.opacity(0.8))
        }
        .padding(.horizontal, isCompact ? 10 : 13)
        .padding(.vertical, 9)
        .background(
            Capsule()
                .fill(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.97, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                .shadow(color: Color.black.opacity(0.10), radius: 6, y: 3)
        )
        .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
        .contentShape(Capsule())
    }
}

/// Cheerful Mario Party sunlit floating sparkle particles.
private struct FloatingPartySparklesView: View {
    private struct Sparkle {
        let xFrac: Double
        let yStart: Double
        let speed: Double
        let radius: CGFloat
        let swayAmp: Double
        let phase: Double
        let isGold: Bool
    }

    private let sparkles: [Sparkle] = (0..<16).map { i in
        let seed = Double(i + 1)
        return Sparkle(
            xFrac: fmod(seed * 0.371 + 0.06, 0.88) + 0.06,
            yStart: fmod(seed * 0.618, 1.0),
            speed: 0.015 + fmod(seed * 0.008, 0.016),
            radius: CGFloat(3.0 + fmod(seed * 2.1, 4.6)),
            swayAmp: 14.0 + fmod(seed * 8.0, 20.0),
            phase: seed * 1.4,
            isGold: i % 2 == 0
        )
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for s in sparkles {
                    let yProgress = 1.0 - fmod(s.yStart + t * s.speed, 1.0)
                    let x = size.width * s.xFrac + CGFloat(sin(t * 1.1 + s.phase) * s.swayAmp)
                    let y = size.height * yProgress
                    let edgeFade = sin(yProgress * .pi)
                    let twinkle = 0.55 + 0.45 * sin(t * 2.6 + s.phase)
                    let alpha = max(0, edgeFade * twinkle * 0.75)

                    let glowR = s.radius * 2.6
                    let glowRect = CGRect(x: x - glowR, y: y - glowR, width: glowR * 2, height: glowR * 2)
                    let tint: Color = s.isGold ? Color(red: 1.0, green: 0.92, blue: 0.45) : .white
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .radialGradient(
                            Gradient(colors: [tint.opacity(alpha), tint.opacity(0)]),
                            center: CGPoint(x: x, y: y),
                            startRadius: 0,
                            endRadius: glowR
                        )
                    )
                }
            }
        }
    }
}

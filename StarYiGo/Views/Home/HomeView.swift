//
//  HomeView.swift
//  StarYi Go — Super Mario Party / Nintendo Switch Glossy Capsule Title Screen
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    @State private var selectedSize: BoardSize = .thirteen
    @State private var selectedDifficulty: AIDifficulty = .fox
    @State private var selectedColor: StoneColor = .black
    @State private var selectedHandicap: Int = 0
    @State private var selectedRuleSet: GameRuleSet = .standard
    @State private var selectedTimeControl: TimeControl = .unlimited
    @State private var selectedCoachingStyle: AICoachingStyle = .standard
    @State private var logoFloating = false
    @State private var logoBounceScale: CGFloat = 1.0

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
                let halfHeight = geo.size.height / 2
                let isCompact = width < 700
                let heroHeight = isCompact ? 114 : min(168, max(114, halfHeight * 0.41))
                let logoHeight = min(halfHeight * 0.82, width * 0.78)
                let horizontalPadding: CGFloat = isCompact ? 16 : 36

                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        homeTitleLogo(height: logoHeight)
                            .frame(width: width, height: halfHeight)

                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: isCompact ? 40 : 52) {
                                if isCompact {
                                    VStack(spacing: 24) {
                                        aiPlayHeroColumn(height: heroHeight, isCompact: true)
                                        islandsHeroColumn(height: heroHeight, isCompact: true)
                                    }
                                    VStack(spacing: 20) {
                                        tabletopTwoPlayerModuleCard
                                        dailyChallengeModuleCard
                                        codexModuleCard
                                        sgfDojoModuleCard
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: 36) {
                                        aiPlayHeroColumn(height: heroHeight, isCompact: false)
                                        islandsHeroColumn(height: heroHeight, isCompact: false)
                                    }
                                    .zIndex(5)

                                    LazyVGrid(
                                        columns: Array(repeating: GridItem(.flexible(), spacing: 24), count: width < 1040 ? 2 : 4),
                                        spacing: 20
                                    ) {
                                        tabletopTwoPlayerModuleCard
                                        dailyChallengeModuleCard
                                        codexModuleCard
                                        sgfDojoModuleCard
                                    }
                                }
                            }
                            .frame(maxWidth: 1100)
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, 16)
                            .frame(minHeight: halfHeight)
                            .frame(maxWidth: .infinity)
                        }
                        .frame(height: halfHeight)
                    }

                    edgeTopBar(isCompact: isCompact)
                        .padding(.horizontal, isCompact ? 16 : 32)
                        .padding(.top, isCompact ? 10 : 18)
                }
                .frame(width: width, height: geo.size.height)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            selectedSize = appState.settings.preferredBoardSize
            selectedDifficulty = appState.settings.preferredDifficulty
            selectedColor = appState.settings.preferredPlayerColor
            selectedHandicap = min(appState.settings.preferredHandicap, selectedSize.maxHandicap)
            selectedRuleSet = appState.settings.preferredRuleSet
            selectedTimeControl = appState.settings.preferredTimeControl
            selectedCoachingStyle = appState.settings.preferredCoachingStyle
            if !logoFloating {
                withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) {
                    logoFloating = true
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
                    appState.showSettingsSheet = true
                } label: {
                    HStack(spacing: 9) {
                        Text(appState.profile.avatarEmoji)
                            .font(.system(size: isCompact ? 18 : 22))
                            .frame(width: isCompact ? 32 : 38, height: isCompact ? 32 : 38)
                            .background(
                                Circle()
                                    .fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
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

                if let active = appState.activeGameViewModel, !active.isGameOver {
                    Button {
                        appState.resumeActiveGame()
                    } label: {
                        Label(l10n.t("home.aiCard.resume"), systemImage: "play.fill")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }
            }

            Spacer()

            let done = min(appState.profile.dailyCompletedCount, appState.profile.dailyGoalTarget)
            let target = max(1, appState.profile.dailyGoalTarget)
            let progress = Double(done) / Double(target)

            HStack(spacing: isCompact ? 8 : 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                        Text("\(appState.puzzleProgress.totalStars)")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                    }

                    if !isCompact {
                        Divider().frame(height: 15)

                        HStack(spacing: 4) {
                            Text("🪙")
                                .font(.system(size: 13))
                            Text("\(appState.profile.starCoins)")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.sunBottom)
                        }

                        if appState.profile.dailyStreak > 0 {
                            Divider().frame(height: 15)
                            HStack(spacing: 3) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(AppTheme.coralBottom)
                                Text("\(appState.profile.dailyStreak)")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.coralBottom)
                            }
                        }

                        Divider().frame(height: 15)

                        HStack(spacing: 5) {
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
                                .foregroundColor(AppTheme.inkPrimary)
                        }
                    }
                }
                .padding(.horizontal, isCompact ? 12 : 15)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(LinearGradient(colors: [.white, Color(red: 0.94, green: 0.97, blue: 1.0)], startPoint: .top, endPoint: .bottom))
                        .shadow(color: AppTheme.skyBottom.opacity(0.18), radius: 12, y: 5)
                )
                .overlay(Capsule().strokeBorder(.white, lineWidth: 3))

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
                    playTapSound: false
                )
            )
            .accessibilityIdentifier("HomeStartMatchButton")

            // Compact glossy white option capsules with generous 44pt touch height & top zIndex
            HStack(spacing: isCompact ? 5 : 8) {
                Menu {
                    ForEach(BoardSize.allCases) { size in
                        Button {
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
                        } label: {
                            HStack {
                                Text("\(l10n.t(size.localizationKey)) · \(l10n.t(size.descLocalizationKey))")
                                if selectedSize == size { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    compactGlossChip(title: l10n.t(selectedSize.localizationKey), icon: "grid", accent: AppTheme.skyBottom, isCompact: isCompact)
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("HomeBoardSizeChip")

                Menu {
                    ForEach(AIDifficulty.allCases) { level in
                        Button {
                            selectedDifficulty = level
                            appState.updateSettings { $0.preferredDifficulty = level }
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            HStack {
                                Text("\(level.avatarEmoji) \(l10n.t(level.nameKey)) (\(level.rankBadge))")
                                if selectedDifficulty == level { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    compactGlossChip(title: "\(selectedDifficulty.avatarEmoji) \(selectedDifficulty.rankBadge)", icon: nil, accent: AppTheme.skyBottom, isCompact: isCompact)
                }
                .menuStyle(.borderlessButton)
                .accessibilityIdentifier("HomeDifficultyChip")

                // Rule mode menu: Standard Territory Go OR Kid-Friendly Capture Go (吃子棋)!
                Menu {
                    Section(l10n.t("home.aiCard.ruleMode")) {
                        Button {
                            selectedRuleSet = .standard
                            appState.updateSettings { $0.preferredRuleSet = .standard }
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            HStack {
                                Text(l10n.t("rule.standard"))
                                if selectedRuleSet == .standard { Image(systemName: "checkmark") }
                            }
                        }
                        ForEach([1, 3, 5], id: \.self) { target in
                            Button {
                                selectedRuleSet = .captureRace(target: target)
                                if selectedSize.rawValue > 9 { selectedSize = .seven }
                                appState.updateSettings {
                                    $0.preferredRuleSet = .captureRace(target: target)
                                    $0.preferredBoardSize = selectedSize
                                }
                                SoundAndHapticsManager.shared.playUITap()
                            } label: {
                                HStack {
                                    Text(l10n.t("rule.captureRace", target))
                                    if selectedRuleSet == .captureRace(target: target) { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                    Section(l10n.t("home.aiCard.playAs")) {
                        Button {
                            selectedColor = .black
                            appState.updateSettings { $0.preferredPlayerColor = .black }
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            Label(l10n.t("stone.black"), systemImage: selectedColor == .black ? "checkmark" : "circle.fill")
                        }
                        Button {
                            selectedColor = .white
                            selectedHandicap = 0
                            appState.updateSettings {
                                $0.preferredPlayerColor = .white
                                $0.preferredHandicap = 0
                            }
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            Label(l10n.t("stone.white"), systemImage: selectedColor == .white ? "checkmark" : "circle")
                        }
                    }
                    if selectedSize.maxHandicap >= 2 && !selectedRuleSet.isCaptureRace {
                        Section(l10n.t("home.aiCard.handicap")) {
                            Button {
                                selectedHandicap = 0
                                appState.updateSettings { $0.preferredHandicap = 0 }
                                SoundAndHapticsManager.shared.playUITap()
                            } label: {
                                HStack {
                                    Text(l10n.t("handicap.none"))
                                    if selectedHandicap == 0 { Image(systemName: "checkmark") }
                                }
                            }
                            ForEach(2...selectedSize.maxHandicap, id: \.self) { count in
                                Button {
                                    selectedColor = .black
                                    selectedHandicap = count
                                    appState.updateSettings {
                                        $0.preferredPlayerColor = .black
                                        $0.preferredHandicap = count
                                    }
                                    SoundAndHapticsManager.shared.playUITap()
                                } label: {
                                    HStack {
                                        Text(l10n.t("handicap.stones", count))
                                        if selectedHandicap == count { Image(systemName: "checkmark") }
                                    }
                                }
                            }
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

                // P2: Go Clock / Byoyomi & Coaching Sparring Style Menu!
                Menu {
                    Section(l10n.bilingual(zh: "围棋计时钟与读秒", en: "Go Clock & Byoyomi")) {
                        ForEach(TimeControl.standardPresets) { tc in
                            Button {
                                selectedTimeControl = tc
                                appState.updateSettings { $0.preferredTimeControl = tc }
                                SoundAndHapticsManager.shared.playUITap()
                            } label: {
                                HStack {
                                    Text(tc.displayLabel(isChinese: l10n.language.isChinese))
                                    if selectedTimeControl == tc { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    }
                    Section(l10n.bilingual(zh: "AI 陪练主题", en: "AI Coaching Focus")) {
                        let styles: [(AICoachingStyle, String, String)] = [
                            (.standard, "标准实战", "Standard Match"),
                            (.capturePractice, "吃子专项陪练", "Capture Practice"),
                            (.shapeAndConnect, "断连手筋陪练", "Cut & Connect"),
                            (.ladderAndNet, "征子枷吃陪练", "Ladder & Net")
                        ]
                        ForEach(styles, id: \.0) { item in
                            Button {
                                selectedCoachingStyle = item.0
                                appState.updateSettings { $0.preferredCoachingStyle = item.0 }
                                SoundAndHapticsManager.shared.playUITap()
                            } label: {
                                HStack {
                                    Text(l10n.bilingual(zh: item.1, en: item.2))
                                    if selectedCoachingStyle == item.0 { Image(systemName: "checkmark") }
                                }
                            }
                        }
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
        let total = BuiltInPuzzleLibrary.allPuzzles.count
        let solved = appState.puzzleProgress.solvedCount
        let mistakes = appState.puzzleProgress.mistakeBookIds.count
        let bootSolved = StarterBootcamp.solvedCount(progress: appState.puzzleProgress)
        let nextBoot = StarterBootcamp.nextUnsolved(progress: appState.puzzleProgress)

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

                        Text(l10n.t("home.puzzleCard.solved", solved, total))
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
                    playTapSound: false
                )
            )
            .accessibilityIdentifier("HomePuzzleQuestButton")

            HStack(spacing: 7) {
                // Zero-friction 5×5 Starter Bootcamp quick chip!
                Button {
                    appState.navigationPath.append(.puzzlePlay(puzzleId: nextBoot.id, isDailyChallenge: false, isStarterBootcamp: true))
                } label: {
                    compactGlossChip(
                        title: "\(l10n.t("home.starterCamp")) (\(bootSolved)/\(StarterBootcamp.puzzles.count))",
                        icon: "sparkles",
                        accent: AppTheme.mintBottom,
                        trailingIcon: "chevron.right"
                    )
                }
                .tactileButton(scale: 0.93)

                Button {
                    appState.navigationPath.append(.trainingDojo)
                } label: {
                    compactGlossChip(
                        title: l10n.bilingual(zh: "围棋道场 · 320题/定式/考级", en: "Dojo · 320+/Joseki/Exams"),
                        icon: "rosette",
                        accent: AppTheme.grapeBottom,
                        trailingIcon: "chevron.right"
                    )
                }
                .tactileButton(scale: 0.93)

                Button {
                    appState.navigationPath.append(.puzzleHub(initialMistakesOnly: true))
                } label: {
                    compactGlossChip(
                        title: l10n.t("home.puzzleCard.mistakes", mistakes),
                        icon: "bookmark.fill",
                        accent: mistakes > 0 ? AppTheme.coralBottom : AppTheme.inkSecondary,
                        trailingIcon: "chevron.right"
                    )
                }
                .tactileButton(scale: 0.93)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Secondary Home Modes

    private var dailyChallengeModuleCard: some View {
        let dailyPuzzle = StarYiIslands.dailyChallengePuzzle()
        let cleared = appState.isDailyChallengeClearedToday
        let teal = GlossyPalette(
            top: Color(red: 0.02, green: 0.48, blue: 0.53),
            bottom: Color(red: 0.01, green: 0.35, blue: 0.40),
            rim: Color(red: 0.01, green: 0.25, blue: 0.29),
            glow: Color(red: 0.02, green: 0.48, blue: 0.53)
        )

        return Button {
            appState.navigationPath.append(.puzzlePlay(puzzleId: dailyPuzzle.id, isDailyChallenge: true, isStarterBootcamp: false))
        } label: {
            moduleCapsuleContent(
                icon: cleared ? "crown.fill" : "sun.max.fill",
                iconColors: cleared ? [AppTheme.sunBottom, AppTheme.sunRim] : [teal.top, teal.bottom],
                rimColor: teal.rim,
                title: l10n.t("home.dailyCard.title"),
                subtitle: cleared ? l10n.t("home.dailyCard.done") : dailyPuzzle.title(l10n)
            )
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: teal, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
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
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
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
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, playTapSound: false))

            // Standalone circular dropdown button on the right: ONLY tapping this circle opens the mode menu!
            Menu {
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
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
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

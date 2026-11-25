//
//  SettingsView.swift
//  StarYi Go — Glossy Nintendo Switch Party Game Settings & Family Profiles Modal
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var showAddKidSheet = false
    @State private var newKidName = ""
    @State private var newKidAvatar = "🐼"
    @State private var unlockMessage: String? = nil
    @FocusState private var isNewKidNameFocused: Bool

    private let avatarChoices = ["🦊", "🐼", "🐰", "🐉", "🦢", "🐯", "🦁", "🦉", "🌟", "🎋"]
    private let eyeCareOptions = [0, 15, 25, 40]

    private var l10n: L10n { appState.l10n }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            VStack(spacing: 0) {
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        dismiss()
                    }

                    Spacer()

                    GameTitleCrest(title: l10n.t("settings.title"))

                    Spacer()

                    Color.clear
                        .frame(width: 94, height: 44)
                }
                .padding(.horizontal, 28)
                .padding(.top, 16)
                .padding(.bottom, 16)

                GeometryReader { geo in
                    let isCompact = geo.size.width < 700
                    ScrollView {
                        if isCompact {
                            VStack(spacing: 16) {
                                profileCard
                                languageCard
                                boardThemeCard
                                scoringRuleCard
                                assistsCard
                                aiThinkingPaceCard
                                audioAndEyeCareCard
                                aboutFooterCard
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        } else {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 18) {
                                    profileCard
                                    languageCard
                                    boardThemeCard
                                }
                                .frame(maxWidth: .infinity)

                                VStack(spacing: 18) {
                                    scoringRuleCard
                                    assistsCard
                                    aiThinkingPaceCard
                                    audioAndEyeCareCard
                                    aboutFooterCard
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: 1080)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }

            if showAddKidSheet {
                addKidProfileOverlay
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: showAddKidSheet)
    }

    private var addKidProfileOverlay: some View {
        ZStack {
            Color(red: 0.05, green: 0.11, blue: 0.22)
                .opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissAddKidModal()
                }
                .transition(.opacity)

            VStack(spacing: 16) {
                StarYiMascotView(emojiKey: newKidAvatar, size: 68, mood: .happy)
                    .shadow(color: AppTheme.skyBottom.opacity(0.24), radius: 10, y: 4)

                VStack(spacing: 6) {
                    Text(l10n.t("settings.profile.addKidTitle"))
                        .font(.system(size: 21, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .multilineTextAlignment(.center)

                    Text(l10n.t("settings.profile.addKidHint"))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Branded rounded nickname field
                TextField(l10n.t("settings.profile.nickname"), text: $newKidName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .multilineTextAlignment(.center)
                    .focused($isNewKidNameFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        confirmAddKidProfile()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.canvasBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isNewKidNameFocused ? AppTheme.skyBottom : AppTheme.skyTop.opacity(0.25),
                                lineWidth: isNewKidNameFocused ? 2.5 : 1.5
                            )
                    )

                // Mascot avatar picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(avatarChoices, id: \.self) { emoji in
                            addKidAvatarButton(emoji: emoji)
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }

                // Glossy Cancel / OK buttons matching GameDialogModifier
                HStack(spacing: 12) {
                    Button {
                        SoundAndHapticsManager.shared.playUITap(weight: .light)
                        dismissAddKidModal()
                    } label: {
                        Text(l10n.t("common.cancel"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: .snow,
                            cornerRadius: 999,
                            rimHeight: 5,
                            whiteBorderWidth: 3,
                            playTapSound: false
                        )
                    )

                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        confirmAddKidProfile()
                    } label: {
                        Text(l10n.t("common.ok"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.mintRim.opacity(0.5), radius: 1.5, y: 1.5)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: .mint,
                            cornerRadius: 999,
                            rimHeight: 5,
                            whiteBorderWidth: 3,
                            playTapSound: false
                        )
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: 430)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white, Color(red: 0.95, green: 0.98, blue: 1.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: Color(red: 0.04, green: 0.14, blue: 0.30).opacity(0.35), radius: 24, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white, lineWidth: 4)
            )
            .padding(.horizontal, 24)
            .transition(.scale(scale: 0.86).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isNewKidNameFocused = true
                }
            }
        }
        .zIndex(900)
    }

    private func addKidAvatarButton(emoji: String) -> some View {
        let selected = newKidAvatar == emoji
        return Button {
            SoundAndHapticsManager.shared.playUITap(weight: .light)
            withAnimation(.spring(response: 0.22, dampingFraction: 0.72)) {
                newKidAvatar = emoji
            }
        } label: {
            StarYiMascotView(
                emojiKey: emoji,
                size: 40,
                mood: selected ? .proud : .happy,
                showRing: selected
            )
            .padding(3)
            .background(
                Circle()
                    .fill(selected ? AppTheme.skyTop.opacity(0.18) : Color.clear)
            )
            .overlay(
                Circle()
                    .strokeBorder(selected ? AppTheme.skyBottom : Color.clear, lineWidth: 2.5)
            )
            .scaleEffect(selected ? 1.08 : 0.94)
        }
        .buttonStyle(.plain)
    }

    private func dismissAddKidModal() {
        isNewKidNameFocused = false
        newKidName = ""
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            showAddKidSheet = false
        }
    }

    private func confirmAddKidProfile() {
        isNewKidNameFocused = false
        appState.addFamilyProfile(nickname: newKidName, avatarEmoji: newKidAvatar)
        newKidName = ""
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            showAddKidSheet = false
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(l10n.t("settings.section.profile"), icon: "person.crop.circle.fill", color: AppTheme.skyBottom)
                Spacer()
                HStack(spacing: 5) {
                    StarCoinBadgeView(size: 15)
                    Text("\(appState.profile.starCoins)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.sunBottom)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(AppTheme.softGoldBg))
            }

            // Multi-kid Family Profile Switcher (siblings sharing one iPad!)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.familyProfiles) { kid in
                        let isActive = kid.id == appState.profile.id
                        Button {
                            appState.switchProfile(to: kid)
                        } label: {
                            HStack(spacing: 6) {
                                StarYiMascotView(emojiKey: kid.avatarEmoji, size: 22, showRing: false)
                                Text(kid.nickname)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(isActive ? .white : AppTheme.inkPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
                            .background(
                                Capsule().fill(
                                    isActive
                                    ? AnyShapeStyle(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(AppTheme.canvasBackground)
                                )
                            )
                        }
                        .tactileButton(scale: 0.94, sound: false)
                    }

                    Button {
                        newKidAvatar = avatarChoices.randomElement() ?? "🐼"
                        showAddKidSheet = true
                    } label: {
                        Label(l10n.t("settings.profile.addKid"), systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.mintBottom)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
                            .background(Capsule().fill(AppTheme.mintTop.opacity(0.16)))
                    }
                    .tactileButton(scale: 0.94)
                }
            }

            HStack {
                Text(l10n.t("settings.profile.nickname"))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                Spacer()
                TextField(
                    l10n.t("settings.profile.nickname"),
                    text: Binding(
                        get: { appState.profile.nickname },
                        set: { newVal in appState.updateProfile { $0.nickname = newVal } }
                    )
                )
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppTheme.skyBottom)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.canvasBackground))
                .frame(maxWidth: 220)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(avatarChoices, id: \.self) { emoji in
                        let selected = appState.profile.avatarEmoji == emoji
                        Button {
                            appState.updateProfile { $0.avatarEmoji = emoji }
                        } label: {
                            StarYiMascotView(
                                emojiKey: emoji,
                                size: AppTheme.buttonFaceHeight,
                                mood: selected ? .proud : .happy,
                                showRing: selected
                            )
                            .overlay(Circle().strokeBorder(selected ? AppTheme.sunTop : Color.clear, lineWidth: 2.5))
                            .shadow(color: selected ? AppTheme.sunBottom.opacity(0.35) : .clear, radius: 6, y: 2)
                        }
                        .tactileButton(scale: 0.90)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(l10n.t("settings.section.language"), icon: "globe", color: AppTheme.grapeBottom)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], spacing: 8) {
                languageOption(.system, label: l10n.t("settings.language.system"))
                languageOption(.zhHans, label: "简体中文")
                languageOption(.zhHant, label: "繁體中文")
                languageOption(.en, label: "English")
                languageOption(.ja, label: "日本語")
                languageOption(.ko, label: "한국어")
            }
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private func languageOption(_ lang: AppLanguage, label: String) -> some View {
        let selected = appState.settings.language == lang
        return Button {
            appState.updateSettings { $0.language = lang }
        } label: {
            Text(label)
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .grape : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
    }

    private var boardThemeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(l10n.t("settings.section.appearance"), icon: "paintpalette.fill", color: AppTheme.sunBottom)
                Spacer()
                if let msg = unlockMessage {
                    Text(msg)
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(BoardTheme.allCases) { theme in
                    let palette = AppTheme.palette(for: theme)
                    let unlocked = appState.isThemeUnlocked(theme)
                    let selected = appState.settings.boardTheme == theme

                    Button {
                        if unlocked {
                            unlockMessage = nil
                            appState.updateSettings { $0.boardTheme = theme }
                        } else if appState.unlockBoardTheme(theme) {
                            unlockMessage = nil
                        } else {
                            unlockMessage = l10n.t("settings.theme.needCoins", theme.unlockCoinCost)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(LinearGradient(colors: [palette.boardBase, palette.boardGradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(height: 50)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(selected ? AppTheme.skyTop : Color.white, lineWidth: selected ? 3.5 : 2)
                                    )
                                    .shadow(color: selected ? AppTheme.skyTop.opacity(0.35) : Color.black.opacity(0.08), radius: 6, y: 3)

                                if !unlocked {
                                    HStack(spacing: 3) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 10, weight: .black))
                                        StarCoinBadgeView(size: 12)
                                        Text("\(theme.unlockCoinCost)")
                                            .font(.system(size: 11, weight: .black, design: .rounded))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.black.opacity(0.45)))
                                }
                            }
                            Text(l10n.t(theme.localizationKey))
                                .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                                .foregroundColor(selected ? AppTheme.skyBottom : AppTheme.inkPrimary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .tactileCard()
                }
            }

            Divider()

            Text(l10n.localized(zh: "收藏级棋子皮肤", en: "Collectible Stone Finishes", ja: "碁石コレクション", ko: "바둑돌 스킨", zhHant: "收藏級棋子皮膚"))
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
                ForEach(StoneStyle.allCases, id: \.self) { style in
                    stoneStyleButton(style)
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private func stoneStyleButton(_ style: StoneStyle) -> some View {
        let unlocked = appState.isStoneStyleUnlocked(style)
        let selected = appState.settings.stoneStyle == style
        return Button {
            if unlocked {
                unlockMessage = nil
                appState.updateSettings { $0.stoneStyle = style }
                SoundAndHapticsManager.shared.playStonePlace(at: BoardPoint(row: 4, col: 4), boardSize: 9, isAtari: false)
            } else if appState.unlockStoneStyle(style) {
                unlockMessage = nil
            } else {
                unlockMessage = style.unlockHint(l10n)
            }
        } label: {
            HStack(spacing: 6) {
                Text(style.badgeEmoji)
                    .font(.system(size: 15))
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.displayName(l10n))
                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                        .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                        .lineLimit(1)
                    if !unlocked {
                        HStack(spacing: 3) {
                            StarCoinBadgeView(size: 11)
                            Text("\(style.unlockCoinCost)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(selected ? .white.opacity(0.9) : AppTheme.sunBottom)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 16, rimHeight: 3, whiteBorderWidth: 2))
    }

    private var scoringRuleCard: some View {
        let isZh = l10n.language.isChinese
        return VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                l10n.localized(
                    zh: "终局计分规则",
                    en: "Scoring Ruleset",
                    ja: "終局計算ルール",
                    ko: "종국 계가 규칙",
                    zhHant: "終局計分規則"
                ),
                icon: "checkmark.seal.fill",
                color: AppTheme.skyBottom
            )

            HStack(spacing: 8) {
                ForEach(ScoringRule.allCases) { rule in
                    let selected = appState.settings.scoringRule == rule
                    Button {
                        appState.updateSettings { $0.scoringRule = rule }
                    } label: {
                        Text(rule == .chinese ? (isZh ? "中国数子法" : "Chinese Area") : (isZh ? "日韩数目法" : "Japanese Terr."))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2))
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private var assistsCard: some View {
        let isZh = l10n.language.isChinese
        return VStack(alignment: .leading, spacing: 11) {
            sectionHeader(l10n.t("settings.section.assists"), icon: "sparkles", color: AppTheme.mintBottom)

            // P2: Assist Graduation Ladder ("脱拐辅助阶梯")
            VStack(alignment: .leading, spacing: 6) {
                Text(isZh ? "视觉辅助退场阶梯（从启蒙过渡到真棋盘）" : "Assist Graduation (Starter -> Real Board)")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                HStack(spacing: 6) {
                    assistPresetChip(.starter, label: isZh ? "启蒙全辅" : "Starter")
                    assistPresetChip(.intermediate, label: isZh ? "进阶半辅" : "Mid")
                    assistPresetChip(.examSim, label: isZh ? "考场脱拐" : "Exam Sim")
                }
            }

            Divider()

            gameToggleRow(l10n.t("settings.assist.expressiveStones"), isOn: Binding(
                get: { appState.settings.expressiveStones },
                set: { v in appState.updateSettings { $0.expressiveStones = v; $0.assistPreset = .custom } }
            ))
            gameToggleRow(l10n.t("settings.assist.liveLiberties"), isOn: Binding(
                get: { appState.settings.showLiveLiberties },
                set: { v in appState.updateSettings { $0.showLiveLiberties = v; $0.assistPreset = .custom } }
            ))
            gameToggleRow(l10n.t("settings.assist.confirmMove"), isOn: Binding(
                get: { appState.settings.stonePlacementMode == .confirmButton },
                set: { v in appState.updateSettings {
                    $0.stonePlacementMode = v ? .confirmButton : .doubleTap
                    $0.confirmBeforePlace = v
                } }
            ))
            gameToggleRow(l10n.t("settings.assist.coordinates"), isOn: Binding(
                get: { appState.settings.showCoordinates },
                set: { v in appState.updateSettings { $0.showCoordinates = v } }
            ))
            gameToggleRow(l10n.t("settings.assist.moveNumbers"), isOn: Binding(
                get: { appState.settings.showMoveNumbers },
                set: { v in appState.updateSettings { $0.showMoveNumbers = v } }
            ))
            gameToggleRow(l10n.t("settings.assist.atari"), isOn: Binding(
                get: { appState.settings.highlightAtari },
                set: { v in appState.updateSettings { $0.highlightAtari = v; $0.assistPreset = .custom } }
            ))
            gameToggleRow(isZh ? "做题自动随机旋转/黑白互换" : "Auto-Rotate & Flip Puzzles", isOn: Binding(
                get: { appState.settings.autoTransformPuzzles },
                set: { v in appState.updateSettings { $0.autoTransformPuzzles = v } }
            ))
            gameToggleRow(l10n.t("settings.assist.zenMode"), isOn: Binding(
                get: { appState.settings.zenDojoMode },
                set: { v in appState.updateSettings { $0.zenDojoMode = v; $0.assistPreset = .custom } }
            ))
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private var aiThinkingPaceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                l10n.localized(
                    zh: "AI 思考节奏",
                    en: "AI Thinking Pace",
                    ja: "AIの思考ペース",
                    ko: "AI 생각 속도",
                    zhHant: "AI 思考節奏"
                ),
                icon: "cpu.fill",
                color: AppTheme.skyBottom
            )

            HStack(spacing: 6) {
                ForEach(AIThinkingPace.allCases) { pace in
                    let selected = appState.settings.aiThinkingPace == pace
                    Button {
                        appState.updateSettings {
                            $0.aiThinkingPace = pace
                            $0.aiSimulatedThinkingEnabled = (pace != .instant)
                        }
                    } label: {
                        Text(pace.shortTitle(l10n))
                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                    .accessibilityIdentifier("SettingsAIPace_\(pace.rawValue)")
                }
            }

            Text(appState.settings.aiThinkingPace.summaryText(l10n))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private func assistPresetChip(_ preset: AssistPreset, label: String) -> some View {
        let selected = appState.settings.assistPreset == preset
        return Button {
            appState.applyAssistPreset(preset)
        } label: {
            Text(label)
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .mint : .snow, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
    }

    private var audioAndEyeCareCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeader(l10n.t("settings.section.feedback"), icon: "speaker.wave.2.fill", color: AppTheme.coralBottom)

            gameToggleRow(l10n.t("settings.feedback.bgm"), isOn: Binding(
                get: { appState.settings.bgmEnabled },
                set: { v in appState.updateSettings { $0.bgmEnabled = v } }
            ))
            gameToggleRow(l10n.t("settings.feedback.sound"), isOn: Binding(
                get: { appState.settings.soundEnabled },
                set: { v in appState.updateSettings { $0.soundEnabled = v } }
            ))
            gameToggleRow(l10n.t("settings.feedback.voice"), isOn: Binding(
                get: { appState.settings.voiceEnabled },
                set: { v in
                    appState.updateSettings { $0.voiceEnabled = v }
                    if v {
                        SoundAndHapticsManager.shared.playVoice(.welcome)
                    }
                }
            ))
            gameToggleRow(l10n.t("settings.feedback.haptics"), isOn: Binding(
                get: { appState.settings.hapticsEnabled },
                set: { v in appState.updateSettings { $0.hapticsEnabled = v } }
            ))

            Divider()

            Text(l10n.t("settings.section.eyecare"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)

            HStack(spacing: 8) {
                ForEach(eyeCareOptions, id: \.self) { mins in
                    let selected = appState.settings.eyeCareMinutes == mins
                    Button {
                        appState.updateSettings { $0.eyeCareMinutes = mins }
                    } label: {
                        Text(mins == 0 ? l10n.t("settings.eyecare.off") : l10n.t("settings.eyecare.minutes", mins))
                            .font(.system(size: 12, weight: .heavy, design: .rounded))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private var aboutFooterCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(l10n.t("settings.section.about"), icon: "heart.circle.fill", color: AppTheme.skyBottom)
            Text(l10n.t("settings.about.kidSafe"))
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.mintBottom)
            Text(l10n.t("settings.about.offlineNote"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
            Text(CoreMLGoAIEngine.shared.activeEngineBadge(l10n))
                .font(.system(size: 11.5, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.skyBottom)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
        } icon: {
            Image(systemName: icon)
                .foregroundColor(color)
        }
    }

    private func gameToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .toggleStyle(GameSwitchToggleStyle())
    }
}

private struct GameSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 12) {
            configuration.label
            Spacer(minLength: 8)
            Button {
                SoundAndHapticsManager.shared.playUITap(weight: .light)
                withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                    configuration.isOn.toggle()
                }
            } label: {
                ZStack {
                    Capsule()
                        .fill(
                            configuration.isOn
                                ? LinearGradient(
                                    colors: [AppTheme.mintTop, AppTheme.mintBottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                                : LinearGradient(
                                    colors: [
                                        Color(red: 0.72, green: 0.76, blue: 0.82),
                                        Color(red: 0.62, green: 0.67, blue: 0.74)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                        )
                        .frame(width: 52, height: 31)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    configuration.isOn
                                        ? AppTheme.mintRim.opacity(0.50)
                                        : Color(red: 0.46, green: 0.52, blue: 0.60).opacity(0.65),
                                    lineWidth: 1.5
                                )
                        )

                    Circle()
                        .fill(Color.white)
                        .frame(width: 25, height: 25)
                        .shadow(color: Color.black.opacity(0.22), radius: 2.5, x: 0, y: 1.5)
                        .offset(x: configuration.isOn ? 10.5 : -10.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(configuration.isOn ? "On" : "Off")
        }
    }
}

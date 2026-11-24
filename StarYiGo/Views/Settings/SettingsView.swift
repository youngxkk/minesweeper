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

                    Button {
                        dismiss()
                    } label: {
                        Text(l10n.t("common.done"))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
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
                                assistsCard
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
                                    assistsCard
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
        }
        .alert(l10n.t("settings.profile.addKidTitle"), isPresented: $showAddKidSheet) {
            TextField(l10n.t("settings.profile.nickname"), text: $newKidName)
            Button(l10n.t("common.ok")) {
                appState.addFamilyProfile(nickname: newKidName, avatarEmoji: newKidAvatar)
                newKidName = ""
            }
            Button(l10n.t("common.cancel"), role: .cancel) {
                newKidName = ""
            }
        } message: {
            Text(l10n.t("settings.profile.addKidHint"))
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(l10n.t("settings.section.profile"), icon: "person.crop.circle.fill", color: AppTheme.skyBottom)
                Spacer()
                Text("🪙 \(appState.profile.starCoins)")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.sunBottom)
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
                                Text(kid.avatarEmoji)
                                Text(kid.nickname)
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .lineLimit(1)
                            }
                            .foregroundColor(isActive ? .white : AppTheme.inkPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
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
                            Text(emoji)
                                .font(.system(size: 24))
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle().fill(
                                        selected
                                        ? AnyShapeStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(AppTheme.canvasBackground)
                                    )
                                )
                                .overlay(Circle().strokeBorder(selected ? Color.white : Color.clear, lineWidth: 2.5))
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
                                        Text("🪙\(theme.unlockCoinCost)")
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
                    .tactileButton(scale: 0.94)
                }
            }
        }
        .warmCard(cornerRadius: 24, padding: 18)
    }

    private var assistsCard: some View {
        let isZh = l10n.language.isChinese
        return VStack(alignment: .leading, spacing: 11) {
            sectionHeader(l10n.t("settings.section.assists"), icon: "sparkles", color: AppTheme.mintBottom)

            // P0: Scoring Rule (Chinese Area vs Japanese Territory)
            VStack(alignment: .leading, spacing: 6) {
                Text(isZh ? "终局计分规则" : "Scoring Ruleset")
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                HStack(spacing: 8) {
                    ForEach(ScoringRule.allCases) { rule in
                        let selected = appState.settings.scoringRule == rule
                        Button {
                            appState.updateSettings { $0.scoringRule = rule }
                        } label: {
                            Text(rule == .chinese ? (isZh ? "中国数子法" : "Chinese Area") : (isZh ? "日韩数目法" : "Japanese Terr."))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2))
                    }
                }
            }

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
                get: { appState.settings.confirmBeforePlace },
                set: { v in appState.updateSettings { $0.confirmBeforePlace = v } }
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
            gameToggleRow(isZh ? "防随手冷静保护（防秒拍）" : "Anti-Impulse Calm Guard", isOn: Binding(
                get: { appState.settings.antiImpulseGuard },
                set: { v in appState.updateSettings { $0.antiImpulseGuard = v } }
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
            Text(
                l10n.language.isChinese
                ? (CoreMLGoAIEngine.shared.isNeuralModelLoaded ? "对弈引擎：神经网络 + 多层蒙特卡洛搜索" : "对弈引擎：星弈多层搜索 + 战术阅读")
                : "AI Engine: \(CoreMLGoAIEngine.shared.engineName)"
            )
            .font(.system(size: 11, weight: .bold, design: .rounded))
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
        .tint(AppTheme.mintBottom)
    }
}

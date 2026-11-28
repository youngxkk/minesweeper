//
//  SettingsView.swift
//  StarYi Go — Glossy Nintendo Switch Party Game Settings & Family Profiles Modal
//

import SwiftUI
import UIKit

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showAddKidSheet = false
    @State private var editingProfile: UserProfile? = nil
    @State private var newKidName = ""
    @State private var newKidAvatar = "🐼"
    @State private var unlockMessage: String? = nil
    @State private var pendingExternalURL: URL? = nil
    @State private var contactToastID: UUID? = nil
    @State private var profilePendingDeletion: UserProfile? = nil
    @FocusState private var isNewKidNameFocused: Bool
    #if DEBUG
    @ObservedObject private var reviewPolicy = ReviewPromptPolicy.shared
    @State private var showDebugResetConfirm = false
    @State private var debugStatusMessage: String? = nil
    #endif

    private let avatarChoices = ["🦊", "🐼", "🐰", "🐉", "🦢", "🐯", "🦁", "🦉", "🌟", "🎋"]
    private let eyeCareOptions = [0, 15, 25, 40]

    private var l10n: L10n { appState.l10n }

    var body: some View {
        #if DEBUG
        settingsBody
            .gameDialog(
                isPresented: $showDebugResetConfirm,
                title: "重置当前档案进度？",
                message: "将清空当前档案「\(appState.profile.nickname)」的金币、经验、段位、题库与海域进度（仅 Debug 本地测试使用）。",
                icon: "arrow.counterclockwise.circle.fill",
                accentPalette: .coral,
                actions: [
                    .secondary(l10n.t("common.cancel")) {
                        showDebugResetConfirm = false
                    },
                    .destructive("确认重置") {
                        appState.debugResetCurrentProfileProgress()
                        debugStatusMessage = "已重置当前档案进度"
                        showDebugResetConfirm = false
                    }
                ]
            )
        #else
        settingsBody
        #endif
    }

    private var settingsBody: some View {
        ZStack {
            SceneBackdrop.paperSettings

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
                .padding(.horizontal, 30)
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
                                aiModelCard
                                aiThinkingPaceCard
                                audioAndEyeCareCard
                                aboutFooterCard
                                #if DEBUG
                                debugModeCard
                                #endif
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 32)
                        } else {
                            HStack(alignment: .top, spacing: 24) {
                                VStack(spacing: 18) {
                                    profileCard
                                    languageCard
                                    boardThemeCard
                                    audioAndEyeCareCard
                                    #if DEBUG
                                    debugModeCard
                                    #endif
                                }
                                .frame(maxWidth: .infinity)

                                VStack(spacing: 18) {
                                    scoringRuleCard
                                    assistsCard
                                    aiModelCard
                                    aiThinkingPaceCard
                                    aboutFooterCard
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 30)
                            .padding(.bottom, 32)
                        }
                    }
                }
            }

            if showAddKidSheet {
                addKidProfileOverlay
            }

            if let targetURL = pendingExternalURL {
                ParentalGateOverlay(
                    l10n: l10n,
                    onCancel: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            pendingExternalURL = nil
                        }
                    },
                    onSuccess: {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                            pendingExternalURL = nil
                        }
                        openExternalDestination(targetURL)
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if contactToastID != nil {
                Label(
                    l10n.localized(
                        zh: "邮箱已复制：\(AppLegalLinks.contactEmail)",
                        en: "Email copied: \(AppLegalLinks.contactEmail)",
                        ja: "メールアドレスをコピーしました：\(AppLegalLinks.contactEmail)",
                        ko: "이메일 주소 복사됨: \(AppLegalLinks.contactEmail)",
                        zhHant: "信箱已複製：\(AppLegalLinks.contactEmail)"
                    ),
                    systemImage: "checkmark.circle.fill"
                )
                .font(AppFont.rounded(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 13)
                .background(RoundedRectangle(cornerRadius: 18).fill(AppTheme.inkPrimary))
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .allowsHitTesting(false)
                .accessibilityIdentifier("SettingsContactEmailCopiedToast")
                .task(id: contactToastID) {
                    do {
                        try await Task.sleep(for: .seconds(3))
                        contactToastID = nil
                    } catch { }
                }
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: showAddKidSheet)
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: pendingExternalURL != nil)
        .gameDialog(
            isPresented: Binding(
                get: { profilePendingDeletion != nil },
                set: { if !$0 { profilePendingDeletion = nil } }
            ),
            title: l10n.localized(
                zh: "删除成员档案？",
                en: "Delete Family Profile?",
                ja: "メンバープロフィールを削除しますか？",
                ko: "가족 프로필을 삭제할까요?",
                zhHant: "刪除成員檔案？"
            ),
            message: l10n.localized(
                zh: "确定要删除「\(profilePendingDeletion?.nickname ?? "")」的本地档案吗？此操作无法撤销。",
                en: "Remove \"\(profilePendingDeletion?.nickname ?? "")\" from this device? This cannot be undone.",
                ja: "「\(profilePendingDeletion?.nickname ?? "")」のプロフィールを端末から削除しますか？元に戻せません。",
                ko: "\"\(profilePendingDeletion?.nickname ?? "")\" 프로필을 이 기기에서 삭제할까요? 되돌릴 수 없습니다.",
                zhHant: "確定要刪除「\(profilePendingDeletion?.nickname ?? "")」的本地檔案嗎？此操作無法復原。"
            ),
            icon: "trash.fill",
            accentPalette: .coral,
            actions: [
                .secondary(l10n.t("common.cancel")) {
                    profilePendingDeletion = nil
                },
                .destructive(l10n.localized(zh: "删除", en: "Delete", ja: "削除", ko: "삭제", zhHant: "刪除")) { [target = profilePendingDeletion] in
                    if let target {
                        appState.deleteFamilyProfile(target)
                    }
                    profilePendingDeletion = nil
                }
            ]
        )
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
                    Text(
                        editingProfile != nil
                            ? l10n.localized(
                                zh: "编辑成员档案",
                                en: "Edit Family Profile",
                                ja: "メンバーを編集",
                                ko: "가족 프로필 편집",
                                zhHant: "編輯成員檔案"
                            )
                            : l10n.t("settings.profile.addKidTitle")
                    )
                        .font(AppFont.rounded(size: 21, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .multilineTextAlignment(.center)

                    Text(
                        editingProfile != nil
                            ? l10n.localized(
                                zh: "修改昵称和专属头像，更改会立即同步到该档案。",
                                en: "Update the nickname and mascot avatar for this profile.",
                                ja: "ニックネームとアイコンを変更して保存できます。",
                                ko: "닉네임과 아바타를 수정해 바로 저장할 수 있어요.",
                                zhHant: "修改暱稱和專屬頭像，變更會立即同步到該檔案。"
                            )
                            : l10n.t("settings.profile.addKidHint")
                    )
                        .font(AppFont.rounded(size: 13.5, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Branded rounded nickname field
                TextField(l10n.t("settings.profile.nickname"), text: $newKidName)
                    .font(AppFont.rounded(size: 16, weight: .heavy))
                    .foregroundColor(AppTheme.inkPrimary)
                    .multilineTextAlignment(.center)
                    .focused($isNewKidNameFocused)
                    .submitLabel(.done)
                    .onChange(of: newKidName) { _, newValue in
                        let clamped = UserProfile.clampedNickname(newValue)
                        if clamped != newValue {
                            newKidName = clamped
                        }
                    }
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
                            .font(AppFont.rounded(size: 16, weight: .black))
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
                            rimHeight: 3,
                            whiteBorderWidth: 3,
                            playTapSound: false
                        )
                    )

                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        confirmAddKidProfile()
                    } label: {
                        Text(l10n.t("common.ok"))
                            .font(AppFont.rounded(size: 16, weight: .black))
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
                            rimHeight: 3,
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
        editingProfile = nil
        withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
            showAddKidSheet = false
        }
    }

    private func confirmAddKidProfile() {
        isNewKidNameFocused = false
        if let target = editingProfile {
            appState.editFamilyProfile(target, nickname: newKidName, avatarEmoji: newKidAvatar)
        } else {
            appState.addFamilyProfile(nickname: newKidName, avatarEmoji: newKidAvatar)
        }
        newKidName = ""
        editingProfile = nil
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
                        .font(AppFont.rounded(size: 13, weight: .black))
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
                                    .font(AppFont.rounded(size: 12, weight: .black))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(maxWidth: 96, alignment: .leading)
                            }
                            .foregroundColor(isActive ? .white : AppTheme.inkPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
                            .background(
                                Capsule().fill(
                                    isActive
                                    ? AnyShapeStyle(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(LinearGradient(
                                        colors: [.white, Color(red: 0.925, green: 0.958, blue: 0.985)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                )
                            )
                            .overlay(
                                Capsule().strokeBorder(
                                    isActive
                                    ? AnyShapeStyle(LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.52), location: 0),
                                            .init(color: .clear, location: 0.55),
                                            .init(color: AppTheme.skyRim.opacity(0.55), location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ))
                                    : AnyShapeStyle(LinearGradient(
                                        stops: [
                                            .init(color: .white.opacity(0.95), location: 0),
                                            .init(color: Color(red: 0.66, green: 0.79, blue: 0.90).opacity(0.55), location: 1)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )),
                                    lineWidth: 1
                                )
                            )
                            .shadow(
                                color: isActive
                                    ? AppTheme.skyBottom.opacity(0.22)
                                    : Color(red: 0.24, green: 0.38, blue: 0.46).opacity(0.06),
                                radius: isActive ? 2.5 : 2,
                                y: 2
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("FamilyProfileChip")
                        .contentShape(.contextMenuPreview, Capsule())
                        .contextMenu {
                            Button {
                                SoundAndHapticsManager.shared.playUITap(weight: .light)
                                editingProfile = kid
                                newKidName = kid.nickname
                                newKidAvatar = kid.avatarEmoji
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                                    showAddKidSheet = true
                                }
                            } label: {
                                Label(
                                    l10n.localized(zh: "编辑档案", en: "Edit Profile", ja: "プロフィールを編集", ko: "프로필 편집", zhHant: "編輯檔案"),
                                    systemImage: "pencil"
                                )
                            }

                            Button(role: .destructive) {
                                SoundAndHapticsManager.shared.playUITap(weight: .light)
                                profilePendingDeletion = kid
                            } label: {
                                Label(
                                    l10n.localized(zh: "删除档案", en: "Delete Profile", ja: "プロフィールを削除", ko: "프로필 삭제", zhHant: "刪除檔案"),
                                    systemImage: "trash"
                                )
                            }
                            .disabled(appState.familyProfiles.count <= 1)
                        }
                    }

                    Button {
                        editingProfile = nil
                        newKidName = ""
                        newKidAvatar = avatarChoices.randomElement() ?? "🐼"
                        showAddKidSheet = true
                    } label: {
                        Label(l10n.t("settings.profile.addKid"), systemImage: "plus.circle.fill")
                            .font(AppFont.rounded(size: 12, weight: .black))
                            .foregroundColor(AppTheme.mintBottom)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
                            .background(Capsule().fill(AppTheme.mintTop.opacity(0.16)))
                    }
                    .tactileButton(scale: 0.94)
                }
                // Room for the chip lift shadow before the context menu appears;
                // without this the horizontal ScrollView clips it top and bottom.
                .padding(.vertical, 8)
            }

            HStack {
                Text(l10n.t("settings.profile.nickname"))
                    .font(AppFont.rounded(size: 14, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)
                Spacer()
                TextField(
                    l10n.t("settings.profile.nickname"),
                    text: Binding(
                        get: { appState.profile.nickname },
                        set: { newVal in
                            let clamped = UserProfile.clampedNickname(newVal)
                            appState.updateProfile { $0.nickname = clamped }
                        }
                    )
                )
                .font(AppFont.rounded(size: 15, weight: .heavy))
                .multilineTextAlignment(.trailing)
                .foregroundColor(AppTheme.skyBottom)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.965, green: 0.98, blue: 0.992),
                                Color(red: 0.925, green: 0.955, blue: 0.98)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                )
                .overlay(
                    Capsule().strokeBorder(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(0.95), location: 0),
                                .init(color: Color(red: 0.74, green: 0.84, blue: 0.91).opacity(0.35), location: 0.55),
                                .init(color: Color(red: 0.63, green: 0.76, blue: 0.86).opacity(0.48), location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
                    .allowsHitTesting(false)
                )
                .frame(maxWidth: 260)
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
        .modifier(WorkshopCardStyle())
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
        .modifier(WorkshopCardStyle())
    }

    private func languageOption(_ lang: AppLanguage, label: String) -> some View {
        let selected = appState.settings.language == lang
        return Button {
            let changed = appState.settings.language != lang
            appState.updateSettings { $0.language = lang }
            if changed && appState.settings.voiceEnabled {
                SoundAndHapticsManager.shared.playVoice(.welcome)
            }
        } label: {
            Text(label)
                .font(AppFont.rounded(size: 12.5, weight: .heavy, languageCode: lang.resolvedCode))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                .padding(.vertical, 9)
        }
        .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.grapeBottom))
    }

    private var boardThemeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader(l10n.t("settings.section.appearance"), icon: "paintpalette.fill", color: AppTheme.sunBottom)
                Spacer()
                if let msg = unlockMessage {
                    Text(msg)
                        .font(AppFont.rounded(size: 11, weight: .heavy))
                        .foregroundColor(AppTheme.coralBottom)
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                ForEach(BoardTheme.allCases) { theme in
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
                                WorkshopBoardPreview(theme: theme, stoneStyle: appState.settings.stoneStyle)
                                    .frame(height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .strokeBorder(selected ? AppTheme.skyBottom : .white, lineWidth: selected ? 3 : 2)
                                    )
                                    .overlay(alignment: .topTrailing) {
                                        if selected {
                                            WorkshopSelectionStone(selected: true)
                                                .padding(5)
                                        }
                                    }
                                    .shadow(color: AppTheme.inkPrimary.opacity(0.12), radius: 4, y: 3)

                                if !unlocked {
                                    HStack(spacing: 3) {
                                        Image(systemName: "lock.fill")
                                            .font(.system(size: 10, weight: .black, design: .rounded))
                                        StarCoinBadgeView(size: 12)
                                        Text("\(theme.unlockCoinCost)")
                                            .font(AppFont.rounded(size: 11, weight: .black))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color.black.opacity(0.45)))
                                }
                            }
                            Text(l10n.t(theme.localizationKey))
                                .font(AppFont.rounded(size: 11.5, weight: .heavy))
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
                .font(AppFont.rounded(size: 12.5, weight: .heavy))
                .foregroundColor(AppTheme.inkSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 8)], spacing: 8) {
                ForEach(StoneStyle.allCases, id: \.self) { style in
                    stoneStyleButton(style)
                }
            }
        }
        .modifier(WorkshopCardStyle())
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
                HStack(spacing: -7) {
                    WorkshopStone(style: style, isBlack: true)
                    WorkshopStone(style: style, isBlack: false)
                }
                .frame(width: 37, height: 24)
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text(style.displayName(l10n))
                        .font(AppFont.rounded(size: 11.5, weight: .black))
                        .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    if !unlocked {
                        HStack(spacing: 3) {
                            StarCoinBadgeView(size: 11)
                            Text("\(style.unlockCoinCost)")
                                .font(AppFont.rounded(size: 10, weight: .bold))
                                .foregroundColor(selected ? .white.opacity(0.9) : AppTheme.sunBottom)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: 38)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.skyBottom))
    }

    private var scoringRuleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
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

            HStack(spacing: 6) {
                ForEach(ScoringRulePreference.allCases) { preference in
                    let selected = appState.settings.scoringRule == preference
                    Button {
                        appState.updateSettings { $0.scoringRule = preference }
                    } label: {
                        Text(scoringPreferenceTitle(preference))
                            .font(AppFont.rounded(size: 11.5, weight: .black))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.skyBottom))
                }
            }

            Text(scoringRuleExplanation)
                .font(AppFont.rounded(size: 11.5, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .modifier(WorkshopCardStyle())
    }

    private var scoringRuleExplanation: String {
        let preference = appState.settings.scoringRule
        if preference == .automatic {
            let active = scoringRuleName(appState.settings.effectiveScoringRule)
            return l10n.localized(
                zh: "按系统地区自动选择，当前：\(active)。",
                en: "Picks by region. Active: \(active).",
                ja: "地域に合わせて自動選択。現在：\(active)。",
                ko: "지역에 맞춰 자동 선택. 현재: \(active).",
                zhHant: "依系統地區自動選擇，目前：\(active)。"
            )
        }
        return scoringPreferenceDetail(preference)
    }

    private func scoringPreferenceTitle(_ preference: ScoringRulePreference) -> String {
        switch preference {
        case .automatic:
            return l10n.localized(zh: "自动", en: "Auto", ja: "自動", ko: "자동", zhHant: "自動")
        case .chinese:
            return l10n.localized(zh: "中国数子", en: "Chinese Area", ja: "中国数子", ko: "중국 수자", zhHant: "中國數子")
        case .japanese:
            return l10n.localized(zh: "日韩数目", en: "JP/KR Territory", ja: "日韓数目", ko: "한일 수목", zhHant: "日韓數目")
        case .aga:
            return l10n.localized(zh: "AGA 面积", en: "AGA Area", ja: "AGA 面積", ko: "AGA 면적", zhHant: "AGA 面積")
        }
    }

    private func scoringPreferenceDetail(_ preference: ScoringRulePreference) -> String {
        switch preference {
        case .automatic:
            return l10n.localized(
                zh: "按系统地区自动选择，可随时改。",
                en: "Picks by region; you can change it anytime.",
                ja: "地域に合わせて自動選択。いつでも変更できます。",
                ko: "지역에 맞춰 자동 선택하며 언제든 바꿀 수 있어요.",
                zhHant: "依系統地區自動選擇，可隨時手動修改。"
            )
        case .chinese:
            return l10n.localized(
                zh: "活棋和围空都算分，适合中国、港澳台。",
                en: "Stones + territory; good for Chinese-speaking regions.",
                ja: "石と地を数える中国式。中国・港澳台向け。",
                ko: "돌과 집을 함께 계산. 중국·홍콩·마카오·대만 추천.",
                zhHant: "活棋和圍空都算分，適合中國、港澳台。"
            )
        case .japanese:
            return l10n.localized(
                zh: "围空加提子算分，适合日本、韩国及欧洲多数比赛。",
                en: "Territory + captures; good for Japan, Korea and most of Europe.",
                ja: "地と取り石を数える日韓式。日本・韓国・欧州向け。",
                ko: "집과 잡은 돌을 계산. 일본·한국·유럽 추천.",
                zhHant: "圍空加提子算分，適合日本、韓國及歐洲多數比賽。"
            )
        case .aga:
            return l10n.localized(
                zh: "面积计分，适合美国、加拿大、英国。",
                en: "Area scoring; good for the US, Canada and the UK.",
                ja: "面積計算。アメリカ・カナダ・イギリス向け。",
                ko: "면적 계산. 미국·캐나다·영국 추천.",
                zhHant: "面積計分，適合美國、加拿大、英國。"
            )
        }
    }

    private func scoringRuleName(_ rule: ScoringRule) -> String {
        switch rule {
        case .chinese:
            return l10n.localized(zh: "中国数子", en: "Chinese Area", ja: "中国数子", ko: "중국 수자", zhHant: "中國數子")
        case .japanese:
            return l10n.localized(zh: "日韩数目", en: "JP/KR Territory", ja: "日韓数目", ko: "한일 수목", zhHant: "日韓數目")
        case .aga:
            return l10n.localized(zh: "AGA 面积", en: "AGA Area", ja: "AGA 面積", ko: "AGA 면적", zhHant: "AGA 面積")
        }
    }

    private var assistsCard: some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeader(l10n.t("settings.section.assists"), icon: "sparkles", color: AppTheme.mintBottom)

            // P2: Assist Graduation Ladder ("脱拐辅助阶梯")
            VStack(alignment: .leading, spacing: 6) {
                Text(
                    l10n.localized(
                        zh: "视觉辅助退场阶梯（从启蒙过渡到真棋盘）",
                        en: "Assist Graduation (Starter -> Real Board)",
                        ja: "視覚アシスト段階（入門から実戦盤へ）",
                        ko: "시각 보조 단계 (입문 → 실전 바둑판)",
                        zhHant: "視覺輔助退場階梯（從啟蒙過渡到真棋盤）"
                    )
                )
                    .font(AppFont.rounded(size: 12.5, weight: .heavy))
                    .foregroundColor(AppTheme.inkSecondary)
                HStack(spacing: 6) {
                    assistPresetChip(.starter, label: l10n.localized(zh: "启蒙全辅", en: "Starter", ja: "入門フル", ko: "입문 전체", zhHant: "啟蒙全輔"))
                    assistPresetChip(.intermediate, label: l10n.localized(zh: "进阶半辅", en: "Mid", ja: "中級", ko: "중급 보조", zhHant: "進階半輔"))
                    assistPresetChip(.examSim, label: l10n.localized(zh: "考场脱拐", en: "Exam Sim", ja: "実戦モード", ko: "실전 모드", zhHant: "考場脫拐"))
                }
            }

            gameToggleRow(l10n.t("settings.assist.expressiveStones"), isOn: Binding(
                get: { appState.settings.expressiveStones },
                set: { v in appState.updateSettings { $0.expressiveStones = v; $0.assistPreset = .custom } }
            ))
            gameToggleRow(l10n.t("settings.assist.liveLiberties"), isOn: Binding(
                get: { appState.settings.showLiveLiberties },
                set: { v in appState.updateSettings { $0.showLiveLiberties = v; $0.assistPreset = .custom } }
            ))
            gameToggleRow(l10n.t("settings.assist.atari"), isOn: Binding(
                get: { appState.settings.highlightAtari },
                set: { v in appState.updateSettings { $0.highlightAtari = v; $0.assistPreset = .custom } }
            ))
            gameToggleRow(l10n.t("settings.assist.zenMode"), isOn: Binding(
                get: { appState.settings.zenDojoMode },
                set: { v in appState.updateSettings { $0.zenDojoMode = v; $0.assistPreset = .custom } }
            ))

            Divider()

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
            gameToggleRow(
                l10n.localized(
                    zh: "做题自动随机旋转/黑白互换",
                    en: "Auto-Rotate & Flip Puzzles",
                    ja: "問題を自動回転・白黒反転",
                    ko: "문제 자동 회전·흑백 반전",
                    zhHant: "做題自動隨機旋轉/黑白互換"
                ),
                isOn: Binding(
                    get: { appState.settings.autoTransformPuzzles },
                    set: { v in appState.updateSettings { $0.autoTransformPuzzles = v } }
                )
            )
        }
        .modifier(WorkshopCardStyle())
    }

    private var aiModelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(
                l10n.localized(
                    zh: "本地 AI 围棋模型",
                    en: "Offline Go AI Model",
                    ja: "ローカル囲碁 AI モデル",
                    ko: "오프라인 바둑 AI 모델",
                    zhHant: "本地 AI 圍棋模型"
                ),
                icon: "brain.head.profile",
                color: AppTheme.grapeBottom
            )

            HStack(spacing: 6) {
                ForEach(KataGoModelPreset.allCases) { preset in
                    let selected = appState.settings.aiModelPreset == preset
                    Button {
                        appState.updateSettings {
                            $0.aiModelPreset = preset
                        }
                        if preset == .b18c384nbt {
                            KataGoProModelODRManager.shared.ensureDownloaded()
                        }
                    } label: {
                        Text(preset.shortTitle(l10n))
                            .font(AppFont.rounded(size: 11.5, weight: .black))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.grapeBottom))
                    .accessibilityIdentifier("SettingsAIModel_\(preset.rawValue)")
                }
            }

            Text(appState.settings.aiModelPreset.summaryText(l10n))
                .font(AppFont.rounded(size: 11.5, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if appState.settings.aiModelPreset == .b18c384nbt {
                let odrManager = KataGoProModelODRManager.shared
                #if DEBUG
                if odrManager.bypassODRUseLocalModel {
                    Text("DEBUG · 专业模型已直连本地包（已跳过 Apple ODR）")
                        .font(AppFont.rounded(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.mintBottom)
                }
                #endif
                let odrState = odrManager.state
                switch odrState {
                case .downloading(let progress):
                    HStack(spacing: 8) {
                        ProgressView(value: progress)
                            .tint(AppTheme.grapeBottom)
                        Text("\(Int(progress * 100))%")
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(AppTheme.grapeBottom)
                            .monospacedDigit()
                    }
                case .failed:
                    Button {
                        KataGoProModelODRManager.shared.ensureDownloaded()
                    } label: {
                        Text(l10n.localized(
                            zh: "专业模型按需下载失败（当前自动回退标准版），点此重试",
                            en: "Pro model download paused (using Standard offline). Tap to retry.",
                            ja: "プロモデルのダウンロード失敗（標準版を使用中）。タップで再試行",
                            ko: "프로 모델 다운로드 실패 (표준 모델 사용 중). 탭하여 재시도",
                            zhHant: "專業模型按需下載失敗（目前自動回退標準版），點此重試"
                        ))
                        .font(AppFont.rounded(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.coralBottom)
                    }
                    .buttonStyle(.plain)
                case .notDownloaded:
                    Button {
                        KataGoProModelODRManager.shared.ensureDownloaded()
                    } label: {
                        Text(l10n.localized(
                            zh: "点此通过 Apple ODR 按需下载专业模型（25.5 MB）",
                            en: "Tap to download Pro model on demand via Apple ODR (25.5 MB)",
                            ja: "Apple ODR でプロモデルをダウンロード（25.5 MB）",
                            ko: "Apple ODR로 프로 모델 다운로드 (25.5 MB)",
                            zhHant: "點此透過 Apple ODR 按需下載專業模型（25.5 MB）"
                        ))
                        .font(AppFont.rounded(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.grapeBottom)
                    }
                    .buttonStyle(.plain)
                case .ready:
                    EmptyView()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WorkshopCardStyle())
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
                            .font(AppFont.rounded(size: 11.5, weight: .black))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.skyBottom))
                    .accessibilityIdentifier("SettingsAIPace_\(pace.rawValue)")
                }
            }

            Text(appState.settings.aiThinkingPace.summaryText(l10n))
                .font(AppFont.rounded(size: 11.5, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WorkshopCardStyle())
    }

    private func assistPresetChip(_ preset: AssistPreset, label: String) -> some View {
        let selected = appState.settings.assistPreset == preset
        return Button {
            appState.applyAssistPreset(preset)
        } label: {
            Text(label)
                .font(AppFont.rounded(size: 11.5, weight: .black))
                .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                .padding(.vertical, 8)
        }
        .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.mintBottom))
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
                .font(AppFont.rounded(size: 13, weight: .heavy))
                .foregroundColor(AppTheme.inkSecondary)

            HStack(spacing: 8) {
                ForEach(eyeCareOptions, id: \.self) { mins in
                    let selected = appState.settings.eyeCareMinutes == mins
                    Button {
                        appState.updateSettings { $0.eyeCareMinutes = mins }
                    } label: {
                        Text(mins == 0 ? l10n.t("settings.eyecare.off") : l10n.t("settings.eyecare.minutes", mins))
                            .font(AppFont.rounded(size: 12, weight: .heavy))
                            .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.skyBottom))
                }
            }
        }
        .modifier(WorkshopCardStyle())
    }

    private var aboutFooterCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(l10n.t("settings.section.about"), icon: "heart.circle.fill", color: AppTheme.skyBottom)
                Spacer()
                Text(AppLegalLinks.appVersionString)
                    .font(AppFont.rounded(size: 11.5, weight: .black))
                    .foregroundColor(AppTheme.inkSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.canvasBackground))
            }

            Text(l10n.t("settings.about.kidSafe"))
                .font(AppFont.rounded(size: 13, weight: .heavy))
                .foregroundColor(AppTheme.mintBottom)
            Text(l10n.t("settings.about.offlineNote"))
                .font(AppFont.rounded(size: 12, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary)
            Text(CoreMLGoAIEngine.shared.activeEngineBadge(l10n))
                .font(AppFont.rounded(size: 11.5, weight: .black))
                .foregroundColor(AppTheme.skyBottom)

            Divider()

            HStack(spacing: 8) {
                legalLinkButton(
                    title: l10n.localized(zh: "联系我们", en: "Contact Us", ja: "お問い合わせ", ko: "문의하기", zhHant: "聯絡我們"),
                    icon: "envelope.fill",
                    url: AppLegalLinks.contactEmailURL
                )
                legalLinkButton(
                    title: "X (Twitter)",
                    icon: "at",
                    url: AppLegalLinks.contactXURL
                )
                .accessibilityLabel("X (Twitter), @invisilab_x")
                .accessibilityIdentifier("SettingsContactXButton")
            }

            HStack(spacing: 8) {
                legalLinkButton(
                    title: l10n.localized(zh: "隐私政策", en: "Privacy Policy", ja: "プライバシーポリシー", ko: "개인정보 처리방침", zhHant: "隱私政策"),
                    icon: "hand.raised.fill",
                    url: AppLegalLinks.privacyPolicyURL(for: appState.settings.language)
                )
                legalLinkButton(
                    title: l10n.localized(zh: "用户协议", en: "User Agreement", ja: "ユーザー契約", ko: "사용자 약관", zhHant: "用戶協議"),
                    icon: "doc.text.fill",
                    url: AppLegalLinks.userAgreementURL(for: appState.settings.language)
                )
                legalLinkButton(
                    title: l10n.localized(zh: "使用条款", en: "Terms of Use", ja: "利用規約", ko: "이용약관", zhHant: "使用條款"),
                    icon: "checkmark.shield.fill",
                    url: AppLegalLinks.termsOfUseURL(for: appState.settings.language)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WorkshopCardStyle())
    }

    private func openExternalDestination(_ url: URL) {
        guard url == AppLegalLinks.contactEmailURL else {
            openURL(url)
            return
        }
        openURL(url) { accepted in
            guard !accepted else { return }
            UIPasteboard.general.string = AppLegalLinks.contactEmail
            contactToastID = UUID()
            UIAccessibility.post(
                notification: .announcement,
                argument: l10n.localized(
                    zh: "邮箱已复制：\(AppLegalLinks.contactEmail)",
                    en: "Email copied: \(AppLegalLinks.contactEmail)",
                    ja: "メールアドレスをコピーしました：\(AppLegalLinks.contactEmail)",
                    ko: "이메일 주소 복사됨: \(AppLegalLinks.contactEmail)",
                    zhHant: "信箱已複製：\(AppLegalLinks.contactEmail)"
                )
            )
        }
    }

    private func legalLinkButton(title: String, icon: String, url: URL) -> some View {
        Button {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                pendingExternalURL = url
            }
        } label: {
            Label(title, systemImage: icon)
                .font(AppFont.rounded(size: 11.5, weight: .heavy))
                .foregroundColor(AppTheme.inkPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.vertical, 8)
        }
        .buttonStyle(WorkshopChoiceStyle(selected: false, accent: AppTheme.skyBottom, showsSelectionStone: false))
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        Label {
            Text(title)
                .font(AppFont.rounded(size: 15, weight: .black))
                .foregroundColor(AppTheme.inkPrimary)
        } icon: {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(color.opacity(0.10)))
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: color.opacity(0.12), radius: 2, y: 2)
        }
    }

    private func gameToggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Text(title)
                .font(AppFont.rounded(size: 13.5, weight: .bold))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .toggleStyle(GameSwitchToggleStyle())
    }

    #if DEBUG
    private var debugModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("Debug 模式", icon: "ladybug.fill", color: AppTheme.coralBottom)
                Spacer()
                Text("DEBUG ONLY")
                    .font(AppFont.rounded(size: 10.5, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.coralBottom))
            }

            gameToggleRow(
                "启用本地调试工具",
                isOn: Binding(
                    get: { appState.isDebugModeEnabled },
                    set: { enabled in
                        appState.setDebugModeEnabled(enabled)
                        if !enabled { reviewPolicy.debugBypassLimits = false }
                    }
                )
            )
            .accessibilityIdentifier("SettingsDebugModeToggle")

            if appState.isDebugModeEnabled {
                Divider()

                gameToggleRow("评分弹窗测试（跳过频率限制）", isOn: $reviewPolicy.debugBypassLimits)
                    .accessibilityIdentifier("SettingsDebugReviewPromptToggle")
                Text("开启后，每局结束 1 秒后请求系统评分弹窗，不受 30 天和版本限制，也不消耗正常邀请次数。关闭调试工具或重启 App 后恢复正常策略。")
                    .font(AppFont.rounded(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)

                gameToggleRow(
                    "跳过家长验证",
                    isOn: Binding(
                        get: { appState.debugSkipParentalVerification },
                        set: { appState.setDebugSkipParentalVerification($0) }
                    )
                )
                .accessibilityIdentifier("SettingsDebugSkipParentalVerificationToggle")

                gameToggleRow(
                    "专业模型本地直连（关掉走 Apple ODR）",
                    isOn: Binding(
                        get: { KataGoProModelODRManager.shared.bypassODRUseLocalModel },
                        set: { enabled in
                            KataGoProModelODRManager.shared.bypassODRUseLocalModel = enabled
                            debugStatusMessage = enabled
                                ? "已切换为本地直连 b18c384nbt（跳过 ODR）"
                                : "已切换为 Apple ODR 模式（未下载时自动回退标准版）"
                        }
                    )
                )
                .accessibilityIdentifier("SettingsDebugBypassProModelODRToggle")

                VStack(alignment: .leading, spacing: 4) {
                    Text("段位 \(appState.profile.rankString) · 金币 \(appState.profile.starCoins) · 体力 \(appState.currentGauntletHearts)/\(PuzzleProgressStore.maxGauntletHearts) · 已解锁海域 \(appState.puzzleProgress.unlockedSeaIds.count)/\(StarYiCampaign.allSeas.count)")
                        .font(AppFont.rounded(size: 11.5, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)

                    if let msg = debugStatusMessage {
                        Text(msg)
                            .font(AppFont.rounded(size: 11.5, weight: .heavy))
                            .foregroundColor(AppTheme.mintBottom)
                    }
                }

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    debugActionButton(title: "+500 金币 / +200 XP", palette: .sun) {
                        appState.debugGrantCoinsAndXP()
                        debugStatusMessage = "已发放 +500 金币 / +200 XP"
                    }
                    debugActionButton(title: "解锁全海域与皮肤", palette: .mint) {
                        appState.debugUnlockAllContent()
                        debugStatusMessage = "已解锁全部海域、棋盘与棋子皮肤"
                    }
                    debugActionButton(title: "补满体力 (3❤️)", palette: .sky) {
                        appState.debugSetGauntletHearts(PuzzleProgressStore.maxGauntletHearts)
                        debugStatusMessage = "体力已补满 (3/3)"
                    }
                    debugActionButton(title: "清空体力 (0❤️)", palette: .snow, isLight: true) {
                        appState.debugSetGauntletHearts(0)
                        debugStatusMessage = "体力已清空 (0/3)"
                    }
                    debugActionButton(title: "重置今日每日道场", palette: .grape) {
                        appState.debugResetTodayDailyDojo()
                        debugStatusMessage = "今日每日道场已重置"
                    }
                    debugActionButton(title: "触发护眼提醒弹窗", palette: .sky) {
                        appState.debugTriggerEyeCareAlert()
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("快速切换认证段位")
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundColor(AppTheme.inkSecondary)

                    let rankChoices: [(tier: Int, label: String)] = [
                        (0, "25K"), (3, "15K"), (4, "10K"), (5, "5K"), (6, "1D"), (8, "5D")
                    ]
                    HStack(spacing: 6) {
                        ForEach(rankChoices, id: \.tier) { choice in
                            let selected = appState.profile.certifiedRankTier == choice.tier
                            Button {
                                appState.debugSetCertifiedRankTier(choice.tier)
                                debugStatusMessage = "已切换段位至 \(choice.label)"
                            } label: {
                                Text(choice.label)
                                    .font(AppFont.rounded(size: 11, weight: .black))
                                    .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(WorkshopChoiceStyle(selected: selected, accent: AppTheme.grapeBottom))
                        }
                    }
                }

                Button {
                    SoundAndHapticsManager.shared.playUITap(weight: .light)
                    showDebugResetConfirm = true
                } label: {
                    Label("重置当前档案进度", systemImage: "arrow.counterclockwise")
                        .font(AppFont.rounded(size: 12.5, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(WorkshopCardStyle())
        .accessibilityIdentifier("SettingsDebugCard")
    }

    private func debugActionButton(
        title: String,
        palette: GlossyPalette,
        isLight: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        return Button(action: action) {
            Text(title)
                .font(AppFont.rounded(size: 11.5, weight: .black))
                .foregroundColor(isLight ? AppTheme.inkPrimary : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: palette, cornerRadius: 999, rimHeight: 2, whiteBorderWidth: 2))
    }
    #endif
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

                    WorkshopStone(style: .classicSlateShell, isBlack: false)
                        .frame(width: 25, height: 25)
                        .overlay {
                            if configuration.isOn {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .black))
                                    .foregroundColor(AppTheme.mintRim)
                            }
                        }
                        .offset(x: configuration.isOn ? 10.5 : -10.5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isButton)
            .accessibilityValue(Text(configuration.isOn ? "1" : "0"))
        }
    }
}

// MARK: - Go workshop materials and controls (settings only)

private struct WorkshopCardStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(red: 0.98, green: 0.978, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    if !reduceTransparency {
                        Canvas { context, size in
                            // Fine paper fibres stay behind the content at very low contrast.
                            var fibres = Path()
                            for row in stride(from: CGFloat(5), to: size.height, by: 6) {
                                fibres.move(to: CGPoint(x: 0, y: row))
                                fibres.addLine(to: CGPoint(x: size.width, y: row + 0.5))
                            }
                            context.stroke(fibres, with: .color(Color.brown.opacity(0.025)), lineWidth: 0.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.95), lineWidth: 2))
            .shadow(color: Color(red: 0.22, green: 0.36, blue: 0.43).opacity(0.10), radius: 12, y: 5)
    }
}

private struct WorkshopStone: View {
    var style: StoneStyle = .classicSlateShell
    var isBlack: Bool

    var body: some View {
        let palette = AppTheme.stonePalette(for: style)
        Circle()
            .fill(RadialGradient(colors: isBlack ? palette.blackColors : palette.whiteColors, center: .topLeading, startRadius: 0, endRadius: 26))
            .overlay(Circle().strokeBorder(isBlack ? .white.opacity(0.20) : .black.opacity(0.13), lineWidth: 0.7))
            .overlay(alignment: .topLeading) {
                Ellipse().fill(.white.opacity(isBlack ? 0.24 : 0.70))
                    .frame(width: 7, height: 3)
                    .rotationEffect(.degrees(-35))
                    .padding(4)
            }
            .shadow(color: .black.opacity(0.19), radius: 1.5, y: 2)
            .aspectRatio(1, contentMode: .fit)
    }
}

private struct WorkshopSelectionStone: View {
    let selected: Bool

    var body: some View {
        WorkshopStone(isBlack: selected)
            .frame(width: 18, height: 18)
            .overlay {
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .black))
                        .foregroundColor(.white)
                }
            }
            .accessibilityHidden(true)
    }
}

private struct WorkshopChoiceStyle: ButtonStyle {
    let selected: Bool
    let accent: Color
    var showsSelectionStone = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let increasedContrast = colorSchemeContrast == .increased
        let shape = RoundedRectangle(cornerRadius: 15, style: .continuous)

        // Settings choices are lit from above: the upper rim fades into the face,
        // while the lower rim carries a soft grounded shadow. This keeps the
        // controls feeling raised instead of looking carved into the white card.
        let faceColors: [Color] = selected
            ? [accent.opacity(0.82), accent]
            : [.white, Color(red: 0.945, green: 0.963, blue: 0.975)]
        let topRim = selected
            ? Color.white.opacity(increasedContrast ? 0.55 : 0.40)
            : Color(red: 0.90, green: 0.95, blue: 0.98).opacity(increasedContrast ? 0.95 : 0.72)
        let middleRim = selected
            ? accent.opacity(0.35)
            : Color(red: 0.64, green: 0.74, blue: 0.80).opacity(increasedContrast ? 0.55 : 0.28)
        let bottomRim = selected
            ? accent.opacity(0.72)
            : Color(red: 0.59, green: 0.70, blue: 0.77).opacity(increasedContrast ? 0.70 : 0.46)

        HStack(spacing: 8) {
            if showsSelectionStone {
                WorkshopSelectionStone(selected: selected)
            }
            configuration.label
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 9)
        .frame(minHeight: 44)
        .background {
            shape
                .fill(LinearGradient(colors: faceColors, startPoint: .top, endPoint: .bottom))
                .overlay {
                    if !increasedContrast {
                        shape.fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .white.opacity(pressed ? 0.12 : (selected ? 0.14 : 0.30)), location: 0),
                                    .init(color: .clear, location: 0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
        }
        .overlay {
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: topRim, location: 0),
                        .init(color: middleRim, location: 0.55),
                        .init(color: bottomRim, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: increasedContrast ? 1.5 : 1
            )
        }
        .shadow(
            color: (selected ? accent : Color(red: 0.24, green: 0.38, blue: 0.46))
                .opacity(pressed ? 0.02 : (selected ? 0.16 : 0.07)),
            radius: pressed ? 1 : 2.5,
            y: pressed ? 0 : 2
        )
        .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .onChange(of: configuration.isPressed) { _, pressed in
            if pressed { SoundAndHapticsManager.shared.playUITap(weight: .light) }
        }
    }
}

private struct WorkshopBoardPreview: View {
    let theme: BoardTheme
    let stoneStyle: StoneStyle

    var body: some View {
        let palette = AppTheme.palette(for: theme)
        GeometryReader { geometry in
            let step = min((geometry.size.width - 20) / 4, (geometry.size.height - 14) / 4)
            let origin = CGPoint(x: (geometry.size.width - step * 4) / 2, y: (geometry.size.height - step * 4) / 2)
            ZStack {
                LinearGradient(colors: [palette.boardBase, palette.boardGradientEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
                Canvas { context, _ in
                    var grid = Path()
                    for index in 0...4 {
                        let offset = CGFloat(index) * step
                        grid.move(to: CGPoint(x: origin.x + offset, y: origin.y))
                        grid.addLine(to: CGPoint(x: origin.x + offset, y: origin.y + step * 4))
                        grid.move(to: CGPoint(x: origin.x, y: origin.y + offset))
                        grid.addLine(to: CGPoint(x: origin.x + step * 4, y: origin.y + offset))
                    }
                    context.stroke(grid, with: .color(palette.gridLine.opacity(0.65)), lineWidth: 0.7)
                    context.fill(Path(ellipseIn: CGRect(x: origin.x + step * 2 - 1.8, y: origin.y + step * 2 - 1.8, width: 3.6, height: 3.6)), with: .color(palette.starPoint))
                }
                WorkshopStone(style: stoneStyle, isBlack: true)
                    .frame(width: step * 0.88, height: step * 0.88)
                    .position(x: origin.x + step, y: origin.y + step * 2)
                WorkshopStone(style: stoneStyle, isBlack: false)
                    .frame(width: step * 0.88, height: step * 0.88)
                    .position(x: origin.x + step * 2, y: origin.y + step)
                WorkshopStone(style: stoneStyle, isBlack: true)
                    .frame(width: step * 0.88, height: step * 0.88)
                    .position(x: origin.x + step * 3, y: origin.y + step * 3)
            }
        }
        .accessibilityHidden(true)
    }
}

//
//  GoCodexView.swift
//  StarYi Go — Clean, Calm 4-Tier × 36 Authentic Go Moves Codex & Spacious Live Demo Modal
//

import SwiftUI

struct GoCodexView: View {
    @EnvironmentObject var appState: AppState
    var embeddedInArchive: Bool = false

    @State private var selectedTier: CodexTier = .starter
    @State private var selectedEntry: GoCodexEntry? = nil

    private var l10n: L10n { appState.l10n }

    private var masteredCount: Int {
        GoTermCodex.allEntries.filter { appState.profile.unlockedCodexIds.contains($0.id) }.count
    }

    var body: some View {
        ZStack {
            if !embeddedInArchive {
                SceneBackdrop.termAlbum
            }

            VStack(spacing: 14) {
                if !embeddedInArchive {
                    // Clean Top Bar
                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        GameTitleCrest(
                            title: l10n.t("codex.title"),
                            subtitle: l10n.t("codex.collectedCount", masteredCount, GoTermCodex.allEntries.count)
                        )
                        Spacer()
                        HStack(spacing: 5) {
                            StarCoinBadgeView(size: 17)
                            Text("\(appState.profile.starCoins)")
                                .font(AppFont.rounded(size: 14.5, weight: .black))
                                .foregroundColor(AppTheme.inkPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.95)).shadow(color: AppTheme.sunBottom.opacity(0.14), radius: 8, y: 3))
                        .overlay(Capsule().strokeBorder(.white, lineWidth: 2))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                }

                // Crisp Single-Line Tier Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CodexTier.allCases) { tier in
                            let count = GoTermCodex.allEntries.filter { $0.tier == tier }.count
                            let done = GoTermCodex.allEntries.filter { $0.tier == tier && appState.profile.unlockedCodexIds.contains($0.id) }.count
                            tierPill(
                                title: "\(l10n.t(tier.titleKey)) \(done)/\(count)",
                                tier: tier,
                                accent: Color(hex: tier.accentHex)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 2)
                }

                // Selected tier card grid
                ScrollView(showsIndicators: false) {
                    let entries = GoTermCodex.allEntries.filter { $0.tier == selectedTier }
                    tierSection(tier: selectedTier, entries: entries)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                        .padding(.bottom, 32)
                }
            }

            // Spacious Interactive Live Demo & Practice Modal
            if let entry = selectedEntry {
                Color(red: 0.08, green: 0.14, blue: 0.26).opacity(0.50)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedEntry = nil
                        }
                    }
                    .transition(.opacity)

                CodexDetailModal(
                    entry: entry,
                    isMastered: appState.profile.unlockedCodexIds.contains(entry.id),
                    theme: appState.settings.boardTheme,
                    expressiveStones: appState.settings.expressiveStones && !appState.settings.zenDojoMode,
                    l10n: l10n,
                    onMarkLearned: {
                        appState.unlockCodexTerm(entry.id, showToast: true)
                    },
                    onPractice: {
                        selectedEntry = nil
                        launchPractice(for: entry)
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                            selectedEntry = nil
                        }
                    }
                )
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                .zIndex(30)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.80), value: selectedEntry)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func tierSection(tier: CodexTier, entries: [GoCodexEntry]) -> some View {
        let tierColor = Color(hex: tier.accentHex)
        let done = entries.filter { appState.profile.unlockedCodexIds.contains($0.id) }.count

        return VStack(alignment: .leading, spacing: 12) {
            // Subtle, well-spaced section header
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(tierColor)
                    .frame(width: 5, height: 18)

                Text(l10n.t(tier.titleKey))
                    .font(AppFont.rounded(size: 18, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                Text(l10n.t(tier.badgeKey))
                    .font(AppFont.rounded(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)

                Spacer()

                Text("\(done)/\(entries.count) ★")
                    .font(AppFont.rounded(size: 12, weight: .heavy))
                    .foregroundColor(tierColor)
            }
            .padding(.horizontal, 4)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 240, maximum: 330), spacing: 16)],
                spacing: 16
            ) {
                ForEach(entries) { entry in
                    codexCard(entry)
                }
            }
        }
    }

    private func tierPill(title: String, tier: CodexTier, accent: Color) -> some View {
        let active = selectedTier == tier
        return Button {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.78)) {
                selectedTier = tier
            }
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            Text(title)
                .font(AppFont.rounded(size: 12.5, weight: .black))
                .foregroundColor(active ? .white : AppTheme.inkPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(active ? accent : Color.white.opacity(0.92))
                )
                .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
        }
        .tactileButton(scale: 0.95, sound: false)
    }

    /// Splits an optional parenthetical note like "真眼与假眼（两眼活棋）" or "Sealing the Escape (Turtle Shell)"
    /// into a crisp single-line main title and a compact secondary note for uniform grid cards.
    private func splitCardTitle(_ raw: String) -> (main: String, note: String?) {
        if let open = raw.firstIndex(of: "（"), let close = raw.lastIndex(of: "）"), open < close {
            let main = String(raw[..<open]).trimmingCharacters(in: .whitespaces)
            let note = String(raw[raw.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            if !main.isEmpty { return (main, note.isEmpty ? nil : note) }
        }
        if let open = raw.firstIndex(of: "("), let close = raw.lastIndex(of: ")"), open < close {
            let main = String(raw[..<open]).trimmingCharacters(in: .whitespaces)
            let note = String(raw[raw.index(after: open)..<close]).trimmingCharacters(in: .whitespaces)
            if !main.isEmpty { return (main, note.isEmpty ? nil : note) }
        }
        return (raw, nil)
    }

    /// Clean, uncluttered card: uniform height across all 36 entries & 5 languages; tapping opens the live demo modal.
    private func codexCard(_ entry: GoCodexEntry) -> some View {
        let mastered = appState.profile.unlockedCodexIds.contains(entry.id)
        let accent = Color(hex: entry.accentHex)
        let titleParts = splitCardTitle(entry.term(l10n))

        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.80)) {
                selectedEntry = entry
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: entry.symbolName)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(accent))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(titleParts.main)
                            .font(AppFont.rounded(size: 16, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        HStack(spacing: 6) {
                            Text(entry.rankTag)
                                .font(AppFont.rounded(size: 10.5, weight: .black))
                                .foregroundColor(accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(accent.opacity(0.12)))
                                .fixedSize()

                            if let note = titleParts.note {
                                Text(note)
                                    .font(AppFont.rounded(size: 11, weight: .bold))
                                    .foregroundColor(AppTheme.inkSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }

                            if mastered {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                                    .foregroundStyle(
                                        LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)
                                    )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Row 2: Crisp 2-line metaphor summary with breathing space
                Text(entry.metaphor(l10n))
                    .font(AppFont.rounded(size: 12.5, weight: .semibold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineSpacing(2.5)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, minHeight: 122, maxHeight: 122, alignment: .topLeading)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: .snow,
                cornerRadius: 24,
                rimHeight: 2.5,
                whiteBorderWidth: 2.5,
                pressStyle: .card
            )
        )
    }

    private func launchPractice(for entry: GoCodexEntry) {
        appState.navigationPath.append(
            .puzzlePlay(
                puzzleId: entry.practicePuzzleId,
                isDailyChallenge: false,
                isStarterBootcamp: false,
                forceRandomTransform: true
            )
        )
    }
}

// MARK: - Spacious Enlarged Live Demo Modal

private struct CodexDetailModal: View {
    let entry: GoCodexEntry
    let isMastered: Bool
    let theme: BoardTheme
    let expressiveStones: Bool
    let l10n: L10n
    let onMarkLearned: () -> Void
    let onPractice: () -> Void
    let onClose: () -> Void

    @State private var states: [GoBoardState] = []
    @State private var step: Int = 0
    @State private var isPlaying: Bool = true
    @State private var playTask: Task<Void, Never>?

    private var currentState: GoBoardState {
        guard !states.isEmpty else { return GoBoardState(size: entry.demoBoardSize) }
        return states[min(max(0, step), states.count - 1)]
    }

    var body: some View {
        GeometryReader { geo in
            let isCompact = geo.size.width < 700
            let modalW = isCompact ? geo.size.width : min(geo.size.width - 24, 1040)
            let modalH = isCompact ? (geo.size.height - 16) : min(geo.size.height - 24, 650)
            let landscapeBoardSide = min(460, max(320, min(modalH - 128, modalW * 0.46)))
            let compactBoardSide = min(360, max(250, geo.size.width - 56))

            Group {
                if isCompact {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            detailHeader
                            demoBoardColumn(size: compactBoardSide)
                            detailTextAndActions
                        }
                        .padding(20)
                    }
                } else {
                    HStack(alignment: .center, spacing: 28) {
                        demoBoardColumn(size: landscapeBoardSide)

                        VStack(alignment: .leading, spacing: 16) {
                            detailHeader
                            ScrollView(showsIndicators: false) {
                                detailTextBody
                            }
                            actionButtonsRow
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                    .padding(28)
                }
            }
            .frame(width: modalW, height: modalH)
            .warmCard(cornerRadius: 36, padding: 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            loadDemoStates()
            startAutoLoop()
        }
        .onDisappear {
            playTask?.cancel()
        }
    }

    private func demoBoardColumn(size: CGFloat) -> some View {
        VStack(spacing: 14) {
            GoBoardView(
                boardState: currentState,
                theme: theme,
                cropRegion: entry.demoCrop,
                showCoordinates: false,
                showMoveNumbers: false,
                highlightAtari: true,
                expressiveStones: expressiveStones,
                showLiveLiberties: true,
                showTwoEyeGlow: true,
                isInteractive: false,
                libertyBadgeFormat: l10n.t("game.libertiesBadge"),
                koBadgeLabel: l10n.t("board.koBadge")
            )
            .frame(width: size, height: size)

            HStack(spacing: 12) {
                GameCircleButton(icon: "backward.end.fill", palette: .snow, tint: AppTheme.inkPrimary, size: 42) {
                    isPlaying = false
                    step = 0
                }
                GameCircleButton(icon: "chevron.left", palette: .snow, tint: AppTheme.inkPrimary, size: 42) {
                    isPlaying = false
                    if !states.isEmpty {
                        step = max(0, step - 1)
                    }
                }
                GameCircleButton(icon: isPlaying ? "pause.fill" : "play.fill", palette: .sky, tint: .white, size: 48) {
                    isPlaying.toggle()
                    if isPlaying { startAutoLoop() }
                }
                GameCircleButton(icon: "chevron.right", palette: .snow, tint: AppTheme.inkPrimary, size: 42) {
                    isPlaying = false
                    if !states.isEmpty {
                        step = (step + 1) % states.count
                    }
                }
                if states.count > 1 {
                    Text("\(step) / \(states.count - 1)")
                        .font(AppFont.rounded(size: 13.5, weight: .black))
                        .foregroundColor(AppTheme.inkSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.canvasBackground))
                }
            }
        }
    }

    private var detailHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: entry.symbolName)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    Circle()
                        .fill(Color(hex: entry.accentHex))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.term(l10n))
                    .font(AppFont.rounded(size: 24, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(entry.rankTag)
                    .font(AppFont.rounded(size: 12, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color(hex: entry.accentHex)))

                Text("\(l10n.t(entry.tier.titleKey)) · \(l10n.t(entry.tier.badgeKey))")
                    .font(AppFont.rounded(size: 13, weight: .bold))
                    .foregroundColor(AppTheme.skyBottom)
                    .lineLimit(1)
            }

            Spacer()

            GameCircleButton(icon: "xmark", palette: .snow, tint: AppTheme.inkSecondary, size: 44) {
                onClose()
            }
        }
    }

    private var detailTextBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.t("codex.metaphorHeader"))
                    .font(AppFont.rounded(size: 12.5, weight: .black))
                    .foregroundColor(AppTheme.sunBottom)
                Text(entry.metaphor(l10n))
                    .font(AppFont.rounded(size: 16.5, weight: .heavy))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.softGoldBg))

            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.t("codex.ruleHeader"))
                    .font(AppFont.rounded(size: 12.5, weight: .black))
                    .foregroundColor(AppTheme.skyBottom)
                Text(entry.explanation(l10n))
                    .font(AppFont.rounded(size: 15, weight: .semibold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.canvasBackground))
        }
    }

    private var actionButtonsRow: some View {
        HStack(spacing: 12) {
            if isMastered {
                Label(l10n.t("codex.masteredStamped"), systemImage: "checkmark.seal.fill")
                    .font(AppFont.rounded(size: 14.5, weight: .black))
                    .foregroundColor(AppTheme.sunBottom)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Capsule().fill(AppTheme.softGoldBg))
            } else {
                Button(action: onMarkLearned) {
                    Label(l10n.t("codex.stampLearned"), systemImage: "star.circle.fill")
                        .font(AppFont.rounded(size: 14.5, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
            }

            Button(action: onPractice) {
                Label(practiceButtonLabel, systemImage: "play.fill")
                    .font(AppFont.rounded(size: 15.5, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
        }
    }

    private var detailTextAndActions: some View {
        VStack(alignment: .leading, spacing: 14) {
            detailTextBody
            actionButtonsRow
        }
    }

    private var practiceButtonLabel: String {
        l10n.t("codex.practiceMove")
    }

    private func loadDemoStates() {
        var initial = GoBoardState(size: entry.demoBoardSize, komi: 0)
        var built: [GoBoardState] = []
        if let root = SGFParser.parse(entry.demoSGF) {
            for pt in root.addedBlackPoints { initial.setSetupStone(.black, at: pt) }
            for pt in root.addedWhitePoints { initial.setSetupStone(.white, at: pt) }
            initial.resetPositionHistoryToCurrent()
            built.append(initial)

            var cur = initial
            var node = root.children.first
            while let n = node {
                if let mv = n.move, case .success(let out) = cur.applying(action: mv.action, color: mv.color) {
                    cur = out.nextState
                    built.append(cur)
                }
                node = n.children.first
            }
        } else {
            built = [initial]
        }
        states = built
        step = 0
    }

    private func startAutoLoop() {
        playTask?.cancel()
        playTask = Task {
            while !Task.isCancelled && isPlaying {
                try? await Task.sleep(nanoseconds: 1_150_000_000)
                guard !Task.isCancelled && isPlaying else { break }
                await MainActor.run {
                    if states.count > 1 {
                        step = (step + 1) % states.count
                    }
                }
            }
        }
    }
}

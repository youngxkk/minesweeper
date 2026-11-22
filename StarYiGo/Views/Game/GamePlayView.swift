//
//  GamePlayView.swift
//  StarYi Go — Modern Glossy Nintendo Switch Party Game Arena
//

import SwiftUI

struct GamePlayView: View {
    @EnvironmentObject var appState: AppState
    @ObservedObject var viewModel: GameViewModel

    @State private var showResignConfirm = false
    @State private var showNewGameConfirm = false
    @State private var showResultOverlay = false
    @State private var quickTermPopover: GoCodexEntry? = nil

    private var l10n: L10n { appState.l10n }
    private let topBarHeight: CGFloat = 58

    private var humanDidWin: Bool {
        guard let result = viewModel.gameResult else { return false }
        if let hc = viewModel.humanColor { return result.winner == hc }
        return true
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = w < 700 ? 12 : 20

                Group {
                    if viewModel.isTwoPlayer && viewModel.isTabletopFaceToFace {
                        tabletopTwoPlayerLayout(w: w, h: h, pad: pad)
                    } else if w < 700 {
                        compactPortraitArena(w: w, h: h, pad: pad)
                    } else {
                        standardLandscapeArena(w: w, h: h, pad: pad)
                    }
                }
                .frame(width: w, height: h)
            }

            // Tap-to-Explain Authentic Go Term Quick Popover (e.g. Komi / Atari / Ko)
            if let term = quickTermPopover {
                Color(red: 0.08, green: 0.14, blue: 0.26).opacity(0.38)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { quickTermPopover = nil }
                    }
                    .transition(.opacity)

                GoTermQuickCard(
                    entry: term,
                    l10n: l10n,
                    onOpenCodex: {
                        quickTermPopover = nil
                        appState.navigationPath.append(.codex)
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { quickTermPopover = nil }
                    }
                )
                .padding(24)
                .transition(.scale(scale: 0.90).combined(with: .opacity))
                .zIndex(25)
            }

            if showResultOverlay, let result = viewModel.gameResult {
                Color(red: 0.08, green: 0.14, blue: 0.26).opacity(0.45)
                    .ignoresSafeArea()
                    .transition(.opacity)

                if humanDidWin {
                    ConfettiBurstView()
                        .ignoresSafeArea()
                        .zIndex(28)
                }

                GameResultOverlayCard(
                    result: result,
                    isBossVictory: viewModel.bossIslandId != nil && humanDidWin,
                    bestMove: viewModel.bestMoveNumber,
                    turningPoint: viewModel.turningPointMoveNumber,
                    l10n: l10n,
                    onRewind: { moveNum in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                            showResultOverlay = false
                        }
                        viewModel.rewindToMove(moveNum)
                    },
                    onPlayAgain: {
                        withAnimation { showResultOverlay = false }
                        viewModel.restartMatch()
                    },
                    onReview: {
                        withAnimation { showResultOverlay = false }
                        if let recId = viewModel.savedRecordId {
                            appState.navigationPath.append(.reviewGame(recordId: recId))
                        }
                    },
                    onBackHome: {
                        withAnimation { showResultOverlay = false }
                        appState.popToHome()
                    }
                )
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .zIndex(30)
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: showResultOverlay)
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: quickTermPopover)
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: viewModel.gameResult) { _, newValue in
            if newValue != nil {
                showResultOverlay = true
            }
        }
        .alert(l10n.t("game.confirm.resignTitle"), isPresented: $showResignConfirm) {
            Button(l10n.t("game.action.resign"), role: .destructive) {
                viewModel.resignCurrentPlayer()
            }
            Button(l10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(l10n.t("game.confirm.resignMessage"))
        }
        .alert(l10n.t("game.confirm.newGameTitle"), isPresented: $showNewGameConfirm) {
            Button(l10n.t("game.action.newGame"), role: .destructive) {
                viewModel.restartMatch()
            }
            Button(l10n.t("common.cancel"), role: .cancel) {}
        } message: {
            Text(l10n.t("game.confirm.newGameMessage"))
        }
        .alert(
            l10n.bilingual(zh: "发现未封口的边界！", en: "Unsealed Boundaries Detected!"),
            isPresented: $viewModel.showUnsealedScoreAlert
        ) {
            Button(l10n.bilingual(zh: "回去补边界", en: "Seal First"), role: .cancel) {}
            Button(l10n.bilingual(zh: "仍要直接数子", en: "Score Anyway")) {
                viewModel.beginDeadStoneReview(bypassUnsealedWarning: true)
            }
        } message: {
            let count = viewModel.endgameReadiness?.warningCount ?? 0
            Text(l10n.bilingual(
                zh: "棋盘上还有 \(count) 处边界未封口（已用红圈标出）。如果边界漏风，这片地盘可能算不成你的空哦！",
                en: "There are \(count) unsealed border spot(s) marked in red. Unsealed territory won't count cleanly!"
            ))
        }
    }

    // MARK: - Standard Landscape Arena (Immutable Board Left + Glossy Controls Right)

    private func standardLandscapeArena(w: CGFloat, h: CGFloat, pad: CGFloat) -> some View {
        let sidebarWidth = min(380, max(324, w * 0.31))
        let boardMaxW = max(260, w - sidebarWidth - pad * 3)
        let contentHeight = max(0, h - topBarHeight - 36)
        let boardSide = min(boardMaxW, contentHeight)

        return VStack(spacing: 12) {
            gameTopBar
                .frame(height: topBarHeight)

            HStack(spacing: pad) {
                boardView
                    .frame(width: boardSide, height: boardSide)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Group {
                    if h < 600 {
                        ScrollView(showsIndicators: false) {
                            rightControlPanel
                        }
                    } else {
                        rightControlPanel
                    }
                }
                .frame(width: sidebarWidth)
            }
            .frame(height: contentHeight)
        }
        .padding(.horizontal, pad)
        .padding(.vertical, 12)
    }

    // MARK: - Responsive Compact Portrait Arena (iPhone Support!)

    private func compactPortraitArena(w: CGFloat, h: CGFloat, pad: CGFloat) -> some View {
        let boardSide = max(0, min(w - pad * 2, h * 0.50))

        return VStack(spacing: 10) {
            gameTopBar
                .frame(height: 50)

            if boardSide > 0 {
                boardView
                    .frame(width: boardSide, height: boardSide)
            }

            ScrollView(showsIndicators: false) {
                rightControlPanel
            }
        }
        .padding(.horizontal, pad)
        .padding(.vertical, 8)
    }

    // MARK: - Two-Player Tabletop Face-to-Face Mode (with Parent-Child Kid Assist!)

    private func tabletopTwoPlayerLayout(w: CGFloat, h: CGFloat, pad: CGFloat) -> some View {
        let wingWidth: CGFloat = 216
        let boardSide = max(260, min(w - wingWidth * 2 - pad * 4, h - pad * 2))

        return HStack(spacing: pad) {
            tabletopPlayerWing(color: .white, rotation: .degrees(90))
                .frame(width: wingWidth)

            boardView
                .frame(width: boardSide, height: boardSide)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabletopPlayerWing(color: .black, rotation: .degrees(-90))
                .frame(width: wingWidth)
        }
        .padding(pad)
        .overlay(alignment: .topLeading) {
            GameBackButton(title: l10n.t("common.back")) {
                appState.popRoute()
            }
            .padding(16)
        }
        .overlay(alignment: .topTrailing) {
            GameCircleButton(icon: "rectangle.portrait.rotate", palette: .mint, tint: .white) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isTabletopFaceToFace.toggle()
                }
            }
            .padding(16)
        }
    }

    private func tabletopPlayerWing(color: StoneColor, rotation: Angle) -> some View {
        let isTurn = !viewModel.isGameOver && viewModel.boardState.currentTurn == color
        let captures = color == .black ? viewModel.boardState.blackCaptures : viewModel.boardState.whiteCaptures
        let hasKidAssist = viewModel.tabletopKidAssistColor == color

        return VStack(spacing: 11) {
            WoodenGoBowlView(capturedColor: color.opposite, count: captures)
                .scaleEffect(1.18)

            Text(l10n.t(color == .black ? "stone.black" : "stone.white"))
                .font(.system(size: 19, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

            if let target = viewModel.ruleSet.captureTarget {
                Text("\(l10n.t("game.captureGoalBadge", captures, target))")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.coralBottom)
            }

            Text(isTurn ? l10n.t(color == .black ? "game.turn.black" : "game.turn.white") : l10n.t("game.moveCount", viewModel.moves.count))
                .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                .foregroundColor(isTurn ? .white : AppTheme.inkSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        isTurn
                        ? AnyShapeStyle(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom))
                        : AnyShapeStyle(AppTheme.canvasBackground)
                    )
                )

            HStack(spacing: 8) {
                GameCircleButton(icon: "arrow.uturn.backward", palette: .snow, tint: AppTheme.inkPrimary, size: 42, playTapSound: false) {
                    viewModel.undo()
                }
                .disabled(viewModel.moves.isEmpty)

                if hasKidAssist {
                    GameCircleButton(icon: "lightbulb.fill", palette: .sun, tint: .white, size: 42) {
                        viewModel.requestHint()
                    }
                    .disabled(!isTurn)
                }

                GameCircleButton(icon: "hand.raised.fill", palette: .snow, tint: AppTheme.inkPrimary, size: 42) {
                    viewModel.passTurn()
                }
                .disabled(!isTurn)
            }

            // Parent-Child Asymmetric Assist toggle
            Button {
                viewModel.tabletopKidAssistColor = hasKidAssist ? nil : color
                SoundAndHapticsManager.shared.playUITap()
            } label: {
                Label(l10n.t("game.tabletop.kidAssist"), systemImage: hasKidAssist ? "sparkles" : "sparkle")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(hasKidAssist ? .white : AppTheme.sunBottom)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(hasKidAssist ? AppTheme.sunBottom : AppTheme.softGoldBg))
            }
            .tactileButton(scale: 0.94, sound: false)
        }
        .padding(14)
        .warmCard(cornerRadius: 28, padding: 12)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(isTurn ? AppTheme.skyTop : Color.clear, lineWidth: 3.5)
        )
        .rotationEffect(rotation)
    }

    // MARK: - Glossy Top Bar (with Tappable Komi Term Explainer!)

    private var gameTopBar: some View {
        HStack(spacing: 12) {
            GameBackButton(title: l10n.t("common.back")) {
                appState.popRoute()
            }

            Spacer()

            Button {
                let termId = viewModel.ruleSet.isCaptureRace ? "capture" : "komi"
                if let entry = GoTermCodex.entry(withId: termId) {
                    SoundAndHapticsManager.shared.playUITap()
                    withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                        quickTermPopover = entry
                    }
                }
            } label: {
                GameTitleCrest(
                    title: headerTitle,
                    subtitle: headerSubtitle
                )
            }
            .tactileButton(scale: 0.96, sound: false)
            .accessibilityIdentifier("GameStatusButton")

            Spacer()

            HStack(spacing: 10) {
                if viewModel.isTwoPlayer {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isTabletopFaceToFace.toggle()
                        }
                    } label: {
                        Label(l10n.t("game.action.tabletop"), systemImage: "rectangle.portrait.rotate")
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }

                Menu {
                    Button {
                        showNewGameConfirm = true
                    } label: {
                        Label(l10n.t("game.action.newGame"), systemImage: "arrow.clockwise")
                    }
                    if !viewModel.isTwoPlayer {
                        Button {
                            viewModel.isCoopMode.toggle()
                            SoundAndHapticsManager.shared.playUITap()
                        } label: {
                            Label(
                                l10n.t("game.action.coopToggle"),
                                systemImage: viewModel.isCoopMode ? "checkmark.circle.fill" : "person.2.fill"
                            )
                        }
                    }
                    if !viewModel.isGameOver {
                        Button(role: .destructive) {
                            showResignConfirm = true
                        } label: {
                            Label(l10n.t("game.action.resign"), systemImage: "flag.fill")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(width: 46, height: 46)
                        .background(
                            ZStack {
                                Circle().fill(GlossyPalette.snow.rim).overlay(Circle().strokeBorder(.white, lineWidth: 3)).offset(y: 5)
                                Circle()
                                    .fill(LinearGradient(colors: [GlossyPalette.snow.top, GlossyPalette.snow.bottom], startPoint: .top, endPoint: .bottom))
                                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                            }
                        )
                        .padding(.bottom, 5)
                }
                .accessibilityIdentifier("GameActionsMenu")

                GameCircleButton(icon: "gearshape.fill", palette: .snow, tint: AppTheme.inkPrimary, size: 46) {
                    appState.showSettingsSheet = true
                }
            }
        }
    }

    private var headerTitle: String {
        switch viewModel.mode {
        case .twoPlayer:
            return "\(l10n.t("game.title.twoPlayer")) · \(l10n.t(viewModel.boardSize.localizationKey))"
        case .vsAI(let diff, _):
            let bossPrefix = viewModel.bossIslandId != nil ? "👑 " : ""
            return "\(bossPrefix)\(l10n.t("game.title.vsAI", l10n.t(diff.nameKey))) (\(diff.rankBadge)) · \(l10n.t(viewModel.boardSize.localizationKey))"
        }
    }

    private var headerSubtitle: String {
        if let target = viewModel.ruleSet.captureTarget {
            return "\(l10n.t("game.moveCount", viewModel.moves.count)) · \(l10n.t("rule.captureShort", target))"
        }
        return "\(l10n.t("game.moveCount", viewModel.moves.count)) · \(l10n.t("game.komi", viewModel.boardState.komi)) ⓘ"
    }

    // MARK: - Immutable Go Board

    private var shouldShowLiveLiberties: Bool {
        if appState.settings.zenDojoMode || viewModel.isExamMatch { return false }
        if viewModel.isTwoPlayer && viewModel.isTabletopFaceToFace {
            return viewModel.tabletopKidAssistColor == viewModel.boardState.currentTurn
        }
        return appState.settings.showLiveLiberties && (viewModel.boardSize.rawValue <= 9 || viewModel.ruleSet.isCaptureRace)
    }

    private var boardView: some View {
        GoBoardView(
            boardState: viewModel.boardState,
            theme: appState.settings.boardTheme,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: appState.settings.showMoveNumbers,
            moveNumbers: viewModel.moveNumberLookup,
            highlightAtari: appState.settings.highlightAtari && !viewModel.isExamMatch,
            expressiveStones: appState.settings.expressiveStones && !appState.settings.zenDojoMode && !viewModel.isExamMatch,
            showLiveLiberties: shouldShowLiveLiberties,
            showTwoEyeGlow: !appState.settings.zenDojoMode && !viewModel.isExamMatch,
            markedDeadIndices: viewModel.markedDeadIndices,
            isDeadStoneReviewMode: viewModel.isMarkingDeadStones,
            territoryEstimate: viewModel.showTerritoryOverlay ? viewModel.territoryEstimate : nil,
            aiSuggestions: viewModel.suggestions,
            unsealedWarningPoints: viewModel.unsealedWarningPoints,
            highlightedPocketPoints: viewModel.highlightedPocketPoints,
            pendingPoint: viewModel.pendingPoint,
            previewColor: viewModel.boardState.currentTurn,
            isInteractive: (viewModel.isHumansTurn && !viewModel.isAIThinking && !viewModel.isGameOver) || viewModel.isMarkingDeadStones,
            capturedFlashPoints: viewModel.lastCapturedPoints,
            captureEventID: viewModel.captureEventID,
            illegalFlashPoint: viewModel.illegalFlashPoint,
            illegalEventID: viewModel.illegalEventID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
            onSelectPoint: { point in
                viewModel.handleBoardTap(at: point)
            }
        )
    }

    // MARK: - Glossy Right Control Panel

    private var rightControlPanel: some View {
        VStack(spacing: 12) {
            if let diff = viewModel.aiDifficulty, !appState.settings.zenDojoMode {
                companionCard(difficulty: diff)
            }

            // Co-op Pair Go Seat Indicator (when playing Parent + Child together!)
            if viewModel.isCoopMode && !viewModel.isGameOver {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppTheme.mintBottom))
                    Text(l10n.t(viewModel.coopTurnSeat == 1 ? "game.coop.kidTurn" : "game.coop.parentTurn"))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.mintBottom)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.mintTop.opacity(0.16)))
            }

            // Capture Race Trophy Bar (when playing 吃子棋!)
            if let target = viewModel.ruleSet.captureTarget {
                captureRaceBanner(target: target)
            }

            // Players & Bowls Card
            VStack(spacing: 10) {
                playerBowlRow(color: .black)
                Divider()
                playerBowlRow(color: .white)
            }
            .warmCard(cornerRadius: 24, padding: 14)

            // Fixed-height Status & Territory Card
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    if viewModel.isAIThinking {
                        ProgressView().scaleEffect(0.82)
                    } else {
                        Circle()
                            .fill(viewModel.boardState.currentTurn == .black ? Color(white: 0.14) : Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                    }

                    Text(primaryStatusLine)
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(isAlertStatus ? AppTheme.coralBottom : AppTheme.inkPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: 32, alignment: .leading)

                if viewModel.showTerritoryOverlay, let est = viewModel.territoryEstimate {
                    territoryBarContent(est: est)
                        .transition(.opacity)
                } else {
                    Text(l10n.t("game.libertiesTip"))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                        .frame(height: 26, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 22, padding: 14)
            .animation(.easeInOut(duration: 0.18), value: viewModel.showTerritoryOverlay)

            Spacer(minLength: 2)

            if viewModel.isMarkingDeadStones {
                deadStoneConfirmationDock
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else {
                // Fixed-height Confirm Placement Slot
                ZStack {
                    if let pending = viewModel.pendingPoint {
                        confirmPlacementBar(for: pending)
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 56)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: viewModel.pendingPoint)

                // Glossy Candy-Capsule Controls Grid
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        glossyActionTile(
                            title: l10n.t("game.action.undo"),
                            icon: "arrow.uturn.backward",
                            palette: .snow,
                            tint: AppTheme.inkPrimary,
                            disabled: !viewModel.isUndoAllowed || viewModel.moves.isEmpty || viewModel.isAIThinking || viewModel.isGameOver,
                            playSound: false
                        ) {
                            viewModel.undo()
                        }

                        glossyActionTile(
                            title: l10n.t("game.action.hint"),
                            icon: viewModel.isComputingHint ? "hourglass" : "lightbulb.fill",
                            palette: .sun,
                            tint: .white,
                            disabled: viewModel.isExamMatch || !viewModel.isHumansTurn || viewModel.isAIThinking || viewModel.isGameOver
                        ) {
                            viewModel.requestHint()
                        }
                    }

                    HStack(spacing: 10) {
                        glossyActionTile(
                            title: l10n.t("game.action.territory"),
                            icon: "square.grid.3x3.topleft.filled",
                            palette: viewModel.showTerritoryOverlay ? .sky : .snow,
                            tint: viewModel.showTerritoryOverlay ? .white : AppTheme.skyBottom,
                            disabled: viewModel.ruleSet.isCaptureRace
                        ) {
                            viewModel.toggleTerritory()
                        }

                        glossyActionTile(
                            title: l10n.t("game.action.pass"),
                            icon: "hand.raised.fill",
                            palette: .snow,
                            tint: AppTheme.inkPrimary,
                            disabled: !viewModel.isHumansTurn || viewModel.isAIThinking || viewModel.isGameOver
                        ) {
                            viewModel.passTurn()
                        }
                    }

                    Button {
                        viewModel.beginDeadStoneReview()
                    } label: {
                        Label(l10n.t("game.action.score"), systemImage: "flag.checkered")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                    .disabled(viewModel.isGameOver || viewModel.moves.count < 2)
                    .opacity(viewModel.isGameOver || viewModel.moves.count < 2 ? 0.42 : 1)
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: viewModel.isMarkingDeadStones)
    }

    private func captureRaceBanner(target: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .black))
                .foregroundColor(AppTheme.sunBottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("rule.captureRace", target))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                HStack(spacing: 12) {
                    Text("⚫️ \(viewModel.boardState.blackCaptures)/\(target)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text("⚪️ \(viewModel.boardState.whiteCaptures)/\(target)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.softGoldBg)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white, lineWidth: 2))
        )
    }

    private var deadStoneConfirmationDock: some View {
        let isZh = l10n.language.isChinese
        return VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(AppTheme.coralBottom)
                Text(l10n.t("game.deadStones.hint"))
                    .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Chinese Area vs Japanese Territory rule toggle + visual pocket count button
            HStack(spacing: 6) {
                ForEach(ScoringRule.allCases) { rule in
                    let selected = viewModel.scoringRule == rule
                    Button {
                        viewModel.switchScoringRule(rule)
                    } label: {
                        Text(rule == .chinese ? (isZh ? "中国数子法" : "Chinese Area") : (isZh ? "日韩数目法" : "Japanese Terr."))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(selected ? .white : AppTheme.inkSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule().fill(
                                    selected
                                    ? AnyShapeStyle(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(AppTheme.canvasBackground)
                                )
                            )
                    }
                    .tactileButton(scale: 0.94, sound: false)
                }

                Spacer()

                Button {
                    viewModel.runVisualPocketCountingDemo()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .black))
                        Text(viewModel.activeCountingPocketLabel ?? (isZh ? "逐块点地" : "Animate"))
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                    }
                    .foregroundColor(AppTheme.sunBottom)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(AppTheme.softGoldBg))
                }
                .tactileButton(scale: 0.94, sound: false)
            }

            if let preview = viewModel.deadStonePreviewResult {
                VStack(spacing: 4) {
                    HStack {
                        Text("⚫️ \(String(format: "%.1f", preview.blackScore))")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Spacer()
                        Text(l10n.t(preview.winner == .black ? "result.blackWins" : "result.whiteWins"))
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.skyBottom)
                        Spacer()
                        Text("⚪️ \(String(format: "%.1f", preview.whiteScore))")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                    }

                    Text(
                        preview.scoringRule == .chinese
                        ? preview.chineseRuleSummary(isChinese: isZh)
                        : preview.japaneseRuleSummary(isChinese: isZh)
                    )
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                    if preview.sekiGroupCount > 0 {
                        Text(isZh ? "🤝 检测到 \(preview.sekiGroupCount) 处双活（自动保护存活）" : "🤝 \(preview.sekiGroupCount) Seki group(s) protected as alive")
                            .font(.system(size: 10.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.mintBottom)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.canvasBackground))
            }

            HStack(spacing: 8) {
                Button {
                    viewModel.playOutDispute()
                } label: {
                    Text(isZh ? "续下验死活" : "Play Dispute")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button {
                    viewModel.confirmDeadStoneScore()
                } label: {
                    Label(l10n.t("game.deadStones.confirm"), systemImage: "checkmark.circle.fill")
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
        }
        .padding(14)
        .warmCard(cornerRadius: 24, padding: 0)
    }

    private func companionCard(difficulty: AIDifficulty) -> some View {
        let moodBadge: String = {
            switch viewModel.companionMood {
            case .greeting: return "👋"
            case .thinking: return "💭"
            case .surprised: return "💦"
            case .excited: return "✨"
            case .playful: return "😏"
            case .calm: return "🍵"
            case .cheering: return "🎉"
            }
        }()

        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CharacterAvatarView(character: difficulty, mood: viewModel.companionMood, size: 50)
                Text(moodBadge)
                    .font(.system(size: 14))
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(l10n.t(difficulty.nameKey)) · \(difficulty.rankBadge)")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.skyBottom)
                Text(viewModel.companionDialogueText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(height: 70)
        .warmCard(cornerRadius: 24, padding: 0)
    }

    private func playerBowlRow(color: StoneColor) -> some View {
        let isActiveTurn = !viewModel.isGameOver && !viewModel.isMarkingDeadStones && viewModel.boardState.currentTurn == color
        let captures = color == .black ? viewModel.boardState.blackCaptures : viewModel.boardState.whiteCaptures
        let name: String = {
            switch viewModel.mode {
            case .twoPlayer:
                return l10n.t(color == .black ? "stone.black" : "stone.white")
            case .vsAI(let diff, let humanColor):
                return color == humanColor ? appState.profile.nickname : l10n.t(diff.nameKey)
            }
        }()

        return HStack(spacing: 12) {
            Circle()
                .fill(color == .black ? Color(white: 0.14) : Color.white)
                .frame(width: 28, height: 28)
                .overlay(Circle().stroke(isActiveTurn ? AppTheme.skyTop : Color.black.opacity(0.20), lineWidth: isActiveTurn ? 3.5 : 1.2))
                .shadow(color: isActiveTurn ? AppTheme.skyTop.opacity(0.45) : .clear, radius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(1)
                Text("\(l10n.t("game.captures")): \(captures)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
            }

            Spacer()

            if viewModel.clock.isActive {
                let pClock = viewModel.clock.state(for: color)
                HStack(spacing: 4) {
                    Image(systemName: pClock.inByoyomi ? "timer" : "clock.fill")
                        .font(.system(size: 10, weight: .black))
                    Text(pClock.formattedDisplay)
                        .font(.system(size: 12.5, weight: .black, design: .monospaced))
                }
                .foregroundColor(pClock.isUrgentCountdown ? .white : (isActiveTurn ? AppTheme.skyBottom : AppTheme.inkSecondary))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(
                        pClock.isUrgentCountdown
                        ? AnyShapeStyle(AppTheme.coralBottom)
                        : AnyShapeStyle(isActiveTurn ? AppTheme.skyTop.opacity(0.16) : AppTheme.canvasBackground)
                    )
                )
            }

            WoodenGoBowlView(capturedColor: color.opposite, count: captures)
        }
    }

    private func confirmPlacementBar(for pending: BoardPoint) -> some View {
        HStack(spacing: 8) {
            Text(pending.humanLabel(boardSize: viewModel.boardState.size))
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundColor(AppTheme.skyBottom)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(AppTheme.skyTop.opacity(0.16)))

            Button {
                viewModel.cancelPendingPlacement()
            } label: {
                Text(l10n.t("game.action.cancelPlace"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5, playTapSound: false))

            Button {
                viewModel.confirmPendingPlacement()
            } label: {
                Label(l10n.t("game.action.confirmPlace"), systemImage: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false))
        }
    }

    private func glossyActionTile(
        title: String,
        icon: String,
        palette: GlossyPalette,
        tint: Color,
        disabled: Bool,
        playSound: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .black))
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, minHeight: 48)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: palette,
                cornerRadius: 999,
                rimHeight: 5,
                whiteBorderWidth: 3,
                playTapSound: playSound
            )
        )
        .disabled(disabled)
        .opacity(disabled ? 0.42 : 1.0)
    }

    private var isAlertStatus: Bool {
        if viewModel.statusBanner != nil && viewModel.suggestions.isEmpty { return true }
        return appState.settings.highlightAtari && !viewModel.boardState.atariPoints().isEmpty && !viewModel.isGameOver && !viewModel.isAIThinking
    }

    private var primaryStatusLine: String {
        if viewModel.isMarkingDeadStones { return l10n.t("game.deadStones.title") }
        if let banner = viewModel.statusBanner { return banner }
        if viewModel.isAIThinking, let diff = viewModel.aiDifficulty {
            return l10n.t("game.turn.aiThinking", l10n.t(diff.nameKey))
        }
        if appState.settings.highlightAtari && !viewModel.boardState.atariPoints().isEmpty && !viewModel.isGameOver {
            return l10n.t("game.status.atariWarning")
        }
        return l10n.t(viewModel.boardState.currentTurn == .black ? "game.turn.black" : "game.turn.white")
    }

    private func territoryBarContent(est: TerritoryEstimate) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(l10n.t("stone.black")): \(String(format: "%.1f", est.blackTotal))")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                Spacer()
                Text("\(l10n.t("stone.white")): \(String(format: "%.1f", est.whiteTotal))")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
            }
            GeometryReader { barGeo in
                HStack(spacing: 2) {
                    Capsule().fill(AppTheme.inkPrimary).frame(width: max(8, barGeo.size.width * est.blackRatio))
                    Capsule().fill(AppTheme.skyTop.opacity(0.35)).overlay(Capsule().stroke(AppTheme.skyBottom.opacity(0.35), lineWidth: 1))
                }
            }
            .frame(height: 8)
        }
        .frame(height: 26)
    }
}

// MARK: - Glossy Nintendo Game Over, Boss Trophy & Time Hourglass Overlay

private struct GameResultOverlayCard: View {
    let result: GameResult
    let isBossVictory: Bool
    let bestMove: Int?
    let turningPoint: Int?
    let l10n: L10n
    let onRewind: (Int) -> Void
    let onPlayAgain: () -> Void
    let onReview: () -> Void
    let onBackHome: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(isBossVictory ? "👑" : (result.winner == .black ? "🏆" : "🎉"))
                .font(.system(size: 56))

            if isBossVictory {
                Text(l10n.t("result.bossDefeatedBadge"))
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)))
            }

            VStack(spacing: 4) {
                Text(l10n.t(result.winner == .black ? "result.blackWins" : "result.whiteWins"))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                Text(resultSubtitle)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.skyBottom)
            }

            if !result.byResignation && !result.byCaptureRace {
                HStack(spacing: 14) {
                    scorePill(title: l10n.t("result.blackScore"), value: String(format: "%.1f", result.blackScore))
                    scorePill(title: l10n.t("result.whiteScore", result.komi), value: String(format: "%.1f", result.whiteScore))
                }
            }

            if bestMove != nil || turningPoint != nil {
                VStack(spacing: 10) {
                    if let bestMove {
                        Label(l10n.t("result.bestMove", bestMove), systemImage: "star.fill")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.sunBottom)
                    }
                    if let turningPoint {
                        Button {
                            onRewind(turningPoint)
                        } label: {
                            Label(l10n.t("result.rewindAction", turningPoint), systemImage: "hourglass")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.sunRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false))
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(AppTheme.softGoldBg))
            }

            HStack(spacing: 12) {
                Button(action: onBackHome) {
                    Text(l10n.t("result.backHome"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button(action: onReview) {
                    Text(l10n.t("result.reviewGame"))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button(action: onPlayAgain) {
                    Text(l10n.t("result.playAgain"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
        }
        .padding(26)
        .frame(maxWidth: 530)
        .warmCard(cornerRadius: 34, padding: 0)
    }

    private var resultSubtitle: String {
        if result.byCaptureRace, let target = result.captureTarget {
            return l10n.t("result.byCaptureRace", target)
        }
        if result.byResignation {
            return l10n.t("result.byResign")
        }
        return l10n.t("result.byPoints", result.margin)
    }

    private func scorePill(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.canvasBackground))
    }
}

//
//  GamePlayView.swift
//  StarYi Go — Modern Glossy Nintendo Switch Party Game Arena
//

import SwiftUI

/// Isolated clock pill observing `GameClockDisplayState` via `@Observable` so 1 Hz clock ticks
/// ONLY re-render this small badge instead of invalidating the entire `GamePlayView` + `GoBoardView`.
private struct GameClockPillView: View {
    let clockDisplay: GameClockDisplayState
    let color: StoneColor
    let isActiveTurn: Bool

    var body: some View {
        if clockDisplay.clock.isActive {
            let pClock = clockDisplay.clock.state(for: color)
            HStack(spacing: 4) {
                Image(systemName: pClock.inByoyomi ? "timer" : "clock.fill")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                Text(pClock.formattedDisplay)
                    .font(AppFont.rounded(size: 12.5, weight: .black))
                    .monospacedDigit()
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
        } else {
            HStack(spacing: 4) {
                Image(systemName: isActiveTurn ? "stopwatch.fill" : "clock")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                Text(clockDisplay.formattedElapsedTime(for: color))
                    .font(AppFont.rounded(size: 12.5, weight: .black))
                    .monospacedDigit()
            }
            .foregroundColor(isActiveTurn ? AppTheme.skyBottom : AppTheme.inkSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(
                    isActiveTurn ? AppTheme.skyTop.opacity(0.16) : AppTheme.canvasBackground
                )
            )
        }
    }
}

struct GamePlayView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var viewModel: GameViewModel

    @State private var showResignConfirm = false
    @State private var showNewGameConfirm = false
    @State private var showLeaveMatchConfirm = false
    @State private var showActionsMenu = false
    @State private var showResultOverlay = false
    @State private var quickTermPopover: GoCodexEntry? = nil

    @State private var focusRegion: BoardCropRegion?
    @State private var isChoosingFocus = false
    @State private var aiThinkingNudgeShake: CGFloat = 0
    @State private var aiThinkingNudgeFlash = false

    private func offersBoardFocus(for width: CGFloat) -> Bool {
        width < 680 && viewModel.boardSize == .nineteen && !viewModel.isTabletopFaceToFace
    }

    private var offersBoardFocus: Bool {
        UIDevice.current.userInterfaceIdiom == .phone &&
            viewModel.boardSize == .nineteen && !viewModel.isTabletopFaceToFace
    }

    private var l10n: L10n { appState.l10n }
    private let topBarHeight: CGFloat = 60

    private var humanDidWin: Bool {
        guard let result = viewModel.gameResult else { return false }
        if let hc = viewModel.humanColor { return result.winner == hc }
        return true
    }

    var body: some View {
        ZStack {
            (viewModel.isTwoPlayer ? SceneBackdrop.tabletop : .seasideRoom)

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let pad: CGFloat = w < 700 ? 12 : 20

                Group {
                    if viewModel.isTwoPlayer && viewModel.isTabletopFaceToFace {
                        tabletopTwoPlayerLayout(w: w, h: h, pad: pad)
                    } else if w < 720 || h > w * 1.15 {
                        compactPortraitArena(w: w, h: h, pad: pad)
                    } else {
                        standardLandscapeArena(w: w, h: h, pad: pad)
                    }
                }
                .frame(width: w, height: h)
            }

            // Custom Game-Styled Top-Right Actions Dropdown Menu (crisp white icons!)
            if showActionsMenu {
                Color.black.opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(showActionsMenu)
                    .onTapGesture {
                        withAnimation(.spring(response: 0.22, dampingFraction: 0.82)) {
                            showActionsMenu = false
                        }
                    }
                    .zIndex(24)

                VStack {
                    HStack {
                        Spacer()
                        gameActionsDropdownCard
                            .padding(.top, topBarHeight + 14)
                            .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .transition(.scale(scale: 0.90, anchor: .topTrailing).combined(with: .opacity))
                .zIndex(25)
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

                let isCampaignMatch = viewModel.campaignNodeId != nil || viewModel.bossIslandId != nil
                GameResultOverlayCard(
                    result: result,
                    didHumanWin: humanDidWin,
                    isBossVictory: viewModel.bossIslandId != nil && humanDidWin,
                    backButtonTitle: isCampaignMatch
                        ? (l10n.language.isChinese ? "返回岛屿" : "Back to Island")
                        : l10n.t("result.backHome"),
                    bestMove: viewModel.bestMoveNumber,
                    bestMoveReason: viewModel.bestMoveReason,
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
                        if isCampaignMatch {
                            appState.popRoute()
                        } else {
                            appState.popToHome()
                        }
                    }
                )
                .transition(.scale(scale: 0.88).combined(with: .opacity))
                .zIndex(30)
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.78), value: showResultOverlay)
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: quickTermPopover)
        .toolbar(.hidden, for: .navigationBar)
        .background {
            // iPadOS Magic Keyboard shortcuts for fluid play
            Group {
                Button("") { viewModel.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!viewModel.isUndoAllowed)
                Button("") { viewModel.passTurn() }
                    .keyboardShortcut("p", modifiers: .command)
                    .disabled(!viewModel.isHumansTurn)
                Button("") { viewModel.requestHint() }
                    .keyboardShortcut("h", modifiers: .command)
                    .disabled(!viewModel.isHumansTurn || viewModel.isExamMatch)
                Button("") { viewModel.confirmPendingPlacement() }
                    .keyboardShortcut(.return, modifiers: [])
                    .disabled(viewModel.pendingPoint == nil)
            }
            .frame(width: 0, height: 0)
            .opacity(0.001)
            .accessibilityHidden(true)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            viewModel.setSuspended(phase != .active)
        }
        .onDisappear {
            viewModel.setSuspended(true)
        }
        .onAppear { viewModel.setSuspended(scenePhase != .active) }
        .onChange(of: viewModel.isTabletopFaceToFace) { _, enabled in
            if enabled {
                focusRegion = nil
                isChoosingFocus = false
            }
        }
        .onChange(of: viewModel.gameResult) { _, newValue in
            if newValue != nil {
                showResultOverlay = true
            }
        }
        .gameDialog(
            isPresented: $showLeaveMatchConfirm,
            title: l10n.localized(
                zh: "离开当前对局？",
                en: "Leave This Match?",
                ja: "対局を中断しますか？",
                ko: "대국을 잠시 멈출까요?",
                zhHant: "離開目前對局？"
            ),
            message: l10n.localized(
                zh: "未下完的棋局会自动保存，下次进入 AI 对弈时可以随时继续。",
                en: "Your unfinished game will be saved automatically so you can resume it next time you play vs AI.",
                ja: "途中の対局は自動で保存され、次回 AI 対局を開いたときに続きから再開できます。",
                ko: "진행 중인 대국은 자동 저장되며, 다음에 AI 대국에 들어오면 이어서 둘 수 있어요.",
                zhHant: "未下完的棋局會自動儲存，下次進入 AI 對弈時可以隨時繼續。"
            ),
            icon: "bookmark.fill",
            accentPalette: .sky,
            actions: [
                .secondary(l10n.localized(
                    zh: "继续下棋",
                    en: "Keep Playing",
                    ja: "対局を続ける",
                    ko: "계속 두기",
                    zhHant: "繼續下棋"
                )),
                .primary(
                    l10n.localized(
                        zh: "保存并返回",
                        en: "Save & Leave",
                        ja: "保存して戻る",
                        ko: "저장하고 나가기",
                        zhHant: "儲存並返回"
                    ),
                    palette: .sky
                ) {
                    if let snapshot = viewModel.makePausedAIMatchSnapshot() {
                        appState.savePausedAIMatch(snapshot)
                    }
                    appState.popRoute()
                }
            ]
        )
        .gameDialog(
            isPresented: $showResignConfirm,
            title: l10n.t("game.confirm.resignTitle"),
            message: l10n.t("game.confirm.resignMessage"),
            icon: "flag.fill",
            accentPalette: .coral,
            actions: [
                .secondary(l10n.t("common.cancel")),
                .destructive(l10n.t("game.action.resign")) {
                    viewModel.resignCurrentPlayer()
                }
            ]
        )
        .gameDialog(
            isPresented: $showNewGameConfirm,
            title: l10n.t("game.confirm.newGameTitle"),
            message: l10n.t("game.confirm.newGameMessage"),
            icon: "arrow.counterclockwise",
            accentPalette: .sky,
            actions: [
                .secondary(l10n.t("common.cancel")),
                .destructive(l10n.t("game.action.newGame")) {
                    viewModel.restartMatch()
                }
            ]
        )
        .gameDialog(
            isPresented: $viewModel.showUnsealedScoreAlert,
            title: l10n.localized(
                zh: "发现未封口的边界！",
                en: "Unsealed Boundaries Detected!",
                ja: "境界が閉じていない場所があります！",
                ko: "열린 경계가 발견되었습니다!",
                zhHant: "發現未封口的邊界！"
            ),
            message: l10n.localized(
                zh: "棋盘上还有 \(viewModel.endgameReadiness?.warningCount ?? 0) 处边界未封口（已用红圈标出）。如果边界漏风，这片地盘可能算不成你的空哦！",
                en: "There are \(viewModel.endgameReadiness?.warningCount ?? 0) unsealed border spot(s) marked in red. Unsealed territory won't count cleanly!",
                ja: "盤上に未封鎖の境界が\(viewModel.endgameReadiness?.warningCount ?? 0)か所（赤丸表示）あります。境界が閉じないと地合いが正しく数えられません。",
                ko: "바둑판에 막히지 않은 경계가 \(viewModel.endgameReadiness?.warningCount ?? 0)곳(빨간 표시) 있습니다. 경계가 열려 있으면 집으로 계산되지 않아요!",
                zhHant: "棋盤上還有 \(viewModel.endgameReadiness?.warningCount ?? 0) 處邊界未封口（已用紅圈標出）。如果邊界漏風，這片地盤可能算不成你的空哦！"
            ),
            icon: "exclamationmark.triangle.fill",
            accentPalette: .sun,
            actions: [
                .primary(
                    l10n.localized(zh: "回去补边界", en: "Seal First", ja: "戻って境界を閉じる", ko: "돌아가서 막기", zhHant: "回去補邊界"),
                    palette: .mint
                ),
                .primary(
                    l10n.localized(zh: "仍要直接数子", en: "Score Anyway", ja: "このまま計算する", ko: "그대로 계가하기", zhHant: "仍要直接數子"),
                    palette: .sun
                ) {
                    viewModel.beginDeadStoneReview(bypassUnsealedWarning: true)
                }
            ]
        )
        .gameDialog(
            isPresented: $viewModel.showAIResignOfferDialog,
            title: l10n.localized(
                zh: "对手提出认输",
                en: "AI Offers Resignation",
                ja: "AIが投了を申し出ました",
                ko: "AI가 기권을 요청했어요",
                zhHant: "對手提出認輸"
            ),
            message: l10n.localized(
                zh: "你已经建立起明显优势，对手觉得难以翻盘，想要中盘认输。要直接接受胜利，还是继续把棋下完？",
                en: "You have a decisive lead and your AI opponent wants to resign. Would you like to accept victory now or keep playing?",
                ja: "あなたの優勢が決定的となり、AIが中押し負け（投了）を申し出ています。このまま勝利を受け取りますか？それとも最後まで打ち続けますか？",
                ko: "이미 확실한 우세를 점해 AI가 불계패(기권)를 요청했습니다. 지금 승리를 받아들이시겠어요, 아니면 끝까지 계속 두시겠어요?",
                zhHant: "你已經建立起明顯優勢，對手覺得難以翻盤，想要中盤認輸。要直接接受勝利，還是繼續把棋下完？"
            ),
            icon: "flag.checkered",
            accentPalette: .mint,
            actions: [
                .secondary(
                    l10n.localized(
                        zh: "继续下完",
                        en: "Keep Playing",
                        ja: "最後まで打つ",
                        ko: "계속 두기",
                        zhHant: "繼續下完"
                    )
                ) {
                    viewModel.declineAIResignation()
                },
                .primary(
                    l10n.localized(
                        zh: "接受胜利",
                        en: "Accept Victory",
                        ja: "勝利を受け取る",
                        ko: "승리 수락",
                        zhHant: "接受勝利"
                    ),
                    palette: .mint
                ) {
                    viewModel.acceptAIResignation()
                }
            ]
        )
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

                ScrollView(showsIndicators: false) {
                    rightControlPanel
                        .frame(minHeight: contentHeight)
                }
                .scrollClipDisabled()
                .scrollBounceBehavior(.basedOnSize)
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
                .frame(height: topBarHeight)

            if boardSide > 0 {
                boardView
                    .frame(width: boardSide, height: boardSide)
            }

            ScrollView(showsIndicators: false) {
                rightControlPanel
            }
            .scrollClipDisabled()
        }
        .padding(.horizontal, pad)
        .padding(.vertical, 8)
    }

    // MARK: - Two-Player Tabletop Face-to-Face Mode (with Parent-Child Kid Assist!)

    private func tabletopTwoPlayerLayout(w: CGFloat, h: CGFloat, pad: CGFloat) -> some View {
        let isPortrait = h > w
        let outerPad: CGFloat = 12
        let gap: CGFloat = 12

        return Group {
            if isPortrait {
                let dockHeight: CGFloat = 104
                let dockWidth = max(280, min(w - outerPad * 2, 620))
                let boardSide = max(240, min(w - outerPad * 2, h - dockHeight * 2 - outerPad * 2 - gap * 2 - 56))

                VStack(spacing: gap) {
                    tabletopPlayerDock(color: .white, length: dockWidth, thickness: dockHeight, rotation: .degrees(180))
                    boardView
                        .frame(width: boardSide, height: boardSide)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    tabletopPlayerDock(color: .black, length: dockWidth, thickness: dockHeight, rotation: .degrees(0))
                }
                .padding(.horizontal, outerPad)
                .padding(.top, 56)
                .padding(.bottom, outerPad)
            } else {
                let dockThickness: CGFloat = 106
                let dockLength = max(340, min(h - 140, 620))
                let boardSide = max(260, min(w - dockThickness * 2 - outerPad * 2 - gap * 2, h - outerPad * 2))

                HStack(spacing: gap) {
                    tabletopPlayerDock(color: .white, length: dockLength, thickness: dockThickness, rotation: .degrees(90))
                        .frame(width: dockThickness, height: dockLength)
                        .frame(maxHeight: .infinity, alignment: .center)

                    boardView
                        .frame(width: boardSide, height: boardSide)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    tabletopPlayerDock(color: .black, length: dockLength, thickness: dockThickness, rotation: .degrees(-90))
                        .frame(width: dockThickness, height: dockLength)
                        .frame(maxHeight: .infinity, alignment: .center)
                }
                .padding(outerPad)
            }
        }
        .overlay(alignment: .topLeading) {
            GameBackButton(title: l10n.t("common.back")) {
                if viewModel.shouldConfirmBeforeLeaving {
                    showLeaveMatchConfirm = true
                } else {
                    appState.popRoute()
                }
            }
            .padding(14)
        }
        .overlay(alignment: .topTrailing) {
            GameCircleButton(icon: "rectangle.portrait.rotate", palette: .mint, tint: .white, size: 46) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.isTabletopFaceToFace.toggle()
                }
            }
            .padding(14)
        }
    }

    /// Sleek horizontal player dock designed in the player's own upright frame, then rotated ±90° (or 180°)
    /// so it spans naturally along their edge of the table while maximizing the Go board size!
    private func tabletopPlayerDock(
        color: StoneColor,
        length: CGFloat,
        thickness: CGFloat,
        rotation: Angle
    ) -> some View {
        let isTurn = !viewModel.isGameOver && viewModel.boardState.currentTurn == color
        let captures = color == .black ? viewModel.boardState.blackCaptures : viewModel.boardState.whiteCaptures
        let hasKidAssist = viewModel.tabletopKidAssistColor == color

        return HStack(spacing: 14) {
            // Left: Captured-stones bowl + Player identity & turn status
            HStack(spacing: 12) {
                WoodenGoBowlView(capturedColor: color.opposite, count: captures)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(l10n.t(color == .black ? "stone.black" : "stone.white"))
                            .font(AppFont.rounded(size: 18, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)

                        if let target = viewModel.ruleSet.captureTarget {
                            Text(l10n.t("game.captureGoalBadge", captures, target))
                                .font(AppFont.rounded(size: 11, weight: .black))
                                .foregroundColor(AppTheme.coralBottom)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.coralTop.opacity(0.14)))
                        }
                    }

                    Text(isTurn ? l10n.t(color == .black ? "game.turn.black" : "game.turn.white") : l10n.t("game.moveCount", viewModel.moves.count))
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundColor(isTurn ? .white : AppTheme.inkSecondary)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                isTurn
                                ? AnyShapeStyle(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(AppTheme.canvasBackground)
                            )
                        )
                }
            }

            Spacer(minLength: 8)

            // Right: Action buttons, Confirm Placement / Dead-Stone Confirm & Parent-Child Kid Assist toggle
            HStack(spacing: 9) {
                if viewModel.isMarkingDeadStones {
                    Button {
                        viewModel.confirmDeadStoneScore()
                    } label: {
                        Label(l10n.t("game.deadStones.confirm"), systemImage: "checkmark.circle.fill")
                            .font(AppFont.rounded(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                } else if viewModel.showsConfirmPlacementButton && viewModel.pendingPoint != nil && isTurn {
                    Button {
                        viewModel.confirmPendingPlacement()
                    } label: {
                        Label(l10n.t("game.action.confirmMove"), systemImage: "checkmark.circle.fill")
                            .font(AppFont.rounded(size: 12, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                }

                GameCircleButton(icon: "arrow.uturn.backward", palette: .snow, tint: AppTheme.inkPrimary, size: 44, playTapSound: false) {
                    viewModel.undo()
                }
                .accessibilityLabel(l10n.t("game.action.undo"))
                .disabled(!viewModel.isUndoAllowed)
                .opacity(viewModel.isUndoAllowed ? 1 : 0.45)

                if hasKidAssist {
                    GameCircleButton(icon: "lightbulb.fill", palette: .sun, tint: .white, size: 44) {
                        viewModel.requestHint()
                    }
                    .accessibilityLabel(l10n.t("game.action.hint"))
                    .disabled(!isTurn)
                    .opacity(isTurn ? 1 : 0.45)
                }

                GameCircleButton(icon: "hand.raised.fill", palette: .snow, tint: AppTheme.inkPrimary, size: 44) {
                    viewModel.passTurn()
                }
                .accessibilityLabel(l10n.t("game.action.pass"))
                .disabled(!isTurn)
                .opacity(isTurn ? 1 : 0.45)

                Button {
                    viewModel.tabletopKidAssistColor = hasKidAssist ? nil : color
                    SoundAndHapticsManager.shared.playUITap()
                } label: {
                    Label(l10n.t("game.tabletop.kidAssist"), systemImage: hasKidAssist ? "sparkles" : "sparkle")
                        .font(AppFont.rounded(size: 12, weight: .black))
                        .foregroundColor(hasKidAssist ? .white : AppTheme.sunBottom)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minHeight: AppTheme.buttonFaceHeight)
                        .background(Capsule().fill(hasKidAssist ? AppTheme.sunBottom : AppTheme.softGoldBg))
                }
                .tactileButton(scale: 0.94, sound: false)
            }
        }
        .padding(.horizontal, 18)
        .frame(width: length, height: thickness)
        .warmCard(cornerRadius: 28, padding: 0)
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(isTurn ? AppTheme.skyTop : Color.clear, lineWidth: 3.5)
        )
        .rotationEffect(rotation)
    }

    // MARK: - Glossy Top Bar (with Tappable Komi Term Explainer!)

    private var canShowResumeLastMatchButton: Bool {
        viewModel.canOfferResumePausedAIMatch
            && appState.pausedAIMatch != nil
    }

    private var gameTopBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
                GameBackButton(title: l10n.t("common.back")) {
                    if viewModel.shouldConfirmBeforeLeaving {
                        showLeaveMatchConfirm = true
                    } else {
                        appState.popRoute()
                    }
                }

                if canShowResumeLastMatchButton {
                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        appState.resumePausedAIMatch()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise.circle.fill")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            Text(l10n.localized(
                                zh: "继续上局",
                                en: "Resume Last",
                                ja: "前回の続き",
                                ko: "이어서 두기",
                                zhHant: "繼續上局"
                            ))
                            .font(AppFont.rounded(size: 14, weight: .heavy))
                            .lineLimit(1)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false))
                    .accessibilityIdentifier("GameResumePausedMatchButton")
                }
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
                if offersBoardFocus {
                    Button {
                        if focusRegion != nil {
                            focusRegion = nil
                        } else {
                            isChoosingFocus.toggle()
                        }
                    } label: {
                        Image(systemName: focusRegion != nil ? "minus.magnifyingglass" : "plus.magnifyingglass")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(focusRegion != nil
                        ? l10n.localized(zh: "显示全盘", en: "Show full board", ja: "全盤を表示", ko: "전체 판 보기", zhHant: "顯示全盤")
                        : l10n.localized(zh: "选择放大区域", en: "Choose area to zoom", ja: "拡大エリアを選択", ko: "확대 영역 선택", zhHant: "選擇放大區域"))
                    .accessibilityIdentifier("GameBoardFocusButton")
                }
                if viewModel.isTwoPlayer {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            viewModel.isTabletopFaceToFace.toggle()
                        }
                    } label: {
                        Label(l10n.t("game.action.tabletop"), systemImage: "rectangle.portrait.rotate")
                            .font(AppFont.rounded(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }

                soundToggleButton

                voiceToggleButton

                stoneDisplayToggleButton

                Button {
                    SoundAndHapticsManager.shared.playUITap(weight: .light)
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.80)) {
                        showActionsMenu.toggle()
                    }
                } label: {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(width: AppTheme.buttonFaceHeight, height: AppTheme.buttonFaceHeight)
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
                .buttonStyle(.plain)
                .accessibilityIdentifier("GameActionsMenu")
                .accessibilityLabel(l10n.localized(zh: "对局菜单", en: "Game Menu", ja: "対局メニュー", ko: "대국 메뉴", zhHant: "對局選單"))
            }
        }
    }

    private enum StoneDisplayMode: Equatable {
        case expressive
        case moveNumbers
        case standard
    }

    private var currentStoneDisplayMode: StoneDisplayMode {
        if appState.settings.showMoveNumbers {
            return .moveNumbers
        }
        if appState.settings.expressiveStones && !appState.settings.zenDojoMode && !viewModel.isExamMatch {
            return .expressive
        }
        return .standard
    }

    private var stoneDisplayAccessibilityLabel: String {
        switch currentStoneDisplayMode {
        case .expressive:
            return l10n.localized(
                zh: "棋子样式：萌趣表情",
                en: "Stone Display: Smiley",
                ja: "碁石の表示：表情",
                ko: "바둑돌 표시: 표정",
                zhHant: "棋子樣式：萌趣表情"
            )
        case .moveNumbers:
            return l10n.localized(
                zh: "棋子样式：显示手数",
                en: "Stone Display: Move Numbers",
                ja: "碁石の表示：手数",
                ko: "바둑돌 표시: 수순",
                zhHant: "棋子樣式：顯示手數"
            )
        case .standard:
            return l10n.localized(
                zh: "棋子样式：默认",
                en: "Stone Display: Default",
                ja: "碁石の表示：デフォルト",
                ko: "바둑돌 표시: 기본",
                zhHant: "棋子樣式：預設"
            )
        }
    }

    private func cycleStoneDisplayMode() {
        let nextMode: StoneDisplayMode
        if viewModel.isExamMatch {
            nextMode = currentStoneDisplayMode == .moveNumbers ? .standard : .moveNumbers
        } else {
            switch currentStoneDisplayMode {
            case .expressive:
                nextMode = .moveNumbers
            case .moveNumbers:
                nextMode = .standard
            case .standard:
                nextMode = .expressive
            }
        }

        withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
            appState.updateSettings { s in
                switch nextMode {
                case .expressive:
                    s.showMoveNumbers = false
                    s.expressiveStones = true
                    s.zenDojoMode = false
                    s.assistPreset = .custom
                case .moveNumbers:
                    s.showMoveNumbers = true
                    s.expressiveStones = false
                    s.assistPreset = .custom
                case .standard:
                    s.showMoveNumbers = false
                    s.expressiveStones = false
                    s.assistPreset = .custom
                }
            }
            if showActionsMenu {
                showActionsMenu = false
            }
        }
        SoundAndHapticsManager.shared.playUITap(weight: .light)
    }

    private var stoneToggleGradientColors: [Color] {
        switch appState.settings.stoneStyle {
        case .classicSlateShell:
            return [
                Color(red: 0.36, green: 0.38, blue: 0.42),
                Color(red: 0.13, green: 0.14, blue: 0.17),
                Color(red: 0.05, green: 0.06, blue: 0.08)
            ]
        case .coralPearl:
            return [
                Color(red: 0.24, green: 0.46, blue: 0.56),
                Color(red: 0.08, green: 0.22, blue: 0.32),
                Color(red: 0.04, green: 0.11, blue: 0.18)
            ]
        case .kyotoLacquer:
            return [
                Color(red: 0.44, green: 0.24, blue: 0.18),
                Color(red: 0.16, green: 0.08, blue: 0.07),
                Color(red: 0.07, green: 0.04, blue: 0.04)
            ]
        case .starlightJade:
            return [
                Color(red: 0.18, green: 0.54, blue: 0.46),
                Color(red: 0.07, green: 0.26, blue: 0.24),
                Color(red: 0.03, green: 0.12, blue: 0.14)
            ]
        }
    }

    private var soundToggleButton: some View {
        let isOn = appState.settings.soundEnabled
        let palette: GlossyPalette = .snow

        return Button {
            let nextValue = !appState.settings.soundEnabled
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                appState.updateSettings { $0.soundEnabled = nextValue }
                if showActionsMenu {
                    showActionsMenu = false
                }
            }
            if nextValue {
                SoundAndHapticsManager.shared.playUITap(weight: .light)
            }
        } label: {
            Image(systemName: isOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(isOn ? AppTheme.inkPrimary : AppTheme.inkSecondary.opacity(0.65))
                .frame(width: AppTheme.buttonFaceHeight, height: AppTheme.buttonFaceHeight)
                .background(
                    ZStack {
                        Circle()
                            .fill(palette.rim)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                            .offset(y: 5)
                        Circle()
                            .fill(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    }
                )
                .padding(.bottom, 5)
        }
        .tactileButton(scale: 0.92, sound: false)
        .accessibilityLabel(
            isOn
                ? l10n.localized(zh: "落子与按钮音效：开", en: "Sound Effects: On", ja: "効果音：オン", ko: "효과음: 켜짐", zhHant: "落子與按鈕音效：開")
                : l10n.localized(zh: "落子与按钮音效：关", en: "Sound Effects: Off", ja: "効果音：オフ", ko: "효과음: 꺼짐", zhHant: "落子與按鈕音效：關")
        )
        .accessibilityIdentifier("GameSoundToggleButton")
    }

    private var voiceToggleButton: some View {
        let isOn = appState.settings.voiceEnabled
        let palette: GlossyPalette = .snow

        return Button {
            SoundAndHapticsManager.shared.playUITap(weight: .light)
            withAnimation(.spring(response: 0.24, dampingFraction: 0.72)) {
                appState.updateSettings { $0.voiceEnabled.toggle() }
                if showActionsMenu {
                    showActionsMenu = false
                }
            }
        } label: {
            ZStack {
                Image(systemName: "person.wave.2.fill")
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(isOn ? AppTheme.inkPrimary : AppTheme.inkSecondary.opacity(0.65))

                if !isOn {
                    Capsule()
                        .fill(AppTheme.coralBottom)
                        .frame(width: 24, height: 2.6)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.95), lineWidth: 0.8)
                        )
                        .rotationEffect(.degrees(-40))
                }
            }
            .frame(width: AppTheme.buttonFaceHeight, height: AppTheme.buttonFaceHeight)
            .background(
                ZStack {
                    Circle()
                        .fill(palette.rim)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .offset(y: 5)
                    Circle()
                        .fill(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom))
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                }
            )
            .padding(.bottom, 5)
        }
        .tactileButton(scale: 0.92, sound: false)
        .accessibilityLabel(
            isOn
                ? l10n.localized(zh: "人声语音：开", en: "Voice Lines: On", ja: "音声ガイド：オン", ko: "음성 안내: 켜짐", zhHant: "人聲語音：開")
                : l10n.localized(zh: "人声语音：关", en: "Voice Lines: Off", ja: "音声ガイド：オフ", ko: "음성 안내: 꺼짐", zhHant: "人聲語音：關")
        )
        .accessibilityIdentifier("GameVoiceToggleButton")
    }

    private var stoneDisplayToggleButton: some View {
        let mode = currentStoneDisplayMode
        let stoneSize: CGFloat = 31

        return Button {
            cycleStoneDisplayMode()
        } label: {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: stoneToggleGradientColors,
                            center: UnitPoint(x: 0.35, y: 0.32),
                            startRadius: 1.5,
                            endRadius: stoneSize * 0.65
                        )
                    )
                    .frame(width: stoneSize, height: stoneSize)
                    .shadow(color: Color.black.opacity(0.24), radius: 2.5, x: 0.8, y: 1.6)

                Group {
                    switch mode {
                    case .expressive:
                        Canvas { ctx, size in
                            let center = CGPoint(x: size.width / 2, y: size.height / 2)
                            let r = min(size.width, size.height) / 2
                            let ink = Color.white.opacity(0.94)
                            let eyeDX = r * 0.29
                            let eyeY = center.y - r * 0.08
                            let eyeR = max(1.6, r * 0.125)

                            for dir in [-1.0, 1.0] {
                                let ex = center.x + CGFloat(dir) * eyeDX
                                ctx.fill(
                                    Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)),
                                    with: .color(ink)
                                )
                            }

                            var smile = Path()
                            smile.move(to: CGPoint(x: center.x - r * 0.22, y: center.y + r * 0.18))
                            smile.addQuadCurve(
                                to: CGPoint(x: center.x + r * 0.22, y: center.y + r * 0.18),
                                control: CGPoint(x: center.x, y: center.y + r * 0.40)
                            )
                            ctx.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        }
                        .frame(width: stoneSize, height: stoneSize)
                    case .moveNumbers:
                        Text("1")
                            .font(AppFont.rounded(size: 14.5, weight: .black))
                            .foregroundColor(.white)
                    case .standard:
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.30), Color.white.opacity(0.0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 6
                                )
                            )
                            .frame(width: 11, height: 11)
                            .offset(x: -5.5, y: -5.5)
                    }
                }
                .id(mode)
                .transition(.scale(scale: 0.72).combined(with: .opacity))
            }
            .frame(width: AppTheme.buttonFaceHeight, height: AppTheme.buttonFaceHeight)
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
        .tactileButton(scale: 0.92, sound: false)
        .accessibilityLabel(stoneDisplayAccessibilityLabel)
        .accessibilityIdentifier("GameStoneDisplayToggleButton")
    }

    private var gameActionsDropdownCard: some View {
        let placementMode = appState.settings.stonePlacementMode

        return VStack(alignment: .leading, spacing: 4) {
            VStack(alignment: .leading, spacing: 6) {
                Text(l10n.localized(
                    zh: "落子方式",
                    en: "Placement Mode",
                    ja: "着手の方法",
                    ko: "착수 방식",
                    zhHant: "落子方式"
                ))
                .font(AppFont.rounded(size: 11.5, weight: .heavy))
                .foregroundColor(Color.white.opacity(0.66))
                .padding(.horizontal, 4)

                HStack(spacing: 4) {
                    menuModeChoiceButton(
                        title: l10n.localized(
                            zh: "点两下落子",
                            en: "Double Tap",
                            ja: "2タップ",
                            ko: "두 번 탭",
                            zhHant: "點兩下落子"
                        ),
                        icon: "hand.tap.fill",
                        isSelected: placementMode == .doubleTap,
                        accessibilityId: "GamePlacementModeDoubleTap"
                    ) {
                        appState.updateSettings { s in
                            s.stonePlacementMode = .doubleTap
                        }
                        SoundAndHapticsManager.shared.playUITap(weight: .light)
                    }

                    menuModeChoiceButton(
                        title: l10n.localized(
                            zh: "确认按钮",
                            en: "Confirm Btn",
                            ja: "確認ボタン",
                            ko: "확인 버튼",
                            zhHant: "確認按鈕"
                        ),
                        icon: "checkmark.circle.fill",
                        isSelected: placementMode == .confirmButton,
                        accessibilityId: "GamePlacementModeConfirmButton"
                    ) {
                        appState.updateSettings { s in
                            s.stonePlacementMode = .confirmButton
                        }
                        SoundAndHapticsManager.shared.playUITap(weight: .light)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(Color.white.opacity(0.10))
                )
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 6)

            Divider()
                .background(Color.white.opacity(0.20))
                .padding(.bottom, 2)

            actionsMenuRow(
                title: l10n.t("settings.assist.coordinates"),
                icon: appState.settings.showCoordinates ? "checkmark.circle.fill" : "grid"
            ) {
                appState.updateSettings { $0.showCoordinates.toggle() }
                SoundAndHapticsManager.shared.playUITap(weight: .light)
            }

            if !viewModel.isTwoPlayer {
                VStack(alignment: .leading, spacing: 6) {
                    Text(l10n.localized(
                        zh: "AI 思考节奏",
                        en: "AI Thinking Pace",
                        ja: "AIの思考ペース",
                        ko: "AI 생각 속도",
                        zhHant: "AI 思考節奏"
                    ))
                    .font(AppFont.rounded(size: 11.5, weight: .heavy))
                    .foregroundColor(Color.white.opacity(0.66))
                    .padding(.horizontal, 4)

                    HStack(spacing: 3) {
                        ForEach(AIThinkingPace.allCases) { pace in
                            let selected = appState.settings.aiThinkingPace == pace
                            Button {
                                appState.updateSettings {
                                    $0.aiThinkingPace = pace
                                    $0.aiSimulatedThinkingEnabled = (pace != .instant)
                                }
                                SoundAndHapticsManager.shared.playUITap(weight: .light)
                            } label: {
                                Text(pace.shortTitle(l10n))
                                    .font(AppFont.rounded(size: 11.5, weight: .heavy))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.76)
                                    .foregroundColor(selected ? .white : Color.white.opacity(0.72))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(
                                                selected
                                                    ? LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)
                                                    : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
                                            )
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("GameAIPace_\(pace.rawValue)")
                        }
                    }
                    .padding(3)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.white.opacity(0.10))
                    )
                }
                .padding(.horizontal, 6)
                .padding(.top, 2)
                .padding(.bottom, 6)

                Divider()
                    .background(Color.white.opacity(0.20))
                    .padding(.bottom, 2)
            }

            actionsMenuRow(
                title: l10n.t("settings.feedback.sound"),
                icon: appState.settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
            ) {
                appState.updateSettings { $0.soundEnabled.toggle() }
                SoundAndHapticsManager.shared.playUITap(weight: .light)
            }

            Divider()
                .background(Color.white.opacity(0.24))
                .padding(.vertical, 4)

            actionsMenuRow(
                title: l10n.t("game.action.newGame"),
                icon: "arrow.clockwise"
            ) {
                showActionsMenu = false
                showNewGameConfirm = true
            }

            if !viewModel.isGameOver {
                actionsMenuRow(
                    title: l10n.t("game.action.resign"),
                    icon: "flag.fill",
                    isDestructive: true
                ) {
                    showActionsMenu = false
                    showResignConfirm = true
                }
            }
        }
        .padding(10)
        .frame(width: 248)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.11, green: 0.16, blue: 0.28).opacity(0.96))
                .shadow(color: Color.black.opacity(0.32), radius: 18, y: 10)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.42), lineWidth: 2)
        )
    }

    private func menuModeChoiceButton(
        title: String,
        icon: String,
        isSelected: Bool,
        accessibilityId: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(title)
                    .font(AppFont.rounded(size: 12.5, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundColor(isSelected ? .white : Color.white.opacity(0.72))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isSelected
                            ? LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)
                            : LinearGradient(colors: [.clear, .clear], startPoint: .top, endPoint: .bottom)
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }

    private func actionsMenuRow(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(isDestructive ? Color(red: 1.0, green: 0.56, blue: 0.56) : .white)
                    .frame(width: 22, alignment: .center)

                Text(title)
                    .font(AppFont.rounded(size: 14.5, weight: .bold))
                    .foregroundColor(isDestructive ? Color(red: 1.0, green: 0.62, blue: 0.62) : .white)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
            stoneStyle: appState.settings.stoneStyle,
            cropRegion: focusRegion,
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
            labeledPoints: viewModel.scenarioBoardLabels,
            highlightedPocketPoints: viewModel.highlightedPocketPoints,
            pendingPoint: viewModel.pendingPoint,
            previewColor: viewModel.boardState.currentTurn,
            isChoosingRegion: isChoosingFocus,
            isInteractive: (viewModel.isHumansTurn && !viewModel.isAIThinking && !viewModel.isGameOver) || viewModel.isMarkingDeadStones,
            capturedFlashPoints: viewModel.lastCapturedPoints,
            captureEventID: viewModel.captureEventID,
            illegalFlashPoint: viewModel.illegalFlashPoint,
            illegalEventID: viewModel.illegalEventID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
            onSelectPoint: { point in
                if isChoosingFocus {
                    focusRegion = .focused(around: point, size: viewModel.boardState.size)
                    isChoosingFocus = false
                } else {
                    viewModel.handleBoardTap(at: point)
                }
            }
        )
        .overlay(alignment: .top) {
            if isChoosingFocus {
                Text(l10n.localized(zh: "点选要放大的位置", en: "Tap the area to zoom", ja: "拡大する場所をタップ", ko: "확대할 위치를 탭하세요", zhHant: "點選要放大的位置"))
                    .font(.caption.bold())
                    .padding(8)
                    .background(.regularMaterial, in: Capsule())
                    .allowsHitTesting(false)
            }
        }
        .overlay {
            if viewModel.isAIThinking && !viewModel.isGameOver && !isChoosingFocus {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        triggerAIThinkingNudge()
                    }
            }
        }
    }

    private func triggerAIThinkingNudge() {
        SoundAndHapticsManager.shared.playUITap(weight: .light)
        withAnimation(.easeInOut(duration: 0.36)) {
            aiThinkingNudgeShake += 2
        }
        withAnimation(.easeOut(duration: 0.14)) {
            aiThinkingNudgeFlash = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation(.easeOut(duration: 0.25)) {
                aiThinkingNudgeFlash = false
            }
        }
    }

    // MARK: - Glossy Right Control Panel

    private var rightControlPanel: some View {
        VStack(spacing: 12) {
            if let diff = viewModel.aiDifficulty, !appState.settings.zenDojoMode {
                companionCard(difficulty: diff)
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
                        ProgressView()
                            .tint(AppTheme.skyBottom)
                            .scaleEffect(0.88)
                    } else {
                        Circle()
                            .fill(viewModel.boardState.currentTurn == .black ? Color(white: 0.14) : Color.white)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 1))
                    }

                    Text(primaryStatusLine)
                        .font(AppFont.rounded(size: 13.5, weight: .heavy))
                        .foregroundColor(
                            isAlertStatus
                                ? AppTheme.coralBottom
                                : (viewModel.isAIThinking ? AppTheme.skyBottom : AppTheme.inkPrimary)
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                .frame(height: 32, alignment: .leading)

                if viewModel.showTerritoryOverlay, let est = viewModel.territoryEstimate {
                    territoryBarContent(est: est)
                        .transition(.opacity)
                } else {
                    Text(l10n.t("game.libertiesTip"))
                        .font(AppFont.rounded(size: 11, weight: .semibold))
                        .foregroundColor(AppTheme.inkSecondary)
                        .lineLimit(1)
                        .frame(height: 26, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 22, padding: 14)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        viewModel.isAIThinking
                            ? AppTheme.skyTop.opacity(aiThinkingNudgeFlash ? 0.95 : 0.55)
                            : Color.clear,
                        lineWidth: aiThinkingNudgeFlash ? 3 : 2
                    )
            )
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(viewModel.isAIThinking ? AppTheme.skyTop.opacity(aiThinkingNudgeFlash ? 0.14 : 0.06) : Color.clear)
            )
            .shadow(
                color: viewModel.isAIThinking ? AppTheme.skyTop.opacity(aiThinkingNudgeFlash ? 0.35 : 0.14) : .clear,
                radius: aiThinkingNudgeFlash ? 14 : 8,
                y: 2
            )
            .modifier(LockedShakeEffect(shakes: aiThinkingNudgeShake, amplitude: 6))
            .animation(.easeInOut(duration: 0.18), value: viewModel.showTerritoryOverlay)
            .animation(.easeInOut(duration: 0.22), value: viewModel.isAIThinking)

            Spacer(minLength: 2)

            if viewModel.isMarkingDeadStones {
                deadStoneConfirmationDock
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
            } else {
                // Fixed-height Confirm Placement Slot
                ZStack {
                    if viewModel.showsConfirmPlacementButton, viewModel.pendingPoint != nil {
                        confirmPlacementBar
                            .environment(\.minimumButtonFaceHeight, AppTheme.boardActionFaceHeight)
                            .transition(.scale(scale: 0.94).combined(with: .opacity))
                    } else {
                        Color.clear
                    }
                }
                .frame(height: AppTheme.boardActionFaceHeight + 5)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: viewModel.pendingPoint)
                .animation(.spring(response: 0.24, dampingFraction: 0.72), value: viewModel.showsConfirmPlacementButton)

                // Glossy Candy-Capsule Controls Grid
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        glossyActionTile(
                            title: l10n.t("game.action.undo"),
                            icon: "arrow.uturn.backward",
                            palette: .snow,
                            tint: AppTheme.inkPrimary,
                            disabled: !viewModel.isUndoAllowed,
                            playSound: false
                        ) {
                            viewModel.undo()
                        }

                        glossyActionTile(
                            title: l10n.t("game.action.hint"),
                            icon: viewModel.isComputingHint ? "hourglass" : "lightbulb.fill",
                            palette: .snow,
                            tint: AppTheme.inkPrimary,
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

                    if !viewModel.ruleSet.isCaptureRace {
                        Button {
                            viewModel.beginDeadStoneReview()
                        } label: {
                            Label(l10n.t("game.action.score"), systemImage: "flag.checkered")
                                .font(AppFont.rounded(size: 16, weight: .black))
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                        .environment(\.minimumButtonFaceHeight, AppTheme.boardActionFaceHeight)
                        .disabled(viewModel.isGameOver || viewModel.moves.count < 2)
                        .opacity(viewModel.isGameOver || viewModel.moves.count < 2 ? 0.42 : 1)
                    }
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: viewModel.isMarkingDeadStones)
    }

    private func captureRaceBanner(target: Int) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.sunBottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(l10n.t("rule.captureRace", target))
                    .font(AppFont.rounded(size: 13, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                HStack(spacing: 12) {
                    Text("⚫️ \(viewModel.boardState.blackCaptures)/\(target)")
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text("⚪️ \(viewModel.boardState.whiteCaptures)/\(target)")
                        .font(AppFont.rounded(size: 12, weight: .heavy))
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
        VStack(spacing: 9) {
            HStack(spacing: 8) {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(AppTheme.coralBottom)
                Text(l10n.t("game.deadStones.hint"))
                    .font(AppFont.rounded(size: 12.5, weight: .heavy))
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
                        Text(
                            rule == .chinese
                            ? l10n.localized(zh: "中国数子法", en: "Chinese Area", ja: "中国ルール", ko: "중국 규칙", zhHant: "中國數子法")
                            : l10n.localized(zh: "日韩数目法", en: "Japanese Terr.", ja: "日本・韓国ルール", ko: "한·일 규칙", zhHant: "日韓數目法")
                        )
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(selected ? .white : AppTheme.inkSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .frame(minHeight: AppTheme.buttonFaceHeight)
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
                            .font(.system(size: 10, weight: .black, design: .rounded))
                        Text(viewModel.activeCountingPocketLabel ?? l10n.localized(zh: "逐块点地", en: "Animate", ja: "順番に計算", ko: "구역별 계가", zhHant: "逐塊點地"))
                            .font(AppFont.rounded(size: 10.5, weight: .black))
                    }
                    .foregroundColor(AppTheme.sunBottom)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .frame(minHeight: AppTheme.buttonFaceHeight)
                    .background(Capsule().fill(AppTheme.softGoldBg))
                }
                .tactileButton(scale: 0.94, sound: false)
            }

            if let preview = viewModel.deadStonePreviewResult {
                VStack(spacing: 4) {
                    HStack {
                        Text("⚫️ \(String(format: "%.1f", preview.blackScore))")
                            .font(AppFont.rounded(size: 15, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                        Spacer()
                        Text(l10n.t(preview.winner == .black ? "result.blackWins" : "result.whiteWins"))
                            .font(AppFont.rounded(size: 13, weight: .black))
                            .foregroundColor(AppTheme.skyBottom)
                        Spacer()
                        Text("⚪️ \(String(format: "%.1f", preview.whiteScore))")
                            .font(AppFont.rounded(size: 15, weight: .black))
                            .foregroundColor(AppTheme.inkSecondary)
                    }

                    Text(localizedScoreSummary(preview))
                    .font(AppFont.rounded(size: 10.5, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                    if preview.sekiGroupCount > 0 {
                        Text(l10n.localized(
                            zh: "🤝 检测到 \(preview.sekiGroupCount) 处双活（自动保护存活）",
                            en: "🤝 \(preview.sekiGroupCount) Seki group(s) protected as alive",
                            ja: "🤝 セキを \(preview.sekiGroupCount) 箇所検出（活きとして自動保護）",
                            ko: "🤝 빅 \(preview.sekiGroupCount)곳 감지 (자동 생존 보호)",
                            zhHant: "🤝 偵測到 \(preview.sekiGroupCount) 處雙活（自動保護存活）"
                        ))
                            .font(AppFont.rounded(size: 10.5, weight: .black))
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
                    Text(l10n.localized(
                        zh: "续下验死活",
                        en: "Play Dispute",
                        ja: "打ち継いで死活確認",
                        ko: "계속 두어 사활 확인",
                        zhHant: "續下驗死活"
                    ))
                        .font(AppFont.rounded(size: 13, weight: .heavy))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button {
                    viewModel.confirmDeadStoneScore()
                } label: {
                    Label(l10n.t("game.deadStones.confirm"), systemImage: "checkmark.circle.fill")
                        .font(AppFont.rounded(size: 14.5, weight: .black))
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

    private func localizedScoreSummary(_ preview: GameResult) -> String {
        let marginStr = String(format: "%.1f", preview.margin)
        if preview.scoringRule == .chinese {
            let baseHalf = Double(preview.boardSize * preview.boardSize) / 2.0
            let blackThreshold = baseHalf + preview.komi / 2.0
            let ziStr = GameResult.formatChineseZi(preview.chineseZiMargin)
            let blackZi = String(format: "%.1f", preview.blackScore)
            let needZi = String(format: "%.2f", blackThreshold)
            let ziMarginStr = String(format: "%.2f", preview.chineseZiMargin)
            return l10n.localized(
                zh: "数子法 · 黑 \(blackZi) 子（过 \(needZi) 胜）· \(preview.winner == .black ? "黑胜" : "白胜") \(ziStr)",
                en: "Chinese Area · \(preview.winner == .black ? "Black" : "White") +\(marginStr) pts (\(ziMarginStr) Zi)",
                ja: "中国ルール · \(preview.winner == .black ? "黒" : "白") +\(marginStr)目（\(ziMarginStr)子）",
                ko: "중국 규칙 · \(preview.winner == .black ? "흑" : "백") +\(marginStr)집（\(ziMarginStr)자）",
                zhHant: "數子法 · 黑 \(blackZi) 子（過 \(needZi) 勝）· \(preview.winner == .black ? "黑勝" : "白勝") \(ziStr)"
            )
        } else {
            let bScore = String(format: "%.1f", preview.blackScore)
            let wScore = String(format: "%.1f", preview.whiteScore)
            let komiStr = String(format: "%.1f", preview.komi)
            return l10n.localized(
                zh: "数目法 · 黑 \(preview.blackTerritory)空+\(preview.blackCaptures)提=\(bScore) · 白 \(preview.whiteTerritory)空+\(preview.whiteCaptures)提+\(komiStr)贴=\(wScore) · \(preview.winner == .black ? "黑胜" : "白胜") \(marginStr) 目",
                en: "Japanese · B \(preview.blackTerritory)+\(preview.blackCaptures)=\(bScore) · W \(preview.whiteTerritory)+\(preview.whiteCaptures)+\(komiStr)=\(wScore) · \(preview.winner == .black ? "Black" : "White") +\(marginStr) pts",
                ja: "日本・韓国ルール · 黒 \(preview.blackTerritory)+\(preview.blackCaptures)=\(bScore) · 白 \(preview.whiteTerritory)+\(preview.whiteCaptures)+\(komiStr)=\(wScore) · \(preview.winner == .black ? "黒" : "白") +\(marginStr)目",
                ko: "한·일 규칙 · 흑 \(preview.blackTerritory)+\(preview.blackCaptures)=\(bScore) · 백 \(preview.whiteTerritory)+\(preview.whiteCaptures)+\(komiStr)=\(wScore) · \(preview.winner == .black ? "흑" : "백") +\(marginStr)집",
                zhHant: "數目法 · 黑 \(preview.blackTerritory)空+\(preview.blackCaptures)提=\(bScore) · 白 \(preview.whiteTerritory)空+\(preview.whiteCaptures)提+\(komiStr)貼=\(wScore) · \(preview.winner == .black ? "黑勝" : "白勝") \(marginStr) 目"
            )
        }
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
                    .font(AppFont.rounded(size: 14, weight: .regular))
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let scenario = viewModel.tacticalScenario {
                    HStack(spacing: 6) {
                        Text(scenario.title(isChinese: l10n.language.isChinese))
                            .font(AppFont.rounded(size: 12, weight: .black))
                            .foregroundColor(AppTheme.coralBottom)
                        if let progressText = viewModel.scenarioProgressSummary {
                            Text(progressText)
                                .font(AppFont.rounded(size: 10.5, weight: .black))
                                .foregroundColor(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(AppTheme.coralBottom))
                        }
                    }
                    Text(scenario.briefing(isChinese: l10n.language.isChinese))
                        .font(AppFont.rounded(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                } else {
                    Text("\(l10n.t(difficulty.nameKey)) · \(difficulty.rankBadge)")
                        .font(AppFont.rounded(size: 12, weight: .black))
                        .foregroundColor(AppTheme.skyBottom)
                    Text(viewModel.companionDialogueText)
                        .font(AppFont.rounded(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
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
                    .font(AppFont.rounded(size: 15, weight: .heavy))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(1)
                Text("\(l10n.t("game.captures")): \(captures)")
                    .font(AppFont.rounded(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)
            }

            Spacer()

            GameClockPillView(
                clockDisplay: viewModel.clockDisplay,
                color: color,
                isActiveTurn: isActiveTurn
            )

            WoodenGoBowlView(capturedColor: color.opposite, count: captures)
        }
    }

    private var confirmPlacementBar: some View {
        Button {
            viewModel.confirmPendingPlacement()
        } label: {
            Label(l10n.t("game.action.confirmPlace"), systemImage: "checkmark.circle.fill")
                .font(AppFont.rounded(size: 15, weight: .black))
                .foregroundColor(.white)
                .shadow(color: AppTheme.skyRim.opacity(0.45), radius: 1, y: 1.5)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false))
        .accessibilityIdentifier("GameConfirmPlaceButton")
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
                    .font(.system(size: 16, weight: .black, design: .rounded))
                Text(title)
                    .font(AppFont.rounded(size: 14, weight: .heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity, minHeight: AppTheme.boardActionFaceHeight)
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
        return appState.settings.highlightAtari && !viewModel.cachedAtariPoints.isEmpty && !viewModel.isGameOver && !viewModel.isAIThinking
    }

    private var primaryStatusLine: String {
        if viewModel.isMarkingDeadStones { return l10n.t("game.deadStones.title") }
        if let banner = viewModel.statusBanner { return banner }
        if viewModel.isAIThinking, let diff = viewModel.aiDifficulty {
            return l10n.t("game.turn.aiThinking", l10n.t(diff.nameKey))
        }
        if appState.settings.highlightAtari && !viewModel.cachedAtariPoints.isEmpty && !viewModel.isGameOver {
            return l10n.t("game.status.atariWarning")
        }
        return l10n.t(viewModel.boardState.currentTurn == .black ? "game.turn.black" : "game.turn.white")
    }

    private func territoryBarContent(est: TerritoryEstimate) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("\(l10n.t("stone.black")): \(String(format: "%.1f", est.blackTotal))")
                    .font(AppFont.rounded(size: 11, weight: .heavy))
                    .foregroundColor(AppTheme.inkPrimary)
                Spacer()
                Text("\(l10n.t("stone.white")): \(String(format: "%.1f", est.whiteTotal))")
                    .font(AppFont.rounded(size: 11, weight: .heavy))
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
    let didHumanWin: Bool
    let isBossVictory: Bool
    let backButtonTitle: String
    let bestMove: Int?
    let bestMoveReason: BestMoveReason?
    let turningPoint: Int?
    let l10n: L10n
    let onRewind: (Int) -> Void
    let onPlayAgain: () -> Void
    let onReview: () -> Void
    let onBackHome: () -> Void

    var body: some View {
        ViewThatFits(in: .vertical) {
            resultCard
            ScrollView { resultCard }
        }
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            Text(isBossVictory ? "👑" : (didHumanWin ? "🏆" : "💪"))
                .font(AppFont.rounded(size: 56, weight: .regular))

            if isBossVictory {
                Text(l10n.t("result.bossDefeatedBadge"))
                    .font(AppFont.rounded(size: 13, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)))
            }

            VStack(spacing: 4) {
                Text(l10n.t(result.winner == .black ? "result.blackWins" : "result.whiteWins"))
                    .font(AppFont.rounded(size: 30, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                Text(resultSubtitle)
                    .font(AppFont.rounded(size: 17, weight: .heavy))
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
                        let baseTitle = l10n.t("result.bestMove", bestMove)
                        let fullTitle = bestMoveReason.map { "\(baseTitle) · \($0.badge(l10n))" } ?? baseTitle
                        Label(fullTitle, systemImage: "star.fill")
                            .font(AppFont.rounded(size: 14, weight: .heavy))
                            .foregroundColor(AppTheme.sunBottom)
                            .multilineTextAlignment(.center)
                    }
                    if let turningPoint {
                        Button {
                            onRewind(turningPoint)
                        } label: {
                            Label(l10n.t("result.rewindAction", turningPoint), systemImage: "hourglass")
                                .font(AppFont.rounded(size: 15, weight: .black))
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
                    Text(backButtonTitle)
                        .font(AppFont.rounded(size: 15, weight: .heavy))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button(action: onReview) {
                    Text(l10n.t("result.reviewGame"))
                        .font(AppFont.rounded(size: 15, weight: .heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button(action: onPlayAgain) {
                    Text(l10n.t("result.playAgain"))
                        .font(AppFont.rounded(size: 15, weight: .black))
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
                .font(AppFont.rounded(size: 26, weight: .black))
                .foregroundColor(AppTheme.inkPrimary)
            Text(title)
                .font(AppFont.rounded(size: 11, weight: .bold))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(AppTheme.canvasBackground))
    }
}

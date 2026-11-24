//
//  PuzzlePlayView.swift
//  StarYi Go — Glossy Nintendo Switch Party Puzzle Arena
//

import SwiftUI

struct PuzzlePlayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: PuzzleViewModel
    @State private var inspectedTerm: GoCodexEntry? = nil

    init(puzzle: GoPuzzle, appState: AppState, isDailyChallenge: Bool = false, isStarterBootcamp: Bool = false) {
        _viewModel = StateObject(
            wrappedValue: PuzzleViewModel(
                puzzle: puzzle,
                appState: appState,
                isDailyChallenge: isDailyChallenge,
                isStarterBootcamp: isStarterBootcamp
            )
        )
    }

    private var l10n: L10n { appState.l10n }
    private let topBarHeight: CGFloat = 60

    private var isSolved: Bool {
        if case .solved = viewModel.status { return true }
        return false
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let isCompact = w < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        GameTitleCrest(
                            title: viewModel.puzzle.title(l10n),
                            subtitle: headerSubtitle
                        )
                        Spacer()
                        HStack(spacing: 8) {
                            if !viewModel.isExamMode {
                                GameCircleButton(
                                    icon: viewModel.showHintText ? "lightbulb.fill" : "lightbulb",
                                    palette: viewModel.showHintText ? .sun : .snow,
                                    tint: viewModel.showHintText ? .white : AppTheme.inkPrimary,
                                    size: 44
                                ) {
                                    if viewModel.showHintText {
                                        viewModel.showHintText = false
                                        viewModel.highlightedHintPoint = nil
                                    } else {
                                        viewModel.showHint()
                                    }
                                }
                                .disabled(viewModel.status != .playing)
                                .opacity(viewModel.status != .playing ? 0.45 : 1)
                                .accessibilityLabel(l10n.t("puzzle.play.hint"))
                                .accessibilityIdentifier("PuzzleTopRightHintButton")
                            }

                            if !viewModel.isStarterBootcamp {
                                GameCircleButton(
                                    icon: "arrow.triangle.2.circlepath",
                                    palette: viewModel.activeTransform.isIdentity ? .snow : .grape,
                                    tint: viewModel.activeTransform.isIdentity ? AppTheme.inkPrimary : .white,
                                    size: 44
                                ) {
                                    viewModel.shuffleTransform()
                                }
                                .accessibilityLabel(l10n.localized(zh: "旋转/黑白互换", en: "Rotate & Flip", ja: "回転・白黒反転", ko: "회전·흑백 반전", zhHant: "旋轉/黑白互換"))

                                GameCircleButton(
                                    icon: viewModel.isExamMode ? "eye.slash.fill" : "eye.fill",
                                    palette: viewModel.isExamMode ? .coral : .snow,
                                    tint: viewModel.isExamMode ? .white : AppTheme.inkPrimary,
                                    size: 44
                                ) {
                                    viewModel.isExamMode.toggle()
                                }
                                .accessibilityLabel(l10n.localized(zh: "无辅助考场模式", en: "Exam Mode", ja: "補助なし試験モード", ko: "무보조 시험 모드", zhHant: "無輔助考場模式"))
                            }
                        }
                    }
                    .frame(height: topBarHeight)

                    if isCompact {
                        let boardSide = max(0, min(w - pad * 2, h * 0.48))
                        puzzleBoard
                            .frame(width: boardSide, height: boardSide)
                        ScrollView(showsIndicators: false) {
                            puzzleSidePanel
                        }
                    } else {
                        let sidebarWidth = min(390, max(324, w * 0.32))
                        let boardSide = max(260, min(w - sidebarWidth - pad * 3, h - topBarHeight - pad * 2 - 12))
                        HStack(spacing: pad) {
                            puzzleBoard
                                .frame(width: boardSide, height: boardSide)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            ScrollView(showsIndicators: false) {
                                puzzleSidePanel
                            }
                            .scrollBounceBehavior(.basedOnSize)
                            .frame(width: sidebarWidth)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
                .frame(width: w, height: h)
            }

            if isSolved {
                ConfettiBurstView()
                    .ignoresSafeArea()
                    .zIndex(15)
            }

            if let term = inspectedTerm {
                Color(red: 0.08, green: 0.14, blue: 0.26).opacity(0.42)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { inspectedTerm = nil }
                    }
                    .transition(.opacity)
                    .zIndex(20)

                GoTermQuickCard(
                    entry: term,
                    l10n: l10n,
                    onOpenCodex: {
                        inspectedTerm = nil
                        appState.navigationPath.append(.codex)
                    },
                    onDismiss: {
                        withAnimation(.spring(response: 0.26, dampingFraction: 0.8)) { inspectedTerm = nil }
                    }
                )
                .padding(24)
                .transition(.scale(scale: 0.90).combined(with: .opacity))
                .zIndex(25)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: inspectedTerm)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var headerSubtitle: String {
        if viewModel.isDailyChallenge { return l10n.t("home.dailyCard.title") }
        if viewModel.isStarterBootcamp { return l10n.t("home.starterCamp") }
        return viewModel.puzzle.rankBadge
    }

    private var puzzleBoard: some View {
        // Keep board crutches hidden by default on real puzzles; Starter Bootcamp lessons or top-right Hint reveal them.
        let showCrutches = (viewModel.isStarterBootcamp || viewModel.showHintText) && !appState.settings.zenDojoMode && !viewModel.isExamMode
        return GoBoardView(
            boardState: viewModel.boardState,
            theme: appState.settings.boardTheme,
            stoneStyle: appState.settings.stoneStyle,
            cropRegion: viewModel.effectiveCropRegion,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: showCrutches && appState.settings.highlightAtari,
            expressiveStones: showCrutches && appState.settings.expressiveStones,
            showLiveLiberties: showCrutches && (appState.settings.showLiveLiberties || viewModel.isStarterBootcamp),
            showTwoEyeGlow: showCrutches,
            puzzleHintPoint: viewModel.highlightedHintPoint,
            previewColor: viewModel.effectivePlayerColor,
            isInteractive: viewModel.status == .playing || (viewModel.status == .wrong && viewModel.isExploringFailure),
            capturedFlashPoints: viewModel.lastCapturedPoints,
            captureEventID: viewModel.captureEventID,
            illegalFlashPoint: viewModel.illegalFlashPoint,
            illegalEventID: viewModel.illegalEventID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
            onSelectPoint: { pt in
                viewModel.handleTap(at: pt)
            }
        )
    }

    private var puzzleSidePanel: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(viewModel.puzzle.rankBadge)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))

                    Text(l10n.t(viewModel.effectivePlayerColor == .black ? "puzzle.play.blackToPlay" : "puzzle.play.whiteToPlay"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.canvasBackground))

                    if viewModel.isExamMode {
                        Text(l10n.localized(zh: "考场模式", en: "Exam", ja: "試験モード", ko: "시험 모드", zhHant: "考場模式"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.coralBottom))
                    }

                    Spacer()

                    Text(l10n.t("puzzle.play.attempts", viewModel.attempts))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }

                Text(viewModel.isStarterBootcamp || viewModel.showHintText || isSolved
                     ? viewModel.puzzle.title(l10n)
                     : viewModel.puzzle.category.displayTitle(isChinese: l10n.language.isChinese))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                Text(viewModel.isStarterBootcamp || viewModel.showHintText || isSolved
                     ? viewModel.puzzle.prompt(l10n, activeColor: viewModel.effectivePlayerColor)
                     : l10n.localized(
                        zh: viewModel.effectivePlayerColor == .black ? "黑先：请找出盘面唯一正解（如实在卡关，可点右上角 💡 查看提示）。" : "白先：请找出盘面唯一正解（如实在卡关，可点右上角 💡 查看提示）。",
                        en: viewModel.effectivePlayerColor == .black ? "Black to play: Find the winning move (tap top-right 💡 only if stuck)." : "White to play: Find the winning move (tap top-right 💡 only if stuck).",
                        ja: viewModel.effectivePlayerColor == .black ? "黒先：最善の一手を見つけましょう（迷った時は右上の💡をタップ）。" : "白先：最善の一手を見つけましょう（迷った時は右上の💡をタップ）。",
                        ko: viewModel.effectivePlayerColor == .black ? "흑선: 최선의 한 수를 찾아보세요 (막힐 때만 우측 상단 💡 탭)." : "백선: 최선의 한 수를 찾아보세요 (막힐 때만 우측 상단 💡 탭).",
                        zhHant: viewModel.effectivePlayerColor == .black ? "黑先：請找出盤面唯一正解（如實在卡關，可點右上角 💡 查看提示）。" : "白先：請找出盤面唯一正解（如實在卡關，可點右上角 💡 查看提示）。"
                     ))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 26, padding: 18)

            // Fixed-height feedback slot (includes Authentic Go Term celebration card on solve!)
            ZStack {
                switch viewModel.status {
                case .solved(let stars):
                    VStack(spacing: 10) {
                        HStack(spacing: 8) {
                            ForEach(1...3, id: \.self) { idx in
                                Image(systemName: idx <= stars ? "star.fill" : "star")
                                    .font(.system(size: 32))
                                    .foregroundStyle(
                                        idx <= stars
                                        ? AnyShapeStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                        : AnyShapeStyle(AppTheme.subtleBorder)
                                    )
                            }
                        }
                        Text(l10n.t("puzzle.play.solved"))
                            .font(.system(size: 19, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.mintBottom)

                        // Authentic Go Term mastery badge (tap to see real-Go explanation + metaphor!)
                        if let term = viewModel.unlockedCodexEntry ?? viewModel.relatedCodexEntry {
                            Button {
                                SoundAndHapticsManager.shared.playUITap()
                                withAnimation(.spring(response: 0.26, dampingFraction: 0.78)) {
                                    inspectedTerm = term
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: term.symbolName)
                                        .font(.system(size: 12, weight: .black))
                                    Text(l10n.t("puzzle.play.learnedTerm", term.term(l10n)))
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(AppTheme.skyBottom)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .frame(minHeight: AppTheme.buttonFaceHeight)
                                .background(Capsule().fill(AppTheme.skyTop.opacity(0.14)))
                            }
                            .tactileButton(scale: 0.94, sound: false)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .warmCard(cornerRadius: 24, padding: 16)
                    .transition(.scale(scale: 0.88).combined(with: .opacity))

                case .wrong:
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppTheme.coralBottom)
                            Text(l10n.t("puzzle.play.tryAgain"))
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.coralBottom)
                        }
                        Text(l10n.localized(
                            zh: "可在棋盘继续试下 1~3 手看失败原因，或点下方查看正解！",
                            en: "Keep tapping the board to see why it fails, or watch the solution below!",
                            ja: "盤面で1〜3手試して失敗の理由を確認するか、下から正解図を見ましょう！",
                            ko: "바둑판에 1~3수 더 두어 실패 이유를 보거나 아래에서 정답을 확인하세요!",
                            zhHant: "可在棋盤繼續試下 1~3 手看失敗原因，或點下方查看正解！"
                        ))
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)

                        if !viewModel.isExamMode {
                            Button {
                                viewModel.playCorrectSolution()
                            } label: {
                                Label(l10n.localized(zh: "演示正解变化", en: "Play Solution", ja: "正解手順を再生", ko: "정답 수순 재생", zhHant: "演示正解變化"), systemImage: "play.circle.fill")
                                    .font(.system(size: 12.5, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 7)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .warmCard(cornerRadius: 24, padding: 14)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))

                case .playingSolution:
                    VStack(spacing: 8) {
                        ProgressView().tint(AppTheme.skyBottom)
                        Text(l10n.localized(zh: "正在演示正解变化图...", en: "Playing official solution...", ja: "正解手順を再生中...", ko: "정답 변화도를 재생하는 중...", zhHant: "正在演示正解變化圖..."))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.skyBottom)
                    }
                    .frame(maxWidth: .infinity)
                    .warmCard(cornerRadius: 24, padding: 16)

                case .playing, .opponentResponding:
                    if viewModel.showHintText {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 20))
                                .foregroundColor(AppTheme.sunBottom)
                            Text(viewModel.puzzle.hint(l10n))
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(AppTheme.softGoldBg)
                                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                        )
                        .transition(.opacity)
                    } else {
                        Text(l10n.t("game.libertiesTip"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .animation(.spring(response: 0.28, dampingFraction: 0.68), value: viewModel.status)
            .animation(.easeInOut(duration: 0.18), value: viewModel.showHintText)

            Spacer(minLength: 4)

            VStack(spacing: 12) {
                Button {
                    viewModel.resetCurrentPuzzle()
                } label: {
                    Label(l10n.t("puzzle.play.reset"), systemImage: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false))
                .environment(\.minimumButtonFaceHeight, AppTheme.boardActionFaceHeight)

                ZStack {
                    if case .solved = viewModel.status {
                        if let next = viewModel.nextPuzzleInLibrary() {
                            Button {
                                viewModel.loadPuzzle(next)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(l10n.t("puzzle.play.next"))
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 20))
                                }
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                            .environment(\.minimumButtonFaceHeight, AppTheme.boardActionFaceHeight)
                            .transition(.scale(scale: 0.90).combined(with: .opacity))
                        } else if viewModel.isStarterBootcamp {
                            Button {
                                appState.popRoute()
                                appState.startCaptureRaceQuickPlay(boardSize: .five, target: 3, difficulty: .sprout)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "flame.fill")
                                        .font(.system(size: 18, weight: .black))
                                    Text(l10n.t("islands.starterDock.captureQuick"))
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.coralRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                            .transition(.scale(scale: 0.90).combined(with: .opacity))
                        } else if viewModel.isDailyChallenge {
                            Button {
                                appState.popRoute()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18, weight: .black))
                                    Text(l10n.t("home.dailyCard.done"))
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.sunRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                            .transition(.scale(scale: 0.90).combined(with: .opacity))
                        } else {
                            Text(l10n.t("puzzle.play.allDone"))
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.mintBottom)
                        }
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 60)
                .animation(.spring(response: 0.28, dampingFraction: 0.68), value: viewModel.status)
            }
        }
    }
}

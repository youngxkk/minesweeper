//
//  PuzzlePlayView.swift
//  StarYi Go — Glossy Nintendo Switch Party Puzzle Arena
//

import SwiftUI

struct PuzzlePlayView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel: PuzzleViewModel
    @State private var inspectedTerm: GoCodexEntry? = nil

    init(
        puzzle: GoPuzzle,
        appState: AppState,
        isDailyChallenge: Bool = false,
        isStarterBootcamp: Bool = false,
        forceRandomTransform: Bool = false,
        dailyDojoQueueIds: [String] = []
    ) {
        _viewModel = StateObject(
            wrappedValue: PuzzleViewModel(
                puzzle: puzzle,
                appState: appState,
                isDailyChallenge: isDailyChallenge,
                isStarterBootcamp: isStarterBootcamp,
                forceRandomTransform: forceRandomTransform,
                dailyDojoQueueIds: dailyDojoQueueIds
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
            if viewModel.isDailyChallenge {
                SceneBackdrop.morningDojo
            } else {
                AppTheme.brightArenaBackground
            }

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
                            if !viewModel.isExamMode && !viewModel.isDailyChallenge {
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

                            if !viewModel.isStarterBootcamp && !viewModel.isDailyChallenge {
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
        if viewModel.isDailyChallenge {
            if let prog = viewModel.dailyDojoProgress {
                return l10n.localized(
                    zh: "每日道场 · 第 \(prog.current)/\(prog.total) 关",
                    en: "Daily Dojo · Stage \(prog.current)/\(prog.total)",
                    ja: "毎日道場 · 第\(prog.current)/\(prog.total)問",
                    ko: "매일 도장 · \(prog.current)/\(prog.total)단계",
                    zhHant: "每日道場 · 第 \(prog.current)/\(prog.total) 關"
                )
            }
            return l10n.t("home.dailyCard.title")
        }
        if viewModel.isStarterBootcamp { return l10n.t("home.starterCamp") }
        return viewModel.puzzle.rankBadge
    }

    private var puzzleBoard: some View {
        // Keep board crutches hidden by default on real puzzles; Daily Dojo never reveals crutches.
        let showCrutches = !viewModel.isDailyChallenge && (viewModel.isStarterBootcamp || viewModel.showHintText) && !appState.settings.zenDojoMode && !viewModel.isExamMode
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
                        .font(AppFont.rounded(size: 12, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))

                    Text(l10n.t(viewModel.effectivePlayerColor == .black ? "puzzle.play.blackToPlay" : "puzzle.play.whiteToPlay"))
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundColor(AppTheme.inkPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(AppTheme.canvasBackground))

                    if viewModel.isDailyChallenge {
                        Text(l10n.localized(zh: "无提示修行", en: "No-Hint Dojo", ja: "ヒントなし", ko: "힌트 없음", zhHant: "無提示修行"))
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.coralBottom))
                    } else if viewModel.isExamMode {
                        Text(l10n.localized(zh: "考场模式", en: "Exam", ja: "試験モード", ko: "시험 모드", zhHant: "考場模式"))
                            .font(AppFont.rounded(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(AppTheme.coralBottom))
                    }

                    Spacer()

                    Text(l10n.t("puzzle.play.attempts", viewModel.attempts))
                        .font(AppFont.rounded(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                }

                Text(viewModel.isStarterBootcamp || viewModel.showHintText || isSolved
                     ? viewModel.puzzle.title(l10n)
                     : viewModel.puzzle.category.displayTitle(isChinese: l10n.language.isChinese))
                    .font(AppFont.rounded(size: 22, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                Text(viewModel.isStarterBootcamp || viewModel.showHintText || isSolved
                     ? viewModel.puzzle.prompt(l10n, activeColor: viewModel.effectivePlayerColor)
                     : (viewModel.isDailyChallenge
                        ? l10n.localized(
                            zh: viewModel.effectivePlayerColor == .black
                                ? "黑先：靠自己动脑找出唯一正解！下错没关系，观察对手怎么反击，反复尝试直到想通！"
                                : "白先：靠自己动脑找出唯一正解！下错没关系，观察对手怎么反击，反复尝试直到想通！",
                            en: viewModel.effectivePlayerColor == .black
                                ? "Black to play: Think it through on your own! Mistakes show how the opponent punishes—keep trying!"
                                : "White to play: Think it through on your own! Mistakes show how the opponent punishes—keep trying!",
                            ja: viewModel.effectivePlayerColor == .black
                                ? "黒先：自分の頭で最善手を見つけよう！間違えても大丈夫、相手の反撃を見て何度でも挑戦！"
                                : "白先：自分の頭で最善手を見つけよう！間違えても大丈夫、相手の反撃を見て何度でも挑戦！",
                            ko: viewModel.effectivePlayerColor == .black
                                ? "흑선: 스스로 생각해 최선의 수를 찾아보세요! 틀려도 괜찮아요, 상대 반격을 보고 계속 도전!"
                                : "백선: 스스로 생각해 최선의 수를 찾아보세요! 틀려도 괜찮아요, 상대 반격을 보고 계속 도전!",
                            zhHant: viewModel.effectivePlayerColor == .black
                                ? "黑先：靠自己動腦找出唯一正解！下錯沒關係，觀察對手怎麼反擊，反覆嘗試直到想通！"
                                : "白先：靠自己動腦找出唯一正解！下錯沒關係，觀察對手怎麼反擊，反覆嘗試直到想通！"
                        )
                        : l10n.localized(
                            zh: viewModel.effectivePlayerColor == .black ? "黑先：请找出盘面唯一正解（如实在卡关，可点右上角 💡 查看提示）。" : "白先：请找出盘面唯一正解（如实在卡关，可点右上角 💡 查看提示）。",
                            en: viewModel.effectivePlayerColor == .black ? "Black to play: Find the winning move (tap top-right 💡 only if stuck)." : "White to play: Find the winning move (tap top-right 💡 only if stuck).",
                            ja: viewModel.effectivePlayerColor == .black ? "黒先：最善の一手を見つけましょう（迷った時は右上の💡をタップ）。" : "白先：最善の一手を見つけましょう（迷った時は右上の💡をタップ）。",
                            ko: viewModel.effectivePlayerColor == .black ? "흑선: 최선의 한 수를 찾아보세요 (막힐 때만 우측 상단 💡 탭)." : "백선: 최선의 한 수를 찾아보세요 (막힐 때만 우측 상단 💡 탭).",
                            zhHant: viewModel.effectivePlayerColor == .black ? "黑先：請找出盤面唯一正解（如實在卡關，可點右上角 💡 查看提示）。" : "白先：請找出盤面唯一正解（如實在卡關，可點右上角 💡 查看提示）。"
                        )))
                    .font(AppFont.rounded(size: 15, weight: .semibold))
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
                        if viewModel.isDailyChallenge {
                            let isFirstTry = viewModel.wrongCount == 0
                            HStack(spacing: 6) {
                                Image(systemName: isFirstTry ? "crown.fill" : "flame.fill")
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                Text(isFirstTry
                                     ? l10n.localized(zh: "一击必杀 · 金冠通关！", en: "One-Shot Gold Crown!", ja: "一撃クリア・金冠！", ko: "원샷 금관 클리어!", zhHant: "一擊必殺 · 金冠通關！")
                                     : l10n.localized(
                                        zh: "百折不挠 · 试了 \(viewModel.wrongCount + 1) 次靠自己解出！",
                                        en: "Unstoppable! Solved on try #\(viewModel.wrongCount + 1)!",
                                        ja: "不屈の精神！\(viewModel.wrongCount + 1)回目で自力クリア！",
                                        ko: "불굴의 도전! \(viewModel.wrongCount + 1)번 만에 스스로 해결!",
                                        zhHant: "百折不撓 · 試了 \(viewModel.wrongCount + 1) 次靠自己解出！"
                                     ))
                                    .font(AppFont.rounded(size: 13.5, weight: .black))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(
                                    LinearGradient(
                                        colors: isFirstTry ? [AppTheme.sunTop, AppTheme.sunBottom] : [AppTheme.coralTop, AppTheme.coralBottom],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            )
                        } else {
                            HStack(spacing: 8) {
                                ForEach(1...3, id: \.self) { idx in
                                    Image(systemName: idx <= stars ? "star.fill" : "star")
                                        .font(.system(size: 32, design: .rounded))
                                        .foregroundStyle(
                                            idx <= stars
                                            ? AnyShapeStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                            : AnyShapeStyle(AppTheme.subtleBorder)
                                        )
                                }
                            }
                        }
                        Text(l10n.t("puzzle.play.solved"))
                            .font(AppFont.rounded(size: 19, weight: .black))
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
                                        .font(.system(size: 12, weight: .black, design: .rounded))
                                    Text(l10n.t("puzzle.play.learnedTerm", term.term(l10n)))
                                        .font(AppFont.rounded(size: 12, weight: .black))
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 12, design: .rounded))
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
                                .font(.system(size: 22, design: .rounded))
                                .foregroundColor(AppTheme.coralBottom)
                            Text(viewModel.isDailyChallenge
                                 ? l10n.localized(
                                    zh: "第 \(viewModel.wrongCount) 次试错！看看对手怎么反击",
                                    en: "Attempt #\(viewModel.wrongCount)! See how the opponent refutes it",
                                    ja: "\(viewModel.wrongCount)回目の挑戦！相手の反撃を見よう",
                                    ko: "\(viewModel.wrongCount)번째 시도! 상대의 반격을 확인해요",
                                    zhHant: "第 \(viewModel.wrongCount) 次試錯！看看對手怎麼反擊"
                                 )
                                 : l10n.t("puzzle.play.tryAgain"))
                                .font(AppFont.rounded(size: 14, weight: .heavy))
                                .foregroundColor(AppTheme.coralBottom)
                        }
                        Text(viewModel.isDailyChallenge
                             ? (viewModel.wrongCount >= 5
                                ? l10n.localized(
                                    zh: "高手都是反复试出来的！观察刚才被反杀的漏洞，换个方向再试试！",
                                    en: "Masters are built by trying again! Spot what went wrong and try a new direction!",
                                    ja: "名人も何度もの失敗から生まれます！別の方向から試してみよう！",
                                    ko: "고수도 여러 번 시도하며 성장해요! 다른 방향으로 다시 도전해 보세요!",
                                    zhHant: "高手都是反覆試出來的！觀察剛才被反殺的漏洞，換個方向再試試！"
                                )
                                : l10n.localized(
                                    zh: "可以在棋盘继续点 1~3 手看失败原因，想清楚后立刻重来！",
                                    en: "Tap 1–3 follow-up moves to see why it fails, then reset and try again!",
                                    ja: "盤面で1〜3手試して失敗の理由を確認したら、すぐ再挑戦しよう！",
                                    ko: "1~3수 더 두어 실패 이유를 확인한 뒤 바로 다시 도전해 보세요!",
                                    zhHant: "可以在棋盤繼續點 1~3 手看失敗原因，想清楚後立刻重來！"
                                ))
                             : l10n.localized(
                                zh: "可在棋盘继续试下 1~3 手看失败原因，或点下方查看正解！",
                                en: "Keep tapping the board to see why it fails, or watch the solution below!",
                                ja: "盤面で1〜3手試して失敗の理由を確認するか、下から正解図を見ましょう！",
                                ko: "바둑판에 1~3수 더 두어 실패 이유를 보거나 아래에서 정답을 확인하세요!",
                                zhHant: "可在棋盤繼續試下 1~3 手看失敗原因，或點下方查看正解！"
                             ))
                        .font(AppFont.rounded(size: 11.5, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)

                        if viewModel.isDailyChallenge {
                            HStack(spacing: 8) {
                                Button {
                                    viewModel.resetCurrentPuzzle()
                                } label: {
                                    Label(l10n.localized(zh: "立刻再试一次", en: "Try Again Now", ja: "すぐ再挑戦", ko: "바로 다시 도전", zhHant: "立刻再試一次"), systemImage: "arrow.counterclockwise")
                                        .font(AppFont.rounded(size: 12.5, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                }
                                .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))

                                if viewModel.wrongCount >= 5 {
                                    Button {
                                        appState.recordPuzzleMistake(puzzleId: viewModel.puzzle.id, isStarterBootcamp: false)
                                        appState.popRoute()
                                    } label: {
                                        Text(l10n.localized(zh: "先收错题本", en: "Save for Later", ja: "復習帳へ", ko: "오답노트에 저장", zhHant: "先收錯題本"))
                                            .font(AppFont.rounded(size: 12, weight: .heavy))
                                            .foregroundColor(AppTheme.inkSecondary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(Capsule().fill(AppTheme.canvasBackground))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if !viewModel.isExamMode {
                            Button {
                                viewModel.playCorrectSolution()
                            } label: {
                                Label(l10n.localized(zh: "演示正解变化", en: "Play Solution", ja: "正解手順を再生", ko: "정답 수순 재생", zhHant: "演示正解變化"), systemImage: "play.circle.fill")
                                    .font(AppFont.rounded(size: 12.5, weight: .black))
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
                            .font(AppFont.rounded(size: 14, weight: .black))
                            .foregroundColor(AppTheme.skyBottom)
                    }
                    .frame(maxWidth: .infinity)
                    .warmCard(cornerRadius: 24, padding: 16)

                case .playing, .opponentResponding:
                    if viewModel.showHintText {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 20, design: .rounded))
                                .foregroundColor(AppTheme.sunBottom)
                            Text(viewModel.puzzle.hint(l10n))
                                .font(AppFont.rounded(size: 14, weight: .bold))
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
                            .font(AppFont.rounded(size: 13, weight: .semibold))
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
                        .font(AppFont.rounded(size: 15, weight: .heavy))
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
                                        .font(AppFont.rounded(size: 18, weight: .black))
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 20, design: .rounded))
                                }
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.mintRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                            .environment(\.minimumButtonFaceHeight, AppTheme.boardActionFaceHeight)
                            .transition(.scale(scale: 0.90).combined(with: .opacity))
                        } else if viewModel.isDailyChallenge {
                            Button {
                                appState.popRoute()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 18, weight: .black, design: .rounded))
                                    Text(l10n.localized(
                                        zh: "返回每日道场",
                                        en: "Back to Daily Dojo",
                                        ja: "毎日道場へ戻る",
                                        ko: "매일 도장으로",
                                        zhHant: "返回每日道場"
                                    ))
                                        .font(AppFont.rounded(size: 17, weight: .black))
                                }
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.sunRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                            .transition(.scale(scale: 0.90).combined(with: .opacity))
                        } else {
                            Button {
                                viewModel.shuffleTransform()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 17, weight: .black, design: .rounded))
                                    Text(l10n.localized(
                                        zh: "换个角度再练一次",
                                        en: "Flip & Practice Again",
                                        ja: "向きを変えてもう一度",
                                        ko: "방향 바꿔 다시 연습",
                                        zhHant: "換個角度再練一次"
                                    ))
                                    .font(AppFont.rounded(size: 16, weight: .black))
                                }
                                .foregroundColor(.white)
                                .shadow(color: AppTheme.skyRim.opacity(0.45), radius: 1, y: 1.5)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5))
                            .environment(\.minimumButtonFaceHeight, AppTheme.boardActionFaceHeight)
                            .transition(.scale(scale: 0.90).combined(with: .opacity))
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

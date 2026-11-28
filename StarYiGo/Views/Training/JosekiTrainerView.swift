//
//  JosekiTrainerView.swift
//  StarYi Go — Interactive Multi-Branch Joseki Explorer & Quizzer (P2)
//

import SwiftUI

struct JosekiTrainerView: View {
    @EnvironmentObject var appState: AppState
    let course: JosekiCourse
    var campaignNodeId: String? = nil

    enum Mode: String, CaseIterable {
        case learn
        case quiz
    }

    @State private var mode: Mode = .learn
    @State private var boardState: GoBoardState
    @State private var rootNode: SGFNode?
    @State private var currentNode: SGFNode?
    @State private var moveHistory: [(GoBoardState, SGFNode)] = []
    @State private var isQuizCompleted: Bool = false
    @State private var quizWrongMessage: String? = nil
    @State private var aiTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }

    init(course: JosekiCourse, campaignNodeId: String? = nil) {
        self.course = course
        self.campaignNodeId = campaignNodeId
        _boardState = State(initialValue: GoBoardState(size: course.boardSize, komi: 7.5, startingTurn: course.playerColor))
    }

    private var branchLabels: [BoardPoint: String] {
        guard mode == .learn, let node = currentNode else { return [:] }
        var map: [BoardPoint: String] = [:]
        let letters = ["A", "B", "C", "D"]
        var idx = 0
        for child in node.children {
            if let mv = child.move, case .place(let pt) = mv.action {
                let isWrong = (child.comment ?? "").uppercased().contains("WRONG")
                if isWrong {
                    map[pt] = "✕"
                } else {
                    map[pt] = idx < letters.count ? letters[idx] : "•"
                    idx += 1
                }
            }
        }
        return map
    }

    private var currentComment: String {
        if let wrong = quizWrongMessage { return wrong }
        let raw = currentNode?.comment ?? ""
        return raw.replacingOccurrences(of: "CORRECT", with: "").replacingOccurrences(of: "WRONG", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            if campaignNodeId == nil {
                SceneBackdrop.morningDojo
            } else {
                AppTheme.brightArenaBackground
            }

            GeometryReader { geo in
                let isCompact = geo.size.width < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    ZStack {
                        GameTitleCrest(title: course.title(l10n), subtitle: course.rankBadge)

                        HStack {
                            GameBackButton(title: l10n.t("common.back")) {
                                appState.popRoute()
                            }
                            Spacer()
                            HStack(spacing: 6) {
                                modePill(.learn, title: l10n.localized(zh: "演示学习", en: "Learn", ja: "学習モード", ko: "학습 모드", zhHant: "演示學習"))
                                modePill(.quiz, title: l10n.localized(zh: "闯关测验", en: "Quiz", ja: "テスト", ko: "퀴즈", zhHant: "闖關測驗"))
                            }
                        }
                    }

                    if isCompact {
                        let side = min(geo.size.width - pad * 2, geo.size.height * 0.46)
                        josekiBoard.frame(width: side, height: side)
                        ScrollView { sidePanel }
                    } else {
                        let sideW: CGFloat = min(380, max(320, geo.size.width * 0.33))
                        let boardSide = max(260, min(geo.size.width - sideW - pad * 3, geo.size.height - 92))
                        HStack(spacing: pad) {
                            josekiBoard
                                .frame(width: boardSide, height: boardSide)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            ScrollView { sidePanel }
                                .frame(width: sideW)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { resetCourse() }
        .onDisappear { aiTask?.cancel() }
    }

    private func modePill(_ m: Mode, title: String) -> some View {
        let active = mode == m
        return Button {
            mode = m
            resetCourse()
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            Text(title)
                .font(AppFont.rounded(size: 12, weight: .black))
                .foregroundColor(active ? .white : AppTheme.inkPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: active ? .grape : .snow, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2, playTapSound: false))
    }

    private var josekiBoard: some View {
        GoBoardView(
            boardState: boardState,
            theme: appState.settings.boardTheme,
            cropRegion: course.cropRegion,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: true,
            expressiveStones: false,
            showTwoEyeGlow: false,
            labeledPoints: branchLabels,
            previewColor: boardState.currentTurn,
            isInteractive: true,
            onSelectPoint: { pt in
                handleTap(at: pt)
            }
        )
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(mode == .learn
                     ? l10n.localized(zh: "探索分支（点棋盘 A/B 或下方按钮）", en: "Explore Branches (Tap A/B on board or below)", ja: "変化を探索（盤上の A/B または下のボタンをタップ）", ko: "변화 탐색 (바둑판 위 A/B 또는 아래 버튼 선택)", zhHant: "探索分支（點棋盤 A/B 或下方按鈕）")
                     : l10n.localized(zh: "定式闯关：轮到你走正确定式！", en: "Joseki Quiz: Play the correct Joseki moves!", ja: "定石テスト：正しい定石の手を打ちましょう！", ko: "정석 퀴즈: 올바른 정석 수순을 두어 보세요!", zhHant: "定石闖關：輪到你走正確定石！"))
                    .font(AppFont.rounded(size: 12, weight: .black))
                    .foregroundColor(AppTheme.grapeBottom)

                Text(currentComment.isEmpty ? course.subtitle(l10n) : currentComment)
                    .font(AppFont.rounded(size: 14, weight: .bold))
                    .foregroundColor(quizWrongMessage != nil ? AppTheme.coralBottom : AppTheme.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 22, padding: 14)

            if isQuizCompleted {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 24, design: .rounded))
                            .foregroundColor(AppTheme.mintBottom)
                        Text(l10n.localized(zh: "定式通关！+20 🪙 已记录掌握", en: "Joseki Cleared! +20 🪙 Mastered", ja: "定石クリア！+20 🪙 習得済み", ko: "정석 클리어! +20 🪙 마스터 기록", zhHant: "定石通關！+20 🪙 已記錄掌握"))
                            .font(AppFont.rounded(size: 14.5, weight: .black))
                            .foregroundColor(AppTheme.mintBottom)
                    }

                    if let nodeId = campaignNodeId, let nextNode = StarYiCampaign.nextNode(after: nodeId) {
                        Button {
                            appState.navigateToCampaignNode(nextNode, replaceTopRoute: true)
                        } label: {
                            Text(l10n.localized(
                                zh: "进入下一关 · \(nextNode.title(isChinese: true)) ▶",
                                en: "Next Stage · \(nextNode.title(isChinese: false)) ▶",
                                ja: "次のステージへ ▶",
                                ko: "다음 스테이지 ▶",
                                zhHant: "進入下一關 · \(nextNode.title(isChinese: true)) ▶"
                            ))
                                .font(AppFont.rounded(size: 14.5, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                    } else if let nodeId = campaignNodeId, let island = StarYiCampaign.island(containingNodeId: nodeId) {
                        Button {
                            if !appState.navigationPath.isEmpty {
                                appState.navigationPath.removeLast()
                            }
                            appState.startCampaignBossMatch(island: island)
                        } label: {
                            Text(l10n.localized(
                                zh: "挑战守岛 Boss ▶",
                                en: "Challenge Island Boss ▶",
                                ja: "島のボスに挑戦 ▶",
                                ko: "섬 보스 도전 ▶",
                                zhHant: "挑戰守島 Boss ▶"
                            ))
                                .font(AppFont.rounded(size: 14.5, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .warmCard(cornerRadius: 20, padding: 14)
            }

            if mode == .learn, let node = currentNode, !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(l10n.localized(zh: "可选后续分支", en: "Available Continuations", ja: "次の変化候補", ko: "선택 가능한 후속 변화", zhHant: "可選後續分支"))
                        .font(AppFont.rounded(size: 12, weight: .black))
                        .foregroundColor(AppTheme.inkSecondary)

                    ForEach(Array(node.children.enumerated()), id: \.offset) { idx, child in
                        if let mv = child.move, case .place(let pt) = mv.action {
                            let isWrong = (child.comment ?? "").uppercased().contains("WRONG")
                            Button {
                                stepInto(child: child)
                            } label: {
                                HStack {
                                    Text(isWrong ? "✕ \(pt.humanLabel(boardSize: course.boardSize))" : "\(idx + 1). \(pt.humanLabel(boardSize: course.boardSize))")
                                        .font(AppFont.rounded(size: 13.5, weight: .black))
                                    Spacer()
                                    Text(isWrong
                                         ? l10n.localized(zh: "常见错手", en: "Mistake", ja: "よくある悪手", ko: "자주 두는 실수", zhHant: "常見錯手")
                                         : l10n.localized(zh: "定式正着", en: "Joseki", ja: "定石の正着", ko: "정석 정착", zhHant: "定石正著"))
                                        .font(AppFont.rounded(size: 11, weight: .bold))
                                }
                                .foregroundColor(isWrong ? AppTheme.coralBottom : AppTheme.inkPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 16, rimHeight: 3, whiteBorderWidth: 2))
                        }
                    }
                }
                .warmCard(cornerRadius: 22, padding: 14)
            }

            HStack(spacing: 10) {
                Button {
                    stepBack()
                } label: {
                    Label(l10n.localized(zh: "退一步", en: "Back", ja: "1手戻る", ko: "한 수 뒤로", zhHant: "退一步"), systemImage: "arrow.uturn.backward")
                        .font(AppFont.rounded(size: 14, weight: .heavy))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                .disabled(moveHistory.count <= 1)

                Button {
                    resetCourse()
                } label: {
                    Label(l10n.localized(zh: "重来", en: "Reset", ja: "やり直す", ko: "처음부터", zhHant: "重來"), systemImage: "arrow.counterclockwise")
                        .font(AppFont.rounded(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
            }
        }
    }

    private func resetCourse() {
        aiTask?.cancel()
        quizWrongMessage = nil
        isQuizCompleted = false
        let root = SGFParser.parse(course.sgf(l10n))
        var st = GoBoardState(size: course.boardSize, komi: 7.5, startingTurn: course.playerColor)
        if let root {
            for pt in root.addedBlackPoints { st.setSetupStone(.black, at: pt) }
            for pt in root.addedWhitePoints { st.setSetupStone(.white, at: pt) }
            st.resetPositionHistoryToCurrent()
        }
        rootNode = root
        currentNode = root
        boardState = st
        moveHistory = root.map { [(st, $0)] } ?? []
    }

    private func stepBack() {
        guard moveHistory.count > 1 else { return }
        aiTask?.cancel()
        quizWrongMessage = nil
        moveHistory.removeLast()
        if let last = moveHistory.last {
            boardState = last.0
            currentNode = last.1
        }
        SoundAndHapticsManager.shared.playUndo()
    }

    private func handleTap(at point: BoardPoint) {
        guard let node = currentNode else { return }
        quizWrongMessage = nil

        if let matched = node.children.first(where: { ch in
            if let mv = ch.move, case .place(let p) = mv.action { return p == point }
            return false
        }) {
            stepInto(child: matched)
        } else if mode == .quiz {
            SoundAndHapticsManager.shared.playWrong()
            SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
            quizWrongMessage = l10n.localized(
                zh: "这步偏离了定式要点！试试紧贴角部或切换「演示学习」查看分支。",
                en: "Off-joseki move! Try closer to the corner or switch to Learn mode to see the branches.",
                ja: "定石の急所から外れています！隅に近い手を試すか「学習モード」で変化を確認しましょう。",
                ko: "정석의 요점에서 벗어났어요! 귀 쪽에 가깝게 두거나 「학습 모드」로 전환해 변화를 확인해 보세요.",
                zhHant: "這步偏離了定石要點！試試緊貼角部或切換「演示學習」查看分支。"
            )
        }
    }

    private func stepInto(child: SGFNode) {
        guard let mv = child.move else { return }
        guard case .success(let out) = boardState.applying(action: mv.action, color: mv.color) else { return }
        boardState = out.nextState
        currentNode = child
        moveHistory.append((out.nextState, child))
        SoundAndHapticsManager.shared.playStonePlace()

        let upperC = (child.comment ?? "").uppercased()
        if upperC.contains("WRONG") {
            SoundAndHapticsManager.shared.playWrong()
            SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
            return
        }
        if upperC.contains("CORRECT") || child.children.isEmpty {
            if mode == .quiz && !isQuizCompleted {
                isQuizCompleted = true
                appState.markJosekiCompleted(course.id)
                if let nodeId = campaignNodeId {
                    appState.recordCampaignNodeCleared(nodeId: nodeId, stars: 3, masteryTier: .normal)
                }
                SoundAndHapticsManager.shared.playSuccess()
                SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.14)
            } else {
                SoundAndHapticsManager.shared.playSuccess()
            }
            return
        }

        // In Quiz mode, AI automatically responds with a random valid opponent branch!
        if mode == .quiz {
            let oppBranches = child.children.filter {
                guard let m = $0.move else { return false }
                return m.color == course.playerColor.opposite && !(($0.comment ?? "").uppercased().contains("WRONG"))
            }
            if let oppNext = oppBranches.randomElement() {
                aiTask?.cancel()
                aiTask = Task {
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.stepInto(child: oppNext)
                    }
                }
            }
        }
    }
}

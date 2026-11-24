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
    private var isZh: Bool { l10n.language.isChinese }

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
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let isCompact = geo.size.width < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        GameTitleCrest(title: course.title(l10n), subtitle: course.rankBadge)
                        Spacer()
                        HStack(spacing: 6) {
                            modePill(.learn, title: isZh ? "演示学习" : "Learn")
                            modePill(.quiz, title: isZh ? "闯关测验" : "Quiz")
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
                .font(.system(size: 12, weight: .black, design: .rounded))
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
                     ? (isZh ? "探索分支（点棋盘 A/B 或下方按钮）" : "Explore Branches (Tap A/B on board or below)")
                     : (isZh ? "定式闯关：轮到你走正确定式！" : "Joseki Quiz: Play the correct Joseki moves!"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.grapeBottom)

                Text(currentComment.isEmpty ? course.subtitle(l10n) : currentComment)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(quizWrongMessage != nil ? AppTheme.coralBottom : AppTheme.inkPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 22, padding: 14)

            if isQuizCompleted {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppTheme.mintBottom)
                    Text(isZh ? "定式通关！+20 🪙 已记录掌握" : "Joseki Cleared! +20 🪙 Mastered")
                        .font(.system(size: 14.5, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.mintBottom)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .warmCard(cornerRadius: 20, padding: 14)
            }

            if mode == .learn, let node = currentNode, !node.children.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isZh ? "可选后续分支" : "Available Continuations")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)

                    ForEach(Array(node.children.enumerated()), id: \.offset) { idx, child in
                        if let mv = child.move, case .place(let pt) = mv.action {
                            let isWrong = (child.comment ?? "").uppercased().contains("WRONG")
                            Button {
                                stepInto(child: child)
                            } label: {
                                HStack {
                                    Text(isWrong ? "✕ \(pt.humanLabel(boardSize: course.boardSize))" : "\(idx + 1). \(pt.humanLabel(boardSize: course.boardSize))")
                                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                                    Spacer()
                                    Text(isWrong ? (isZh ? "常见错手" : "Mistake") : (isZh ? "定式正着" : "Joseki"))
                                        .font(.system(size: 11, weight: .bold, design: .rounded))
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
                    Label(isZh ? "退一步" : "Back", systemImage: "arrow.uturn.backward")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                .disabled(moveHistory.count <= 1)

                Button {
                    resetCourse()
                } label: {
                    Label(isZh ? "重来" : "Reset", systemImage: "arrow.counterclockwise")
                        .font(.system(size: 14, weight: .black, design: .rounded))
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
            quizWrongMessage = isZh ? "这步偏离了定式要点！试试紧贴角部或切换「演示学习」查看分支。" : "Off-joseki move! Try closer to the corner or switch to Learn mode to see the branches."
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
            isQuizCompleted = true
            appState.markJosekiCompleted(course.id)
            if let nodeId = campaignNodeId {
                appState.recordCampaignNodeCleared(nodeId: nodeId, stars: 3, masteryTier: .normal)
            }
            SoundAndHapticsManager.shared.playSuccess()
            SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.14)
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

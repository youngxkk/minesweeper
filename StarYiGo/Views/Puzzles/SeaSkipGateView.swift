//
//  SeaSkipGateView.swift
//  StarYi Go — Duolingo-Style Sea Skip Gate (Pass 4/5 Exam-Mode Puzzles to Jump Straight to Any Sea!)
//

import SwiftUI

struct SeaSkipGateView: View {
    @EnvironmentObject var appState: AppState
    let sea: CampaignSea

    @State private var index: Int = 0
    @State private var correctCount: Int = 0
    @State private var finished: Bool = false
    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var rootNode: SGFNode?
    @State private var currentNode: SGFNode?
    @State private var isLocked: Bool = false
    @State private var statusBanner: String? = nil
    @State private var replyTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }

    private var gatePuzzles: [GoPuzzle] {
        sea.skipGatePuzzleIds.compactMap { appState.findAnyPuzzle(withId: $0) }
    }

    private var currentPuzzle: GoPuzzle? {
        guard index < gatePuzzles.count else { return nil }
        return gatePuzzles[index]
    }

    private var didPass: Bool {
        correctCount >= sea.skipGatePassCount
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
                        GameTitleCrest(
                            title: isZh ? "🔑 跳级试炼门 · \(sea.nameZh)" : "🔑 Skip Gate · \(sea.nameEn)",
                            subtitle: isZh ? "无辅助考场 · 需答对 \(sea.skipGatePassCount)/\(gatePuzzles.count) 题直接解锁" : "Exam Mode · Pass \(sea.skipGatePassCount)/\(gatePuzzles.count) to unlock"
                        )
                        Spacer()
                    }

                    if finished {
                        Spacer()
                        resultCard.frame(maxWidth: 500)
                        Spacer()
                    } else if let puzzle = currentPuzzle {
                        HStack(spacing: 8) {
                            ForEach(0..<gatePuzzles.count, id: \.self) { i in
                                Capsule()
                                    .fill(i < index ? AppTheme.mintBottom : (i == index ? AppTheme.sunBottom : AppTheme.subtleBorder))
                                    .frame(height: 8)
                            }
                        }
                        .frame(maxWidth: 640)

                        if isCompact {
                            let side = min(geo.size.width - pad * 2, geo.size.height * 0.48)
                            gateBoard(puzzle).frame(width: side, height: side)
                            infoCard(puzzle)
                        } else {
                            let sideW = min(370, max(310, geo.size.width * 0.32))
                            let side = max(250, min(geo.size.width - sideW - pad * 3, geo.size.height - 132))
                            HStack(spacing: pad) {
                                gateBoard(puzzle)
                                    .frame(width: side, height: side)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                infoCard(puzzle).frame(width: sideW)
                            }
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
            }

            if finished && didPass {
                ConfettiBurstView()
                    .ignoresSafeArea()
                    .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadQuestion() }
        .onDisappear { replyTask?.cancel() }
    }

    private func gateBoard(_ puzzle: GoPuzzle) -> some View {
        GoBoardView(
            boardState: boardState,
            theme: appState.settings.boardTheme,
            cropRegion: puzzle.cropRegion,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: false,
            expressiveStones: false,
            showLiveLiberties: false,
            showTwoEyeGlow: false,
            isInteractive: !isLocked,
            onSelectPoint: { pt in handleTap(pt, puzzle: puzzle) }
        )
    }

    private func infoCard(_ puzzle: GoPuzzle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isZh ? "跳级第 \(index + 1)/\(gatePuzzles.count) 题" : "Gate Q\(index + 1)/\(gatePuzzles.count)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.sunBottom))
                    Text(puzzle.rankBadge)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                    Spacer()
                    Text(isZh ? "已对 \(correctCount) 题" : "\(correctCount) Passed")
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.mintBottom)
                }
                Text(puzzle.category.displayTitle(isChinese: isZh))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                Text(puzzle.playerColor == .black
                     ? (isZh ? "黑先：考场无提示模式，请找出盘面唯一正解。" : "Black to play: Exam mode (no hints) — find the winning move.")
                     : (isZh ? "白先：考场无提示模式，请找出盘面唯一正解。" : "White to play: Exam mode (no hints) — find the winning move."))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .warmCard(cornerRadius: 24, padding: 16)

            if let status = statusBanner {
                Text(status)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .warmCard(cornerRadius: 18, padding: 12)
            }
            Spacer(minLength: 0)
        }
    }

    private var resultCard: some View {
        VStack(spacing: 16) {
            Text(didPass ? "🔑✨" : "🧭").font(.system(size: 56))
            Text(didPass
                 ? (isZh ? "跳级成功！已解锁 \(sea.nameZh)" : "Gate Cleared! \(sea.nameEn) Unlocked!")
                 : (isZh ? "差一点点！答对 \(correctCount)/\(gatePuzzles.count) 题" : "Almost! Scored \(correctCount)/\(gatePuzzles.count)"))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
                .multilineTextAlignment(.center)
            Text(didPass
                 ? (isZh ? "你的实力已经足够驾驭这片海域！可以直接挑战本海域的岛屿与 Boss！" : "You've proven your strength — dive straight into this Sea!")
                 : (isZh ? "需要答对至少 \(sea.skipGatePassCount) 题才能跳级，可以先练几关再来挑战！" : "Score at least \(sea.skipGatePassCount) to skip ahead — try again anytime!"))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                if !didPass {
                    Button {
                        index = 0
                        correctCount = 0
                        finished = false
                        loadQuestion()
                    } label: {
                        Text(isZh ? "重新试炼" : "Try Again")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }
                Button {
                    appState.popRoute()
                } label: {
                    Text(didPass ? (isZh ? "扬帆起航 →" : "Set Sail →") : (isZh ? "返回地图" : "Back to Map"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
        }
        .padding(24)
        .warmCard(cornerRadius: 30, padding: 0)
    }

    private func loadQuestion() {
        replyTask?.cancel()
        guard let puzzle = currentPuzzle else { return }
        boardState = puzzle.initialBoardState()
        rootNode = puzzle.parsedRoot()
        currentNode = rootNode
        isLocked = false
        statusBanner = nil
    }

    private func handleTap(_ pt: BoardPoint, puzzle: GoPuzzle) {
        guard !isLocked, let node = currentNode else { return }
        guard case .success(let out) = boardState.applying(action: .place(pt), color: puzzle.playerColor) else {
            SoundAndHapticsManager.shared.playKoBounce()
            return
        }
        boardState = out.nextState
        SoundAndHapticsManager.shared.playStonePlace()

        let matched = node.children.first { ch in
            if let mv = ch.move, case .place(let cPt) = mv.action {
                return cPt == pt && mv.color == puzzle.playerColor
            }
            return false
        }
        guard let next = matched else {
            finishQuestion(passed: false)
            return
        }
        currentNode = next
        if let c = next.comment?.uppercased(), c.contains("CORRECT") {
            finishQuestion(passed: true)
            return
        }
        let oppMoves = next.children.filter { $0.move?.color == puzzle.playerColor.opposite }
        if let opp = oppMoves.randomElement(), let mv = opp.move {
            isLocked = true
            replyTask = Task {
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if case .success(let oppOut) = boardState.applying(action: mv.action, color: mv.color) {
                        boardState = oppOut.nextState
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                    currentNode = opp
                    isLocked = false
                    if let c = opp.comment?.uppercased() {
                        if c.contains("WRONG") { finishQuestion(passed: false) }
                        else if c.contains("CORRECT") { finishQuestion(passed: true) }
                    }
                }
            }
        } else {
            finishQuestion(passed: false)
        }
    }

    private func finishQuestion(passed: Bool) {
        isLocked = true
        if passed {
            correctCount += 1
            statusBanner = isZh ? "✅ 正解！" : "✅ Correct!"
            SoundAndHapticsManager.shared.playSuccess()
            if index + 1 < gatePuzzles.count {
                SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.10)
            }
        } else {
            statusBanner = isZh ? "❌ 本题未通过，继续下一题" : "❌ Missed — moving to next question"
            SoundAndHapticsManager.shared.playWrong()
            if index + 1 < gatePuzzles.count {
                SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
            }
        }
        replyTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if index + 1 < gatePuzzles.count {
                    index += 1
                    loadQuestion()
                } else {
                    finished = true
                    if didPass {
                        appState.unlockSeaViaSkipGate(seaId: sea.id)
                        SoundAndHapticsManager.shared.playVictoryFanfare()
                        SoundAndHapticsManager.shared.playVoice(.examPass, delay: 0.24)
                    } else {
                        SoundAndHapticsManager.shared.playVoice(.encourageLoss, delay: 0.18)
                    }
                }
            }
        }
    }
}

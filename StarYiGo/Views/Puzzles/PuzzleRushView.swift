//
//  PuzzleRushView.swift
//  StarYi Go — Endless Escalating Puzzle Rush (30K -> 5D, 3 Lives, Blitz 3m or Survival Mode!)
//

import SwiftUI

struct PuzzleRushView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum RushMode: String, CaseIterable {
        case blitz3m   // 3 minutes, 3 hearts
        case survival  // Untimed, 3 hearts
    }

    enum Phase: Equatable {
        case lobby
        case running
        case finished
    }

    @State private var rushMode: RushMode = .blitz3m
    @State private var phase: Phase = .lobby
    @State private var sequence: [GoPuzzle] = []
    @State private var currentIdx: Int = 0
    @State private var score: Int = 0
    @State private var hearts: Int = 3
    @State private var highestRankBadge: String = "30K"
    @State private var secondsRemaining: Int = 180
    @State private var rushTimer: Timer?

    // Active puzzle state
    @State private var activeTransform: PuzzleTransform = .identity
    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var rootNode: SGFNode?
    @State private var currentNode: SGFNode?
    @State private var isLocked: Bool = false
    @State private var flashResult: Bool? = nil // true = correct, false = wrong
    @State private var replyTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }

    private var currentPuzzle: GoPuzzle? {
        guard !sequence.isEmpty else { return nil }
        return sequence[currentIdx % sequence.count]
    }

    private var effectiveColor: StoneColor {
        guard let p = currentPuzzle else { return .black }
        return activeTransform.apply(to: p.playerColor)
    }

    private var effectiveCrop: BoardCropRegion {
        guard let p = currentPuzzle else { return .full(size: 9) }
        return activeTransform.apply(to: p.cropRegion, boardSize: p.boardSize)
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let isCompact = geo.size.width < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    topHeader

                    switch phase {
                    case .lobby:
                        ViewThatFits(in: .vertical) {
                            lobbyCard.frame(maxWidth: 560)
                            ScrollView { lobbyCard.frame(maxWidth: 560) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    case .running:
                        if isCompact {
                            let side = min(geo.size.width - pad * 2, geo.size.height * 0.48)
                            rushBoard.frame(width: side, height: side)
                            rushHudCard
                        } else {
                            let sideW = min(370, max(310, geo.size.width * 0.32))
                            let side = max(250, min(geo.size.width - sideW - pad * 3, geo.size.height - 96))
                            HStack(spacing: pad) {
                                rushBoard
                                    .frame(width: side, height: side)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                rushHudCard.frame(width: sideW)
                            }
                        }

                    case .finished:
                        ViewThatFits(in: .vertical) {
                            finishedCard.frame(maxWidth: 520)
                            ScrollView { finishedCard.frame(maxWidth: 520) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
            }

            if phase == .finished && score >= 5 {
                ConfettiBurstView()
                    .ignoresSafeArea()
                    .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear {
            rushTimer?.invalidate()
            replyTask?.cancel()
        }
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack {
            GameBackButton(title: l10n.t("common.back")) {
                rushTimer?.invalidate()
                replyTask?.cancel()
                appState.popRoute()
            }
            Spacer()
            GameTitleCrest(
                title: isZh ? "星辰无尽冲关" : "Endless Puzzle Rush",
                subtitle: isZh
                    ? "30K → 5D 步步升级 · 最高纪录 \(appState.puzzleProgress.bestPuzzleRushScore) 题 (\(appState.puzzleProgress.bestPuzzleRushRank))"
                    : "30K → 5D Escalating · Best \(appState.puzzleProgress.bestPuzzleRushScore) (\(appState.puzzleProgress.bestPuzzleRushRank))"
            )
            Spacer()
            if phase == .running {
                HStack(spacing: 10) {
                    if rushMode == .blitz3m {
                        let mm = secondsRemaining / 60
                        let ss = secondsRemaining % 60
                        Text(String(format: "⏱ %d:%02d", mm, ss))
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                            .foregroundColor(secondsRemaining <= 20 ? .white : AppTheme.coralBottom)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(secondsRemaining <= 20 ? AppTheme.coralBottom : Color.white))
                    }
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { i in
                            Image(systemName: i < hearts ? "heart.fill" : "heart")
                                .font(.system(size: 15, weight: .black))
                                .foregroundColor(i < hearts ? AppTheme.coralBottom : AppTheme.subtleBorder)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white))
                }
            }
        }
    }

    // MARK: - Lobby

    private var lobbyCard: some View {
        VStack(spacing: 18) {
            Text("🔥").font(.system(size: 56))
            Text(isZh ? "测测你的真实棋力上限！" : "Test Your True Reading Ceiling!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            Text(isZh
                 ? "从 30K 启蒙起步，每答对一题难度自动递增直至 5D！自动旋转与黑白互换防止背图，拥有 3 颗心容错。无论 25K、15K 还是高段，都能打出自己的极限纪录！"
                 : "Starts at 30K and escalates all the way to 5D with live rotation & color-swap! 3 hearts — built for every skill level from beginner to Dan!")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                modeOptionButton(
                    mode: .blitz3m,
                    icon: "bolt.fill",
                    title: isZh ? "3分钟极速冲刺" : "3-Min Blitz",
                    subtitle: isZh ? "紧张刺激 · 3颗心" : "Fast-paced · 3 ❤️"
                )
                modeOptionButton(
                    mode: .survival,
                    icon: "infinity",
                    title: isZh ? "无限时生存" : "Survival",
                    subtitle: isZh ? "从容深算 · 3颗心" : "Untimed · 3 ❤️"
                )
            }

            Button {
                startRush()
            } label: {
                Label(isZh ? "立即开始无尽冲关！" : "Start Puzzle Rush!", systemImage: "flame.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true))

            Button {
                SoundAndHapticsManager.shared.playUITap()
                GameCenterService.shared.presentLeaderboards()
            } label: {
                Label(
                    l10n.localized(zh: "全球排行榜 (Game Center)", en: "Global Leaderboards (Game Center)", ja: "世界ランキング (Game Center)", ko: "글로벌 랭킹 (Game Center)", zhHant: "全球排行榜 (Game Center)"),
                    systemImage: "trophy.fill"
                )
                .font(.system(size: 13.5, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.skyBottom)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .frame(minHeight: AppTheme.buttonFaceHeight)
                .background(Capsule().fill(AppTheme.skyTop.opacity(0.12)))
            }
            .tactileButton(scale: 0.95, sound: false)
        }
        .padding(24)
        .warmCard(cornerRadius: 30, padding: 0)
    }

    private func modeOptionButton(mode: RushMode, icon: String, title: String, subtitle: String) -> some View {
        let selected = rushMode == mode
        return Button {
            rushMode = mode
            SoundAndHapticsManager.shared.playUITap()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(selected ? .white : AppTheme.skyBottom)
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(selected ? .white : AppTheme.inkPrimary)
                Text(subtitle)
                    .font(.system(size: 11.5, weight: .bold, design: .rounded))
                    .foregroundColor(selected ? .white.opacity(0.92) : AppTheme.inkSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: selected ? .sky : .snow, cornerRadius: 22, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false, pressStyle: .card))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - Board & Live HUD

    private var rushBoard: some View {
        GoBoardView(
            boardState: boardState,
            theme: appState.settings.boardTheme,
            stoneStyle: appState.settings.stoneStyle,
            cropRegion: effectiveCrop,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: false,
            expressiveStones: false,
            showLiveLiberties: false,
            showTwoEyeGlow: false,
            isInteractive: phase == .running && !isLocked,
            onSelectPoint: { pt in
                handleTap(at: pt)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    flashResult == true ? AppTheme.mintBottom : (flashResult == false ? AppTheme.coralBottom : Color.clear),
                    lineWidth: 6
                )
                .allowsHitTesting(false)
        )
    }

    private var rushHudCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isZh ? "当前连闯" : "Solved")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                    Text("\(score)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                }
                Spacer()
                if let p = currentPuzzle {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(isZh ? "本题难度" : "Current Rank")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.inkSecondary)
                        Text(p.rankBadge)
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(AppTheme.grapeBottom))
                    }
                }
            }
            .warmCard(cornerRadius: 24, padding: 16)

            if let p = currentPuzzle {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(p.category.displayTitle(isChinese: isZh))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.skyBottom)
                        Spacer()
                        Text(effectiveColor == .black ? (isZh ? "⚫️ 黑先" : "⚫️ Black") : (isZh ? "⚪️ 白先" : "⚪️ White"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                    }
                    Text(p.category.displayTitle(isChinese: isZh))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(effectiveColor == .black
                         ? (isZh ? "黑先：不依赖提示，迅速找出盘面最佳一手！" : "Black to play: Spot the winning move with zero hints!")
                         : (isZh ? "白先：不依赖提示，迅速找出盘面最佳一手！" : "White to play: Spot the winning move with zero hints!"))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .warmCard(cornerRadius: 24, padding: 16)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Finished Card

    private var finishedCard: some View {
        VStack(spacing: 16) {
            Text(score >= 15 ? "🏆" : (score >= 8 ? "🌟" : "🔥")).font(.system(size: 56))
            Text(isZh ? "本次冲关成绩" : "Puzzle Rush Complete!")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                    Text(isZh ? "答对题数" : "Solved")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                Divider().frame(height: 44)
                VStack(spacing: 2) {
                    Text(highestRankBadge)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                    Text(isZh ? "触达最高棋力" : "Peak Rank")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button {
                    startRush()
                } label: {
                    Label(isZh ? "再来一局破纪录" : "Play Again", systemImage: "flame.fill")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button {
                    appState.popRoute()
                } label: {
                    Text(isZh ? "返回地图" : "Back to Map")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
        }
        .padding(24)
        .warmCard(cornerRadius: 30, padding: 0)
    }

    // MARK: - Rush Engine

    private func startRush() {
        rushTimer?.invalidate()
        replyTask?.cancel()
        sequence = PuzzlePackLoader.generatePuzzleRushSequence()
        currentIdx = 0
        score = 0
        hearts = 3
        highestRankBadge = "30K"
        secondsRemaining = 180
        phase = .running
        loadPuzzle()

        if rushMode == .blitz3m {
            rushTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                Task { @MainActor in
                    if secondsRemaining > 1 {
                        secondsRemaining -= 1
                    } else {
                        secondsRemaining = 0
                        endRush()
                    }
                }
            }
        }
    }

    private func loadPuzzle() {
        replyTask?.cancel()
        guard let p = currentPuzzle else { return }
        activeTransform = score >= 3 ? .random(allowColorSwap: true) : .identity
        boardState = p.initialBoardState(transform: activeTransform)
        rootNode = p.parsedRoot(transform: activeTransform)
        currentNode = rootNode
        isLocked = false
        flashResult = nil
    }

    private func handleTap(at point: BoardPoint) {
        guard phase == .running, !isLocked, let p = currentPuzzle, let node = currentNode else { return }
        guard case .success(let outcome) = boardState.applying(action: .place(point), color: effectiveColor) else {
            SoundAndHapticsManager.shared.playKoBounce()
            return
        }
        boardState = outcome.nextState
        SoundAndHapticsManager.shared.playStonePlace()

        let matched = node.children.first { ch in
            if let mv = ch.move, case .place(let pt) = mv.action {
                return pt == point && mv.color == effectiveColor
            }
            return false
        }

        guard let nextNode = matched else {
            markWrong(puzzle: p)
            return
        }
        currentNode = nextNode
        if let c = nextNode.comment?.uppercased(), c.contains("CORRECT") {
            markCorrect(puzzle: p)
            return
        }

        let oppMoves = nextNode.children.filter { $0.move?.color == effectiveColor.opposite }
        if let opp = oppMoves.randomElement(), let oppMove = opp.move {
            isLocked = true
            replyTask = Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if case .success(let out) = boardState.applying(action: oppMove.action, color: oppMove.color) {
                        boardState = out.nextState
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                    currentNode = opp
                    isLocked = false
                    if let c = opp.comment?.uppercased() {
                        if c.contains("WRONG") { markWrong(puzzle: p) }
                        else if c.contains("CORRECT") { markCorrect(puzzle: p) }
                    }
                }
            }
        } else {
            markWrong(puzzle: p)
        }
    }

    private func markCorrect(puzzle: GoPuzzle) {
        score += 1
        highestRankBadge = puzzle.rankBadge
        flashResult = true
        isLocked = true
        SoundAndHapticsManager.shared.playSuccess()
        if score == 3 {
            SoundAndHapticsManager.shared.playVoice(.combo3, delay: 0.06)
        } else if score >= 5 && score % 5 == 0 {
            SoundAndHapticsManager.shared.playVoice(.combo5, delay: 0.06)
        } else {
            SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.06)
        }
        replyTask = Task {
            try? await Task.sleep(nanoseconds: 340_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                currentIdx += 1
                loadPuzzle()
            }
        }
    }

    private func markWrong(puzzle: GoPuzzle) {
        hearts -= 1
        flashResult = false
        isLocked = true
        SoundAndHapticsManager.shared.playWrong()
        if hearts > 0 {
            SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.08)
        }
        appState.recordPuzzleMistake(puzzleId: puzzle.id, isStarterBootcamp: false)
        replyTask = Task {
            try? await Task.sleep(nanoseconds: 480_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if hearts <= 0 {
                    endRush()
                } else {
                    currentIdx += 1
                    loadPuzzle()
                }
            }
        }
    }

    private func endRush() {
        rushTimer?.invalidate()
        replyTask?.cancel()
        phase = .finished
        appState.recordPuzzleRushRun(score: score, highestRankBadge: highestRankBadge)
        if score >= 5 {
            SoundAndHapticsManager.shared.playVictoryFanfare()
            SoundAndHapticsManager.shared.playVoice(.victory, delay: 0.22)
        } else {
            SoundAndHapticsManager.shared.playVoice(.encourageLoss, delay: 0.16)
        }
    }
}

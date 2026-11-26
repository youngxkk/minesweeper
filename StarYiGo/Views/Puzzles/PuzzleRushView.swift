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
                title: l10n.localized(
                    zh: "星辰无尽冲关",
                    en: "Endless Puzzle Rush",
                    ja: "エンドレス連続挑戦",
                    ko: "무한 연속 도전",
                    zhHant: "星辰無盡衝關"
                ),
                subtitle: l10n.localized(
                    zh: "30K → 5D 步步升级 · 最高纪录 \(appState.puzzleProgress.bestPuzzleRushScore) 题 (\(appState.puzzleProgress.bestPuzzleRushRank))",
                    en: "30K → 5D Escalating · Best \(appState.puzzleProgress.bestPuzzleRushScore) (\(appState.puzzleProgress.bestPuzzleRushRank))",
                    ja: "30K → 5D 段階アップ · 最高記録 \(appState.puzzleProgress.bestPuzzleRushScore) 問 (\(appState.puzzleProgress.bestPuzzleRushRank))",
                    ko: "30K → 5D 난이도 상승 · 최고 기록 \(appState.puzzleProgress.bestPuzzleRushScore)문제 (\(appState.puzzleProgress.bestPuzzleRushRank))",
                    zhHant: "30K → 5D 步步升級 · 最高紀錄 \(appState.puzzleProgress.bestPuzzleRushScore) 題 (\(appState.puzzleProgress.bestPuzzleRushRank))"
                )
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
            Text(l10n.localized(
                zh: "测测你的真实棋力上限！",
                en: "Test Your True Reading Ceiling!",
                ja: "自分の本当の棋力限界に挑戦しよう！",
                ko: "당신의 진짜 기력 한계를 테스트해 보세요!",
                zhHant: "測測你的真實棋力上限！"
            ))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            Text(l10n.localized(
                zh: "从 30K 启蒙起步，每答对一题难度自动递增直至 5D！自动旋转与黑白互换防止背图，拥有 3 颗心容错。无论 25K、15K 还是高段，都能打出自己的极限纪录！",
                en: "Starts at 30K and escalates all the way to 5D with live rotation & color-swap! 3 hearts — built for every skill level from beginner to Dan!",
                ja: "30K入門からスタートし、1問正解ごとに5Dまで自動で難化！盤面の回転・白黒反転で暗記を防ぎ、ハート3つで挑戦。初心者から高段者まで自分の限界記録を目指そう！",
                ko: "30K 입문부터 시작해 1문제 맞힐 때마다 5D까지 자동으로 난이도가 상승합니다! 자동 회전·흑백 반전으로 암기를 방지하고 하트 3개로 도전하세요. 초급부터 고단자까지 한계 기록에 도전!",
                zhHant: "從 30K 啟蒙起步，每答對一題難度自動遞增直至 5D！自動旋轉與黑白互換防止背圖，擁有 3 顆心容錯。無論 25K、15K 還是高段，都能打出自己的極限紀錄！"
            ))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 12) {
                modeOptionButton(
                    mode: .blitz3m,
                    icon: "bolt.fill",
                    title: l10n.localized(zh: "3分钟极速冲刺", en: "3-Min Blitz", ja: "3分スピード挑戦", ko: "3분 스피드 도전", zhHant: "3分鐘極速衝刺"),
                    subtitle: l10n.localized(zh: "紧张刺激 · 3颗心", en: "Fast-paced · 3 ❤️", ja: "スリル満点 · ハート3つ", ko: "스릴 만점 · 하트 3개", zhHant: "緊張刺激 · 3顆心")
                )
                modeOptionButton(
                    mode: .survival,
                    icon: "infinity",
                    title: l10n.localized(zh: "无限时生存", en: "Survival", ja: "時間無制限サバイバル", ko: "무제한 서바이벌", zhHant: "無限時生存"),
                    subtitle: l10n.localized(zh: "从容深算 · 3颗心", en: "Untimed · 3 ❤️", ja: "じっくり読み · ハート3つ", ko: "깊은 수읽기 · 하트 3개", zhHant: "從容深算 · 3顆心")
                )
            }

            Button {
                startRush()
            } label: {
                Label(
                    l10n.localized(zh: "立即开始无尽冲关！", en: "Start Puzzle Rush!", ja: "連続挑戦をスタート！", ko: "무한 연속 도전 시작!", zhHant: "立即開始無盡衝關！"),
                    systemImage: "flame.fill"
                )
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true))

            /* [v1.0 暂不启用 Game Center，保留供后续版本恢复]
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
            */
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
                    Text(l10n.localized(zh: "当前连闯", en: "Solved", ja: "連続正解", ko: "연속 정답", zhHant: "當前連闖"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                    Text("\(score)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                }
                Spacer()
                if let p = currentPuzzle {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(l10n.localized(zh: "本题难度", en: "Current Rank", ja: "問題レベル", ko: "문제 난이도", zhHant: "本題難度"))
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
                        Text(p.category.localizedTitle(l10n))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.skyBottom)
                        Spacer()
                        Text(effectiveColor == .black
                             ? l10n.localized(zh: "⚫️ 黑先", en: "⚫️ Black", ja: "⚫️ 黒番", ko: "⚫️ 흑선", zhHant: "⚫️ 黑先")
                             : l10n.localized(zh: "⚪️ 白先", en: "⚪️ White", ja: "⚪️ 白番", ko: "⚪️ 백선", zhHant: "⚪️ 白先"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                    }
                    Text(p.category.localizedTitle(l10n))
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(effectiveColor == .black
                         ? l10n.localized(
                             zh: "黑先：不依赖提示，迅速找出盘面最佳一手！",
                             en: "Black to play: Spot the winning move with zero hints!",
                             ja: "黒番：ヒントなしで盤面の最善手を素早く見つけよう！",
                             ko: "흑선: 힌트 없이 바둑판의 최선수를 빠르게 찾아보세요!",
                             zhHant: "黑先：不依賴提示，迅速找出盤面最佳一手！"
                         )
                         : l10n.localized(
                             zh: "白先：不依赖提示，迅速找出盘面最佳一手！",
                             en: "White to play: Spot the winning move with zero hints!",
                             ja: "白番：ヒントなしで盤面の最善手を素早く見つけよう！",
                             ko: "백선: 힌트 없이 바둑판의 최선수를 빠르게 찾아보세요!",
                             zhHant: "白先：不依賴提示，迅速找出盤面最佳一手！"
                         ))
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
            Text(l10n.localized(zh: "本次冲关成绩", en: "Puzzle Rush Complete!", ja: "今回の連続挑戦の成績", ko: "이번 연속 도전 성적", zhHant: "本次衝關成績"))
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)

            HStack(spacing: 24) {
                VStack(spacing: 2) {
                    Text("\(score)")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                    Text(l10n.localized(zh: "答对题数", en: "Solved", ja: "正解数", ko: "정답 수", zhHant: "答對題數"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                Divider().frame(height: 44)
                VStack(spacing: 2) {
                    Text(highestRankBadge)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                    Text(l10n.localized(zh: "触达最高棋力", en: "Peak Rank", ja: "到達最高棋力", ko: "도달 최고 기력", zhHant: "觸達最高棋力"))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                Button {
                    startRush()
                } label: {
                    Label(
                        l10n.localized(zh: "再来一局破纪录", en: "Play Again", ja: "もう一度挑戦して記録更新", ko: "다시 도전해 기록 경신", zhHant: "再來一局破紀錄"),
                        systemImage: "flame.fill"
                    )
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                Button {
                    appState.popRoute()
                } label: {
                    Text(l10n.localized(zh: "返回地图", en: "Back to Map", ja: "マップへ戻る", ko: "지도로 돌아가기", zhHant: "返回地圖"))
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

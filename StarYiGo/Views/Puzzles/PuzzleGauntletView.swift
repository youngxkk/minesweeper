//
//  PuzzleGauntletView.swift
//  StarYi Go — Multi-Puzzle Stage Gauntlet (3-4 Puzzles / Persistent Hearts / Anti-Guess / Mistake Review Recovery) & SRS Ghost Buster
//

import SwiftUI

// MARK: - Reusable Persistent Hearts Badge (with live 5-min regen countdown)

struct GauntletHeartsBadge: View {
    @EnvironmentObject var appState: AppState
    var overrideHearts: Int? = nil
    var onTapWhenNotFull: (() -> Void)? = nil

    private var l10n: L10n { appState.l10n }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let maxHearts = PuzzleProgressStore.maxGauntletHearts
            let displayHearts = overrideHearts ?? appState.puzzleProgress.effectiveGauntletHearts(now: now)
            let secondsLeft = overrideHearts == nil ? appState.secondsUntilNextGauntletHeart(now: now) : nil

            let content = HStack(spacing: 5) {
                HStack(spacing: 3.5) {
                    ForEach(0..<maxHearts, id: \.self) { i in
                        Image(systemName: i < displayHearts ? "heart.fill" : "heart")
                            .font(.system(size: 15, weight: .black))
                            .foregroundColor(i < displayHearts ? AppTheme.coralBottom : AppTheme.subtleBorder)
                    }
                }
                if let sec = secondsLeft {
                    Text(Self.formatCountdown(sec))
                        .font(.system(size: 11.5, weight: .black, design: .monospaced))
                        .foregroundColor(displayHearts == 0 ? AppTheme.coralBottom : AppTheme.inkSecondary)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: (displayHearts == 0 ? AppTheme.coralBottom : Color.black).opacity(displayHearts == 0 ? 0.18 : 0.08), radius: 7, y: 3)
            )
            .overlay(
                Capsule()
                    .strokeBorder(displayHearts == 0 ? AppTheme.coralTop.opacity(0.85) : Color.white, lineWidth: 2.5)
            )
            .onChange(of: displayHearts) { oldVal, newVal in
                if overrideHearts == nil && newVal > oldVal {
                    appState.refreshGauntletHearts(now: now)
                }
            }

            if let onTap = onTapWhenNotFull, displayHearts < maxHearts {
                Button {
                    SoundAndHapticsManager.shared.playUITap()
                    onTap()
                } label: {
                    content
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("GauntletHeartsRecoverButton")
            } else {
                content
                    .accessibilityIdentifier("GauntletHeartsBadge")
            }
        }
    }

    static func formatCountdown(_ totalSeconds: Int) -> String {
        let clamped = max(0, totalSeconds)
        let m = clamped / 60
        let s = clamped % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Interactive Mistake Review Recovery Sheet (Study Solution -> Verify on Rotated Board -> Restore Hearts)

struct MistakeReviewRecoverySheet: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    let reviewPuzzles: [GoPuzzle]
    var headerNote: String? = nil
    var onRecovered: () -> Void

    enum Phase: Equatable {
        case study
        case verify
        case completed
    }

    @State private var currentIdx: Int = 0
    @State private var phase: Phase = .study
    @State private var studyCooldown: Int = 3
    @State private var isPlayingDemo: Bool = false

    @State private var activeTransform: PuzzleTransform = .identity
    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var rootNode: SGFNode?
    @State private var currentNode: SGFNode?
    @State private var isOpponentMoving: Bool = false
    @State private var feedbackText: String? = nil
    @State private var isFeedbackError: Bool = false
    @State private var lastCaptured: [BoardPoint] = []
    @State private var captureEventID: UUID = UUID()
    @State private var illegalFlash: BoardPoint? = nil
    @State private var illegalEventID: UUID = UUID()
    @State private var animTask: Task<Void, Never>?
    @State private var cooldownTask: Task<Void, Never>?

    private var l10n: L10n { appState.l10n }

    private var currentPuzzle: GoPuzzle {
        reviewPuzzles[min(currentIdx, max(0, reviewPuzzles.count - 1))]
    }

    private var effectivePlayerColor: StoneColor {
        activeTransform.apply(to: currentPuzzle.playerColor)
    }

    private var effectiveCrop: BoardCropRegion {
        activeTransform.apply(to: currentPuzzle.cropRegion, boardSize: currentPuzzle.boardSize)
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let isCompact = geo.size.width < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    sheetTopBar

                    if phase == .completed {
                        Spacer()
                        completedCard
                            .frame(maxWidth: 460)
                        Spacer()
                    } else if isCompact {
                        let side = min(geo.size.width - pad * 2, geo.size.height * 0.42)
                        reviewBoard.frame(width: side, height: side)
                        ScrollView(showsIndicators: false) { reviewSidePanel }
                    } else {
                        let sideW = min(380, max(310, geo.size.width * 0.36))
                        let side = max(240, min(geo.size.width - sideW - pad * 3, geo.size.height - 96))
                        HStack(spacing: pad) {
                            reviewBoard
                                .frame(width: side, height: side)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            ScrollView(showsIndicators: false) { reviewSidePanel }
                                .frame(width: sideW)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 14)
            }
        }
        .onAppear {
            startStudyPhase()
        }
        .onDisappear {
            animTask?.cancel()
            cooldownTask?.cancel()
        }
    }

    private var sheetTopBar: some View {
        HStack(spacing: 10) {
            Button {
                SoundAndHapticsManager.shared.playUITap()
                dismiss()
            } label: {
                Label(l10n.t("common.close"), systemImage: "xmark")
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.white).shadow(color: Color.black.opacity(0.08), radius: 6, y: 3))
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text(l10n.localized(
                    zh: "❤️ 错题复盘 · 满血恢复",
                    en: "❤️ Mistake Review · Refill Hearts",
                    ja: "❤️ 間違い復習 · ハート全回復",
                    ko: "❤️ 오답 복습 · 하트 전체 회복",
                    zhHant: "❤️ 錯題復盤 · 滿血恢復"
                ))
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                if let note = headerNote {
                    Text(note)
                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(min(currentIdx + 1, max(1, reviewPuzzles.count)))/\(max(1, reviewPuzzles.count))")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(AppTheme.coralBottom))
        }
    }

    private var reviewBoard: some View {
        GoBoardView(
            boardState: boardState,
            theme: appState.settings.boardTheme,
            stoneStyle: appState.settings.stoneStyle,
            cropRegion: effectiveCrop,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: phase == .study,
            highlightAtari: phase == .study,
            expressiveStones: false,
            showLiveLiberties: false,
            showTwoEyeGlow: phase == .study,
            puzzleHintPoint: nil,
            isInteractive: phase == .verify && !isOpponentMoving,
            capturedFlashPoints: lastCaptured,
            captureEventID: captureEventID,
            illegalFlashPoint: illegalFlash,
            illegalEventID: illegalEventID,
            onSelectPoint: { pt in
                handleVerifyTap(at: pt)
            }
        )
    }

    private var reviewSidePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text(phase == .study
                     ? l10n.localized(zh: "第 1 步 · 看懂正解", en: "Step 1 · Study Solution", ja: "ステップ1 · 正解を確認", ko: "1단계 · 정답 이해", zhHant: "第 1 步 · 看懂正解")
                     : l10n.localized(zh: "第 2 步 · 换向检验", en: "Step 2 · Rotated Check", ja: "ステップ2 · 回転テスト", ko: "2단계 · 회전 검증", zhHant: "第 2 步 · 換向檢驗"))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(phase == .study ? AppTheme.skyBottom : AppTheme.mintBottom))

                Text(currentPuzzle.rankBadge)
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.grapeBottom)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(AppTheme.grapeTop.opacity(0.16)))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(currentPuzzle.title(l10n))
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                if phase == .study {
                    Text(currentPuzzle.prompt(l10n, activeColor: effectivePlayerColor))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    Text(l10n.localized(zh: "💡 小老师要点", en: "💡 Key Idea", ja: "💡 先生のポイント", ko: "💡 핵심 포인트", zhHant: "💡 小老師要點"))
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.sunBottom)

                    Text(currentPuzzle.hint(l10n))
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(l10n.localized(
                        zh: "棋盘已旋转/镜像！现在不看提示，自己走出刚才学会的妙手吧：",
                        en: "Board rotated/mirrored! Play the winning move you just learned without hints:",
                        ja: "盤面を回転・反転しました！ヒントなしで今学んだ妙手を打ってみよう：",
                        ko: "바둑판을 회전/반전했어요! 힌트 없이 방금 배운 묘수를 직접 두어보세요:",
                        zhHant: "棋盤已旋轉/鏡像！現在不看提示，自己走出剛才學會的妙手吧："
                    ))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 22, padding: 16)

            if let msg = feedbackText {
                HStack(spacing: 10) {
                    Image(systemName: isFeedbackError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(isFeedbackError ? AppTheme.coralBottom : AppTheme.mintBottom)
                    Text(msg)
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundColor(isFeedbackError ? AppTheme.coralBottom : AppTheme.mintBottom)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .warmCard(cornerRadius: 18, padding: 12)
            }

            if phase == .study {
                Button {
                    replaySolutionDemo()
                } label: {
                    Label(
                        l10n.localized(zh: "重播正解演示", en: "Replay Solution", ja: "正解をもう一度再生", ko: "정답 다시 보기", zhHant: "重播正解演示"),
                        systemImage: "play.circle.fill"
                    )
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

                Button {
                    startVerifyPhase()
                } label: {
                    Text(studyCooldown > 0
                         ? l10n.localized(
                            zh: "仔细看演示（\(studyCooldown)s）",
                            en: "Watch carefully (\(studyCooldown)s)",
                            ja: "手本を確認中（\(studyCooldown)秒）",
                            ko: "설명을 확인하세요 (\(studyCooldown)초)",
                            zhHant: "仔細看演示（\(studyCooldown)s）"
                         )
                         : l10n.localized(
                            zh: "我学会了，开始检验 →",
                            en: "Got it — Test Me →",
                            ja: "分かった！テストへ →",
                            ko: "이해했어요, 검증 시작 →",
                            zhHant: "我學會了，開始檢驗 →"
                         ))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: studyCooldown > 0 ? .locked : .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                .disabled(studyCooldown > 0)
            } else {
                Button {
                    startStudyPhase()
                } label: {
                    Label(
                        l10n.localized(zh: "再看一遍正解演示", en: "Watch Demo Again", ja: "もう一度手本を見る", ko: "정답 설명 다시 보기", zhHant: "再看一遍正解演示"),
                        systemImage: "arrow.uturn.backward.circle.fill"
                    )
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
            }
        }
    }

    private var completedCard: some View {
        VStack(spacing: 16) {
            Text("❤️❤️❤️").font(.system(size: 46))
            Text(l10n.localized(
                zh: "复盘通关！体力已满血恢复！",
                en: "Review Complete — Hearts Refilled!",
                ja: "復習完了！ハートが全回復しました！",
                ko: "복습 완료! 하트가 모두 회복되었어요!",
                zhHant: "復盤通關！體力已滿血恢復！"
            ))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
                .multilineTextAlignment(.center)
            Text(l10n.localized(
                zh: "你已经真正掌握了刚才的错题，快回关卡拿下胜利吧！",
                en: "You've mastered those tricky shapes — jump back in and clear the stage!",
                ja: "さっきのミスをしっかり克服したよ！ステージに戻ってクリアしよう！",
                ko: "방금 틀렸던 문제를 완벽히 익혔어요! 스테이지로 돌아가 돌파해 보세요!",
                zhHant: "你已經真正掌握了剛才的錯題，快回關卡拿下勝利吧！"
            ))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

            Button {
                onRecovered()
                dismiss()
            } label: {
                Text(l10n.localized(zh: "继续闯关", en: "Back to Challenge", ja: "挑戦に戻る", ko: "도전 계속하기", zhHant: "繼續闖關"))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
        }
        .padding(24)
        .warmCard(cornerRadius: 28, padding: 0)
    }

    private func startStudyPhase() {
        animTask?.cancel()
        cooldownTask?.cancel()
        phase = .study
        activeTransform = .identity
        feedbackText = nil
        isFeedbackError = false
        studyCooldown = 3
        replaySolutionDemo()

        cooldownTask = Task {
            for remaining in stride(from: 2, through: 0, by: -1) {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    studyCooldown = remaining
                }
            }
        }
    }

    private func replaySolutionDemo() {
        animTask?.cancel()
        let initial = currentPuzzle.initialBoardState(transform: .identity)
        let root = currentPuzzle.parsedRoot(transform: .identity)
        boardState = initial
        rootNode = root
        currentNode = root
        isPlayingDemo = true

        guard let root else {
            isPlayingDemo = false
            return
        }
        let line = GoPuzzle.solutionLine(from: root)
        animTask = Task {
            for step in line {
                try? await Task.sleep(nanoseconds: 650_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if case .success(let out) = boardState.applying(action: .place(step.point), color: step.color) {
                        boardState = out.nextState
                        if !out.capturedPoints.isEmpty {
                            lastCaptured = out.capturedPoints
                            captureEventID = UUID()
                            SoundAndHapticsManager.shared.playCapture(count: out.capturedPoints.count)
                        } else {
                            SoundAndHapticsManager.shared.playStonePlace()
                        }
                    }
                }
            }
            await MainActor.run {
                isPlayingDemo = false
            }
        }
    }

    private func startVerifyPhase() {
        animTask?.cancel()
        cooldownTask?.cancel()
        phase = .verify
        // Apply a guaranteed non-identity rotation/mirror so the learner proves understanding, not pixel memory
        var transform = PuzzleTransform.random(allowColorSwap: false)
        if transform.isIdentity {
            transform = PuzzleTransform(rotation: Int.random(in: 1..<4), mirrored: Bool.random(), swapColors: false)
        }
        activeTransform = transform
        boardState = currentPuzzle.initialBoardState(transform: transform)
        rootNode = currentPuzzle.parsedRoot(transform: transform)
        currentNode = rootNode
        isOpponentMoving = false
        feedbackText = nil
        isFeedbackError = false
        SoundAndHapticsManager.shared.playUITap()
    }

    private func handleVerifyTap(at point: BoardPoint) {
        guard phase == .verify, !isOpponentMoving, let node = currentNode else { return }
        guard case .success(let outcome) = boardState.applying(action: .place(point), color: effectivePlayerColor) else {
            illegalFlash = point
            illegalEventID = UUID()
            SoundAndHapticsManager.shared.playKoBounce()
            return
        }

        boardState = outcome.nextState
        if !outcome.capturedPoints.isEmpty {
            lastCaptured = outcome.capturedPoints
            captureEventID = UUID()
            SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
        } else {
            SoundAndHapticsManager.shared.playStonePlace()
        }

        let matched = node.children.first { ch in
            if let mv = ch.move, case .place(let pt) = mv.action {
                return pt == point && mv.color == effectivePlayerColor
            }
            return false
        }

        guard let nextNode = matched else {
            handleVerifyWrong()
            return
        }

        currentNode = nextNode
        if let c = nextNode.comment?.uppercased(), c.contains("CORRECT") {
            handleVerifySolved()
            return
        }

        let oppMoves = nextNode.children.filter { $0.move?.color == effectivePlayerColor.opposite }
        if let opp = oppMoves.randomElement(), let oppMove = opp.move {
            isOpponentMoving = true
            animTask = Task {
                try? await Task.sleep(nanoseconds: 340_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if case .success(let oppOut) = boardState.applying(action: oppMove.action, color: oppMove.color) {
                        boardState = oppOut.nextState
                        if !oppOut.capturedPoints.isEmpty {
                            lastCaptured = oppOut.capturedPoints
                            captureEventID = UUID()
                            SoundAndHapticsManager.shared.playCapture(count: oppOut.capturedPoints.count)
                        } else {
                            SoundAndHapticsManager.shared.playStonePlace()
                        }
                    }
                    currentNode = opp
                    isOpponentMoving = false
                    if let c = opp.comment?.uppercased() {
                        if c.contains("WRONG") {
                            handleVerifyWrong()
                        } else if c.contains("CORRECT") {
                            handleVerifySolved()
                        }
                    }
                }
            }
        } else {
            handleVerifyWrong()
        }
    }

    private func handleVerifyWrong() {
        SoundAndHapticsManager.shared.playWrong()
        isFeedbackError = true
        feedbackText = l10n.localized(
            zh: "差一点点！再想一想刚才的要点，或者点下方重看演示。",
            en: "Almost! Think back to the key move, or tap below to watch again.",
            ja: "惜しい！さっきのポイントを思い出して、もう一回打ってみよう。",
            ko: "아쉬워요! 방금 본 핵심 수를 떠올리거나 아래에서 다시 확인해 보세요.",
            zhHant: "差一點點！再想一想剛才的要點，或者點下方重看演示。"
        )
        isOpponentMoving = true
        animTask = Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                boardState = currentPuzzle.initialBoardState(transform: activeTransform)
                currentNode = rootNode
                isOpponentMoving = false
            }
        }
    }

    private func handleVerifySolved() {
        SoundAndHapticsManager.shared.playSuccess()
        isFeedbackError = false
        feedbackText = l10n.localized(zh: "✨ 检验通过！", en: "✨ Verified!", ja: "✨ クリア！", ko: "✨ 검증 통과!", zhHant: "✨ 檢驗通過！")
        isOpponentMoving = true
        animTask = Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if currentIdx + 1 < reviewPuzzles.count {
                    currentIdx += 1
                    startStudyPhase()
                } else {
                    appState.restoreGauntletHeartsFromMistakeReview(reviewedPuzzleIds: reviewPuzzles.map(\.id))
                    SoundAndHapticsManager.shared.playVictoryFanfare()
                    phase = .completed
                }
            }
        }
    }
}

// MARK: - Main Puzzle Gauntlet View

struct PuzzleGauntletView: View {
    @EnvironmentObject var appState: AppState
    let titleZh: String
    let titleEn: String
    let puzzles: [GoPuzzle]
    let campaignNodeId: String?
    let masteryTier: StageMasteryTier
    let isGhostBuster: Bool

    /// Queue of remaining puzzles in the current run. Missed puzzles are re-queued to the back with rotated/mirrored views.
    @State private var runQueue: [GoPuzzle] = []
    @State private var solvedCount: Int = 0
    @State private var missedIdsInRun: Set<String> = []
    @State private var ghostHearts: Int = 3
    @State private var mistakesInRun: Int = 0
    @State private var usedAnyHint: Bool = false
    @State private var combo: Int = 0
    @State private var runState: RunOutcome = .playing
    @State private var earnedStars: Int = 0
    @State private var showMistakeReviewSheet: Bool = false

    // Active puzzle board state
    @State private var activeTransform: PuzzleTransform = .identity
    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var rootNode: SGFNode?
    @State private var currentNode: SGFNode?
    @State private var isOpponentMoving: Bool = false
    @State private var highlightedHint: BoardPoint? = nil
    @State private var showHintText: Bool = false
    @State private var feedbackBanner: String? = nil
    @State private var isFeedbackError: Bool = false
    @State private var lastCaptured: [BoardPoint] = []
    @State private var captureEventID: UUID = UUID()
    @State private var illegalFlash: BoardPoint? = nil
    @State private var illegalEventID: UUID = UUID()
    @State private var replyTask: Task<Void, Never>?

    enum RunOutcome: Equatable {
        case playing
        case victory
        case outOfHearts
    }

    private var l10n: L10n { appState.l10n }
    private var isExam: Bool { masteryTier == .examCrown }

    private var activeHearts: Int {
        isGhostBuster ? ghostHearts : appState.currentGauntletHearts
    }

    private var currentPuzzle: GoPuzzle {
        runQueue.first ?? puzzles[0]
    }

    private func localizedMasteryTitle(_ tier: StageMasteryTier) -> String {
        switch tier {
        case .normal:
            return l10n.localized(zh: "普通模式", en: "Standard", ja: "通常モード", ko: "일반 모드", zhHant: "普通模式")
        case .transformed:
            return l10n.localized(zh: "旋转换色（防背图）", en: "Rotated & Flip", ja: "回転・白黒反転", ko: "회전·흑백 반전", zhHant: "旋轉換色（防背圖）")
        case .examCrown:
            return l10n.localized(zh: "无提示皇冠考", en: "No-Hint Exam", ja: "ヒントなし王冠試験", ko: "힌트 없음 왕관 시험", zhHant: "無提示皇冠考")
        }
    }

    private func localizedMasteryBadge(_ tier: StageMasteryTier) -> String {
        switch tier {
        case .normal:
            return l10n.localized(zh: "★ 普通", en: "★ Normal", ja: "★ 通常", ko: "★ 일반", zhHant: "★ 普通")
        case .transformed:
            return l10n.localized(zh: "🔄 旋转换色", en: "🔄 Flip", ja: "🔄 回転反転", ko: "🔄 회전반전", zhHant: "🔄 旋轉換色")
        case .examCrown:
            return l10n.localized(zh: "👑 无提示考", en: "👑 No-Hint", ja: "👑 無ヒント", ko: "👑 무힌트", zhHant: "👑 無提示考")
        }
    }

    private func localizedMasteryDescription(_ tier: StageMasteryTier) -> String {
        switch tier {
        case .normal:
            return l10n.localized(zh: "原图带提示，先看懂招式", en: "Original board with helpful hints", ja: "ヒント付きで基本の手筋を学ぼう", ko: "힌트와 함께 기본 수읽기를 익혀요", zhHant: "原圖帶提示，先看懂招式")
        case .transformed:
            return l10n.localized(zh: "棋盘旋转或黑白互换，检验是不是真学会", en: "Board rotated or swapped to test true mastery", ja: "盤面の回転や白黒反転で本当の棋力を確認", ko: "바둑판 회전·흑백 반전으로 진짜 실력 검증", zhHant: "棋盤旋轉或黑白互換，檢驗是不是真學會")
        case .examCrown:
            return l10n.localized(zh: "关闭所有辅助提示，0 失误通关赢皇冠", en: "All hints off — clear with 0 mistakes for Crown", ja: "補助ヒントなし・ミス0でクリアして王冠獲得", ko: "모든 힌트 끄고 무실수로 클리어해 왕관 획득", zhHant: "關閉所有輔助提示，0 失誤通關贏皇冠")
        }
    }

    private var effectivePlayerColor: StoneColor {
        activeTransform.apply(to: currentPuzzle.playerColor)
    }

    private var effectiveCrop: BoardCropRegion {
        activeTransform.apply(to: currentPuzzle.cropRegion, boardSize: currentPuzzle.boardSize)
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let isCompact = geo.size.width < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 10) {
                    topBar

                    if runState == .playing {
                        progressRibbon

                        if isCompact {
                            let side = min(geo.size.width - pad * 2, geo.size.height * 0.45)
                            gauntletBoard.frame(width: side, height: side)
                            ScrollView(showsIndicators: false) { sidePanel }
                        } else {
                            let sideW = min(380, max(320, geo.size.width * 0.32))
                            let side = max(250, min(geo.size.width - sideW - pad * 3, geo.size.height - 134))
                            HStack(spacing: pad) {
                                gauntletBoard
                                    .frame(width: side, height: side)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                ScrollView(showsIndicators: false) { sidePanel }
                                    .frame(width: sideW)
                            }
                        }
                    } else {
                        Spacer()
                        summaryCard
                            .frame(maxWidth: 520)
                        Spacer()
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 10)
            }

            if runState == .victory {
                ConfettiBurstView()
                    .ignoresSafeArea()
                    .zIndex(20)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showMistakeReviewSheet) {
            MistakeReviewRecoverySheet(
                reviewPuzzles: appState.pendingMistakeReviewPuzzles(fallbackPuzzles: puzzles),
                onRecovered: {
                    restartWholeRun(shuffle: true)
                }
            )
            .environmentObject(appState)
        }
        .onAppear {
            let hasPriorMistakes = puzzles.contains { appState.puzzleProgress.pendingReviewPuzzleIds.contains($0.id) }
            restartWholeRun(shuffle: hasPriorMistakes)
        }
        .onChange(of: masteryTier) { _, _ in
            restartWholeRun(shuffle: true)
        }
        .onDisappear {
            replyTask?.cancel()
        }
    }

    // MARK: - Header & Progress Ribbon

    private var topBar: some View {
        HStack(spacing: 10) {
            GameBackButton(title: l10n.t("common.back")) {
                appState.popRoute()
            }
            Spacer()
            GameTitleCrest(
                title: l10n.localized(zh: titleZh, en: titleEn),
                subtitle: isGhostBuster
                    ? l10n.localized(
                        zh: "👻 错题幽灵剿灭战 · 双倍星币",
                        en: "👻 Ghost Buster · 2× Coins",
                        ja: "👻 間違いゴースト退治 · スターコイン2倍",
                        ko: "👻 오답 고스트 퇴치전 · 별코인 2배",
                        zhHant: "👻 錯題幽靈剿滅戰 · 雙倍星幣"
                    )
                    : localizedMasteryBadge(masteryTier)
            )
            Spacer()
            HStack(spacing: 8) {
                GauntletHeartsBadge(
                    overrideHearts: isGhostBuster ? ghostHearts : nil,
                    onTapWhenNotFull: isGhostBuster ? nil : {
                        showMistakeReviewSheet = true
                    }
                )

                if runState == .playing && !isExam {
                    GameCircleButton(
                        icon: showHintText ? "lightbulb.fill" : "lightbulb",
                        palette: showHintText ? .sun : .snow,
                        tint: showHintText ? .white : AppTheme.inkPrimary,
                        size: 42
                    ) {
                        toggleHintOverlay()
                    }
                    .accessibilityLabel(l10n.t("puzzle.play.hint"))
                    .accessibilityIdentifier("GauntletTopRightHintButton")
                }
            }
        }
    }

    private var progressRibbon: some View {
        HStack(spacing: 8) {
            ForEach(0..<puzzles.count, id: \.self) { i in
                Capsule()
                    .fill(
                        i < solvedCount ? AppTheme.mintBottom :
                        (i == solvedCount ? AppTheme.skyBottom : AppTheme.subtleBorder)
                    )
                    .frame(height: 8)
            }
            if combo >= 2 {
                Text("🔥 \(combo)x")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(AppTheme.coralBottom))
            }
        }
        .frame(maxWidth: 680)
    }

    // MARK: - Board & Side Panel

    private var gauntletBoard: some View {
        // Hints and visual crutches stay hidden by default during campaign challenges;
        // players can reveal them via the top-right lightbulb button only when truly stuck.
        let showVisualAssists = showHintText && !isExam
        return GoBoardView(
            boardState: boardState,
            theme: appState.settings.boardTheme,
            stoneStyle: appState.settings.stoneStyle,
            cropRegion: effectiveCrop,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: showVisualAssists && appState.settings.highlightAtari,
            expressiveStones: showVisualAssists && appState.settings.expressiveStones && !appState.settings.zenDojoMode,
            showLiveLiberties: showVisualAssists && appState.settings.showLiveLiberties && !appState.settings.zenDojoMode,
            showTwoEyeGlow: showVisualAssists && !appState.settings.zenDojoMode,
            puzzleHintPoint: showHintText ? highlightedHint : nil,
            isInteractive: runState == .playing && !isOpponentMoving,
            capturedFlashPoints: lastCaptured,
            captureEventID: captureEventID,
            illegalFlashPoint: illegalFlash,
            illegalEventID: illegalEventID,
            onSelectPoint: { pt in
                handleTap(at: pt)
            }
        )
    }

    private var neutralObjectiveText: String {
        let mover = effectivePlayerColor == .black
            ? l10n.localized(zh: "黑先", en: "Black to play", ja: "黒番", ko: "흑선", zhHant: "黑先")
            : l10n.localized(zh: "白先", en: "White to play", ja: "白番", ko: "백선", zhHant: "白先")
        switch currentPuzzle.category {
        case .capture:
            return l10n.localized(
                zh: "\(mover)：找出最佳吃子或救棋一手。",
                en: "\(mover): Find the best capture or rescue move.",
                ja: "\(mover)：最善の石取りまたは助ける一手を見つけよう。",
                ko: "\(mover): 최선의 따내기 또는 살리는 한 수를 찾아보세요.",
                zhHant: "\(mover)：找出最佳吃子或救棋一手。"
            )
        case .tactics:
            return l10n.localized(
                zh: "\(mover)：找出局部最强手筋。",
                en: "\(mover): Find the sharpest local tesuji.",
                ja: "\(mover)：部分的な最強の手筋を見つけよう。",
                ko: "\(mover): 부분 최강의 맥점을 찾아보세요.",
                zhHant: "\(mover)：找出局部最強手筋。"
            )
        case .lifeAndDeath:
            return l10n.localized(
                zh: "\(mover)：判断死活要点，做活或杀棋。",
                en: "\(mover): Find the vital life-and-death point.",
                ja: "\(mover)：詰碁の急所を見極めて生き・殺しを決めよう。",
                ko: "\(mover): 사활의 급소를 찾아 살거나 잡아보세요.",
                zhHant: "\(mover)：判斷死活要點，做活或殺棋。"
            )
        case .capturingRace:
            return l10n.localized(
                zh: "\(mover)：算清气数次序，赢下对杀。",
                en: "\(mover): Calculate liberties carefully to win the race.",
                ja: "\(mover)：呼吸点と手順を読み切って攻め合いに勝とう。",
                ko: "\(mover): 활로와 수순을 정확히 읽어 수상전에서 승리하세요.",
                zhHant: "\(mover)：算清氣數次序，贏下對殺。"
            )
        case .opening:
            return l10n.localized(
                zh: "\(mover)：选出全局效率最高的大场或急所。",
                en: "\(mover): Choose the highest-value opening move.",
                ja: "\(mover)：全局で最も効率の良い大場・急所を選ぼう。",
                ko: "\(mover): 전체에서 가장 효율이 높은 큰자리나 급소를 고르세요.",
                zhHant: "\(mover)：選出全局效率最高的大場或急所。"
            )
        case .endgame:
            return l10n.localized(
                zh: "\(mover)：找出价值最大的官子妙手。",
                en: "\(mover): Find the best endgame move.",
                ja: "\(mover)：最も価値の大きいヨセの妙手を見つけよう。",
                ko: "\(mover): 가치가 가장 큰 끝내기 묘수를 찾아보세요.",
                zhHant: "\(mover)：找出價值最大的官子妙手。"
            )
        }
    }

    private var sidePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(l10n.localized(
                        zh: "第 \(min(solvedCount + 1, puzzles.count))/\(puzzles.count) 题",
                        en: "Puzzle \(min(solvedCount + 1, puzzles.count))/\(puzzles.count)",
                        ja: "第 \(min(solvedCount + 1, puzzles.count))/\(puzzles.count) 問",
                        ko: "제 \(min(solvedCount + 1, puzzles.count))/\(puzzles.count)문제",
                        zhHant: "第 \(min(solvedCount + 1, puzzles.count))/\(puzzles.count) 題"
                    ))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.skyBottom))

                    Text(currentPuzzle.rankBadge)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.grapeTop.opacity(0.16)))

                    if !activeTransform.isIdentity && masteryTier == .normal {
                        Text(l10n.localized(zh: "🔄 换向重考", en: "🔄 Rotated", ja: "🔄 回転出題", ko: "🔄 회전 출제", zhHant: "🔄 換向重考"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.skyBottom)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(AppTheme.skyTop.opacity(0.16)))
                    }

                    Spacer()

                    Text(effectivePlayerColor == .black
                         ? l10n.localized(zh: "⚫️ 黑先", en: "⚫️ Black", ja: "⚫️ 黒番", ko: "⚫️ 흑선", zhHant: "⚫️ 黑先")
                         : l10n.localized(zh: "⚪️ 白先", en: "⚪️ White", ja: "⚪️ 白番", ko: "⚪️ 백선", zhHant: "⚪️ 白先"))
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                }

                Text(showHintText ? currentPuzzle.title(l10n) : currentPuzzle.category.localizedTitle(l10n))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                Text(showHintText ? currentPuzzle.prompt(l10n, activeColor: effectivePlayerColor) : neutralObjectiveText)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .warmCard(cornerRadius: 24, padding: 16)

            if let msg = feedbackBanner {
                HStack(spacing: 10) {
                    Image(systemName: isFeedbackError ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .black))
                        .foregroundColor(isFeedbackError ? AppTheme.coralBottom : AppTheme.mintBottom)
                    Text(msg)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(isFeedbackError ? AppTheme.coralBottom : AppTheme.mintBottom)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .warmCard(cornerRadius: 20, padding: 14)
            }

            if showHintText {
                VStack(alignment: .leading, spacing: 4) {
                    Text(l10n.localized(zh: "💡 小老师锦囊", en: "💡 Coach Hint", ja: "💡 先生のヒント", ko: "💡 선생님 힌트", zhHant: "💡 小老師錦囊"))
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.sunBottom)
                    Text(currentPuzzle.hint(l10n))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .warmCard(cornerRadius: 20, padding: 14)
            }

            Button {
                resetCurrentPuzzle()
            } label: {
                Label(l10n.t("puzzle.play.reset"), systemImage: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
        }
    }

    // MARK: - Victory / Out-of-Hearts Recovery Card

    private var summaryCard: some View {
        VStack(spacing: 16) {
            if runState == .victory {
                Text(masteryTier == .examCrown ? "👑" : (isGhostBuster ? "👻✨" : "🏆"))
                    .font(.system(size: 54))
                Text(isGhostBuster
                     ? l10n.localized(zh: "错题幽灵全部消灭！", en: "All Mistake Ghosts Cleared!", ja: "間違いゴーストをすべて退治！", ko: "오답 고스트 모두 퇴치!", zhHant: "錯題幽靈全部消滅！")
                     : l10n.localized(zh: "连闯大成功！", en: "Gauntlet Cleared!", ja: "連続挑戦クリア！", ko: "연속 도전 클리어!", zhHant: "連闖大成功！"))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                HStack(spacing: 8) {
                    ForEach(1...3, id: \.self) { i in
                        Image(systemName: i <= earnedStars ? "star.fill" : "star")
                            .font(.system(size: 32, weight: .black))
                            .foregroundStyle(
                                i <= earnedStars
                                    ? AnyShapeStyle(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                    : AnyShapeStyle(AppTheme.subtleBorder)
                            )
                    }
                }

                Text(l10n.localized(
                    zh: "共完成 \(puzzles.count) 道题 · 失误 \(mistakesInRun) 次 · \(localizedMasteryTitle(masteryTier))",
                    en: "\(puzzles.count) puzzles cleared · \(mistakesInRun) mistake(s) · \(localizedMasteryTitle(masteryTier))",
                    ja: "\(puzzles.count) 問クリア · ミス \(mistakesInRun) 回 · \(localizedMasteryTitle(masteryTier))",
                    ko: "\(puzzles.count)문제 완료 · 실수 \(mistakesInRun)회 · \(localizedMasteryTitle(masteryTier))",
                    zhHant: "共完成 \(puzzles.count) 道題 · 失誤 \(mistakesInRun) 次 · \(localizedMasteryTitle(masteryTier))"
                ))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)

                if campaignNodeId != nil, masteryTier < .examCrown {
                    let nextTier: StageMasteryTier = masteryTier == .normal ? .transformed : .examCrown
                    Text(l10n.localized(
                        zh: "下一档「\(localizedMasteryTitle(nextTier))」：\(localizedMasteryDescription(nextTier))",
                        en: "Next — \(localizedMasteryTitle(nextTier)): \(localizedMasteryDescription(nextTier))",
                        ja: "次のランク「\(localizedMasteryTitle(nextTier))」：\(localizedMasteryDescription(nextTier))",
                        ko: "다음 단계 「\(localizedMasteryTitle(nextTier))」: \(localizedMasteryDescription(nextTier))",
                        zhHant: "下一檔「\(localizedMasteryTitle(nextTier))」：\(localizedMasteryDescription(nextTier))"
                    ))
                        .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.grapeTop.opacity(0.12)))
                }

                HStack(spacing: 12) {
                    if let nodeId = campaignNodeId, masteryTier < .examCrown {
                        let nextTier: StageMasteryTier = masteryTier == .normal ? .transformed : .examCrown
                        Button {
                            appState.navigationPath.removeLast()
                            appState.navigationPath.append(.puzzleGauntlet(nodeId: nodeId, masteryTier: nextTier))
                        } label: {
                            Text(l10n.localized(
                                zh: "挑战 \(localizedMasteryBadge(nextTier))",
                                en: "Try \(localizedMasteryBadge(nextTier))",
                                ja: "\(localizedMasteryBadge(nextTier)) に挑戦",
                                ko: "\(localizedMasteryBadge(nextTier)) 도전",
                                zhHant: "挑戰 \(localizedMasteryBadge(nextTier))"
                            ))
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                    }

                    Button {
                        appState.popRoute()
                    } label: {
                        Text(l10n.localized(zh: "返回岛屿", en: "Back to Island", ja: "島へ戻る", ko: "섬으로 돌아가기", zhHant: "返回島嶼"))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }
            } else {
                outOfHeartsContent
            }
        }
        .padding(24)
        .warmCard(cornerRadius: 30, padding: 0)
    }

    private var outOfHeartsContent: some View {
        TimelineView(.periodic(from: .now, by: 1.0)) { context in
            let now = context.date
            let heartsNow = isGhostBuster ? ghostHearts : appState.puzzleProgress.effectiveGauntletHearts(now: now)
            let secondsLeft = isGhostBuster ? nil : appState.secondsUntilNextGauntletHeart(now: now)

            VStack(spacing: 14) {
                Text(heartsNow > 0 ? "❤️" : "💔").font(.system(size: 52))
                Text(heartsNow > 0
                     ? l10n.localized(zh: "体力已恢复，可以继续闯关！", en: "Heart Restored — Ready to Go!", ja: "ハート回復！再挑戦できるよ！", ko: "하트가 회복되었어요! 다시 도전하세요!", zhHant: "體力已恢復，可以繼續闖關！")
                     : l10n.localized(zh: "体力耗尽啦！先复盘错题再战", en: "Out of Hearts — Review to Refill", ja: "ハートが0に！間違いを復習して回復しよう", ko: "하트가 모두 소진됐어요! 오답을 복습해 회복하세요", zhHant: "體力耗盡啦！先復盤錯題再戰"))
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .multilineTextAlignment(.center)

                Text(l10n.localized(
                    zh: "本轮已解出 \(solvedCount)/\(puzzles.count) 题。把错题看懂并检验通过，立刻恢复 3 颗 ❤️！",
                    en: "Solved \(solvedCount)/\(puzzles.count). Study & verify your mistake(s) to refill all 3 ❤️ right away!",
                    ja: "\(solvedCount)/\(puzzles.count) 問クリア。間違いを復習して確認テストに通ると、すぐハート3個全回復！",
                    ko: "\(solvedCount)/\(puzzles.count)문제 해결. 오답을 이해하고 검증에 통과하면 바로 하트 3개가 회복돼요!",
                    zhHant: "本輪已解出 \(solvedCount)/\(puzzles.count) 題。把錯題看懂並檢驗通過，立刻恢復 3 顆 ❤️！"
                ))
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(AppTheme.inkSecondary)
                    .multilineTextAlignment(.center)

                if let sec = secondsLeft, heartsNow == 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(AppTheme.coralBottom)
                        Text(l10n.localized(
                            zh: "或等待 \(GauntletHeartsBadge.formatCountdown(sec)) 后自动恢复 1 颗 ❤️",
                            en: "Or wait \(GauntletHeartsBadge.formatCountdown(sec)) for +1 ❤️ auto-regen",
                            ja: "または \(GauntletHeartsBadge.formatCountdown(sec)) 待つとハート1個自動回復",
                            ko: "또는 \(GauntletHeartsBadge.formatCountdown(sec)) 후 하트 1개 자동 회복",
                            zhHant: "或等待 \(GauntletHeartsBadge.formatCountdown(sec)) 後自動恢復 1 顆 ❤️"
                        ))
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.coralBottom)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(AppTheme.coralTop.opacity(0.14)))
                }

                VStack(spacing: 10) {
                    if !isGhostBuster && heartsNow == 0 {
                        Button {
                            SoundAndHapticsManager.shared.playUITap()
                            showMistakeReviewSheet = true
                        } label: {
                            Label(
                                l10n.localized(
                                    zh: "复习错题 · 立刻满血恢复 ❤️",
                                    en: "Review Mistakes · Refill ❤️ Now",
                                    ja: "間違いを復習 · 今すぐハート全回復 ❤️",
                                    ko: "오답 복습 · 지금 하트 전체 회복 ❤️",
                                    zhHant: "復習錯題 · 立刻滿血恢復 ❤️"
                                ),
                                systemImage: "book.pages.fill"
                            )
                                .font(.system(size: 15.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                        .accessibilityIdentifier("GauntletMistakeReviewRecoverButton")
                    } else {
                        Button {
                            if !isGhostBuster {
                                appState.refreshGauntletHearts(now: now)
                            } else {
                                ghostHearts = 3
                            }
                            restartWholeRun(shuffle: true)
                        } label: {
                            Text(l10n.localized(zh: "继续挑战", en: "Continue Challenge", ja: "再挑戦する", ko: "도전 계속하기", zhHant: "繼續挑戰"))
                                .font(.system(size: 15.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                    }

                    Button {
                        appState.popRoute()
                    } label: {
                        Text(l10n.localized(zh: "先回岛屿", en: "Back to Island", ja: "島へ戻る", ko: "섬으로 돌아가기", zhHant: "先回島嶼"))
                            .font(.system(size: 14.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                }
            }
        }
    }

    // MARK: - Puzzle Logic

    private func loadCurrentPuzzle(forceNewTransform: Bool = false) {
        replyTask?.cancel()
        guard !runQueue.isEmpty else { return }

        let shouldTransformInNormal = forceNewTransform
            || missedIdsInRun.contains(currentPuzzle.id)
            || appState.puzzleProgress.pendingReviewPuzzleIds.contains(currentPuzzle.id)

        if masteryTier >= .transformed {
            var candidate = PuzzleTransform.random(allowColorSwap: true)
            if forceNewTransform && candidate == activeTransform {
                candidate = PuzzleTransform(rotation: (activeTransform.rotation + 1) % 4, mirrored: !activeTransform.mirrored, swapColors: activeTransform.swapColors)
            }
            activeTransform = candidate
        } else if shouldTransformInNormal {
            // Rotate/mirror (without color swap in Normal tier) so players cannot brute-force memorized coordinates
            var candidate = PuzzleTransform.random(allowColorSwap: false)
            if candidate.isIdentity || (forceNewTransform && candidate == activeTransform) {
                candidate = PuzzleTransform(rotation: ((activeTransform.rotation + 1) % 3) + 1, mirrored: !activeTransform.mirrored, swapColors: false)
            }
            activeTransform = candidate
        } else {
            activeTransform = .identity
        }

        boardState = currentPuzzle.initialBoardState(transform: activeTransform)
        rootNode = currentPuzzle.parsedRoot(transform: activeTransform)
        currentNode = rootNode
        isOpponentMoving = false
        highlightedHint = nil
        showHintText = false
        feedbackBanner = nil
        isFeedbackError = false
    }

    private func resetCurrentPuzzle() {
        replyTask?.cancel()
        boardState = currentPuzzle.initialBoardState(transform: activeTransform)
        currentNode = rootNode
        isOpponentMoving = false
        highlightedHint = nil
        feedbackBanner = nil
        isFeedbackError = false
        SoundAndHapticsManager.shared.playUndo()
    }

    private func restartWholeRun(shuffle: Bool) {
        replyTask?.cancel()
        if !isGhostBuster {
            appState.refreshGauntletHearts()
            if appState.currentGauntletHearts <= 0 {
                runQueue = puzzles
                solvedCount = 0
                runState = .outOfHearts
                return
            }
        } else {
            ghostHearts = 3
        }

        if shuffle && puzzles.count > 1 {
            var shuffled = puzzles.shuffled()
            if shuffled.map(\.id) == puzzles.map(\.id) {
                shuffled.append(shuffled.removeFirst())
            }
            runQueue = shuffled
        } else {
            runQueue = puzzles
        }
        solvedCount = 0
        missedIdsInRun = []
        mistakesInRun = 0
        usedAnyHint = false
        combo = 0
        runState = .playing
        loadCurrentPuzzle(forceNewTransform: shuffle)
    }

    private func toggleHintOverlay() {
        guard !isExam, let node = currentNode else { return }
        if showHintText {
            withAnimation(.easeInOut(duration: 0.2)) {
                showHintText = false
                highlightedHint = nil
            }
            SoundAndHapticsManager.shared.playUITap()
        } else {
            usedAnyHint = true
            withAnimation(.easeInOut(duration: 0.2)) {
                showHintText = true
                highlightedHint = GoPuzzle.firstCorrectMove(from: node)
            }
            SoundAndHapticsManager.shared.playHint()
        }
    }

    private func handleTap(at point: BoardPoint) {
        guard runState == .playing, !isOpponentMoving, let node = currentNode else { return }
        guard case .success(let outcome) = boardState.applying(action: .place(point), color: effectivePlayerColor) else {
            illegalFlash = point
            illegalEventID = UUID()
            SoundAndHapticsManager.shared.playKoBounce()
            return
        }

        highlightedHint = nil
        boardState = outcome.nextState
        if !outcome.capturedPoints.isEmpty {
            lastCaptured = outcome.capturedPoints
            captureEventID = UUID()
            SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
        } else {
            SoundAndHapticsManager.shared.playStonePlace()
        }

        let matched = node.children.first { ch in
            if let mv = ch.move, case .place(let pt) = mv.action {
                return pt == point && mv.color == effectivePlayerColor
            }
            return false
        }

        guard let nextNode = matched else {
            handleWrongMove()
            return
        }

        currentNode = nextNode
        if let c = nextNode.comment?.uppercased(), c.contains("CORRECT") {
            handlePuzzleSolved()
            return
        }

        let oppMoves = nextNode.children.filter { $0.move?.color == effectivePlayerColor.opposite }
        if let opp = oppMoves.randomElement(), let oppMove = opp.move {
            isOpponentMoving = true
            replyTask = Task {
                try? await Task.sleep(nanoseconds: 340_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if case .success(let oppOut) = boardState.applying(action: oppMove.action, color: oppMove.color) {
                        boardState = oppOut.nextState
                        if !oppOut.capturedPoints.isEmpty {
                            lastCaptured = oppOut.capturedPoints
                            captureEventID = UUID()
                            SoundAndHapticsManager.shared.playCapture(count: oppOut.capturedPoints.count)
                        } else {
                            SoundAndHapticsManager.shared.playStonePlace()
                        }
                    }
                    currentNode = opp
                    isOpponentMoving = false
                    if let c = opp.comment?.uppercased() {
                        if c.contains("WRONG") {
                            handleWrongMove()
                        } else if c.contains("CORRECT") {
                            handlePuzzleSolved()
                        }
                    }
                }
            }
        } else {
            handleWrongMove()
        }
    }

    private func handleWrongMove() {
        mistakesInRun += 1
        combo = 0
        missedIdsInRun.insert(currentPuzzle.id)
        SoundAndHapticsManager.shared.playWrong()
        appState.recordPuzzleMistake(puzzleId: currentPuzzle.id, isStarterBootcamp: false)

        let remainingHearts: Int
        if isGhostBuster {
            ghostHearts = max(0, ghostHearts - 1)
            remainingHearts = ghostHearts
        } else {
            remainingHearts = appState.consumeGauntletHeart(forPuzzleId: currentPuzzle.id)
        }

        if remainingHearts <= 0 {
            SoundAndHapticsManager.shared.playVoice(.encourageLoss, delay: 0.16)
            runState = .outOfHearts
            return
        }
        SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)

        let willRequeue = runQueue.count > 1
        isFeedbackError = true
        feedbackBanner = willRequeue
            ? l10n.localized(
                zh: "这手不对哦（-1 ❤️）！已放回本关末尾，换向后再来考你！",
                en: "Not quite (-1 ❤️)! Moved to the end of this stage — you'll face it rotated!",
                ja: "不正解（ハート-1）！このステージの最後へ回したので、後でもう一度挑戦しよう！",
                ko: "오답이에요 (-1 ❤️)! 이 스테이지 끝으로 보냈으니 회전된 판에서 다시 도전해요!",
                zhHant: "這手不對喔（-1 ❤️）！已放回本關末尾，換向後再來考你！"
            )
            : l10n.localized(
                zh: "这手不对哦（-1 ❤️）！棋盘即将换向，仔细算清再落子！",
                en: "Not quite (-1 ❤️)! Board rotating — read carefully before playing!",
                ja: "不正解（ハート-1）！盤面を回転するのでよく読んで打とう！",
                ko: "오답이에요 (-1 ❤️)! 바둑판을 회전하니 꼼꼼히 읽고 두어보세요!",
                zhHant: "這手不對喔（-1 ❤️）！棋盤即將換向，仔細算清再落子！"
            )

        isOpponentMoving = true
        replyTask = Task {
            try? await Task.sleep(nanoseconds: 1_150_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if runQueue.count > 1 {
                    let missed = runQueue.removeFirst()
                    runQueue.append(missed)
                    loadCurrentPuzzle(forceNewTransform: false)
                } else {
                    loadCurrentPuzzle(forceNewTransform: true)
                }
            }
        }
    }

    private func handlePuzzleSolved() {
        combo += 1
        solvedCount += 1
        SoundAndHapticsManager.shared.playSuccess()
        let hasMore = runQueue.count > 1
        if hasMore {
            if combo == 3 {
                SoundAndHapticsManager.shared.playVoice(.combo3, delay: 0.10)
            } else if combo >= 5 && combo % 5 == 0 {
                SoundAndHapticsManager.shared.playVoice(.combo5, delay: 0.10)
            } else {
                SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.10)
            }
        }
        let perStars = mistakesInRun == 0 && !usedAnyHint ? 3 : 2
        _ = appState.recordPuzzleSolved(puzzleId: currentPuzzle.id, stars: perStars)
        if isGhostBuster {
            // Bonus double star coins for clearing an SRS Mistake Ghost!
            appState.updateProfile { $0.starCoins += 15 }
        }

        isFeedbackError = false
        feedbackBanner = l10n.localized(zh: "✨ 妙手正解！", en: "✨ Brilliant Move!", ja: "✨ 妙手・正解！", ko: "✨ 묘수·정답!", zhHant: "✨ 妙手正解！")
        isOpponentMoving = true

        replyTask = Task {
            try? await Task.sleep(nanoseconds: 680_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !runQueue.isEmpty {
                    runQueue.removeFirst()
                }
                if !runQueue.isEmpty {
                    loadCurrentPuzzle()
                } else {
                    finishWholeRun()
                }
            }
        }
    }

    private func finishWholeRun() {
        let stars: Int
        if mistakesInRun == 0 && !usedAnyHint {
            stars = 3
        } else if mistakesInRun <= 1 {
            stars = 2
        } else {
            stars = 1
        }
        earnedStars = stars
        if let nodeId = campaignNodeId {
            // Exam Crown requires 0 mistakes to officially crown; otherwise credits transformed/normal
            let effectiveTier: StageMasteryTier = (masteryTier == .examCrown && mistakesInRun > 0) ? .transformed : masteryTier
            appState.recordCampaignNodeCleared(nodeId: nodeId, stars: stars, masteryTier: effectiveTier)
        }
        if isGhostBuster && appState.currentGauntletHearts < PuzzleProgressStore.maxGauntletHearts {
            // Clearing SRS Mistake Ghosts also rewards full hearts!
            appState.restoreGauntletHeartsFromMistakeReview(reviewedPuzzleIds: puzzles.map(\.id))
        }
        SoundAndHapticsManager.shared.playVictoryFanfare()
        SoundAndHapticsManager.shared.playVoice(.victory, delay: 0.24)
        runState = .victory
    }
}

//
//  GoMiniDrillPlayView.swift
//  StarYi Go — Interactive Arena for All 4 Specialized Kid-Friendly Go Mini-Drills (P2)
//

import SwiftUI

struct GoMiniDrillPlayView: View {
    @EnvironmentObject var appState: AppState
    let kind: MiniDrillKind
    var campaignNodeId: String? = nil
    var startOffset: Int = 0
    var targetQuestionCount: Int? = nil

    @State private var index: Int = 0
    @State private var questionsDone: Int = 0
    @State private var score: Int = 0
    @State private var answered: Bool = false
    @State private var isCorrectAnswer: Bool = false
    @State private var feedbackText: String = ""
    @State private var campaignClearedStars: Int? = nil

    // Animated Ladder playback state
    @State private var displayState: GoBoardState = GoBoardState(size: 9)
    @State private var animTask: Task<Void, Never>?

    // Counting quiz territory reveal
    @State private var showCountingReveal: Bool = false

    // Speed Liberties countdown timer (60s)
    @State private var secondsLeft: Int = 60
    @State private var drillTimer: Timer?

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }

    private var totalItems: Int {
        switch kind {
        case .speedLiberties: return GoMiniDrillsLibrary.speedLibertyQuestions.count
        case .ladderReading: return GoMiniDrillsLibrary.ladderDrills.count
        case .countingQuiz: return GoMiniDrillsLibrary.countingDrills.count
        case .openingPicker: return GoMiniDrillsLibrary.openingDrills.count
        case .blunderSpotter: return GoMiniDrillsLibrary.blunderDrills.count
        }
    }

    private var goalCount: Int {
        targetQuestionCount ?? totalItems
    }

    private var activeIndex: Int {
        (startOffset + index) % max(1, totalItems)
    }

    private var boardLabels: [BoardPoint: String] {
        switch kind {
        case .openingPicker:
            let item = GoMiniDrillsLibrary.openingDrills[activeIndex]
            var map: [BoardPoint: String] = [:]
            for c in item.choices { map[c.point] = c.id }
            return map
        case .ladderReading:
            let item = GoMiniDrillsLibrary.ladderDrills[activeIndex]
            if !answered, let first = BoardPoint(sgf: item.firstAtariBlackSGF) {
                return [first: "①"]
            }
            return [:]
        case .blunderSpotter:
            let item = GoMiniDrillsLibrary.blunderDrills[activeIndex]
            var map: [BoardPoint: String] = [:]
            if let bp = item.blunderPoint { map[bp] = "✕" }
            if answered, let cp = item.correctPoints.first { map[cp] = "✓" }
            return map
        default:
            return [:]
        }
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
                            title: kind.title(isChinese: isZh),
                            subtitle: isZh ? "第 \(min(questionsDone + 1, goalCount))/\(goalCount) 题 · 得分 \(score)" : "Q \(min(questionsDone + 1, goalCount))/\(goalCount) · Score \(score)"
                        )
                        Spacer()
                        if kind == .speedLiberties {
                            Text("⏱ \(secondsLeft)s")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundColor(secondsLeft <= 10 ? .white : AppTheme.coralBottom)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(secondsLeft <= 10 ? AppTheme.coralBottom : Color.white))
                        }
                    }

                    if isCompact {
                        let side = min(geo.size.width - pad * 2, geo.size.height * 0.45)
                        drillBoard.frame(width: side, height: side)
                        ScrollView { controlPanel }
                    } else {
                        let sideW: CGFloat = min(390, max(330, geo.size.width * 0.34))
                        let side = max(260, min(geo.size.width - sideW - pad * 3, geo.size.height - 92))
                        HStack(spacing: pad) {
                            drillBoard
                                .frame(width: side, height: side)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            ScrollView { controlPanel }
                                .frame(width: sideW)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadCurrentItem()
            if kind == .speedLiberties { startSpeedTimer() }
        }
        .onDisappear {
            animTask?.cancel()
            drillTimer?.invalidate()
        }
    }

    private var drillBoard: some View {
        GoBoardView(
            boardState: displayState,
            theme: appState.settings.boardTheme,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: kind != .speedLiberties && kind != .ladderReading,
            expressiveStones: false,
            showLiveLiberties: false,
            showTwoEyeGlow: false,
            territoryEstimate: (kind == .countingQuiz && showCountingReveal) ? GoScoring.estimateTerritory(state: displayState) : nil,
            labeledPoints: boardLabels,
            isInteractive: kind == .speedLiberties || kind == .openingPicker || kind == .blunderSpotter,
            onSelectPoint: { pt in
                handleBoardTap(pt)
            }
        )
    }

    @ViewBuilder
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let stars = campaignClearedStars {
                VStack(spacing: 12) {
                    Text("🏆").font(.system(size: 46))
                    Text(isZh ? "专项闯关完成！" : "Mini-Drill Cleared!")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    HStack(spacing: 6) {
                        ForEach(1...3, id: \.self) { i in
                            Image(systemName: i <= stars ? "star.fill" : "star")
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(i <= stars ? AppTheme.sunBottom : AppTheme.subtleBorder)
                        }
                    }
                    Text(isZh ? "答对 \(score)/\(goalCount) 题" : "Scored \(score)/\(goalCount)")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)

                    Button {
                        appState.popRoute()
                    } label: {
                        Label(isZh ? "返回岛屿继续闯关" : "Return to Island", systemImage: "flag.checkered")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }
                .frame(maxWidth: .infinity)
                .warmCard(cornerRadius: 24, padding: 18)
            } else {
            switch kind {
            case .speedLiberties:
                let q = GoMiniDrillsLibrary.speedLibertyQuestions[activeIndex]
                promptCard(title: isZh ? "闪电火眼金睛" : "Speed Spotter", body: isZh ? q.promptZh : q.promptEn)

            case .ladderReading:
                let item = GoMiniDrillsLibrary.ladderDrills[activeIndex]
                promptCard(
                    title: isZh ? item.titleZh : item.titleEn,
                    body: isZh ? "黑棋下在 ① 发动征子！不要落子，先在脑中沿着 45° 斜线算清楚：征子能吃掉白棋吗？" : "Black starts the ladder at ①! Read in your head without placing stones: does Black capture White?"
                )
                if !answered {
                    HStack(spacing: 10) {
                        Button { answerLadder(guessWorks: true) } label: {
                            Label(isZh ? "征子成立 ✅" : "Works ✅", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                        Button { answerLadder(guessWorks: false) } label: {
                            Label(isZh ? "征子失败 ❌" : "Fails ❌", systemImage: "xmark.circle.fill")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                    }
                }

            case .countingQuiz:
                let item = GoMiniDrillsLibrary.countingDrills[activeIndex]
                promptCard(
                    title: isZh ? item.titleZh : item.titleEn,
                    body: isZh ? "中国数子法（白棋贴 \(String(format: "%.1f", item.komi)) 目）：不用辅助工具，快速心算判断哪一方领先？" : "Chinese Area Scoring (Komi \(String(format: "%.1f", item.komi))): Estimate who is ahead on the board!"
                )
                if !answered {
                    HStack(spacing: 10) {
                        Button { answerCounting(guessWinner: .black) } label: {
                            Text(isZh ? "⚫️ 黑棋领先" : "⚫️ Black Ahead")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))

                        Button { answerCounting(guessWinner: .white) } label: {
                            Text(isZh ? "⚪️ 白棋领先" : "⚪️ White Ahead")
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                    }
                }

            case .openingPicker:
                let item = GoMiniDrillsLibrary.openingDrills[activeIndex]
                promptCard(title: isZh ? item.titleZh : item.titleEn, body: isZh ? item.promptZh : item.promptEn)
                VStack(spacing: 9) {
                    ForEach(item.choices) { ch in
                        Button {
                            answerOpening(ch)
                        } label: {
                            HStack {
                                Text(isZh ? ch.labelZh : ch.labelEn)
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.inkPrimary)
                                Spacer()
                                if answered {
                                    Image(systemName: ch.isCorrect ? "checkmark.circle.fill" : "xmark.circle")
                                        .foregroundColor(ch.isCorrect ? AppTheme.mintBottom : AppTheme.coralBottom)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 18, rimHeight: 4, whiteBorderWidth: 2.5))
                        .disabled(answered)
                    }
                }

            case .blunderSpotter:
                let item = GoMiniDrillsLibrary.blunderDrills[activeIndex]
                promptCard(
                    title: "\(item.rankBadge) · \(isZh ? item.titleZh : item.titleEn)",
                    body: isZh ? item.promptZh : item.promptEn
                )
            }

            if answered {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isCorrectAnswer ? (isZh ? "🎉 判断完全正确！" : "🎉 Spot On!") : (isZh ? "💡 差点意思，看棋理解析：" : "💡 Good try — here's why:"))
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(isCorrectAnswer ? AppTheme.mintBottom : AppTheme.coralBottom)
                    Text(feedbackText)
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        advanceToNext()
                    } label: {
                        Label(
                            (campaignNodeId != nil && questionsDone + 1 >= goalCount)
                                ? (isZh ? "结算本关星级 →" : "Finish Stage →")
                                : (isZh ? "下一题 →" : "Next Question →"),
                            systemImage: "arrow.right.circle.fill"
                        )
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
                }
                .warmCard(cornerRadius: 22, padding: 14)
            }
            }
        }
    }

    private func promptCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            Text(body)
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(cornerRadius: 22, padding: 14)
    }

    private func loadCurrentItem() {
        animTask?.cancel()
        answered = false
        isCorrectAnswer = false
        feedbackText = ""
        showCountingReveal = false

        switch kind {
        case .speedLiberties:
            displayState = GoMiniDrillsLibrary.speedLibertyQuestions[activeIndex].makeState()
        case .ladderReading:
            displayState = GoMiniDrillsLibrary.ladderDrills[activeIndex].makeState()
        case .countingQuiz:
            displayState = GoMiniDrillsLibrary.countingDrills[activeIndex].makeState()
        case .openingPicker:
            displayState = GoMiniDrillsLibrary.openingDrills[activeIndex].makeState()
        case .blunderSpotter:
            displayState = GoMiniDrillsLibrary.blunderDrills[activeIndex].makeState()
        }
    }

    private func handleBoardTap(_ pt: BoardPoint) {
        guard !answered else { return }
        if kind == .speedLiberties {
            let q = GoMiniDrillsLibrary.speedLibertyQuestions[activeIndex]
            let ok = q.targetPoints.contains(pt)
            finishQuestion(ok: ok, explanation: isZh ? q.explanationZh : q.explanationEn)
        } else if kind == .openingPicker {
            let item = GoMiniDrillsLibrary.openingDrills[activeIndex]
            if let ch = item.choices.first(where: { $0.point == pt }) {
                answerOpening(ch)
            }
        } else if kind == .blunderSpotter {
            let item = GoMiniDrillsLibrary.blunderDrills[activeIndex]
            let ok = item.correctPoints.contains(pt)
            if ok, case .success(let out) = displayState.applying(action: .place(pt), color: .black) {
                displayState = out.nextState
            }
            finishQuestion(ok: ok, explanation: isZh ? item.explanationZh : item.explanationEn)
        }
    }

    private func answerLadder(guessWorks: Bool) {
        let item = GoMiniDrillsLibrary.ladderDrills[activeIndex]
        let eval = item.evaluate()
        let ok = (guessWorks == eval.works)
        finishQuestion(ok: ok, explanation: isZh ? item.explanationZh : item.explanationEn)

        // Automatically animate the exact ladder chase step-by-step so kids SEE the proof!
        animTask?.cancel()
        animTask = Task {
            var cur = item.makeState()
            var turn: StoneColor = .black
            for pt in eval.steps {
                try? await Task.sleep(nanoseconds: 340_000_000)
                guard !Task.isCancelled else { return }
                if case .success(let out) = cur.applying(action: .place(pt), color: turn) {
                    cur = out.nextState
                    turn = turn.opposite
                    await MainActor.run {
                        self.displayState = cur
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                }
            }
        }
    }

    private func answerCounting(guessWinner: StoneColor) {
        let item = GoMiniDrillsLibrary.countingDrills[activeIndex]
        let res = item.exactResult()
        showCountingReveal = true
        let ok = (guessWinner == res.winner)
        let summary = res.chineseRuleSummary(isChinese: isZh)
        finishQuestion(ok: ok, explanation: "\(summary)\n\(isZh ? item.tipZh : item.tipEn)")
    }

    private func answerOpening(_ choice: OpeningChoice) {
        finishQuestion(ok: choice.isCorrect, explanation: isZh ? choice.feedbackZh : choice.feedbackEn)
    }

    private func finishQuestion(ok: Bool, explanation: String) {
        answered = true
        isCorrectAnswer = ok
        feedbackText = explanation
        if ok {
            score += 1
            SoundAndHapticsManager.shared.playSuccess()
            SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.12)
            appState.updateProfile { p in
                p.xp += 10
                p.starCoins += 5
            }
        } else {
            SoundAndHapticsManager.shared.playWrong()
            SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
        }
    }

    private func advanceToNext() {
        questionsDone += 1
        if let nodeId = campaignNodeId, questionsDone >= goalCount {
            let ratio = Double(score) / Double(max(1, goalCount))
            let stars = ratio >= 0.99 ? 3 : (ratio >= 0.65 ? 2 : 1)
            appState.recordCampaignNodeCleared(nodeId: nodeId, stars: stars, masteryTier: .normal)
            campaignClearedStars = stars
            SoundAndHapticsManager.shared.playVictoryFanfare()
            SoundAndHapticsManager.shared.playVoice(.victory, delay: 0.22)
            return
        }
        index = (index + 1) % totalItems
        loadCurrentItem()
    }

    private func startSpeedTimer() {
        drillTimer?.invalidate()
        secondsLeft = 60
        drillTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                if secondsLeft > 0 {
                    secondsLeft -= 1
                } else {
                    drillTimer?.invalidate()
                }
            }
        }
    }
}

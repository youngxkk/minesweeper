//
//  GoMiniDrillPlayView.swift
//  StarYi Go — Interactive Arena for All 4 Specialized Kid-Friendly Go Mini-Drills (P2)
//

import SwiftUI

struct GoMiniDrillPlayView: View {
    @EnvironmentObject var appState: AppState
    let kind: MiniDrillKind

    @State private var index: Int = 0
    @State private var score: Int = 0
    @State private var answered: Bool = false
    @State private var isCorrectAnswer: Bool = false
    @State private var feedbackText: String = ""

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
        }
    }

    private var boardLabels: [BoardPoint: String] {
        switch kind {
        case .openingPicker:
            let item = GoMiniDrillsLibrary.openingDrills[index % GoMiniDrillsLibrary.openingDrills.count]
            var map: [BoardPoint: String] = [:]
            for c in item.choices { map[c.point] = c.id }
            return map
        case .ladderReading:
            let item = GoMiniDrillsLibrary.ladderDrills[index % GoMiniDrillsLibrary.ladderDrills.count]
            if !answered, let first = BoardPoint(sgf: item.firstAtariBlackSGF) {
                return [first: "①"]
            }
            return [:]
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
                            subtitle: isZh ? "第 \(index + 1)/\(totalItems) 题 · 得分 \(score)" : "Q \(index + 1)/\(totalItems) · Score \(score)"
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
            isInteractive: kind == .speedLiberties || kind == .openingPicker,
            onSelectPoint: { pt in
                handleBoardTap(pt)
            }
        )
    }

    @ViewBuilder
    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch kind {
            case .speedLiberties:
                let q = GoMiniDrillsLibrary.speedLibertyQuestions[index % totalItems]
                promptCard(title: isZh ? "闪电火眼金睛" : "Speed Spotter", body: isZh ? q.promptZh : q.promptEn)

            case .ladderReading:
                let item = GoMiniDrillsLibrary.ladderDrills[index % totalItems]
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
                let item = GoMiniDrillsLibrary.countingDrills[index % totalItems]
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
                let item = GoMiniDrillsLibrary.openingDrills[index % totalItems]
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
                        Label(isZh ? "下一题 →" : "Next Question →", systemImage: "arrow.right.circle.fill")
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
            displayState = GoMiniDrillsLibrary.speedLibertyQuestions[index % totalItems].makeState()
        case .ladderReading:
            displayState = GoMiniDrillsLibrary.ladderDrills[index % totalItems].makeState()
        case .countingQuiz:
            displayState = GoMiniDrillsLibrary.countingDrills[index % totalItems].makeState()
        case .openingPicker:
            displayState = GoMiniDrillsLibrary.openingDrills[index % totalItems].makeState()
        }
    }

    private func handleBoardTap(_ pt: BoardPoint) {
        guard !answered else { return }
        if kind == .speedLiberties {
            let q = GoMiniDrillsLibrary.speedLibertyQuestions[index % totalItems]
            let ok = q.targetPoints.contains(pt)
            finishQuestion(ok: ok, explanation: isZh ? q.explanationZh : q.explanationEn)
        } else if kind == .openingPicker {
            let item = GoMiniDrillsLibrary.openingDrills[index % totalItems]
            if let ch = item.choices.first(where: { $0.point == pt }) {
                answerOpening(ch)
            }
        }
    }

    private func answerLadder(guessWorks: Bool) {
        let item = GoMiniDrillsLibrary.ladderDrills[index % totalItems]
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
        let item = GoMiniDrillsLibrary.countingDrills[index % totalItems]
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
            appState.updateProfile { p in
                p.xp += 10
                p.starCoins += 5
            }
        } else {
            SoundAndHapticsManager.shared.playWrong()
        }
    }

    private func advanceToNext() {
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

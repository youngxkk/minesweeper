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
    var isDailyDojoWarmup: Bool = false

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

    // Board tactile & wrong-move feedback state
    @State private var wrongFlashPoint: BoardPoint? = nil
    @State private var wrongFlashID: UUID = UUID()
    @State private var capturedFlashPoints: [BoardPoint] = []
    @State private var captureEventID: UUID = UUID()
    @State private var lastWrongAttemptText: String? = nil
    @State private var hadWrongAttemptOnCurrent: Bool = false

    // Counting quiz territory reveal
    @State private var showCountingReveal: Bool = false

    // Speed Liberties countdown timer (60s)
    @State private var secondsLeft: Int = 60
    @State private var drillTimer: Timer?

    private var l10n: L10n { appState.l10n }

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
            for c in item.choices where displayState.stone(at: c.point) == nil {
                map[c.point] = c.id
            }
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
                        GameTitleCrest(
                            title: kind.title(isChinese: l10n.language.isChinese),
                            subtitle: l10n.localized(
                                zh: "第 \(min(questionsDone + 1, goalCount))/\(goalCount) 题 · 得分 \(score)",
                                en: "Q \(min(questionsDone + 1, goalCount))/\(goalCount) · Score \(score)",
                                ja: "第 \(min(questionsDone + 1, goalCount))/\(goalCount) 問 · スコア \(score)",
                                ko: "\(min(questionsDone + 1, goalCount))/\(goalCount)번 · 점수 \(score)",
                                zhHant: "第 \(min(questionsDone + 1, goalCount))/\(goalCount) 題 · 得分 \(score)"
                            )
                        )

                        HStack {
                            GameBackButton(title: l10n.t("common.back")) {
                                appState.popRoute()
                            }
                            Spacer()
                            if kind == .speedLiberties {
                                Text("⏱ \(secondsLeft)s")
                                    .font(AppFont.rounded(size: 14, weight: .black))
                                    .foregroundColor(secondsLeft <= 10 ? .white : AppTheme.coralBottom)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Capsule().fill(secondsLeft <= 10 ? AppTheme.coralBottom : Color.white))
                            }
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
            stoneStyle: appState.settings.stoneStyle,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: false,
            highlightAtari: kind != .speedLiberties && kind != .ladderReading,
            expressiveStones: false,
            showLiveLiberties: false,
            showTwoEyeGlow: false,
            territoryEstimate: (kind == .countingQuiz && showCountingReveal) ? GoScoring.estimateTerritory(state: displayState) : nil,
            labeledPoints: boardLabels,
            previewColor: .black,
            isInteractive: !answered && (kind == .speedLiberties || kind == .openingPicker || kind == .blunderSpotter),
            capturedFlashPoints: capturedFlashPoints,
            captureEventID: captureEventID,
            illegalFlashPoint: wrongFlashPoint,
            illegalEventID: wrongFlashID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
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
                    Text("🏆").font(AppFont.rounded(size: 46, weight: .regular))
                    Text(isDailyDojoWarmup
                         ? l10n.localized(zh: "今日热身完成！", en: "Daily Warmup Done!", ja: "今日のウォームアップ完了！", ko: "오늘의 워밍업 완료!", zhHant: "今日熱身完成！")
                         : l10n.localized(zh: "专项闯关完成！", en: "Mini-Drill Cleared!", ja: "特訓クリア！", ko: "특훈 클리어!", zhHant: "專項闖關完成！"))
                        .font(AppFont.rounded(size: 20, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    HStack(spacing: 6) {
                        ForEach(1...3, id: \.self) { i in
                            Image(systemName: i <= stars ? "star.fill" : "star")
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .foregroundColor(i <= stars ? AppTheme.sunBottom : AppTheme.subtleBorder)
                        }
                    }
                    Text(l10n.localized(zh: "答对 \(score)/\(goalCount) 题", en: "Scored \(score)/\(goalCount)", ja: "\(score)/\(goalCount) 問正解", ko: "\(score)/\(goalCount)문제 정답", zhHant: "答對 \(score)/\(goalCount) 題"))
                        .font(AppFont.rounded(size: 14, weight: .heavy))
                        .foregroundColor(AppTheme.inkSecondary)

                    if isDailyDojoWarmup {
                        Button {
                            appState.popRoute()
                        } label: {
                            Label(
                                l10n.localized(zh: "返回每日道场", en: "Return to Daily Dojo", ja: "毎日の道場に戻る", ko: "일일 도장으로 돌아가기", zhHant: "返回每日道場"),
                                systemImage: "flag.checkered"
                            )
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
                    } else if let nodeId = campaignNodeId, let nextNode = StarYiCampaign.nextNode(after: nodeId) {
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
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
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
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
                    }
                }
                .frame(maxWidth: .infinity)
                .warmCard(cornerRadius: 24, padding: 18)
            } else {
            switch kind {
            case .speedLiberties:
                let q = GoMiniDrillsLibrary.speedLibertyQuestions[activeIndex]
                promptCard(
                    title: l10n.localized(zh: "闪电火眼金睛", en: "Speed Spotter", ja: "スピード呼吸点チェック", ko: "스피드 활로 찾기", zhHant: "閃電火眼金睛"),
                    body: l10n.localized(zh: q.promptZh, en: q.promptEn)
                )

            case .ladderReading:
                let item = GoMiniDrillsLibrary.ladderDrills[activeIndex]
                promptCard(
                    title: l10n.localized(zh: item.titleZh, en: item.titleEn),
                    body: l10n.localized(
                        zh: "黑棋下在 ① 发动征子！不要落子，先在脑中沿着 45° 斜线算清楚：征子能吃掉白棋吗？",
                        en: "Black starts the ladder at ①! Read in your head without placing stones: does Black capture White?",
                        ja: "黒①でシチョウを仕掛けます！石を置かずに頭の中で斜めに読み切りましょう：黒は白を取れますか？",
                        ko: "흑이 ①에 두어 축을 시작합니다! 돌을 놓지 말고 머릿속으로 대각선을 수읽기해 보세요: 축으로 백을 잡을 수 있을까요?",
                        zhHant: "黑棋下在 ① 發動征子！不要落子，先在腦中沿著 45° 斜線算清楚：征子能吃掉白棋嗎？"
                    )
                )
                if !answered {
                    HStack(spacing: 10) {
                        Button { answerLadder(guessWorks: true) } label: {
                            Label(l10n.localized(zh: "征子成立 ✅", en: "Works ✅", ja: "シチョウ成立 ✅", ko: "축 성립 ✅", zhHant: "征子成立 ✅"), systemImage: "checkmark.circle.fill")
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))

                        Button { answerLadder(guessWorks: false) } label: {
                            Label(l10n.localized(zh: "征子失败 ❌", en: "Fails ❌", ja: "シチョウ不成立 ❌", ko: "축 실패 ❌", zhHant: "征子失敗 ❌"), systemImage: "xmark.circle.fill")
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
                    }
                }

            case .countingQuiz:
                let item = GoMiniDrillsLibrary.countingDrills[activeIndex]
                promptCard(
                    title: l10n.localized(zh: item.titleZh, en: item.titleEn),
                    body: l10n.localized(
                        zh: "中国数子法（白棋贴 \(String(format: "%.1f", item.komi)) 目）：不用辅助工具，快速心算判断哪一方领先？",
                        en: "Chinese Area Scoring (Komi \(String(format: "%.1f", item.komi))): Estimate who is ahead on the board!",
                        ja: "中国ルール（コミ \(String(format: "%.1f", item.komi)) 目）：補助なしで素早く形勢判断しましょう。どちらが優勢？",
                        ko: "중국식 계가(덤 \(String(format: "%.1f", item.komi))집): 보조 도구 없이 빠르게 형세판단해 보세요. 어느 쪽이 유리할까요?",
                        zhHant: "中國數子法（白棋貼 \(String(format: "%.1f", item.komi)) 目）：不用輔助工具，快速心算判斷哪一方領先？"
                    )
                )
                if !answered {
                    HStack(spacing: 10) {
                        Button { answerCounting(guessWinner: .black) } label: {
                            Text(l10n.localized(zh: "⚫️ 黑棋领先", en: "⚫️ Black Ahead", ja: "⚫️ 黒優勢", ko: "⚫️ 흑 우세", zhHant: "⚫️ 黑棋領先"))
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))

                        Button { answerCounting(guessWinner: .white) } label: {
                            Text(l10n.localized(zh: "⚪️ 白棋领先", en: "⚪️ White Ahead", ja: "⚪️ 白優勢", ko: "⚪️ 백 우세", zhHant: "⚪️ 白棋領先"))
                                .font(AppFont.rounded(size: 15, weight: .black))
                                .foregroundColor(AppTheme.inkPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
                    }
                }

            case .openingPicker:
                let item = GoMiniDrillsLibrary.openingDrills[activeIndex]
                promptCard(title: l10n.localized(zh: item.titleZh, en: item.titleEn), body: l10n.localized(zh: item.promptZh, en: item.promptEn))
                VStack(spacing: 9) {
                    ForEach(item.choices) { ch in
                        Button {
                            answerOpening(ch)
                        } label: {
                            HStack {
                                Text(l10n.localized(zh: ch.labelZh, en: ch.labelEn))
                                    .font(AppFont.rounded(size: 14, weight: .black))
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
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 18, rimHeight: 2.5, whiteBorderWidth: 2.5))
                        .disabled(answered)
                    }
                }

            case .blunderSpotter:
                let item = GoMiniDrillsLibrary.blunderDrills[activeIndex]
                promptCard(
                    title: "\(item.rankBadge) · \(l10n.localized(zh: item.titleZh, en: item.titleEn))",
                    body: l10n.localized(zh: item.promptZh, en: item.promptEn)
                )
            }

            if !answered, let wrongMsg = lastWrongAttemptText {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(l10n.localized(zh: "落子不对，再试试！", en: "Not quite — try again!", ja: "惜しい！もう一度考えてみましょう！", ko: "아쉬워요, 다시 시도해 보세요!", zhHant: "落子不對，再試試！"))
                            .font(AppFont.rounded(size: 14.5, weight: .black))
                            .foregroundColor(.red)
                        Text(wrongMsg)
                            .font(AppFont.rounded(size: 13, weight: .bold))
                            .foregroundColor(AppTheme.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.45), lineWidth: 2)
                        )
                )
            }

            if answered {
                VStack(alignment: .leading, spacing: 8) {
                    Text(isCorrectAnswer
                         ? l10n.localized(zh: "🎉 判断完全正确！", en: "🎉 Spot On!", ja: "🎉 大正解！", ko: "🎉 완벽한 판단이에요!", zhHant: "🎉 判斷完全正確！")
                         : l10n.localized(zh: "💡 差点意思，看棋理解析：", en: "💡 Good try — here's why:", ja: "💡 惜しい！解説をチェック：", ko: "💡 아깝네요! 해설을 확인해 보세요:", zhHant: "💡 差點意思，看棋理解析："))
                        .font(AppFont.rounded(size: 15, weight: .black))
                        .foregroundColor(isCorrectAnswer ? AppTheme.mintBottom : AppTheme.coralBottom)
                    Text(feedbackText)
                        .font(AppFont.rounded(size: 13.5, weight: .bold))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        advanceToNext()
                    } label: {
                        Label(
                            ((campaignNodeId != nil || isDailyDojoWarmup) && questionsDone + 1 >= goalCount)
                                ? (isDailyDojoWarmup
                                    ? l10n.localized(zh: "完成今日热身 →", en: "Finish Warmup →", ja: "今日のウォームアップ完了 →", ko: "오늘의 워밍업 완료 →", zhHant: "完成今日熱身 →")
                                    : l10n.localized(zh: "结算本关星级 →", en: "Finish Stage →", ja: "ステージ結果へ →", ko: "스테이지 정산 →", zhHant: "結算本關星級 →"))
                                : l10n.localized(zh: "下一题 →", en: "Next Question →", ja: "次の問題 →", ko: "다음 문제 →", zhHant: "下一題 →"),
                            systemImage: "arrow.right.circle.fill"
                        )
                            .font(AppFont.rounded(size: 15, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
                }
                .warmCard(cornerRadius: 22, padding: 14)
            }
            }
        }
    }

    private func promptCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.rounded(size: 17, weight: .black))
                .foregroundColor(AppTheme.inkPrimary)
            Text(body)
                .font(AppFont.rounded(size: 13.5, weight: .bold))
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
        wrongFlashPoint = nil
        capturedFlashPoints = []
        lastWrongAttemptText = nil
        hadWrongAttemptOnCurrent = false

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

    private func placeCorrectStone(at pt: BoardPoint, color: StoneColor = .black) {
        if case .success(let out) = displayState.applying(action: .place(pt), color: color) {
            displayState = out.nextState
            if !out.capturedPoints.isEmpty {
                capturedFlashPoints = out.capturedPoints
                captureEventID = UUID()
                SoundAndHapticsManager.shared.playCapture(count: out.capturedPoints.count)
            } else {
                SoundAndHapticsManager.shared.playStonePlace()
            }
        }
    }

    private func triggerBoardWrong(at pt: BoardPoint, message: String) {
        hadWrongAttemptOnCurrent = true
        wrongFlashPoint = pt
        wrongFlashID = UUID()
        lastWrongAttemptText = message
        SoundAndHapticsManager.shared.playWrong()
        SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
    }

    private func handleBoardTap(_ pt: BoardPoint) {
        guard !answered else { return }
        if kind == .speedLiberties {
            let q = GoMiniDrillsLibrary.speedLibertyQuestions[activeIndex]
            if q.targetPoints.contains(pt) {
                let placePoint = (displayState.stone(at: pt) == nil)
                    ? pt
                    : q.targetPoints.first(where: { displayState.stone(at: $0) == nil })
                if let placePoint {
                    placeCorrectStone(at: placePoint, color: .black)
                }
                lastWrongAttemptText = nil
                finishQuestion(ok: true, explanation: l10n.localized(zh: q.explanationZh, en: q.explanationEn))
            } else {
                triggerBoardWrong(
                    at: pt,
                    message: l10n.localized(
                        zh: "这里不是要点哦，再仔细看看棋盘上的气数和急所，重新落子试试！",
                        en: "Not that intersection! Check the liberties and vital point, then try again!",
                        ja: "ここは急所ではありません。呼吸点と急所をよく見て、もう一度打ってみましょう！",
                        ko: "여기는 급소가 아니에요! 활로와 급소를 잘 살펴보고 다시 두어 보세요!",
                        zhHant: "這裡不是要點喔，再仔細看看棋盤上的氣數和急所，重新落子試試！"
                    )
                )
            }
        } else if kind == .openingPicker {
            let item = GoMiniDrillsLibrary.openingDrills[activeIndex]
            if let ch = item.choices.first(where: { $0.point == pt }) {
                answerOpening(ch)
            } else {
                triggerBoardWrong(
                    at: pt,
                    message: l10n.localized(
                        zh: "请点击标有 A / B / C 的候选大场位置哦！",
                        en: "Tap one of the A / B / C candidate points on the board!",
                        ja: "盤上の A / B / C の候補点をタップしてください！",
                        ko: "바둑판 위 A / B / C 후보 자리를 눌러 주세요!",
                        zhHant: "請點擊標有 A / B / C 的候選大場位置喔！"
                    )
                )
            }
        } else if kind == .blunderSpotter {
            let item = GoMiniDrillsLibrary.blunderDrills[activeIndex]
            if item.correctPoints.contains(pt) {
                placeCorrectStone(at: pt, color: .black)
                lastWrongAttemptText = nil
                finishQuestion(ok: true, explanation: l10n.localized(zh: item.explanationZh, en: item.explanationEn))
            } else {
                triggerBoardWrong(
                    at: pt,
                    message: l10n.localized(
                        zh: "这里还不是最佳改错点哦！观察恶手留下的弱点，换个交叉点试试！",
                        en: "Not the winning correction yet! Spot the weakness and try another point!",
                        ja: "まだ最善の修正手ではありません！悪手が残した弱点を見つけて別の交点を試しましょう！",
                        ko: "아직 최선의 교정수가 아니에요! 악수가 남긴 약점을 찾아 다른 곳에 두어 보세요!",
                        zhHant: "這裡還不是最佳改錯點喔！觀察惡手留下的弱點，換個交叉點試試！"
                    )
                )
            }
        }
    }

    private func answerLadder(guessWorks: Bool) {
        let item = GoMiniDrillsLibrary.ladderDrills[activeIndex]
        let eval = item.evaluate()
        let ok = (guessWorks == eval.works)
        finishQuestion(ok: ok, explanation: l10n.localized(zh: item.explanationZh, en: item.explanationEn))

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
        let summary = res.chineseRuleSummary(isChinese: l10n.language.isChinese)
        finishQuestion(ok: ok, explanation: "\(summary)\n\(l10n.localized(zh: item.tipZh, en: item.tipEn))")
    }

    private func answerOpening(_ choice: OpeningChoice) {
        guard !answered else { return }
        if choice.isCorrect {
            placeCorrectStone(at: choice.point, color: .black)
            lastWrongAttemptText = nil
            finishQuestion(ok: true, explanation: l10n.localized(zh: choice.feedbackZh, en: choice.feedbackEn))
        } else {
            triggerBoardWrong(at: choice.point, message: l10n.localized(zh: choice.feedbackZh, en: choice.feedbackEn))
        }
    }

    private func finishQuestion(ok: Bool, explanation: String) {
        answered = true
        isCorrectAnswer = ok
        feedbackText = explanation
        if ok {
            if !hadWrongAttemptOnCurrent {
                score += 1
            }
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
        if isDailyDojoWarmup && questionsDone >= goalCount {
            let ratio = Double(score) / Double(max(1, goalCount))
            let stars = ratio >= 0.99 ? 3 : (ratio >= 0.5 ? 2 : 1)
            appState.recordDailyDojoWarmupCompleted(score: score, total: goalCount)
            campaignClearedStars = stars
            SoundAndHapticsManager.shared.playVictoryFanfare()
            SoundAndHapticsManager.shared.playVoice(.victory, delay: 0.22)
            return
        }
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
                guard !appState.isPortraitGuidanceActive else { return }
                if secondsLeft > 0 {
                    secondsLeft -= 1
                } else {
                    drillTimer?.invalidate()
                }
            }
        }
    }
}

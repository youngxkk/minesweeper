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
                            title: l10n.localized(
                                zh: "🔑 跳级试炼门 · \(sea.localizedName(l10n))",
                                en: "🔑 Skip Gate · \(sea.localizedName(l10n))",
                                ja: "🔑 飛び級試験 · \(sea.localizedName(l10n))",
                                ko: "🔑 월반 시험 · \(sea.localizedName(l10n))",
                                zhHant: "🔑 跳級試煉門 · \(sea.localizedName(l10n))"
                            ),
                            subtitle: l10n.localized(
                                zh: "无辅助考场 · 需答对 \(sea.skipGatePassCount)/\(gatePuzzles.count) 题直接解锁",
                                en: "Exam Mode · Pass \(sea.skipGatePassCount)/\(gatePuzzles.count) to unlock",
                                ja: "ヒントなし試験 · \(sea.skipGatePassCount)/\(gatePuzzles.count) 問正解で即解放",
                                ko: "무힌트 시험 · \(sea.skipGatePassCount)/\(gatePuzzles.count)문제 정답 시 즉시 해금",
                                zhHant: "無輔助考場 · 需答對 \(sea.skipGatePassCount)/\(gatePuzzles.count) 題直接解鎖"
                            )
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
                    Text(l10n.localized(
                        zh: "跳级第 \(index + 1)/\(gatePuzzles.count) 题",
                        en: "Gate Q\(index + 1)/\(gatePuzzles.count)",
                        ja: "飛び級 第 \(index + 1)/\(gatePuzzles.count) 問",
                        ko: "월반 \(index + 1)/\(gatePuzzles.count)번",
                        zhHant: "跳級第 \(index + 1)/\(gatePuzzles.count) 題"
                    ))
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(AppTheme.sunBottom))
                    Text(puzzle.rankBadge)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.grapeBottom)
                    Spacer()
                    Text(l10n.localized(
                        zh: "已对 \(correctCount) 题",
                        en: "\(correctCount) Passed",
                        ja: "\(correctCount) 問正解",
                        ko: "\(correctCount)문제 통과",
                        zhHant: "已對 \(correctCount) 題"
                    ))
                        .font(.system(size: 12.5, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.mintBottom)
                }
                Text(puzzle.category.localizedTitle(l10n))
                    .font(.system(size: 19, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                Text(puzzle.playerColor == .black
                     ? l10n.localized(
                         zh: "黑先：考场无提示模式，请找出盘面唯一正解。",
                         en: "Black to play: Exam mode (no hints) — find the winning move.",
                         ja: "黒番：ヒントなし試験モードです。盤面の正解を見つけよう。",
                         ko: "흑선: 힌트 없는 시험 모드입니다. 바둑판의 정답을 찾아보세요.",
                         zhHant: "黑先：考場無提示模式，請找出盤面唯一正解。"
                     )
                     : l10n.localized(
                         zh: "白先：考场无提示模式，请找出盘面唯一正解。",
                         en: "White to play: Exam mode (no hints) — find the winning move.",
                         ja: "白番：ヒントなし試験モードです。盤面の正解を見つけよう。",
                         ko: "백선: 힌트 없는 시험 모드입니다. 바둑판의 정답을 찾아보세요.",
                         zhHant: "白先：考場無提示模式，請找出盤面唯一正解。"
                     ))
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
                 ? l10n.localized(
                     zh: "跳级成功！已解锁 \(sea.localizedName(l10n))",
                     en: "Gate Cleared! \(sea.localizedName(l10n)) Unlocked!",
                     ja: "飛び級成功！「\(sea.localizedName(l10n))」を解放！",
                     ko: "월반 성공! \(sea.localizedName(l10n)) 해금!",
                     zhHant: "跳級成功！已解鎖 \(sea.localizedName(l10n))"
                 )
                 : l10n.localized(
                     zh: "差一点点！答对 \(correctCount)/\(gatePuzzles.count) 题",
                     en: "Almost! Scored \(correctCount)/\(gatePuzzles.count)",
                     ja: "あと少し！\(correctCount)/\(gatePuzzles.count) 問正解",
                     ko: "조금만 더! \(correctCount)/\(gatePuzzles.count)문제 정답",
                     zhHant: "差一點點！答對 \(correctCount)/\(gatePuzzles.count) 題"
                 ))
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
                .multilineTextAlignment(.center)
            Text(didPass
                 ? l10n.localized(
                     zh: "你的实力已经足够驾驭这片海域！可以直接挑战本海域的岛屿与 Boss！",
                     en: "You've proven your strength — dive straight into this Sea!",
                     ja: "この海域に挑む実力は十分です！島やボスにすぐ挑戦しよう！",
                     ko: "이 해역에 도전할 실력이 충분합니다! 섬과 보스에 바로 도전해 보세요!",
                     zhHant: "你的實力已經足夠駕馭這片海域！可以直接挑戰本海域的島嶼與 Boss！"
                 )
                 : l10n.localized(
                     zh: "需要答对至少 \(sea.skipGatePassCount) 题才能跳级，可以先练几关再来挑战！",
                     en: "Score at least \(sea.skipGatePassCount) to skip ahead — try again anytime!",
                     ja: "飛び級には \(sea.skipGatePassCount) 問以上の正解が必要です。少し練習してから再挑戦しよう！",
                     ko: "월반하려면 최소 \(sea.skipGatePassCount)문제를 맞혀야 합니다. 조금 연습하고 다시 도전해 보세요!",
                     zhHant: "需要答對至少 \(sea.skipGatePassCount) 題才能跳級，可以先練幾關再來挑戰！"
                 ))
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
                        Text(l10n.localized(zh: "重新试炼", en: "Try Again", ja: "再挑戦", ko: "다시 시험", zhHant: "重新試煉"))
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
                    Text(didPass
                         ? l10n.localized(zh: "扬帆起航 →", en: "Set Sail →", ja: "出航する →", ko: "출항하기 →", zhHant: "揚帆起航 →")
                         : l10n.localized(zh: "返回地图", en: "Back to Map", ja: "マップへ戻る", ko: "지도로 돌아가기", zhHant: "返回地圖"))
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
            statusBanner = l10n.localized(zh: "✅ 正解！", en: "✅ Correct!", ja: "✅ 正解！", ko: "✅ 정답!", zhHant: "✅ 正解！")
            SoundAndHapticsManager.shared.playSuccess()
            if index + 1 < gatePuzzles.count {
                SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.10)
            }
        } else {
            statusBanner = l10n.localized(
                zh: "❌ 本题未通过，继续下一题",
                en: "❌ Missed — moving to next question",
                ja: "❌ 不正解・次の問題へ進みます",
                ko: "❌ 오답 · 다음 문제로 넘어갑니다",
                zhHant: "❌ 本題未通過，繼續下一題"
            )
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

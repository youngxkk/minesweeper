//
//  RankExamHallView.swift
//  StarYi Go — Dual-Requirement Rank Certification Hall & 5-Question Exam Mode Test (P2)
//

import SwiftUI

struct RankExamHallView: View {
    @EnvironmentObject var appState: AppState

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            VStack(spacing: 14) {
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        appState.popRoute()
                    }
                    Spacer()
                    GameTitleCrest(
                        title: isZh ? "星弈段级位考级室" : "Rank Certification Hall",
                        subtitle: isZh ? "当前官方认证：\(appState.profile.rankString)" : "Certified Rank: \(appState.profile.rankString)"
                    )
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 310, maximum: 460), spacing: 16)], spacing: 16) {
                        ForEach(RankExamSystem.allExams) { spec in
                            examCard(spec)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func examCard(_ spec: RankExamSpec) -> some View {
        let rec = appState.puzzleProgress.rankExamRecord
        let writtenOK = rec.isWrittenPassed(spec.tier)
        let wins = rec.wins(for: spec.tier)
        let played = rec.gamesPlayed(for: spec.tier)
        let matchOK = rec.isMatchPassed(spec)
        let certified = rec.isFullyCertified(spec)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(spec.rankCode)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(certified ? AppTheme.mintBottom : AppTheme.skyBottom))

                Text(spec.title(isChinese: isZh))
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)

                Spacer()

                if certified {
                    Image(systemName: "rosette")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(AppTheme.sunBottom)
                }
            }

            HStack(spacing: 8) {
                Label(
                    isZh ? "笔试 5 题（对 \(spec.requiredPuzzlePass) 题）" : "Test (\(spec.requiredPuzzlePass)/5)",
                    systemImage: writtenOK ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(writtenOK ? AppTheme.mintBottom : AppTheme.inkSecondary)

                Spacer()

                Label(
                    isZh ? "实战 \(wins)/\(spec.requiredMatchWins) 胜（已赛 \(played)/\(spec.matchSeriesLength)）" : "Matches \(wins)/\(spec.requiredMatchWins) (\(played)/\(spec.matchSeriesLength))",
                    systemImage: matchOK ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(matchOK ? AppTheme.mintBottom : AppTheme.inkSecondary)
            }

            Text(isZh
                 ? "\(spec.boardSize.rawValue)路 · 考场脱拐（无辅助/禁悔棋）· \(spec.timeControl.displayLabel(isChinese: true))"
                 : "\(spec.boardSize.rawValue)×\(spec.boardSize.rawValue) · Exam Sim (No Assist/Undo) · \(spec.timeControl.displayLabel(isChinese: false))")
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)

            HStack(spacing: 10) {
                Button {
                    appState.navigationPath.append(.rankExamTest(tier: spec.tier))
                } label: {
                    Label(writtenOK ? (isZh ? "重考笔试" : "Retake Test") : (isZh ? "考死活笔试" : "Take Written Test"), systemImage: "pencil.and.list.clipboard")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(writtenOK ? AppTheme.inkPrimary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: writtenOK ? .snow : .grape, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

                Button {
                    appState.startRankExamMatch(spec: spec)
                } label: {
                    Label(isZh ? "开始定级赛" : "Play Exam Match", systemImage: "flag.checkered")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
            }
        }
        .padding(16)
        .warmCard(cornerRadius: 24, padding: 0)
    }
}

/// 5-Question Exam-Mode Tsumego Written Test (zero hints, zero visual crutches, 4/5 required to pass!).
struct RankExamWrittenTestView: View {
    @EnvironmentObject var appState: AppState
    let spec: RankExamSpec

    @State private var currentIdx: Int = 0
    @State private var correctCount: Int = 0
    @State private var finished: Bool = false
    @State private var boardState: GoBoardState = GoBoardState(size: 9)
    @State private var currentNode: SGFNode?
    @State private var activeTransform: PuzzleTransform = .identity
    @State private var questionLocked: Bool = false
    @State private var lastResultCorrect: Bool? = nil

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }

    private var puzzles: [GoPuzzle] {
        spec.examPuzzleIds.compactMap { DojoPuzzleBank.findPuzzle(withId: $0) }
    }

    private var currentPuzzle: GoPuzzle? {
        guard currentIdx < puzzles.count else { return nil }
        return puzzles[currentIdx]
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            VStack(spacing: 14) {
                HStack {
                    GameBackButton(title: l10n.t("common.back")) {
                        appState.popRoute()
                    }
                    Spacer()
                    GameTitleCrest(
                        title: isZh ? "\(spec.rankCode) 考级笔试" : "\(spec.rankCode) Written Exam",
                        subtitle: isZh ? "第 \(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count) 题 · 无提示无辅助" : "Q \(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count) · Exam Mode"
                    )
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 14)

                if finished {
                    examSummaryCard
                        .padding(24)
                        .frame(maxWidth: 460)
                    Spacer()
                } else if let puzzle = currentPuzzle {
                    GeometryReader { geo in
                        let side = min(geo.size.width - 48, geo.size.height * 0.56, 460)
                        VStack(spacing: 14) {
                            GoBoardView(
                                boardState: boardState,
                                theme: appState.settings.boardTheme,
                                cropRegion: activeTransform.apply(to: puzzle.cropRegion, boardSize: puzzle.boardSize),
                                showCoordinates: true,
                                showMoveNumbers: false,
                                highlightAtari: false,
                                expressiveStones: false,
                                showLiveLiberties: false,
                                showTwoEyeGlow: false,
                                previewColor: activeTransform.apply(to: puzzle.playerColor),
                                isInteractive: !questionLocked,
                                onSelectPoint: { pt in handleExamTap(pt, puzzle: puzzle) }
                            )
                            .frame(width: side, height: side)

                            VStack(spacing: 8) {
                                Text(puzzle.prompt(l10n, activeColor: activeTransform.apply(to: puzzle.playerColor)))
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.inkPrimary)
                                    .multilineTextAlignment(.center)

                                if let ok = lastResultCorrect {
                                    Text(ok ? (isZh ? "✓ 本题答对！" : "✓ Correct!") : (isZh ? "✕ 本题失误" : "✕ Incorrect"))
                                        .font(.system(size: 14, weight: .black, design: .rounded))
                                        .foregroundColor(ok ? AppTheme.mintBottom : AppTheme.coralBottom)
                                }
                            }
                            .frame(maxWidth: 480)
                            .warmCard(cornerRadius: 22, padding: 14)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { loadQuestion(0) }
    }

    private var examSummaryCard: some View {
        let passed = correctCount >= spec.requiredPuzzlePass
        return VStack(spacing: 14) {
            Text(passed ? "🎓" : "📚").font(.system(size: 56))
            Text(passed
                 ? (isZh ? "恭喜通过 \(spec.rankCode) 死活笔试！" : "Passed \(spec.rankCode) Written Test!")
                 : (isZh ? "答对 \(correctCount)/\(puzzles.count) 题（需 \(spec.requiredPuzzlePass) 题及格）" : "Scored \(correctCount)/\(puzzles.count) (Need \(spec.requiredPuzzlePass))"))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(passed ? AppTheme.mintBottom : AppTheme.coralBottom)
                .multilineTextAlignment(.center)

            Text(passed
                 ? (isZh ? "太棒了！再赢下对应定级实战赛即可获得官方 \(spec.rankCode) 认证！" : "Awesome! Complete your timed promotion match series to earn \(spec.rankCode)!")
                 : (isZh ? "再去分级题库练练手，很快就能一次通关！" : "Practice a few more puzzles in the Dojo and try again!"))
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

            Button {
                appState.popRoute()
            } label: {
                Text(isZh ? "返回考级室" : "Back to Exam Hall")
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: passed ? .mint : .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
        }
        .warmCard(cornerRadius: 28, padding: 22)
    }

    private func loadQuestion(_ idx: Int) {
        guard idx < puzzles.count else {
            finished = true
            if correctCount >= spec.requiredPuzzlePass {
                appState.recordExamWrittenPass(tier: spec.tier)
                SoundAndHapticsManager.shared.playVictoryFanfare()
                SoundAndHapticsManager.shared.playVoice(.examPass, delay: 0.24)
            } else {
                SoundAndHapticsManager.shared.playVoice(.encourageLoss, delay: 0.18)
            }
            return
        }
        currentIdx = idx
        questionLocked = false
        lastResultCorrect = nil
        activeTransform = PuzzleTransform.random(allowColorSwap: true)
        let p = puzzles[idx]
        boardState = p.initialBoardState(transform: activeTransform)
        currentNode = p.parsedRoot(transform: activeTransform)
    }

    private func handleExamTap(_ pt: BoardPoint, puzzle: GoPuzzle) {
        guard !questionLocked, let node = currentNode else { return }
        let color = activeTransform.apply(to: puzzle.playerColor)
        guard case .success(let out) = boardState.applying(action: .place(pt), color: color) else { return }
        boardState = out.nextState
        SoundAndHapticsManager.shared.playStonePlace()

        let matched = node.children.first { ch in
            if let mv = ch.move, case .place(let p) = mv.action {
                return p == pt && mv.color == color
            }
            return false
        }

        guard let next = matched else {
            concludeQuestion(correct: false)
            return
        }
        currentNode = next

        if (next.comment ?? "").uppercased().contains("CORRECT") {
            concludeQuestion(correct: true)
            return
        }
        if let opp = next.children.randomElement(), let oppMv = opp.move {
            questionLocked = true
            Task {
                try? await Task.sleep(nanoseconds: 340_000_000)
                await MainActor.run {
                    if case .success(let oppOut) = boardState.applying(action: oppMv.action, color: oppMv.color) {
                        boardState = oppOut.nextState
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                    currentNode = opp
                    if (opp.comment ?? "").uppercased().contains("WRONG") || opp.children.isEmpty {
                        concludeQuestion(correct: false)
                    } else if (opp.comment ?? "").uppercased().contains("CORRECT") {
                        concludeQuestion(correct: true)
                    } else {
                        questionLocked = false
                    }
                }
            }
        } else {
            concludeQuestion(correct: GoPuzzle.isCorrectBranch(next))
        }
    }

    private func concludeQuestion(correct: Bool) {
        questionLocked = true
        lastResultCorrect = correct
        if correct {
            correctCount += 1
            SoundAndHapticsManager.shared.playSuccess()
            if currentIdx + 1 < puzzles.count {
                SoundAndHapticsManager.shared.playVoice(.correct, delay: 0.10)
            }
        } else {
            SoundAndHapticsManager.shared.playWrong()
            if currentIdx + 1 < puzzles.count {
                SoundAndHapticsManager.shared.playVoice(.wrong, delay: 0.10)
            }
        }
        Task {
            try? await Task.sleep(nanoseconds: 850_000_000)
            await MainActor.run {
                loadQuestion(currentIdx + 1)
            }
        }
    }
}

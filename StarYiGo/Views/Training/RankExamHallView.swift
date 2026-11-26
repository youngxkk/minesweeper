//
//  RankExamHallView.swift
//  StarYi Go — Dual-Requirement Rank Certification Hall & 5-Question Exam Mode Test (P2)
//

import SwiftUI

struct RankExamHallView: View {
    @EnvironmentObject var appState: AppState

    private var l10n: L10n { appState.l10n }

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
                        title: l10n.localized(zh: "星弈段级位考级室", en: "Rank Certification Hall", ja: "StarYi 段級位認定試験室", ko: "StarYi 급·단 인증 시험실", zhHant: "星弈段級位考級室"),
                        subtitle: l10n.localized(zh: "当前官方认证：\(appState.profile.rankString)", en: "Certified Rank: \(appState.profile.rankString)", ja: "現在の認定段級位：\(appState.profile.rankString)", ko: "현재 공식 인증: \(appState.profile.rankString)", zhHant: "當前官方認證：\(appState.profile.rankString)")
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

                Text(spec.title(isChinese: l10n.language.isChinese))
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
                    l10n.localized(
                        zh: "笔试 5 题（对 \(spec.requiredPuzzlePass) 题）",
                        en: "Test (\(spec.requiredPuzzlePass)/5)",
                        ja: "筆記試験（5問中\(spec.requiredPuzzlePass)問）",
                        ko: "필기시험 (5문제 중 \(spec.requiredPuzzlePass)문제)",
                        zhHant: "筆試 5 題（對 \(spec.requiredPuzzlePass) 題）"
                    ),
                    systemImage: writtenOK ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(writtenOK ? AppTheme.mintBottom : AppTheme.inkSecondary)

                Spacer()

                Label(
                    l10n.localized(
                        zh: "实战 \(wins)/\(spec.requiredMatchWins) 胜（已赛 \(played)/\(spec.matchSeriesLength)）",
                        en: "Matches \(wins)/\(spec.requiredMatchWins) (\(played)/\(spec.matchSeriesLength))",
                        ja: "対局 \(wins)/\(spec.requiredMatchWins)勝（\(played)/\(spec.matchSeriesLength)局）",
                        ko: "실전 \(wins)/\(spec.requiredMatchWins)승 (\(played)/\(spec.matchSeriesLength)국)",
                        zhHant: "實戰 \(wins)/\(spec.requiredMatchWins) 勝（已賽 \(played)/\(spec.matchSeriesLength)）"
                    ),
                    systemImage: matchOK ? "checkmark.circle.fill" : "circle"
                )
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(matchOK ? AppTheme.mintBottom : AppTheme.inkSecondary)
            }

            Text(l10n.localized(
                zh: "\(spec.boardSize.rawValue)路 · 考场脱拐（无辅助/禁悔棋）· \(spec.timeControl.displayLabel(isChinese: true))",
                en: "\(spec.boardSize.rawValue)×\(spec.boardSize.rawValue) · Exam Sim (No Assist/Undo) · \(spec.timeControl.displayLabel(isChinese: false))",
                ja: "\(spec.boardSize.rawValue)路盤 · 本番モード（補助なし・待ったなし）· \(spec.timeControl.displayLabel(isChinese: false))",
                ko: "\(spec.boardSize.rawValue)줄 바둑판 · 실전 시험 (보조 없음/무르기 금지) · \(spec.timeControl.displayLabel(isChinese: false))",
                zhHant: "\(spec.boardSize.rawValue)路 · 考場脫拐（無輔助/禁悔棋）· \(spec.timeControl.displayLabel(isChinese: true))"
            ))
                .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)

            HStack(spacing: 10) {
                Button {
                    appState.navigationPath.append(.rankExamTest(tier: spec.tier))
                } label: {
                    Label(
                        writtenOK
                            ? l10n.localized(zh: "重考笔试", en: "Retake Test", ja: "筆記を再受験", ko: "필기 재응시", zhHant: "重考筆試")
                            : l10n.localized(zh: "考死活笔试", en: "Take Written Test", ja: "詰碁筆記を受験", ko: "사활 필기 응시", zhHant: "考死活筆試"),
                        systemImage: "pencil.and.list.clipboard"
                    )
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(writtenOK ? AppTheme.inkPrimary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: writtenOK ? .snow : .grape, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

                Button {
                    appState.startRankExamMatch(spec: spec)
                } label: {
                    Label(l10n.localized(zh: "开始定级赛", en: "Play Exam Match", ja: "認定対局を開始", ko: "승급 대국 시작", zhHant: "開始定級賽"), systemImage: "flag.checkered")
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
                        title: l10n.localized(zh: "\(spec.rankCode) 考级笔试", en: "\(spec.rankCode) Written Exam", ja: "\(spec.rankCode) 認定筆記試験", ko: "\(spec.rankCode) 승급 필기시험", zhHant: "\(spec.rankCode) 考級筆試"),
                        subtitle: l10n.localized(
                            zh: "第 \(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count) 题 · 无提示无辅助",
                            en: "Q \(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count) · Exam Mode",
                            ja: "第 \(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count) 問 · 本番モード",
                            ko: "\(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count)번 · 시험 모드",
                            zhHant: "第 \(min(currentIdx + 1, max(1, puzzles.count)))/\(puzzles.count) 題 · 無提示無輔助"
                        )
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
                                    Text(ok
                                         ? l10n.localized(zh: "✓ 本题答对！", en: "✓ Correct!", ja: "✓ 正解！", ko: "✓ 정답!", zhHant: "✓ 本題答對！")
                                         : l10n.localized(zh: "✕ 本题失误", en: "✕ Incorrect", ja: "✕ 不正解", ko: "✕ 오답", zhHant: "✕ 本題失誤"))
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
                 ? l10n.localized(zh: "恭喜通过 \(spec.rankCode) 死活笔试！", en: "Passed \(spec.rankCode) Written Test!", ja: "\(spec.rankCode) 筆記試験に合格！", ko: "\(spec.rankCode) 사활 필기시험 합격!", zhHant: "恭喜通過 \(spec.rankCode) 死活筆試！")
                 : l10n.localized(zh: "答对 \(correctCount)/\(puzzles.count) 题（需 \(spec.requiredPuzzlePass) 题及格）", en: "Scored \(correctCount)/\(puzzles.count) (Need \(spec.requiredPuzzlePass))", ja: "\(correctCount)/\(puzzles.count) 問正解（合格ライン \(spec.requiredPuzzlePass) 問）", ko: "\(correctCount)/\(puzzles.count)문제 정답 (합격 기준 \(spec.requiredPuzzlePass)문제)", zhHant: "答對 \(correctCount)/\(puzzles.count) 題（需 \(spec.requiredPuzzlePass) 題及格）"))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(passed ? AppTheme.mintBottom : AppTheme.coralBottom)
                .multilineTextAlignment(.center)

            Text(passed
                 ? l10n.localized(zh: "太棒了！再赢下对应定级实战赛即可获得官方 \(spec.rankCode) 认证！", en: "Awesome! Complete your timed promotion match series to earn \(spec.rankCode)!", ja: "素晴らしい！あとは認定対局シリーズをクリアすれば公式 \(spec.rankCode) を獲得できます！", ko: "훌륭해요! 승급 대국 시리즈까지 통과하면 공식 \(spec.rankCode) 인증을 획득합니다!", zhHant: "太棒了！再贏下對應定級實戰賽即可獲得官方 \(spec.rankCode) 認證！")
                 : l10n.localized(zh: "再去分级题库练练手，很快就能一次通关！", en: "Practice a few more puzzles in the Dojo and try again!", ja: "道場の詰碁でもう少し練習して再挑戦しましょう！", ko: "도장 문제집에서 조금 더 연습하고 다시 도전해 보세요!", zhHant: "再去分級題庫練練手，很快就能一次通關！"))
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
                .multilineTextAlignment(.center)

            Button {
                appState.popRoute()
            } label: {
                Text(l10n.localized(zh: "返回考级室", en: "Back to Exam Hall", ja: "試験室に戻る", ko: "시험실로 돌아가기", zhHant: "返回考級室"))
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

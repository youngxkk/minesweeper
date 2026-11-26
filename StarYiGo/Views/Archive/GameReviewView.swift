//
//  GameReviewView.swift
//  StarYi Go — AI Winrate Curve, Plain-Language Diagnostics, PV Variations & Blunder-to-Puzzle Loop
//

import SwiftUI
import UIKit

struct GameReviewView: View {
    @EnvironmentObject var appState: AppState
    let record: SavedGameRecord

    @State private var mainLineStates: [GoBoardState] = []
    @State private var mainLineMoves: [GoMove] = []
    @State private var mainLineComments: [String?] = []
    @State private var stepIndex: Int = 0
    @State private var isAutoPlaying: Bool = false
    @State private var autoPlayTask: Task<Void, Never>?
    @State private var isVariationMode: Bool = false
    @State private var variationState: GoBoardState?
    @State private var showTerritory: Bool = false
    @State private var showMoveNumbers: Bool = true
    @State private var copiedFeedback: Bool = false
    @State private var variationCaptured: [BoardPoint] = []
    @State private var variationCaptureID: UUID = UUID()

    // P1 AI Review State
    @State private var isAnalyzingGame: Bool = false
    @State private var reviewReport: GameReviewReport? = nil
    @State private var pvPreviewLabels: [BoardPoint: String] = [:]
    @State private var savedBlunderMoveNumbers: Set<Int> = []
    @State private var analysisTask: Task<Void, Never>?

    // Academy Interactive Theater State (Highlights, Master Move Quiz, Good vs Mistake, Stamp)
    @State private var showingCounterExample: Bool = false
    @State private var isQuizMode: Bool = false
    @State private var quizFeedback: String? = nil
    @State private var quizSolved: Bool = false
    @State private var justStampedBanner: Bool = false

    private var l10n: L10n { appState.l10n }
    private var academyEntry: AcademyEntry? { GoAcademyLibrary.entry(forRecordId: record.id) }
    private var isAcademyStudied: Bool {
        guard let entry = academyEntry else { return false }
        return appState.profile.studiedAcademyIds.contains(entry.id)
    }
    private let topBarHeight: CGFloat = 60

    private var activeState: GoBoardState {
        if isVariationMode, let v = variationState { return v }
        guard !mainLineStates.isEmpty else {
            return GoBoardState(size: record.boardSize, komi: record.komi, handicap: record.handicap)
        }
        return mainLineStates[min(max(0, stepIndex), mainLineStates.count - 1)]
    }

    private var currentComment: String? {
        guard !isVariationMode, stepIndex >= 0, stepIndex < mainLineComments.count else { return nil }
        return mainLineComments[stepIndex]
    }

    private var currentReviewedMove: ReviewedMove? {
        guard let report = reviewReport, stepIndex > 0, stepIndex <= report.reviewedMoves.count else { return nil }
        return report.reviewedMoves[stepIndex - 1]
    }

    private var activeMoveNumbers: [BoardPoint: Int] {
        var map: [BoardPoint: Int] = [:]
        guard !isVariationMode else { return map }
        let limit = min(stepIndex, mainLineMoves.count)
        for i in 0..<limit {
            let m = mainLineMoves[i]
            if case .place(let pt) = m.action, activeState.stone(at: pt) != nil {
                map[pt] = m.moveNumber
            }
        }
        return map
    }

    private var activeAISuggestions: [MoveSuggestion] {
        guard !isVariationMode, pvPreviewLabels.isEmpty, let rev = currentReviewedMove, rev.isBlunderOrMistake else {
            return []
        }
        return rev.topVariations.prefix(3).map {
            MoveSuggestion(point: $0.firstMove, score: $0.winrateForMover, reason: $0.reason, pvMoves: $0.pvMoves)
        }
    }

    var body: some View {
        ZStack {
            AppTheme.brightArenaBackground

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let isCompact = w < 700
                let pad: CGFloat = isCompact ? 14 : 22

                VStack(spacing: 12) {
                    HStack {
                        GameBackButton(title: l10n.t("common.back")) {
                            appState.popRoute()
                        }
                        Spacer()
                        GameTitleCrest(
                            title: l10n.t("review.title"),
                            subtitle: l10n.t("review.moveOf", stepIndex, max(0, mainLineStates.count - 1))
                        )
                        Spacer()
                        GameCircleButton(
                            icon: showMoveNumbers ? "number.circle.fill" : "number.circle",
                            palette: showMoveNumbers ? .sky : .snow,
                            tint: showMoveNumbers ? .white : AppTheme.inkSecondary,
                            size: 46
                        ) {
                            showMoveNumbers.toggle()
                        }
                    }
                    .frame(height: topBarHeight)

                    if isCompact {
                        let boardSide = max(0, min(w - pad * 2, h * 0.42))
                        reviewBoard.frame(width: boardSide, height: boardSide)
                        VStack(spacing: 10) {
                            ScrollView(showsIndicators: false) {
                                reviewScrollableContent
                            }
                            reviewPinnedPlaybackDock
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        let sidebarWidth = min(400, max(336, w * 0.33))
                        let boardSide = max(260, min(w - sidebarWidth - pad * 3, h - topBarHeight - pad * 2 - 12))
                        HStack(spacing: pad) {
                            reviewBoard
                                .frame(width: boardSide, height: boardSide)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            VStack(spacing: 10) {
                                ScrollView(showsIndicators: false) {
                                    reviewScrollableContent
                                }
                                reviewPinnedPlaybackDock
                            }
                            .frame(width: sidebarWidth)
                            .frame(maxHeight: .infinity)
                        }
                    }
                }
                .padding(.horizontal, pad)
                .padding(.vertical, 12)
                .frame(width: w, height: h)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            loadMainLineFromSGF()
        }
        .onDisappear {
            stopAutoPlay()
            analysisTask?.cancel()
        }
        .onChange(of: stepIndex) { _, newValue in
            pvPreviewLabels = [:]
            if let entry = academyEntry,
               !showingCounterExample,
               mainLineStates.count > 1,
               newValue == mainLineStates.count - 1 {
                triggerAcademyStamp(entry)
            }
        }
    }

    private var reviewBoard: some View {
        GoBoardView(
            boardState: activeState,
            theme: appState.settings.boardTheme,
            showCoordinates: appState.settings.showCoordinates || academyEntry != nil,
            showMoveNumbers: showMoveNumbers && !isVariationMode,
            moveNumbers: activeMoveNumbers,
            highlightAtari: appState.settings.highlightAtari,
            expressiveStones: appState.settings.expressiveStones && !appState.settings.zenDojoMode && !showMoveNumbers,
            showTwoEyeGlow: !appState.settings.zenDojoMode,
            territoryEstimate: showTerritory ? GoScoring.estimateTerritory(state: activeState) : nil,
            aiSuggestions: activeAISuggestions,
            labeledPoints: pvPreviewLabels,
            previewColor: activeState.currentTurn,
            isInteractive: isVariationMode || isQuizMode,
            capturedFlashPoints: variationCaptured,
            captureEventID: variationCaptureID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
            onSelectPoint: { pt in
                if isQuizMode {
                    handleQuizTap(at: pt)
                    return
                }
                guard isVariationMode, let current = variationState else { return }
                if case .success(let outcome) = current.applying(action: .place(pt), color: current.currentTurn) {
                    variationState = outcome.nextState
                    if !outcome.capturedPoints.isEmpty {
                        variationCaptured = outcome.capturedPoints
                        variationCaptureID = UUID()
                        SoundAndHapticsManager.shared.playCapture(count: outcome.capturedPoints.count)
                    } else {
                        SoundAndHapticsManager.shared.playStonePlace()
                    }
                } else {
                    SoundAndHapticsManager.shared.playWrong()
                }
            }
        )
    }

    private var reviewScrollableContent: some View {
        VStack(spacing: 11) {
            // Header Card
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("\(record.boardSize)×\(record.boardSize)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.skyTop, AppTheme.skyBottom], startPoint: .top, endPoint: .bottom)))
                    Text(record.resultString)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)))
                    Spacer()

                    if reviewReport == nil && !mainLineMoves.isEmpty {
                        Button {
                            runAIAnalysis()
                        } label: {
                            HStack(spacing: 4) {
                                if isAnalyzingGame {
                                    ProgressView().scaleEffect(0.7).tint(.white)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                        .font(.system(size: 11, weight: .black))
                                }
                                Text(
                                    isAnalyzingGame
                                    ? l10n.localized(zh: "分析中...", en: "Analyzing...", ja: "解析中...", ko: "분석 중...", zhHant: "分析中...")
                                    : l10n.localized(zh: "AI 深度复盘", en: "AI Review", ja: "AI 詳細検討", ko: "AI 심층 복기", zhHant: "AI 深度復盤")
                                )
                                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                        .disabled(isAnalyzingGame)
                    }
                }

                Text("⚫️ \(record.blackName)   vs   ⚪️ \(record.whiteName)")
                    .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .warmCard(cornerRadius: 22, padding: 13)

            // Academy Interactive Strip: Stamp + Good vs Mistake + Highlights + Guess Master Move
            if let entry = academyEntry {
                academyInteractiveSection(entry: entry)
            }

            // P1: Interactive Winrate Curve Chart (Tap to jump to any move!)
            if let report = reviewReport {
                winrateCurveCard(report: report)
            }

            // P1: Per-Move AI Quality Diagnosis + PV Variation + One-Click Blunder-to-Puzzle!
            if let rev = currentReviewedMove, !isVariationMode {
                moveDiagnosisCard(rev: rev)
            }

            // Interactive Coach Commentary Bubble from SGF `C[...]`
            if let comment = currentComment, !comment.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    CharacterAvatarView(character: .panda, mood: .greeting, size: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(l10n.t("review.coachLabel"))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.sunBottom)
                        Text(comment)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppTheme.softGoldBg)
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                )
            }
        }
    }

    /// Fixed bottom action buttons + playback controls so neither section shifts vertically as commentary changes.
    private var reviewPinnedPlaybackDock: some View {
        VStack(spacing: 10) {
            // Action Buttons (pinned right above playback controls)
            VStack(spacing: 10) {
                Button {
                    stopAutoPlay()
                    pvPreviewLabels = [:]
                    if isVariationMode {
                        isVariationMode = false
                        variationState = nil
                    } else {
                        variationState = activeState
                        isVariationMode = true
                    }
                } label: {
                    Label(
                        isVariationMode ? l10n.t("review.exitVariation") : l10n.t("review.tryVariation"),
                        systemImage: isVariationMode ? "arrow.uturn.backward.circle.fill" : "hand.tap.fill"
                    )
                    .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                    .foregroundColor(isVariationMode ? .white : AppTheme.inkPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: isVariationMode ? .coral : .snow,
                        cornerRadius: 999,
                        rimHeight: 4,
                        whiteBorderWidth: 2.5
                    )
                )

                HStack(spacing: 10) {
                    Button {
                        showTerritory.toggle()
                    } label: {
                        Label(l10n.t("game.action.territory"), systemImage: "square.grid.3x3.topleft.filled")
                            .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                            .foregroundColor(showTerritory ? .white : AppTheme.skyBottom)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: showTerritory ? .sky : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))

                    Button {
                        UIPasteboard.general.string = record.sgf
                        copiedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            copiedFeedback = false
                        }
                    } label: {
                        Label(
                            copiedFeedback ? l10n.t("review.copiedSGF") : l10n.t("review.copySGF"),
                            systemImage: copiedFeedback ? "checkmark" : "doc.on.doc"
                        )
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundColor(copiedFeedback ? .white : AppTheme.inkPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: copiedFeedback ? .mint : .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                }
            }

            if isVariationMode {
                HStack(spacing: 10) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppTheme.coralBottom)
                    Text(l10n.t("review.variationBanner"))
                        .font(.system(size: 13.5, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom)
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppTheme.coralTop.opacity(0.14))
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(.white, lineWidth: 2.5))
                )
            } else if mainLineStates.count > 1 {
                VStack(spacing: 10) {
                    currentMoveCoordinateRow

                    Slider(
                        value: Binding(
                            get: { Double(stepIndex) },
                            set: {
                                stopAutoPlay()
                                let next = Int($0)
                                if next != stepIndex {
                                    stepIndex = next
                                    SoundAndHapticsManager.shared.playGridTick()
                                }
                            }
                        ),
                        in: 0...Double(mainLineStates.count - 1),
                        step: 1
                    )
                    .tint(AppTheme.skyBottom)

                    HStack(spacing: 8) {
                        navButton("backward.end.fill") { stopAutoPlay(); stepIndex = 0 }
                        navButton("chevron.left") { stopAutoPlay(); stepIndex = max(0, stepIndex - 1) }
                        Button { toggleAutoPlay() } label: {
                            Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 15, weight: .black))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: isAutoPlaying ? .coral : .mint, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
                        navButton("chevron.right") { stopAutoPlay(); stepIndex = min(mainLineStates.count - 1, stepIndex + 1) }
                        navButton("forward.end.fill") { stopAutoPlay(); stepIndex = mainLineStates.count - 1 }
                    }
                }
                .warmCard(cornerRadius: 22, padding: 12)
            }
        }
    }

    // MARK: - P1 Winrate Curve Card

    private func winrateCurveCard(report: GameReviewReport) -> some View {
        let wr = report.winrateHistory[min(stepIndex, report.winrateHistory.count - 1)]
        let lead = report.scoreLeadHistory[min(stepIndex, report.scoreLeadHistory.count - 1)]
        let pct = Int(round(wr * 100))

        let leadStr = String(format: "%+.1f", lead)

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(l10n.localized(
                    zh: "胜率曲线 · 点击跳转",
                    en: "Winrate Curve · Tap to Jump",
                    ja: "勝率グラフ · タップで移動",
                    ko: "승률 그래프 · 탭하여 이동",
                    zhHant: "勝率曲線 · 點擊跳轉"
                ))
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.grapeBottom)
                Spacer()
                Text(l10n.localized(
                    zh: "黑胜率 \(pct)% (\(leadStr)目)",
                    en: "B \(pct)% (\(leadStr) pts)",
                    ja: "黒勝率 \(pct)% (\(leadStr)目)",
                    ko: "흑 승률 \(pct)% (\(leadStr)집)",
                    zhHant: "黑勝率 \(pct)% (\(leadStr)目)"
                ))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.inkPrimary)
            }

            GeometryReader { geo in
                let count = max(2, report.winrateHistory.count)
                Canvas { ctx, size in
                    // 50% midline
                    var mid = Path()
                    mid.move(to: CGPoint(x: 0, y: size.height * 0.5))
                    mid.addLine(to: CGPoint(x: size.width, y: size.height * 0.5))
                    ctx.stroke(mid, with: .color(AppTheme.subtleBorder), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    var line = Path()
                    for (i, val) in report.winrateHistory.enumerated() {
                        let x = size.width * CGFloat(i) / CGFloat(count - 1)
                        let y = size.height * CGFloat(1.0 - min(0.98, max(0.02, val)))
                        if i == 0 { line.move(to: CGPoint(x: x, y: y)) }
                        else { line.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    ctx.stroke(line, with: .color(AppTheme.skyBottom), style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))

                    // Blunder dots
                    for rev in report.keyMistakes {
                        let i = min(rev.moveNumber, count - 1)
                        let x = size.width * CGFloat(i) / CGFloat(count - 1)
                        let y = size.height * CGFloat(1.0 - min(0.98, max(0.02, report.winrateHistory[i])))
                        let dot = CGRect(x: x - 3.5, y: y - 3.5, width: 7, height: 7)
                        ctx.fill(Path(ellipseIn: dot), with: .color(AppTheme.coralBottom))
                    }

                    // Active playhead
                    let curX = size.width * CGFloat(min(stepIndex, count - 1)) / CGFloat(count - 1)
                    var head = Path()
                    head.move(to: CGPoint(x: curX, y: 0))
                    head.addLine(to: CGPoint(x: curX, y: size.height))
                    ctx.stroke(head, with: .color(AppTheme.sunBottom), lineWidth: 2)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            stopAutoPlay()
                            let frac = max(0, min(1, val.location.x / max(1, geo.size.width)))
                            stepIndex = Int(round(frac * Double(count - 1)))
                        }
                )
            }
            .frame(height: 68)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.canvasBackground))

            if !report.keyMistakes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(report.keyMistakes.prefix(5)) { m in
                            Button {
                                stopAutoPlay()
                                stepIndex = m.moveNumber
                            } label: {
                                Text(l10n.localized(
                                    zh: "第\(m.moveNumber)手 \(m.quality.symbol)",
                                    en: "#\(m.moveNumber) \(m.quality.symbol)",
                                    ja: "\(m.moveNumber)手目 \(m.quality.symbol)",
                                    ko: "\(m.moveNumber)수 \(m.quality.symbol)",
                                    zhHant: "第\(m.moveNumber)手 \(m.quality.symbol)"
                                ))
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                                    .foregroundColor(stepIndex == m.moveNumber ? .white : AppTheme.coralBottom)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .frame(minHeight: AppTheme.buttonFaceHeight)
                                    .background(Capsule().fill(stepIndex == m.moveNumber ? AppTheme.coralBottom : AppTheme.coralTop.opacity(0.14)))
                            }
                            .tactileButton(scale: 0.94)
                        }
                    }
                }
            }
        }
        .warmCard(cornerRadius: 22, padding: 12)
    }

    // MARK: - P1 Per-Move Diagnosis + PV + Blunder-to-Puzzle Card

    private func moveDiagnosisCard(rev: ReviewedMove) -> some View {
        let badgeColor: Color = {
            switch rev.quality {
            case .brilliant: return AppTheme.mintBottom
            case .good: return AppTheme.skyBottom
            case .inaccuracy: return AppTheme.sunBottom
            case .mistake, .blunder: return AppTheme.coralBottom
            }
        }()

        let alreadySaved = savedBlunderMoveNumbers.contains(rev.moveNumber)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(l10n.localized(
                    zh: "第 \(rev.moveNumber) 手诊断 \(rev.quality.symbol)",
                    en: "Move #\(rev.moveNumber) \(rev.quality.symbol)",
                    ja: "\(rev.moveNumber)手目の診断 \(rev.quality.symbol)",
                    ko: "\(rev.moveNumber)수 진단 \(rev.quality.symbol)",
                    zhHant: "第 \(rev.moveNumber) 手診斷 \(rev.quality.symbol)"
                ))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(badgeColor))

                Spacer()

                if let firstVar = rev.topVariations.first, !firstVar.pvMoves.isEmpty {
                    Button {
                        togglePVPreview(variation: firstVar)
                    } label: {
                        Label(
                            pvPreviewLabels.isEmpty
                            ? l10n.localized(zh: "看推荐变化", en: "Show AI PV", ja: "推奨変化を見る", ko: "추천 변화도 보기", zhHant: "看推薦變化")
                            : l10n.localized(zh: "隐藏变化", en: "Hide PV", ja: "変化を隠す", ko: "변화도 숨기기", zhHant: "隱藏變化"),
                            systemImage: "sparkles"
                        )
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .frame(minHeight: AppTheme.buttonFaceHeight)
                        .background(Capsule().fill(AppTheme.skyTop.opacity(0.16)))
                    }
                    .tactileButton(scale: 0.94)
                }
            }

            Text(rev.diagnosis(l10n))
                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if rev.isBlunderOrMistake {
                Button {
                    saveBlunderAsPersonalPuzzle(rev)
                } label: {
                    Label(
                        alreadySaved
                        ? l10n.localized(zh: "已加入我的实战错题本 ✓", en: "Added to Mistake Book ✓", ja: "実戦ミス帳に追加済み ✓", ko: "실전 오답노트에 추가됨 ✓", zhHant: "已加入我的實戰錯題本 ✓")
                        : l10n.localized(zh: "一键转成我的实战错题", en: "Save Blunder as Practice Puzzle", ja: "実戦ミス問題として保存", ko: "실전 오답 문제로 저장", zhHant: "一鍵轉成我的實戰錯題"),
                        systemImage: alreadySaved ? "checkmark.circle.fill" : "bookmark.fill"
                    )
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: alreadySaved ? .mint : .coral, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                .disabled(alreadySaved)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(cornerRadius: 22, padding: 12)
    }

    private func togglePVPreview(variation: MoveVariation) {
        if !pvPreviewLabels.isEmpty {
            pvPreviewLabels = [:]
            return
        }
        var labels: [BoardPoint: String] = [:]
        for (idx, pt) in variation.pvMoves.prefix(5).enumerated() {
            labels[pt] = "\(idx + 1)"
        }
        pvPreviewLabels = labels
        SoundAndHapticsManager.shared.playHint()
    }

    private func saveBlunderAsPersonalPuzzle(_ rev: ReviewedMove) {
        let beforeIdx = max(0, min(mainLineStates.count - 1, rev.moveNumber - 1))
        let stateBefore = mainLineStates[beforeIdx]
        if let puzzle = GoTacticalReader.makePersonalPuzzle(
            fromState: stateBefore,
            reviewedMove: rev,
            gameTitle: record.blackName
        ) {
            appState.addPersonalBlunderPuzzle(puzzle)
            savedBlunderMoveNumbers.insert(rev.moveNumber)
            SoundAndHapticsManager.shared.playSuccess()
        }
    }

    private func runAIAnalysis() {
        guard !isAnalyzingGame, let initial = mainLineStates.first, !mainLineMoves.isEmpty else { return }
        isAnalyzingGame = true
        let movesCopy = mainLineMoves
        analysisTask?.cancel()
        analysisTask = Task {
            let report = await CoreMLGoAIEngine.shared.analyzeGame(initialState: initial, moves: movesCopy)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.reviewReport = report
                self.isAnalyzingGame = false
                SoundAndHapticsManager.shared.playSuccess()
                if let worst = report.keyMistakes.first {
                    self.stepIndex = worst.moveNumber
                }
            }
        }
    }

    private var currentMoveCoordinateRow: some View {
        let total = max(0, mainLineStates.count - 1)
        return HStack(spacing: 8) {
            if stepIndex > 0, stepIndex <= mainLineMoves.count {
                let mv = mainLineMoves[stepIndex - 1]
                let colorDot = mv.color == .black ? "⚫️" : "⚪️"
                let pointText: String = {
                    switch mv.action {
                    case .place(let pt):
                        return pt.humanLabel(boardSize: record.boardSize)
                    case .pass:
                        return l10n.localized(zh: "虚着", en: "Pass", ja: "パス", ko: "패스", zhHant: "虛著")
                    case .resign:
                        return l10n.localized(zh: "认输", en: "Resign", ja: "投了", ko: "기권", zhHant: "認輸")
                    }
                }()
                Text(l10n.localized(
                    zh: "第 \(mv.moveNumber) 手 · \(colorDot) 落点 \(pointText)",
                    en: "Move #\(mv.moveNumber) · \(colorDot) \(pointText)",
                    ja: "\(mv.moveNumber)手目 · \(colorDot) \(pointText)",
                    ko: "\(mv.moveNumber)수 · \(colorDot) \(pointText)",
                    zhHant: "第 \(mv.moveNumber) 手 · \(colorDot) 落點 \(pointText)"
                ))
                .font(.system(size: 12.5, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
            } else {
                Text(l10n.localized(
                    zh: "开局前 · 全谱共 \(total) 手",
                    en: "Start · \(total) moves total",
                    ja: "開始前 · 全\(total)手",
                    ko: "시작 전 · 총 \(total)수",
                    zhHant: "開局前 · 全譜共 \(total) 手"
                ))
                .font(.system(size: 12.5, weight: .black, design: .rounded))
                .foregroundColor(AppTheme.inkSecondary)
            }
            Spacer()
            Text("\(stepIndex) / \(total)")
                .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                .foregroundColor(AppTheme.skyBottom)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(AppTheme.skyTop.opacity(0.14)))
        }
    }

    private func navButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(AppTheme.inkPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 4, whiteBorderWidth: 2.5))
    }

    private func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
            return
        }
        if stepIndex >= mainLineStates.count - 1 {
            stepIndex = 0
        }
        isAutoPlaying = true
        autoPlayTask?.cancel()
        autoPlayTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_250_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    if stepIndex + 1 < mainLineStates.count {
                        stepIndex += 1
                        SoundAndHapticsManager.shared.playStonePlace()
                    } else {
                        stopAutoPlay()
                    }
                }
            }
        }
    }

    private func stopAutoPlay() {
        isAutoPlaying = false
        autoPlayTask?.cancel()
        autoPlayTask = nil
    }

    // MARK: - Academy Interactive Theater Helpers

    @ViewBuilder
    private func academyInteractiveSection(entry: AcademyEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Stamp + Good vs Mistake Toggle Row
            HStack(spacing: 8) {
                if isAcademyStudied {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12.5, weight: .black))
                        Text(justStampedBanner
                             ? l10n.localized(zh: "已赏析 ★ +10🪙", en: "Studied ★ +10🪙", ja: "鑑賞済 ★ +10🪙", ko: "감상 완료 ★ +10🪙", zhHant: "已賞析 ★ +10🪙")
                             : l10n.localized(zh: "已赏析 ★", en: "Studied ★", ja: "鑑賞済 ★", ko: "감상 완료 ★", zhHant: "已賞析 ★"))
                            .font(.system(size: 12, weight: .black, design: .rounded))
                    }
                    .foregroundColor(AppTheme.sunBottom)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.softGoldBg))
                } else {
                    Button {
                        triggerAcademyStamp(entry)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "star.circle.fill")
                                .font(.system(size: 12.5, weight: .black))
                            Text(l10n.localized(zh: "已看懂！盖章 +10🪙", en: "Stamp Studied +10🪙", ja: "理解した！+10🪙", ko: "이해 완료! +10🪙", zhHant: "已看懂！蓋章 +10🪙"))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                }

                Spacer()

                if let quiz = entry.quizStep, !showingCounterExample {
                    Button {
                        stopAutoPlay()
                        isVariationMode = false
                        variationState = nil
                        if isQuizMode {
                            isQuizMode = false
                            quizFeedback = nil
                        } else {
                            stepIndex = min(max(0, quiz.beforeMoveIndex), max(0, mainLineStates.count - 1))
                            isQuizMode = true
                            quizSolved = false
                            quizFeedback = nil
                            SoundAndHapticsManager.shared.playUITap()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: isQuizMode ? "xmark.circle.fill" : "sparkles")
                                .font(.system(size: 12, weight: .black))
                            Text(isQuizMode
                                 ? l10n.localized(zh: "退出猜手", en: "Exit Quiz", ja: "終了", ko: "퀴즈 종료", zhHant: "退出猜手")
                                 : l10n.localized(zh: "猜大师下一手", en: "Guess Move", ja: "次の一手", ko: "다음 수 퀴즈", zhHant: "猜大師下一手"))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(GlossyCapsuleButtonStyle(palette: isQuizMode ? .coral : .grape, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 2))
                }
            }

            // 2. Good vs Mistake One-Tap Comparison (for 棋理十诀 / 奇局)
            if entry.hasCounterExample {
                HStack(spacing: 8) {
                    Button {
                        if showingCounterExample {
                            stopAutoPlay()
                            isQuizMode = false
                            isVariationMode = false
                            showingCounterExample = false
                            loadMainLineFromSGF()
                            SoundAndHapticsManager.shared.playUITap()
                        }
                    } label: {
                        Text(l10n.localized(zh: "✅ 正着演示", en: "✅ Good Move", ja: "✅ 正解", ko: "✅ 정수", zhHant: "✅ 正著演示"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(!showingCounterExample ? .white : AppTheme.mintBottom)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(!showingCounterExample ? AppTheme.mintBottom : AppTheme.mintTop.opacity(0.14)))
                    }
                    .tactileButton(scale: 0.96, sound: false)

                    Button {
                        if !showingCounterExample {
                            stopAutoPlay()
                            isQuizMode = false
                            isVariationMode = false
                            showingCounterExample = true
                            loadMainLineFromSGF()
                            SoundAndHapticsManager.shared.playUITap()
                        }
                    } label: {
                        Text(l10n.localized(zh: "❌ 贪心/错着对比", en: "❌ Mistake Demo", ja: "❌ 失敗例", ko: "❌ 실수 비교", zhHant: "❌ 貪心/錯著對比"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(showingCounterExample ? .white : AppTheme.coralBottom)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(showingCounterExample ? AppTheme.coralBottom : AppTheme.coralTop.opacity(0.14)))
                    }
                    .tactileButton(scale: 0.96, sound: false)
                }
            }

            // 3. Master Move Quiz Prompt Card
            if isQuizMode, let quiz = entry.quizStep {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.point.up.left.fill")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(AppTheme.grapeBottom)
                        Text(l10n.localized(zh: "猜大师下一手 · 直接点击棋盘！", en: "Guess the Master's Move — Tap the Board!", ja: "次の一手・盤面をタップ！", ko: "다음 수 맞히기 · 바둑판을 탭하세요!", zhHant: "猜大師下一手 · 直接點擊棋盤！"))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.grapeBottom)
                    }
                    Text(quiz.prompt(l10n))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let feedback = quizFeedback {
                        Text(feedback)
                            .font(.system(size: 12.5, weight: .heavy, design: .rounded))
                            .foregroundColor(quizSolved ? AppTheme.mintBottom : AppTheme.coralBottom)
                    }

                    if !quizSolved {
                        Button {
                            revealQuizAnswer(quiz: quiz)
                        } label: {
                            Text(l10n.localized(zh: "揭晓大师一手 →", en: "Reveal Master's Move →", ja: "正解を見る →", ko: "정답 보기 →", zhHant: "揭曉大師一手 →"))
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.skyBottom)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(AppTheme.grapeTop.opacity(0.10))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(AppTheme.grapeTop.opacity(0.35), lineWidth: 1.5))
                )
            }

            // 4. Clickable Highlight Jump Pills
            if !entry.highlights.isEmpty && !showingCounterExample {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(entry.highlights) { h in
                            let clamped = min(max(0, h.moveIndex), max(0, mainLineStates.count - 1))
                            let isHere = stepIndex == clamped && !isQuizMode
                            Button {
                                stopAutoPlay()
                                isQuizMode = false
                                isVariationMode = false
                                stepIndex = clamped
                                SoundAndHapticsManager.shared.playGridTick()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 10, weight: .black))
                                    Text("\(h.label(l10n)) (#\(clamped))")
                                        .font(.system(size: 11.5, weight: .black, design: .rounded))
                                }
                                .foregroundColor(isHere ? .white : AppTheme.inkPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(isHere ? AppTheme.skyBottom : AppTheme.canvasBackground))
                            }
                            .tactileButton(scale: 0.95, sound: false)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .warmCard(cornerRadius: 22, padding: 12)
    }

    private func triggerAcademyStamp(_ entry: AcademyEntry) {
        if appState.markAcademyStudied(entry.id) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                justStampedBanner = true
            }
        }
    }

    private func handleQuizTap(at point: BoardPoint) {
        guard let entry = academyEntry,
              let quiz = entry.quizStep,
              quiz.beforeMoveIndex >= 0,
              quiz.beforeMoveIndex < mainLineMoves.count else { return }

        let targetMove = mainLineMoves[quiz.beforeMoveIndex]
        if case .place(let expectedPt) = targetMove.action, expectedPt == point {
            quizSolved = true
            isQuizMode = false
            stepIndex = min(quiz.beforeMoveIndex + 1, mainLineStates.count - 1)
            quizFeedback = l10n.localized(
                zh: "🎉 太棒了！你和大师想到一块去了！",
                en: "🎉 Spot on! You found the exact master move!",
                ja: "🎉 大正解！名人の一手と完全一致です！",
                ko: "🎉 정답! 고수의 한 수와 정확히 일치해요!",
                zhHant: "🎉 太棒了！你和大師想到一塊去了！"
            )
            SoundAndHapticsManager.shared.playSuccess()
            triggerAcademyStamp(entry)
        } else {
            quizFeedback = l10n.localized(
                zh: "思路不错，再仔细看看棋盘要点，或点下方「揭晓大师一手」！",
                en: "Nice try! Look closely at the vital point, or tap Reveal below.",
                ja: "惜しい！急所をもう一度探すか、下の正解を見てみましょう。",
                ko: "아쉬워요! 급소를 다시 찾아보거나 아래 정답 보기를 눌러보세요.",
                zhHant: "思路不錯，再仔細看看棋盤要點，或點下方「揭曉大師一手」！"
            )
            SoundAndHapticsManager.shared.playWrong()
        }
    }

    private func revealQuizAnswer(quiz: AcademyQuizStep) {
        isQuizMode = false
        quizFeedback = nil
        stepIndex = min(quiz.beforeMoveIndex + 1, mainLineStates.count - 1)
        SoundAndHapticsManager.shared.playStonePlace()
    }

    private func loadMainLineFromSGF() {
        var states: [GoBoardState] = []
        var moves: [GoMove] = []
        var comments: [String?] = []

        let activeSGF: String
        if showingCounterExample, let counter = academyEntry?.counterExampleSgf(l10n) {
            activeSGF = counter
        } else {
            activeSGF = record.sgf
        }

        if let root = SGFParser.parse(activeSGF) {
            let initial = root.initialBoard(size: record.boardSize, komi: record.komi, handicap: record.handicap)
            states.append(initial)
            comments.append(root.comment)

            var current = initial
            var node = root.children.first
            while let curNode = node {
                if let mv = curNode.move {
                    if case .success(let outcome) = current.applying(action: mv.action, color: mv.color) {
                        current = outcome.nextState
                        states.append(current)
                        comments.append(curNode.comment)
                        moves.append(GoMove(
                            moveNumber: moves.count + 1,
                            color: mv.color,
                            action: mv.action,
                            capturedPoints: outcome.capturedPoints
                        ))
                    }
                }
                node = curNode.children.first
            }
        } else {
            states = [GoBoardState(size: record.boardSize, komi: record.komi, handicap: record.handicap)]
            comments = [nil]
        }

        mainLineStates = states
        mainLineMoves = moves
        mainLineComments = comments
        let hasCommentary = comments.contains { ($0 ?? "").isEmpty == false }
        stepIndex = hasCommentary ? 0 : max(0, states.count - 1)
    }
}

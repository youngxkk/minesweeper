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

    private var l10n: L10n { appState.l10n }
    private var isZh: Bool { l10n.language.isChinese }
    private let topBarHeight: CGFloat = 58

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
                        let boardSide = min(w - pad * 2, h * 0.44)
                        reviewBoard.frame(width: boardSide, height: boardSide)
                        ScrollView(showsIndicators: false) {
                            reviewControlsPanel
                        }
                    } else {
                        let sidebarWidth = min(400, max(336, w * 0.33))
                        let boardSide = max(260, min(w - sidebarWidth - pad * 3, h - topBarHeight - pad * 2 - 12))
                        HStack(spacing: pad) {
                            reviewBoard
                                .frame(width: boardSide, height: boardSide)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)

                            ScrollView(showsIndicators: false) {
                                reviewControlsPanel
                            }
                            .frame(width: sidebarWidth)
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
        .onChange(of: stepIndex) { _, _ in
            pvPreviewLabels = [:]
        }
    }

    private var reviewBoard: some View {
        GoBoardView(
            boardState: activeState,
            theme: appState.settings.boardTheme,
            showCoordinates: appState.settings.showCoordinates,
            showMoveNumbers: showMoveNumbers && !isVariationMode,
            moveNumbers: activeMoveNumbers,
            highlightAtari: appState.settings.highlightAtari,
            expressiveStones: appState.settings.expressiveStones && !appState.settings.zenDojoMode && !showMoveNumbers,
            showTwoEyeGlow: !appState.settings.zenDojoMode,
            territoryEstimate: showTerritory ? GoScoring.estimateTerritory(state: activeState) : nil,
            aiSuggestions: activeAISuggestions,
            labeledPoints: pvPreviewLabels,
            previewColor: activeState.currentTurn,
            isInteractive: isVariationMode,
            capturedFlashPoints: variationCaptured,
            captureEventID: variationCaptureID,
            libertyBadgeFormat: l10n.t("game.libertiesBadge"),
            koBadgeLabel: l10n.t("board.koBadge"),
            onSelectPoint: { pt in
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

    private var reviewControlsPanel: some View {
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
                                Text(isAnalyzingGame ? (isZh ? "分析中..." : "Analyzing...") : (isZh ? "AI 深度复盘" : "AI Review"))
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

            // Scrubber / Variation Banner
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

            // Action Buttons
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
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                }
                .buttonStyle(
                    GlossyCapsuleButtonStyle(
                        palette: isVariationMode ? .coral : .sky,
                        cornerRadius: 999,
                        rimHeight: 5,
                        whiteBorderWidth: 3
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
        }
    }

    // MARK: - P1 Winrate Curve Card

    private func winrateCurveCard(report: GameReviewReport) -> some View {
        let wr = report.winrateHistory[min(stepIndex, report.winrateHistory.count - 1)]
        let lead = report.scoreLeadHistory[min(stepIndex, report.scoreLeadHistory.count - 1)]
        let pct = Int(round(wr * 100))

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isZh ? "胜率曲线 · 点击跳转" : "Winrate Curve · Tap to Jump")
                    .font(.system(size: 11.5, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.grapeBottom)
                Spacer()
                Text(isZh ? "黑胜率 \(pct)% (\(String(format: "%+.1f", lead))目)" : "B \(pct)% (\(String(format: "%+.1f", lead)))")
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
                                Text(isZh ? "第\(m.moveNumber)手 \(m.quality.symbol)" : "#\(m.moveNumber) \(m.quality.symbol)")
                                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                                    .foregroundColor(stepIndex == m.moveNumber ? .white : AppTheme.coralBottom)
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
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
                Text(isZh ? "第 \(rev.moveNumber) 手诊断 \(rev.quality.symbol)" : "Move #\(rev.moveNumber) \(rev.quality.symbol)")
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
                            pvPreviewLabels.isEmpty ? (isZh ? "看推荐变化" : "Show AI PV") : (isZh ? "隐藏变化" : "Hide PV"),
                            systemImage: "sparkles"
                        )
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
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
                        ? (isZh ? "已加入我的实战错题本 ✓" : "Added to Mistake Book ✓")
                        : (isZh ? "一键转成我的实战错题" : "Save Blunder as Practice Puzzle"),
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

    private func loadMainLineFromSGF() {
        var initial = GoBoardState(size: record.boardSize, komi: record.komi, handicap: record.handicap)
        var states: [GoBoardState] = []
        var moves: [GoMove] = []
        var comments: [String?] = []

        if let root = SGFParser.parse(record.sgf) {
            if record.handicap == 0 {
                for pt in root.addedBlackPoints { initial.setSetupStone(.black, at: pt) }
                for pt in root.addedWhitePoints { initial.setSetupStone(.white, at: pt) }
                initial.resetPositionHistoryToCurrent()
            }
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
            states = [initial]
            comments = [nil]
        }

        mainLineStates = states
        mainLineMoves = moves
        mainLineComments = comments
        let hasCommentary = comments.contains { ($0 ?? "").isEmpty == false }
        stepIndex = hasCommentary ? 0 : max(0, states.count - 1)
    }
}

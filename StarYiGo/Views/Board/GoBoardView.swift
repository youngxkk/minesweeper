//
//  GoBoardView.swift
//  StarYi Go
//

import SwiftUI

/// High-DPI SwiftUI Canvas Go Board engineered with Nintendo physicality & Apple HIG ergonomics:
/// - Rock-solid immutable square geometry (zero layout shifts)
/// - Pinch-and-float shadow when dragging stones + ergonomic finger offset + grid-crossing ticks
/// - Long-press any placed stone to illuminate its group & twinkling "Firefly Liberties" (萤火虫气数)
/// - Optional Expressive Cute Stones (happy / tense / Atari sweating / Two-Eye Crown) & Living Two-Eye Sparkles
/// - Visual Ko Lock Hourglass badge (`劫`) + Live Beginner Liberty Dots
/// - Interactive Endgame Dead-Stone Overlay (`markedDeadIndices`)
struct GoBoardView: View {
    let boardState: GoBoardState
    let theme: BoardTheme
    var stoneStyle: StoneStyle = .classicSlateShell
    var cropRegion: BoardCropRegion? = nil
    var showCoordinates: Bool = true
    var showMoveNumbers: Bool = false
    var moveNumbers: [BoardPoint: Int] = [:]
    var highlightAtari: Bool = true
    var expressiveStones: Bool = false
    var showLiveLiberties: Bool = false
    var showTwoEyeGlow: Bool = true
    var markedDeadIndices: Set<Int> = []
    var isDeadStoneReviewMode: Bool = false
    var territoryEstimate: TerritoryEstimate? = nil
    var aiSuggestions: [MoveSuggestion] = []
    var puzzleHintPoint: BoardPoint? = nil
    var unsealedWarningPoints: [BoardPoint] = []
    var labeledPoints: [BoardPoint: String] = [:]
    var highlightedPocketPoints: Set<BoardPoint> = []
    var pendingPoint: BoardPoint? = nil
    var previewColor: StoneColor = .black
    var isChoosingRegion = false
    var isInteractive: Bool = true
    var capturedFlashPoints: [BoardPoint] = []
    var captureEventID: UUID = UUID()
    var illegalFlashPoint: BoardPoint? = nil
    var illegalEventID: UUID = UUID()
    var libertyBadgeFormat: String = "%d"
    var koBadgeLabel: String = "劫"
    var onSelectPoint: ((BoardPoint) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    @GestureState private var isTouchActive: Bool = false
    @State private var dragHoverPoint: BoardPoint? = nil
    @State private var isDraggingAim: Bool = false
    @State private var inspectedGroup: GoGroup? = nil
    @State private var inspectAnchorPoint: BoardPoint? = nil

    @State private var lastMoveTimestamp: Date = .distantPast
    @State private var lastMovePointCached: BoardPoint? = nil
    @State private var captureTimestamp: Date = .distantPast
    @State private var activeCapturedBurst: [BoardPoint] = []
    @State private var illegalTimestamp: Date = .distantPast
    @State private var activeIllegalPoint: BoardPoint? = nil
    @State private var shakeOffset: CGFloat = 0
    @State private var highFPSAnimationActive: Bool = false
    @State private var highFPSCooldownTask: Task<Void, Never>? = nil

    private var effectiveRegion: BoardCropRegion {
        cropRegion ?? BoardCropRegion.full(size: boardState.size)
    }

    private func needsHighFPSTimeline() -> Bool {
        dragHoverPoint != nil || highFPSAnimationActive
    }

    private func scheduleHighFPSBurst(duration: TimeInterval) {
        guard !reduceMotion else { return }
        highFPSAnimationActive = true
        highFPSCooldownTask?.cancel()
        highFPSCooldownTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            highFPSAnimationActive = false
        }
    }

    private func needsAmbientTimeline(hasAtari: Bool, hasTwoEyes: Bool) -> Bool {
        guard !reduceMotion else { return false }
        return hasAtari || hasTwoEyes || boardState.koIndex != nil || !aiSuggestions.isEmpty || puzzleHintPoint != nil || !unsealedWarningPoints.isEmpty || !highlightedPocketPoints.isEmpty || pendingPoint != nil || inspectedGroup != nil || showLiveLiberties
    }

    private func timelineInterval(hasAtari: Bool, hasTwoEyes: Bool) -> TimeInterval {
        if needsHighFPSTimeline() {
            return 1.0 / 60.0
        }
        return needsAmbientTimeline(hasAtari: hasAtari, hasTwoEyes: hasTwoEyes) ? (1.0 / 15.0) : 1.0
    }

    private func isTimelinePaused(hasAtari: Bool, hasTwoEyes: Bool) -> Bool {
        !needsHighFPSTimeline() && !needsAmbientTimeline(hasAtari: hasAtari, hasTwoEyes: hasTwoEyes)
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let region = effectiveRegion
            let palette = AppTheme.palette(for: theme)
            let atariSet = highlightAtari ? boardState.atariPoints() : []
            let twoEyeAnalysis = showTwoEyeGlow ? boardState.twoEyeAliveAnalysis() : (eyePoints: Set<BoardPoint>(), aliveStoneIndices: Set<Int>())
            let cachedGroups = (expressiveStones || showLiveLiberties) ? boardState.allGroups() : []

            let hasAtari = !atariSet.isEmpty
            let hasTwoEyes = !twoEyeAnalysis.eyePoints.isEmpty
            let interval = timelineInterval(hasAtari: hasAtari, hasTwoEyes: hasTwoEyes)
            let paused = isTimelinePaused(hasAtari: hasAtari, hasTwoEyes: hasTwoEyes)

            ZStack {
                // Static board surface (wood grain, grid lines, star points, coordinates) — rasterized once & never redrawn by TimelineView ticks
                Canvas { context, size in
                    drawStaticBoardSurface(
                        context: &context,
                        canvasSize: size,
                        region: region,
                        palette: palette
                    )
                }
                .drawingGroup()
                .frame(width: side, height: side)
                .allowsHitTesting(false)

                TimelineView(.animation(minimumInterval: interval, paused: paused)) { timeline in
                    let now = timeline.date
                    Canvas { context, size in
                        drawBoard(
                            context: &context,
                            canvasSize: size,
                            region: region,
                            palette: palette,
                            atariSet: atariSet,
                            twoEyeAnalysis: twoEyeAnalysis,
                            cachedGroups: cachedGroups,
                            now: now
                        )
                    }
                    .frame(width: side, height: side)
                }
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(palette.frameBorder, lineWidth: 4)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 12)
            .offset(x: shakeOffset)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouchActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                            if isChoosingRegion || isDeadStoneReviewMode { return }
                            let distMoved = hypot(value.translation.width, value.translation.height)
                            if distMoved > 12 {
                                isDraggingAim = true
                            }
                            let cellStep = side / CGFloat(max(region.rowCount, region.colCount) + 1)
                            let dragOffset = min(26.0, cellStep * 1.1)
                            let aimedLocation = isDraggingAim
                                ? CGPoint(x: value.location.x, y: max(0, value.location.y - dragOffset))
                                : value.location

                            guard let pt = nearestPoint(for: aimedLocation, side: side, region: region) else {
                                dragHoverPoint = nil
                                inspectedGroup = nil
                                inspectAnchorPoint = nil
                                return
                            }

                            // Nintendo "Firefly Liberties": touching/holding an existing stone illuminates its group's liberties!
                            if boardState.stone(at: pt) != nil && !isDraggingAim {
                                let idx = boardState.index(row: pt.row, col: pt.col)
                                if inspectAnchorPoint != pt, let group = boardState.groupAndLiberties(at: idx) {
                                    inspectedGroup = group
                                    inspectAnchorPoint = pt
                                    SoundAndHapticsManager.shared.playFireflyInspect()
                                }
                                dragHoverPoint = nil
                                return
                            }

                            inspectedGroup = nil
                            inspectAnchorPoint = nil

                            guard isInteractive else { return }
                            if boardState.stone(at: pt) == nil {
                                if dragHoverPoint != pt {
                                    dragHoverPoint = pt
                                    if isDraggingAim {
                                        SoundAndHapticsManager.shared.playGridTick()
                                    }
                                }
                            } else {
                                dragHoverPoint = nil
                            }
                        }
                        .onEnded { value in
                            if isChoosingRegion {
                                if let point = nearestPoint(for: value.location, side: side, region: region) {
                                    onSelectPoint?(point)
                                }
                                return
                            }
                            if isDeadStoneReviewMode {
                                if let pt = nearestPoint(for: value.location, side: side, region: region),
                                   boardState.stone(at: pt) != nil {
                                    onSelectPoint?(pt)
                                }
                                return
                            }

                            let wasInspecting = (inspectedGroup != nil)
                            inspectedGroup = nil
                            inspectAnchorPoint = nil

                            guard isInteractive, !wasInspecting else {
                                dragHoverPoint = nil
                                isDraggingAim = false
                                return
                            }
                            let wasDraggingAim = isDraggingAim
                            let cellStep = side / CGFloat(max(region.rowCount, region.colCount) + 1)
                            let dragOffset = min(26.0, cellStep * 1.1)
                            let aimedLocation = wasDraggingAim
                                ? CGPoint(x: value.location.x, y: max(0, value.location.y - dragOffset))
                                : value.location
                            // If drag-aim ended over an occupied stone or off-board (`dragHoverPoint == nil`),
                            // cancel silently instead of firing a false illegal-move error!
                            let target: BoardPoint? = wasDraggingAim
                                ? dragHoverPoint
                                : (dragHoverPoint ?? nearestPoint(for: aimedLocation, side: side, region: region))
                            dragHoverPoint = nil
                            isDraggingAim = false
                            if let target {
                                onSelectPoint?(target)
                            }
                        }
                )
            .onContinuousHover { phase in
                guard isInteractive, !isChoosingRegion, !isDeadStoneReviewMode, !isTouchActive else { return }
                switch phase {
                case .active(let location):
                    if let pt = nearestPoint(for: location, side: side, region: region),
                       boardState.stone(at: pt) == nil {
                        dragHoverPoint = pt
                    } else {
                        dragHoverPoint = nil
                    }
                case .ended:
                    dragHoverPoint = nil
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("GoBoardCanvas")
        .accessibilityLabel(boardAccessibilitySummary)
        .accessibilityHint(isInteractive ? "Double-tap or use board intersections to place a stone." : "")
        .overlay {
            if voiceOverEnabled && isInteractive {
                voiceOverGridOverlay
            }
        }
        .onChange(of: isTouchActive) { _, active in
            if !active {
                dragHoverPoint = nil
                isDraggingAim = false
                inspectedGroup = nil
                inspectAnchorPoint = nil
            }
        }
        .onChange(of: boardState.moveCount) { _, _ in
            if case .place(let pt) = boardState.lastMove {
                lastMovePointCached = pt
                lastMoveTimestamp = Date()
                scheduleHighFPSBurst(duration: 0.50)
            }
        }
        .onChange(of: captureEventID) { _, _ in
            if !capturedFlashPoints.isEmpty {
                activeCapturedBurst = capturedFlashPoints
                captureTimestamp = Date()
                scheduleHighFPSBurst(duration: 0.65)
            }
        }
        .onChange(of: illegalEventID) { _, _ in
            if let pt = illegalFlashPoint {
                activeIllegalPoint = pt
                illegalTimestamp = Date()
                scheduleHighFPSBurst(duration: 0.90)
                triggerMicroShake()
            }
        }
        .onDisappear {
            highFPSCooldownTask?.cancel()
            highFPSCooldownTask = nil
            highFPSAnimationActive = false
        }
    }

    private func triggerMicroShake() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 0.055)) { shakeOffset = -6 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            withAnimation(.easeInOut(duration: 0.055)) { shakeOffset = 6 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.easeInOut(duration: 0.055)) { shakeOffset = -3.5 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.165) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.7)) { shakeOffset = 0 }
        }
    }

    // MARK: - Geometry Layout Math

    private struct BoardMetrics {
        static let stoneRadiusPerCell: CGFloat = 0.465

        // A lifted preview has the largest stone-and-shadow footprint.
        static let stoneExtentPerCell = stoneRadiusPerCell * 1.08 * 1.42

        let padding: CGFloat
        let cellStep: CGFloat
        let originX: CGFloat
        let originY: CGFloat
        let region: BoardCropRegion

        func center(for point: BoardPoint) -> CGPoint {
            let localCol = CGFloat(point.col - region.minCol)
            let localRow = CGFloat(point.row - region.minRow)
            return CGPoint(
                x: originX + localCol * cellStep,
                y: originY + localRow * cellStep
            )
        }
    }

    private func computeMetrics(side: CGFloat, region: BoardCropRegion) -> BoardMetrics {
        let maxSpan = max(region.rowCount, region.colCount)
        let coordMargin: CGFloat = showCoordinates ? max(24, side * 0.050) : max(16, side * 0.034)
        let gridIntervals = max(1, CGFloat(maxSpan - 1))
        let standardStep = max(0, side - coordMargin * 2) / gridIntervals
        let frameClearance: CGFloat = showCoordinates ? coordMargin * 0.44 + 9 : 8
        let stoneSafeStep = max(0, side - frameClearance * 2)
            / (gridIntervals + BoardMetrics.stoneExtentPerCell * 2)
        let step = min(standardStep, stoneSafeStep)

        let gridWidth = CGFloat(region.colCount - 1) * step
        let gridHeight = CGFloat(region.rowCount - 1) * step
        let originX = (side - gridWidth) / 2
        let originY = (side - gridHeight) / 2

        return BoardMetrics(
            padding: coordMargin,
            cellStep: step,
            originX: originX,
            originY: originY,
            region: region
        )
    }

    private func nearestPoint(for location: CGPoint, side: CGFloat, region: BoardCropRegion) -> BoardPoint? {
        let m = computeMetrics(side: side, region: region)
        guard m.cellStep > 0, location.x.isFinite, location.y.isFinite else { return nil }
        let col = Int(round((location.x - m.originX) / m.cellStep)) + region.minCol
        let row = Int(round((location.y - m.originY) / m.cellStep)) + region.minRow

        guard row >= region.minRow && row <= region.maxRow &&
              col >= region.minCol && col <= region.maxCol &&
              boardState.isValid(row: row, col: col) else {
            return nil
        }

        let candidate = BoardPoint(row: row, col: col)
        let center = m.center(for: candidate)
        let dist = hypot(location.x - center.x, location.y - center.y)
        guard dist <= m.cellStep * 0.65 else { return nil }
        return candidate
    }

    // MARK: - Canvas Rendering

    /// Draws the static board surface (wood grain, vignette, grid, star points, coordinates).
    /// Separated from `TimelineView` so animations never re-rasterize wood fibers or grid lines.
    private func drawStaticBoardSurface(
        context: inout GraphicsContext,
        canvasSize: CGSize,
        region: BoardCropRegion,
        palette: AppTheme.BoardPalette
    ) {
        let rect = CGRect(origin: .zero, size: canvasSize)
        let m = computeMetrics(side: min(canvasSize.width, canvasSize.height), region: region)

        // 1. Background gradient
        context.fill(
            Path(rect),
            with: .linearGradient(
                Gradient(colors: [palette.boardBase, palette.boardGradientEnd]),
                startPoint: .zero,
                endPoint: CGPoint(x: canvasSize.width, y: canvasSize.height)
            )
        )

        context.stroke(
            Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 16),
            with: .color(Color.white.opacity(theme == .midnightStar ? 0.10 : 0.30)),
            lineWidth: 1.5
        )

        // 2. Organic multi-frequency Kaya wood grain + subtle warm board vignette
        let stripeCount = 44
        for i in 0..<stripeCount {
            var fiber = Path()
            let frac = (CGFloat(i) + 0.5) / CGFloat(stripeCount)
            let x = canvasSize.width * frac
            let wave1 = sin(Double(i) * 0.73 + 0.4) * 4.2
            let wave2 = cos(Double(i) * 1.41) * 2.1
            fiber.move(to: CGPoint(x: x, y: 0))
            fiber.addCurve(
                to: CGPoint(x: x + CGFloat(wave1 * 0.7), y: canvasSize.height),
                control1: CGPoint(x: x - CGFloat(wave1 - wave2), y: canvasSize.height * 0.33),
                control2: CGPoint(x: x + CGFloat(wave1 + wave2 * 0.8), y: canvasSize.height * 0.68)
            )
            let alphaScale: Double = (i % 5 == 0) ? 1.35 : ((i % 3 == 0) ? 0.90 : 0.55)
            context.stroke(
                fiber,
                with: .color(palette.grainColor.opacity(alphaScale)),
                lineWidth: (i % 5 == 0) ? 1.7 : 1.05
            )
        }
        // Subtle warm edge vignette for physical wooden table depth
        context.fill(
            Path(rect),
            with: .radialGradient(
                Gradient(colors: [
                    Color.clear,
                    Color.clear,
                    Color.black.opacity(theme == .midnightStar ? 0.18 : 0.08)
                ]),
                center: CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.48),
                startRadius: min(canvasSize.width, canvasSize.height) * 0.36,
                endRadius: max(canvasSize.width, canvasSize.height) * 0.76
            )
        )

        // 3. Grid lines
        let extendLeft: CGFloat = region.minCol > 0 ? m.cellStep * 0.38 : 0
        let extendRight: CGFloat = region.maxCol < boardState.size - 1 ? m.cellStep * 0.38 : 0
        let extendTop: CGFloat = region.minRow > 0 ? m.cellStep * 0.38 : 0
        let extendBottom: CGFloat = region.maxRow < boardState.size - 1 ? m.cellStep * 0.38 : 0

        let gridMinX = m.originX - extendLeft
        let gridMaxX = m.originX + CGFloat(region.colCount - 1) * m.cellStep + extendRight
        let gridMinY = m.originY - extendTop
        let gridMaxY = m.originY + CGFloat(region.rowCount - 1) * m.cellStep + extendBottom

        var gridPath = Path()
        for r in region.minRow...region.maxRow {
            let y = m.originY + CGFloat(r - region.minRow) * m.cellStep
            gridPath.move(to: CGPoint(x: gridMinX, y: y))
            gridPath.addLine(to: CGPoint(x: gridMaxX, y: y))
        }
        for c in region.minCol...region.maxCol {
            let x = m.originX + CGFloat(c - region.minCol) * m.cellStep
            gridPath.move(to: CGPoint(x: x, y: gridMinY))
            gridPath.addLine(to: CGPoint(x: x, y: gridMaxY))
        }
        let lineWidth: CGFloat = boardState.size >= 19 ? 1.0 : 1.35
        context.stroke(gridPath, with: .color(palette.gridLine), lineWidth: lineWidth)

        var borderPath = Path()
        if region.minRow == 0 {
            let y = m.originY
            borderPath.move(to: CGPoint(x: m.originX, y: y))
            borderPath.addLine(to: CGPoint(x: m.originX + CGFloat(region.colCount - 1) * m.cellStep, y: y))
        }
        if region.maxRow == boardState.size - 1 {
            let y = m.originY + CGFloat(region.rowCount - 1) * m.cellStep
            borderPath.move(to: CGPoint(x: m.originX, y: y))
            borderPath.addLine(to: CGPoint(x: m.originX + CGFloat(region.colCount - 1) * m.cellStep, y: y))
        }
        if region.minCol == 0 {
            let x = m.originX
            borderPath.move(to: CGPoint(x: x, y: m.originY))
            borderPath.addLine(to: CGPoint(x: x, y: m.originY + CGFloat(region.rowCount - 1) * m.cellStep))
        }
        if region.maxCol == boardState.size - 1 {
            let x = m.originX + CGFloat(region.colCount - 1) * m.cellStep
            borderPath.move(to: CGPoint(x: x, y: m.originY))
            borderPath.addLine(to: CGPoint(x: x, y: m.originY + CGFloat(region.rowCount - 1) * m.cellStep))
        }
        context.stroke(borderPath, with: .color(palette.gridLine), lineWidth: lineWidth + 0.85)

        // 4. Star Points (Hoshi) + Tengen golden glow
        let stars = BoardSize(rawValue: boardState.size)?.starPoints ?? []
        let tengen = BoardPoint(row: boardState.size / 2, col: boardState.size / 2)
        let starRadius = max(3.0, min(5.2, m.cellStep * 0.125))
        for sp in stars where region.contains(sp) {
            let center = m.center(for: sp)
            if sp == tengen {
                let glowRect = CGRect(x: center.x - starRadius * 3.0, y: center.y - starRadius * 3.0, width: starRadius * 6.0, height: starRadius * 6.0)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [palette.tengenGlow, palette.tengenGlow.opacity(0)]),
                        center: center,
                        startRadius: 0,
                        endRadius: starRadius * 3.0
                    )
                )
            }
            let dotRect = CGRect(x: center.x - starRadius, y: center.y - starRadius, width: starRadius * 2, height: starRadius * 2)
            context.fill(Path(ellipseIn: dotRect), with: .color(palette.starPoint))
        }

        // 5. Coordinates
        if showCoordinates {
            let fontSize = max(9.5, min(13, m.cellStep * 0.29))
            for c in region.minCol...region.maxCol {
                let letter = c < BoardPoint.columnLetters.count ? String(BoardPoint.columnLetters[c]) : ""
                let x = m.originX + CGFloat(c - region.minCol) * m.cellStep
                let label = Text(letter).font(AppFont.rounded(size: fontSize, weight: .semibold)).foregroundColor(palette.coordText)
                context.draw(label, at: CGPoint(x: x, y: m.padding * 0.44))
                context.draw(label, at: CGPoint(x: x, y: canvasSize.height - m.padding * 0.44))
            }
            for r in region.minRow...region.maxRow {
                let num = "\(boardState.size - r)"
                let y = m.originY + CGFloat(r - region.minRow) * m.cellStep
                let label = Text(num).font(AppFont.rounded(size: fontSize, weight: .semibold)).foregroundColor(palette.coordText)
                context.draw(label, at: CGPoint(x: m.padding * 0.44, y: y))
                context.draw(label, at: CGPoint(x: canvasSize.width - m.padding * 0.44, y: y))
            }
        }
    }

    private func drawBoard(
        context: inout GraphicsContext,
        canvasSize: CGSize,
        region: BoardCropRegion,
        palette: AppTheme.BoardPalette,
        atariSet: Set<BoardPoint>,
        twoEyeAnalysis: (eyePoints: Set<BoardPoint>, aliveStoneIndices: Set<Int>),
        cachedGroups: [GoGroup],
        now: Date
    ) {
        let rect = CGRect(origin: .zero, size: canvasSize)
        let m = computeMetrics(side: min(canvasSize.width, canvasSize.height), region: region)
        let timePhase = now.timeIntervalSinceReferenceDate
        let breathe = 0.5 + 0.5 * sin(timePhase * 4.4)
        let stoneRadius = m.cellStep * BoardMetrics.stoneRadiusPerCell

        // Use hoisted group liberty counts for expressive stones & beginner live liberties
        var libertyCountByIndex: [Int: Int] = [:]
        var urgentLibertyPoints: Set<BoardPoint> = []
        if !cachedGroups.isEmpty {
            for g in cachedGroups {
                let libCount = g.liberties.count
                for s in g.stones {
                    libertyCountByIndex[s] = libCount
                }
                if showLiveLiberties && libCount <= 2 {
                    for libIdx in g.liberties {
                        urgentLibertyPoints.insert(boardState.point(for: libIdx))
                    }
                }
            }
        }

        // 6. Territory Overlay
        if let est = territoryEstimate {
            let sq = m.cellStep * 0.36
            for r in region.minRow...region.maxRow {
                for c in region.minCol...region.maxCol {
                    let pt = BoardPoint(row: r, col: c)
                    let idx = boardState.index(row: r, col: c)
                    guard boardState.grid[idx] == nil || markedDeadIndices.contains(idx) else { continue }
                    let val = est.ownership[idx]
                    guard abs(val) > 0.28 else { continue }
                    let center = m.center(for: pt)
                    let sqRect = CGRect(x: center.x - sq / 2, y: center.y - sq / 2, width: sq, height: sq)
                    let alpha = min(0.84, max(0.32, abs(val) * 0.85))
                    if val > 0 {
                        let fill = Color(red: 0.08, green: 0.24, blue: 0.20).opacity(alpha)
                        context.fill(Path(roundedRect: sqRect, cornerRadius: 4), with: .color(fill))
                        if differentiateWithoutColor {
                            context.stroke(Path(roundedRect: sqRect, cornerRadius: 4), with: .color(.white.opacity(0.65)), lineWidth: 1.2)
                        }
                    } else {
                        let fill = Color.white.opacity(alpha)
                        if differentiateWithoutColor {
                            // Distinct diamond/circle shape for White territory in colorblind mode
                            context.fill(Path(ellipseIn: sqRect), with: .color(fill))
                            context.stroke(Path(ellipseIn: sqRect), with: .color(AppTheme.inkPrimary.opacity(0.65)), lineWidth: 1.2)
                        } else {
                            context.fill(Path(roundedRect: sqRect, cornerRadius: 4), with: .color(fill))
                            context.stroke(Path(roundedRect: sqRect, cornerRadius: 4), with: .color(AppTheme.starGold.opacity(0.45)), lineWidth: 1)
                        }
                    }
                }
            }
        }

        // 6B. Living Two-Eye Star Sparkles ("两眼活棋 · 真眼发光")
        if showTwoEyeGlow && !twoEyeAnalysis.eyePoints.isEmpty {
            for eyePt in twoEyeAnalysis.eyePoints where region.contains(eyePt) {
                let center = m.center(for: eyePt)
                let glowR = stoneRadius * (0.42 + 0.10 * breathe)
                let glowRect = CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 0.48, green: 0.94, blue: 1.0).opacity(0.85),
                            AppTheme.skyTop.opacity(0.35),
                            Color.clear
                        ]),
                        center: center,
                        startRadius: 1,
                        endRadius: glowR
                    )
                )
                context.draw(
                    Text("✦")
                        .font(.system(size: max(10, stoneRadius * 0.56), weight: .black, design: .rounded))
                        .foregroundColor(.white),
                    at: center
                )
            }
        }

        // 6C. Gentle Live Beginner Liberty Dots (for 1-2 liberty groups so kids intuitively see "气"!)
        if showLiveLiberties && !urgentLibertyPoints.isEmpty && inspectedGroup == nil && !isDeadStoneReviewMode {
            for libPt in urgentLibertyPoints where region.contains(libPt) && boardState.stone(at: libPt) == nil {
                let center = m.center(for: libPt)
                let dotR = max(3.5, stoneRadius * (0.24 + 0.06 * breathe))
                let dotRect = CGRect(x: center.x - dotR, y: center.y - dotR, width: dotR * 2, height: dotR * 2)
                context.fill(
                    Path(ellipseIn: dotRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 1.0, green: 0.95, blue: 0.55).opacity(0.95),
                            AppTheme.starGold.opacity(0.42),
                            Color.clear
                        ]),
                        center: center,
                        startRadius: 0.5,
                        endRadius: dotR * 1.4
                    )
                )
            }
        }

        // 6D. Visual Ko Lock Badge ("打劫 · 冷却一回合")
        if let koPt = boardState.koPoint, region.contains(koPt), boardState.stone(at: koPt) == nil {
            let center = m.center(for: koPt)
            let boxR = stoneRadius * (0.58 + 0.06 * breathe)
            let boxRect = CGRect(x: center.x - boxR, y: center.y - boxR, width: boxR * 2, height: boxR * 2)
            context.fill(Path(roundedRect: boxRect, cornerRadius: boxR * 0.45), with: .color(AppTheme.sunBottom.opacity(0.24)))
            context.stroke(Path(roundedRect: boxRect, cornerRadius: boxR * 0.45), with: .color(AppTheme.sunBottom), lineWidth: 2.2)
            context.draw(
                Text(koBadgeLabel)
                    .font(.system(size: max(9, boxR * 0.95), weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.sunRim),
                at: center
            )
        }

        // 7. Capture Burst Animation
        let capAge = now.timeIntervalSince(captureTimestamp)
        if capAge >= 0 && capAge < 0.56 {
            let progress = capAge / 0.56
            let fade = 1.0 - progress
            for capPt in activeCapturedBurst where region.contains(capPt) {
                let center = m.center(for: capPt)
                let ringR = stoneRadius * (0.55 + progress * 1.30)
                let ringRect = CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2)
                context.stroke(
                    Path(ellipseIn: ringRect),
                    with: .color(AppTheme.starGold.opacity(fade * 0.92)),
                    lineWidth: max(1.2, 4.4 * fade)
                )
                for k in 0..<8 {
                    let angle = Double(k) * (.pi / 4.0) + progress * 0.8
                    let sparkDist = stoneRadius * (0.4 + progress * 1.45)
                    let sx = center.x + CGFloat(cos(angle)) * sparkDist
                    let sy = center.y + CGFloat(sin(angle)) * sparkDist
                    let sr = max(1.2, 3.6 * fade)
                    context.fill(
                        Path(ellipseIn: CGRect(x: sx - sr, y: sy - sr, width: sr * 2, height: sr * 2)),
                        with: .color(AppTheme.starGold.opacity(fade * 0.95))
                    )
                }
            }
        }

        // 8. Stones with Atari Shiver, Expressive Cute Faces, Two-Eye Crown, Dead-Stone Overlay & Landing Pop
        let lastMovePoint: BoardPoint? = {
            if case .place(let p) = boardState.lastMove { return p }
            return nil
        }()
        let landingAge = now.timeIntervalSince(lastMoveTimestamp)
        let inspectedStoneIndices = inspectedGroup?.stones ?? []

        for r in region.minRow...region.maxRow {
            for c in region.minCol...region.maxCol {
                let pt = BoardPoint(row: r, col: c)
                guard let color = boardState.stone(at: pt) else { continue }
                let idx = boardState.index(row: r, col: c)
                var center = m.center(for: pt)
                let isMarkedDead = markedDeadIndices.contains(idx)

                if atariSet.contains(pt) && !isMarkedDead {
                    let shiver = CGFloat(sin(timePhase * 28.0 + Double(idx))) * 1.1
                    center.x += shiver

                    let haloScale = 1.12 + 0.10 * breathe
                    let haloR = stoneRadius * haloScale
                    let haloRect = CGRect(x: center.x - haloR, y: center.y - haloR, width: haloR * 2, height: haloR * 2)
                    context.fill(Path(ellipseIn: haloRect), with: .color(AppTheme.vermilionAccent.opacity(0.24 + 0.18 * breathe)))
                    context.stroke(Path(ellipseIn: haloRect), with: .color(AppTheme.vermilionAccent.opacity(0.65 + 0.30 * breathe)), lineWidth: 2.2)
                }

                if inspectedStoneIndices.contains(idx) {
                    let auraR = stoneRadius * 1.16
                    let auraRect = CGRect(x: center.x - auraR, y: center.y - auraR, width: auraR * 2, height: auraR * 2)
                    context.stroke(Path(ellipseIn: auraRect), with: .color(AppTheme.starGold.opacity(0.90)), lineWidth: 2.8)
                }

                var renderRadius = stoneRadius
                var landingDiveOffset: CGFloat = 0
                if pt == lastMovePoint && pt == lastMovePointCached && landingAge >= 0 && landingAge < 0.36 && !reduceMotion {
                    let t = landingAge / 0.36
                    let ripR = stoneRadius * (0.95 + t * 0.75)
                    let ripRect = CGRect(x: center.x - ripR, y: center.y - ripR, width: ripR * 2, height: ripR * 2)
                    context.stroke(Path(ellipseIn: ripRect), with: .color(Color.white.opacity((1.0 - t) * 0.58)), lineWidth: max(1.0, 2.8 * (1.0 - t)))
                    if landingAge < 0.085 {
                        // Tactile 3-stage drop: stone dives from pinched hover onto Kaya wood
                        let dropT = 1.0 - (landingAge / 0.085)
                        landingDiveOffset = -stoneRadius * 0.24 * CGFloat(dropT * dropT)
                        renderRadius = stoneRadius * CGFloat(1.0 + 0.07 * dropT)
                    } else if landingAge < 0.20 {
                        let st = (landingAge - 0.085) / 0.115
                        let bounce = 1.0 + 0.12 * exp(-st * 5.0) * cos(st * .pi * 2.0)
                        renderRadius = stoneRadius * CGFloat(bounce)
                    }
                }

                drawStone(
                    context: &context,
                    center: CGPoint(x: center.x, y: center.y + landingDiveOffset),
                    radius: renderRadius,
                    color: color,
                    opacity: isMarkedDead ? 0.36 : 1.0,
                    lifted: landingDiveOffset < -1.0
                )

                // Colorblind-friendly Atari shape badge (dashed ring + tiny exclamation pip)
                if differentiateWithoutColor && atariSet.contains(pt) && !isMarkedDead {
                    let badgeR = max(3.5, stoneRadius * 0.28)
                    let badgeCenter = CGPoint(x: center.x + stoneRadius * 0.58, y: center.y - stoneRadius * 0.58)
                    let badgeRect = CGRect(x: badgeCenter.x - badgeR, y: badgeCenter.y - badgeR, width: badgeR * 2, height: badgeR * 2)
                    context.fill(Path(ellipseIn: badgeRect), with: .color(AppTheme.vermilionAccent))
                    context.stroke(Path(ellipseIn: badgeRect), with: .color(.white), lineWidth: 1.2)
                    context.draw(
                        Text("!").font(.system(size: max(7, badgeR * 1.3), weight: .black, design: .rounded)).foregroundColor(.white),
                        at: badgeCenter
                    )
                }

                // Nintendo Expressive Kids Stone Faces (hidden when move numbers are shown or board is too dense)
                if expressiveStones && !showMoveNumbers && !isMarkedDead && stoneRadius >= 11 {
                    let libs = libertyCountByIndex[idx] ?? 3
                    let isTwoEyeAlive = twoEyeAnalysis.aliveStoneIndices.contains(idx)
                    drawExpressiveFace(
                        context: &context,
                        center: center,
                        radius: renderRadius,
                        color: color,
                        liberties: libs,
                        isTwoEyeAlive: isTwoEyeAlive
                    )
                }

                // Dead-stone confirmation X badge
                if isMarkedDead {
                    let xr = renderRadius * 0.42
                    var xPath = Path()
                    xPath.move(to: CGPoint(x: center.x - xr, y: center.y - xr))
                    xPath.addLine(to: CGPoint(x: center.x + xr, y: center.y + xr))
                    xPath.move(to: CGPoint(x: center.x + xr, y: center.y - xr))
                    xPath.addLine(to: CGPoint(x: center.x - xr, y: center.y + xr))
                    context.stroke(xPath, with: .color(AppTheme.coralBottom), style: StrokeStyle(lineWidth: max(2.2, renderRadius * 0.16), lineCap: .round))
                } else if showMoveNumbers, let num = moveNumbers[pt] {
                    let numColor: Color = (color == .black) ? .white : AppTheme.inkPrimary
                    let numFont = Font.system(size: max(9, stoneRadius * 0.78), weight: .bold, design: .rounded)
                    context.draw(Text("\(num)").font(numFont).foregroundColor(numColor), at: center)
                } else if lastMovePoint == pt {
                    let ringR = expressiveStones ? stoneRadius * 0.88 : stoneRadius * 0.36
                    let ringRect = CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2)
                    let ringColor: Color = (color == .black) ? Color(red: 0.96, green: 0.79, blue: 0.36) : AppTheme.vermilionAccent
                    context.stroke(Path(ellipseIn: ringRect), with: .color(ringColor), lineWidth: max(2.0, stoneRadius * 0.13))
                }
            }
        }

        // 9. Firefly Liberties Visualization (when holding any stone!)
        if let group = inspectedGroup {
            for libIdx in group.liberties {
                let libPt = boardState.point(for: libIdx)
                guard region.contains(libPt) else { continue }
                let center = m.center(for: libPt)
                let glowR = stoneRadius * (0.58 + 0.14 * breathe)
                let glowRect = CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)
                context.fill(
                    Path(ellipseIn: glowRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color(red: 1.0, green: 0.96, blue: 0.68),
                            AppTheme.starGold.opacity(0.65),
                            AppTheme.starGold.opacity(0)
                        ]),
                        center: center,
                        startRadius: 1,
                        endRadius: glowR
                    )
                )
            }
            if let anchor = inspectAnchorPoint, region.contains(anchor) {
                let c = m.center(for: anchor)
                let badgeY = c.y > 50 ? c.y - stoneRadius * 1.85 : c.y + stoneRadius * 1.85
                let badgeW: CGFloat = 58
                let badgeRect = CGRect(x: c.x - badgeW / 2, y: badgeY - 13, width: badgeW, height: 26)
                context.fill(Path(roundedRect: badgeRect, cornerRadius: 13), with: .color(AppTheme.starGold))
                context.stroke(Path(roundedRect: badgeRect, cornerRadius: 13), with: .color(.white.opacity(0.8)), lineWidth: 1.5)
                let label = String(format: libertyBadgeFormat, group.liberties.count)
                context.draw(
                    Text(label).font(AppFont.rounded(size: 12, weight: .black)).foregroundColor(.white),
                    at: CGPoint(x: c.x, y: badgeY)
                )
            }
        }

        // 10. Wrong / Illegal move vivid red flash, X marker & brief red board border pulse
        let illAge = now.timeIntervalSince(illegalTimestamp)
        if let illPt = activeIllegalPoint, region.contains(illPt), illAge >= 0 && illAge < 0.80 {
            let p = illAge / 0.80
            // Keep full visibility for the first ~55% then fade out smoothly
            let fade = p < 0.55 ? 1.0 : max(0.0, 1.0 - (p - 0.55) / 0.45)
            let pulse = 0.5 + 0.5 * sin(illAge * 26.0)
            let center = m.center(for: illPt)

            // Subtle red warning flash along the board edge during the shake
            if illAge < 0.45 {
                let edgeFade = 1.0 - (illAge / 0.45)
                context.stroke(
                    Path(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 15),
                    with: .color(Color.red.opacity(0.65 * edgeFade)),
                    lineWidth: 6.0
                )
            }

            // Expanding red shockwave ring
            let waveR = stoneRadius * (0.72 + min(1.0, illAge / 0.45) * 0.85)
            let waveFade = max(0.0, 1.0 - illAge / 0.50)
            if waveFade > 0 {
                let waveRect = CGRect(x: center.x - waveR, y: center.y - waveR, width: waveR * 2, height: waveR * 2)
                context.stroke(
                    Path(ellipseIn: waveRect),
                    with: .color(Color.red.opacity(0.90 * waveFade)),
                    lineWidth: max(1.8, 3.6 * waveFade)
                )
            }

            // Vivid pulsing red halo + filled red badge + crisp white X
            let glowR = stoneRadius * (1.05 + 0.16 * pulse)
            let glowRect = CGRect(x: center.x - glowR, y: center.y - glowR, width: glowR * 2, height: glowR * 2)
            context.fill(
                Path(ellipseIn: glowRect),
                with: .radialGradient(
                    Gradient(colors: [
                        Color.red.opacity(0.55 * fade),
                        AppTheme.vermilionAccent.opacity(0.22 * fade),
                        Color.clear
                    ]),
                    center: center,
                    startRadius: stoneRadius * 0.25,
                    endRadius: glowR
                )
            )

            let badgeR = stoneRadius * 0.62
            let badgeRect = CGRect(x: center.x - badgeR, y: center.y - badgeR, width: badgeR * 2, height: badgeR * 2)
            context.fill(Path(ellipseIn: badgeRect), with: .color(Color.red.opacity(0.92 * fade)))
            context.stroke(Path(ellipseIn: badgeRect), with: .color(Color.white.opacity(0.95 * fade)), lineWidth: 2.2)

            let xr = badgeR * 0.46
            var xPath = Path()
            xPath.move(to: CGPoint(x: center.x - xr, y: center.y - xr))
            xPath.addLine(to: CGPoint(x: center.x + xr, y: center.y + xr))
            xPath.move(to: CGPoint(x: center.x + xr, y: center.y - xr))
            xPath.addLine(to: CGPoint(x: center.x - xr, y: center.y + xr))
            context.stroke(
                xPath,
                with: .color(Color.white.opacity(fade)),
                style: StrokeStyle(lineWidth: max(2.4, badgeR * 0.26), lineCap: .round)
            )
        }

        // 11. AI Suggestions
        for (idx, suggestion) in aiSuggestions.enumerated() where region.contains(suggestion.point) {
            guard boardState.stone(at: suggestion.point) == nil else { continue }
            let center = m.center(for: suggestion.point)
            let r = stoneRadius * (0.74 + 0.08 * breathe)
            let hintRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            let badgeColor = idx == 0 ? AppTheme.jadeAccent : AppTheme.starGold
            context.fill(Path(ellipseIn: hintRect), with: .color(badgeColor.opacity(0.22 + 0.14 * breathe)))
            context.stroke(Path(ellipseIn: hintRect), with: .color(badgeColor), lineWidth: 2.6)
            context.draw(
                Text("\(idx + 1)").font(.system(size: max(11, r * 0.88), weight: .bold, design: .rounded)).foregroundColor(badgeColor),
                at: center
            )
        }

        // 12. Puzzle Hint Beacon
        if let hintPt = puzzleHintPoint, region.contains(hintPt), boardState.stone(at: hintPt) == nil {
            let center = m.center(for: hintPt)
            let r = stoneRadius * (0.76 + 0.12 * breathe)
            let hintRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: hintRect), with: .color(AppTheme.starGold.opacity(0.28 + 0.18 * breathe)))
            context.stroke(Path(ellipseIn: hintRect), with: .color(AppTheme.starGold), lineWidth: 3.0)
        }

        // 12B. Highlighted Territory Pocket (Animated step-by-step counting!)
        if !highlightedPocketPoints.isEmpty {
            let sq = m.cellStep * 0.56
            for pt in highlightedPocketPoints where region.contains(pt) {
                let center = m.center(for: pt)
                let sqRect = CGRect(x: center.x - sq / 2, y: center.y - sq / 2, width: sq, height: sq)
                context.fill(Path(roundedRect: sqRect, cornerRadius: 6), with: .color(AppTheme.sunTop.opacity(0.38 + 0.20 * breathe)))
                context.stroke(Path(roundedRect: sqRect, cornerRadius: 6), with: .color(AppTheme.sunBottom), lineWidth: 2.0)
            }
        }

        // 12C. Unsealed Endgame Boundary Warning Beacons ("边界漏风提醒")
        if !unsealedWarningPoints.isEmpty {
            for pt in unsealedWarningPoints where region.contains(pt) {
                let center = m.center(for: pt)
                let r = stoneRadius * (0.64 + 0.14 * breathe)
                let warnRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: warnRect), with: .color(AppTheme.coralTop.opacity(0.26 + 0.16 * breathe)))
                context.stroke(Path(ellipseIn: warnRect), with: .color(AppTheme.coralBottom), lineWidth: 2.6)
                context.draw(
                    Text("!")
                        .font(.system(size: max(10, r * 0.95), weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.coralBottom),
                    at: center
                )
            }
        }

        // 12D. Board Text Labels (A / B / C for Opening Picker, 1 / 2 / 3 for PV Variations!)
        if !labeledPoints.isEmpty {
            for (pt, text) in labeledPoints where region.contains(pt) {
                let center = m.center(for: pt)
                let r = stoneRadius * 0.72
                let badgeRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                let hasStone = boardState.stone(at: pt) != nil
                let isWrongMarker = (text == "✕" || text == "×" || text == "X")
                let badgeColor = isWrongMarker ? AppTheme.coralBottom : AppTheme.skyBottom
                if !hasStone {
                    context.fill(Path(ellipseIn: badgeRect), with: .color(badgeColor.opacity(0.94)))
                    context.stroke(Path(ellipseIn: badgeRect), with: .color(.white), lineWidth: 2.0)
                }
                context.draw(
                    Text(text)
                        .font(.system(size: max(10, r * 0.92), weight: .black, design: .rounded))
                        .foregroundColor(hasStone ? (isWrongMarker ? AppTheme.coralBottom : AppTheme.sunTop) : .white),
                    at: center
                )
            }
        }

        // 13. Lifted Pinched Stone Hover / Pending Confirm Crosshair
        if !isDeadStoneReviewMode,
           let ghost = dragHoverPoint ?? pendingPoint,
           region.contains(ghost),
           boardState.stone(at: ghost) == nil {
            let center = m.center(for: ghost)
            var cross = Path()
            cross.move(to: CGPoint(x: m.originX, y: center.y))
            cross.addLine(to: CGPoint(x: m.originX + CGFloat(region.colCount - 1) * m.cellStep, y: center.y))
            cross.move(to: CGPoint(x: center.x, y: m.originY))
            cross.addLine(to: CGPoint(x: center.x, y: m.originY + CGFloat(region.rowCount - 1) * m.cellStep))
            context.stroke(cross, with: .color(AppTheme.jadeAccent.opacity(0.45)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))

            drawStone(
                context: &context,
                center: center,
                radius: isDraggingAim ? stoneRadius * 1.08 : stoneRadius,
                color: previewColor,
                opacity: isDraggingAim ? 0.86 : 0.68,
                lifted: isDraggingAim
            )

            let ringR = stoneRadius * (1.10 + 0.08 * breathe)
            let ringRect = CGRect(x: center.x - ringR, y: center.y - ringR, width: ringR * 2, height: ringR * 2)
            context.stroke(Path(ellipseIn: ringRect), with: .color(AppTheme.jadeAccent), lineWidth: 2.6)

            if isDraggingAim {
                let badgeY = center.y > 48 ? center.y - stoneRadius * 2.0 : center.y + stoneRadius * 2.0
                let badgeRect = CGRect(x: center.x - 24, y: badgeY - 12, width: 48, height: 24)
                context.fill(Path(roundedRect: badgeRect, cornerRadius: 12), with: .color(AppTheme.jadeAccent))
                context.draw(
                    Text(ghost.humanLabel(boardSize: boardState.size))
                        .font(AppFont.rounded(size: 12, weight: .heavy))
                        .foregroundColor(.white),
                    at: CGPoint(x: center.x, y: badgeY)
                )
            }
        }
    }

    private func drawExpressiveFace(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: StoneColor,
        liberties: Int,
        isTwoEyeAlive: Bool
    ) {
        let ink: Color = (color == .black) ? Color.white.opacity(0.90) : Color(red: 0.16, green: 0.20, blue: 0.28).opacity(0.86)
        let eyeDX = radius * 0.28
        let eyeY = center.y - radius * 0.06
        let eyeR = max(1.2, radius * 0.115)

        if liberties == 1 {
            // Sweating / wide-eyed Atari panic!
            for dir in [-1.0, 1.0] {
                let ex = center.x + CGFloat(dir) * eyeDX
                context.stroke(
                    Path(ellipseIn: CGRect(x: ex - eyeR * 1.15, y: eyeY - eyeR * 1.15, width: eyeR * 2.3, height: eyeR * 2.3)),
                    with: .color(ink),
                    lineWidth: max(1.1, radius * 0.08)
                )
            }
            // Tiny blue sweat drop
            let dropX = center.x + radius * 0.44
            let dropY = center.y - radius * 0.34
            context.fill(
                Path(ellipseIn: CGRect(x: dropX - eyeR * 0.65, y: dropY - eyeR * 0.85, width: eyeR * 1.3, height: eyeR * 1.7)),
                with: .color(AppTheme.skyTop)
            )
            // Worried "o" mouth
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - eyeR * 0.75, y: center.y + radius * 0.14, width: eyeR * 1.5, height: eyeR * 1.5)),
                with: .color(ink)
            )
        } else if isTwoEyeAlive {
            // Happy invincible ^ ^ eyes + golden star dot!
            for dir in [-1.0, 1.0] {
                let ex = center.x + CGFloat(dir) * eyeDX
                var arc = Path()
                arc.move(to: CGPoint(x: ex - eyeR, y: eyeY + eyeR * 0.3))
                arc.addQuadCurve(to: CGPoint(x: ex + eyeR, y: eyeY + eyeR * 0.3), control: CGPoint(x: ex, y: eyeY - eyeR * 1.1))
                context.stroke(arc, with: .color(ink), style: StrokeStyle(lineWidth: max(1.2, radius * 0.085), lineCap: .round))
            }
            // Golden invincibility sparkle on forehead
            let dotR = max(1.6, radius * 0.12)
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - dotR, y: center.y - radius * 0.48 - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(AppTheme.sunTop)
            )
        } else if liberties == 2 {
            // Alert / focused eyes
            for dir in [-1.0, 1.0] {
                let ex = center.x + CGFloat(dir) * eyeDX
                context.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(ink))
            }
            var flat = Path()
            flat.move(to: CGPoint(x: center.x - radius * 0.14, y: center.y + radius * 0.22))
            flat.addLine(to: CGPoint(x: center.x + radius * 0.14, y: center.y + radius * 0.22))
            context.stroke(flat, with: .color(ink), style: StrokeStyle(lineWidth: max(1.1, radius * 0.075), lineCap: .round))
        } else {
            // Relaxed smiling Nintendo stone!
            for dir in [-1.0, 1.0] {
                let ex = center.x + CGFloat(dir) * eyeDX
                context.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(ink))
            }
            var smile = Path()
            smile.move(to: CGPoint(x: center.x - radius * 0.17, y: center.y + radius * 0.16))
            smile.addQuadCurve(
                to: CGPoint(x: center.x + radius * 0.17, y: center.y + radius * 0.16),
                control: CGPoint(x: center.x, y: center.y + radius * 0.34)
            )
            context.stroke(smile, with: .color(ink), style: StrokeStyle(lineWidth: max(1.1, radius * 0.075), lineCap: .round))
        }
    }

    private func drawStone(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: StoneColor,
        opacity: Double,
        lifted: Bool
    ) {
        let shadowOffsetX = lifted ? radius * 0.34 : radius * 0.14
        let shadowOffsetY = lifted ? radius * 0.42 : radius * 0.18
        let shadowCenter = CGPoint(x: center.x + shadowOffsetX, y: center.y + shadowOffsetY)
        let shadowRect = CGRect(
            x: shadowCenter.x - radius,
            y: shadowCenter.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.fill(
            Path(ellipseIn: shadowRect),
            with: .color(Color.black.opacity((lifted ? 0.22 : 0.28) * opacity))
        )

        let drawCenter = lifted ? CGPoint(x: center.x, y: center.y - radius * 0.12) : center
        let stoneRect = CGRect(x: drawCenter.x - radius, y: drawCenter.y - radius, width: radius * 2, height: radius * 2)
        let lightCenter = CGPoint(x: drawCenter.x - radius * 0.30, y: drawCenter.y - radius * 0.30)

        if color == .black {
            let colors: [Color]
            switch stoneStyle {
            case .classicSlateShell:
                colors = [
                    Color(red: 0.34, green: 0.36, blue: 0.39).opacity(opacity),
                    Color(red: 0.12, green: 0.13, blue: 0.15).opacity(opacity),
                    Color(red: 0.05, green: 0.06, blue: 0.07).opacity(opacity)
                ]
            case .coralPearl:
                colors = [
                    Color(red: 0.24, green: 0.46, blue: 0.56).opacity(opacity),
                    Color(red: 0.08, green: 0.22, blue: 0.32).opacity(opacity),
                    Color(red: 0.04, green: 0.11, blue: 0.18).opacity(opacity)
                ]
            case .kyotoLacquer:
                colors = [
                    Color(red: 0.44, green: 0.24, blue: 0.18).opacity(opacity),
                    Color(red: 0.16, green: 0.08, blue: 0.07).opacity(opacity),
                    Color(red: 0.07, green: 0.04, blue: 0.04).opacity(opacity)
                ]
            case .starlightJade:
                colors = [
                    Color(red: 0.18, green: 0.54, blue: 0.46).opacity(opacity),
                    Color(red: 0.07, green: 0.26, blue: 0.24).opacity(opacity),
                    Color(red: 0.03, green: 0.12, blue: 0.14).opacity(opacity)
                ]
            }
            context.fill(
                Path(ellipseIn: stoneRect),
                with: .radialGradient(
                    Gradient(colors: colors),
                    center: lightCenter,
                    startRadius: radius * 0.08,
                    endRadius: radius * 1.25
                )
            )
            if stoneStyle == .starlightJade || stoneStyle == .kyotoLacquer {
                context.stroke(
                    Path(ellipseIn: stoneRect),
                    with: .color((stoneStyle == .starlightJade ? Color(red: 0.65, green: 0.96, blue: 0.88) : Color(red: 0.96, green: 0.72, blue: 0.36)).opacity(0.32 * opacity)),
                    lineWidth: 0.9
                )
            }
        } else {
            let gradient: Gradient
            switch stoneStyle {
            case .classicSlateShell:
                gradient = Gradient(stops: [
                    .init(color: Color.white.opacity(opacity), location: 0.0),
                    .init(color: Color(red: 0.99, green: 0.99, blue: 0.995).opacity(opacity), location: 0.42),
                    .init(color: Color(red: 0.92, green: 0.93, blue: 0.945).opacity(opacity), location: 0.78),
                    .init(color: Color(red: 0.80, green: 0.82, blue: 0.85).opacity(opacity), location: 1.0)
                ])
            case .coralPearl:
                gradient = Gradient(stops: [
                    .init(color: Color.white.opacity(opacity), location: 0.0),
                    .init(color: Color(red: 0.985, green: 0.985, blue: 0.99).opacity(opacity), location: 0.45),
                    .init(color: Color(red: 0.92, green: 0.925, blue: 0.94).opacity(opacity), location: 0.80),
                    .init(color: Color(red: 0.82, green: 0.83, blue: 0.86).opacity(opacity), location: 1.0)
                ])
            case .kyotoLacquer:
                gradient = Gradient(stops: [
                    .init(color: Color(red: 1.00, green: 0.98, blue: 0.90).opacity(opacity), location: 0.0),
                    .init(color: Color(red: 0.99, green: 0.88, blue: 0.66).opacity(opacity), location: 0.55),
                    .init(color: Color(red: 0.86, green: 0.66, blue: 0.36).opacity(opacity), location: 1.0)
                ])
            case .starlightJade:
                gradient = Gradient(stops: [
                    .init(color: Color.white.opacity(opacity), location: 0.0),
                    .init(color: Color(red: 0.93, green: 0.96, blue: 1.00).opacity(opacity), location: 0.55),
                    .init(color: Color(red: 0.78, green: 0.85, blue: 0.96).opacity(opacity), location: 1.0)
                ])
            }
            context.fill(
                Path(ellipseIn: stoneRect),
                with: .radialGradient(
                    gradient,
                    center: lightCenter,
                    startRadius: radius * 0.08,
                    endRadius: radius * 1.28
                )
            )
            // Authentic Clamshell (蛤碁石) subtle curved shell striations on classic white stones
            if stoneStyle == .classicSlateShell && radius >= 8 {
                var clipped = context
                clipped.clip(to: Path(ellipseIn: stoneRect))
                for sIdx in -2...2 {
                    let yOff = drawCenter.y + CGFloat(sIdx) * radius * 0.30
                    var striation = Path()
                    striation.move(to: CGPoint(x: drawCenter.x - radius, y: yOff - radius * 0.10))
                    striation.addQuadCurve(
                        to: CGPoint(x: drawCenter.x + radius, y: yOff + radius * 0.08),
                        control: CGPoint(x: drawCenter.x, y: yOff - radius * 0.24)
                    )
                    clipped.stroke(
                        striation,
                        with: .color(Color(red: 0.78, green: 0.80, blue: 0.83).opacity(0.14 * opacity)),
                        lineWidth: max(0.55, radius * 0.035)
                    )
                }
            }
            // Soft realistic ceramic/clamshell top-left specular highlight
            if radius >= 6 {
                let specW = radius * 0.52
                let specH = radius * 0.32
                let specRect = CGRect(
                    x: drawCenter.x - radius * 0.44 - specW * 0.25,
                    y: drawCenter.y - radius * 0.48 - specH * 0.25,
                    width: specW,
                    height: specH
                )
                context.fill(
                    Path(ellipseIn: specRect),
                    with: .radialGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.85 * opacity),
                            Color.white.opacity(0.0)
                        ]),
                        center: CGPoint(x: specRect.midX, y: specRect.midY),
                        startRadius: 0,
                        endRadius: specW * 0.55
                    )
                )
            }
            context.stroke(
                Path(ellipseIn: stoneRect),
                with: .color(Color(red: 0.45, green: 0.48, blue: 0.54).opacity(0.22 * opacity)),
                lineWidth: 0.85
            )
        }
    }

    // MARK: - VoiceOver Full Board Accessibility

    private var boardAccessibilitySummary: String {
        let turnLabel = boardState.currentTurn == .black ? "Black" : "White"
        let lastLabel: String
        if case .place(let pt) = boardState.lastMove {
            lastLabel = pt.humanLabel(boardSize: boardState.size)
        } else if case .pass = boardState.lastMove {
            lastLabel = "Pass"
        } else {
            lastLabel = "None"
        }
        return "\(boardState.size) by \(boardState.size) Go board. \(turnLabel) to play. Move \(boardState.moveCount). Last move \(lastLabel). Captures: Black \(boardState.blackCaptures), White \(boardState.whiteCaptures)."
    }

    private var voiceOverGridOverlay: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let region = effectiveRegion
            let m = computeMetrics(side: side, region: region)
            let hitSize = max(18, m.cellStep)

            ZStack {
                ForEach(region.minRow...region.maxRow, id: \.self) { r in
                    ForEach(region.minCol...region.maxCol, id: \.self) { c in
                        let pt = BoardPoint(row: r, col: c)
                        let center = m.center(for: pt)
                        Button {
                            onSelectPoint?(pt)
                        } label: {
                            Color.clear
                                .frame(width: hitSize, height: hitSize)
                        }
                        .position(x: center.x, y: center.y)
                        .accessibilityLabel(accessibilityLabel(for: pt))
                    }
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    private func accessibilityLabel(for pt: BoardPoint) -> String {
        let coord = pt.humanLabel(boardSize: boardState.size)
        if let stone = boardState.stone(at: pt) {
            let colorName = stone == .black ? "Black" : "White"
            let idx = boardState.index(row: pt.row, col: pt.col)
            let libs = boardState.groupAndLiberties(at: idx)?.liberties.count ?? 0
            let isLast = (boardState.lastMove == .place(pt)) ? ", last move" : ""
            return "\(coord), \(colorName) stone, \(libs) liberties\(isLast)"
        }
        if boardState.koPoint == pt {
            return "\(coord), Ko forbidden"
        }
        return "\(coord), empty"
    }
}

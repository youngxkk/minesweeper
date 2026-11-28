//
//  GoBoardView.swift
//  StarYi Go
//

import SwiftUI
import Combine
#if canImport(UIKit)
import UIKit
#endif

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
    /// Optional pre-computed analysis (atari / two-eye / groups) supplied by the owning model.
    /// When nil the view falls back to computing it locally (previews, one-off boards).
    var analysis: GoBoardAnalysis? = nil
    var onSelectPoint: ((BoardPoint) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

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
    @State private var isHoverAnimating: Bool = false
    @State private var hoverIdleTask: Task<Void, Never>? = nil
    @State private var ambientPulseActive: Bool = false
    @State private var ambientPulseTask: Task<Void, Never>? = nil
    @State private var landingAnimationActive: Bool = false
    @State private var landingAnimationTask: Task<Void, Never>? = nil
    @State private var voiceOverEnabled: Bool = {
        #if canImport(UIKit)
        return UIAccessibility.isVoiceOverRunning
        #else
        return false
        #endif
    }()

    private var effectiveRegion: BoardCropRegion {
        cropRegion ?? BoardCropRegion.full(size: boardState.size)
    }

    /// Only active, user-driven motion (a moving preview / hover) needs the 60 fps budget.
    /// Once the pointer or finger rests, the board drops back to a static frame instead of
    /// ticking forever — a parked trackpad cursor used to keep the whole board at 60 fps.
    private func needsHighFPSTimeline() -> Bool {
        (isHoverAnimating && !reduceMotion) || highFPSAnimationActive
    }

    private func noteContinuousMotion() {
        guard !reduceMotion else { return }
        isHoverAnimating = true
        hoverIdleTask?.cancel()
        hoverIdleTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            isHoverAnimating = false
        }
    }

    private func stopContinuousMotion() {
        hoverIdleTask?.cancel()
        hoverIdleTask = nil
        isHoverAnimating = false
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

    /// Ambient effects (two-eye glow, live liberties, atari halo, hint ring) used to keep a
    /// 15 fps full-board redraw running for the entire game. They now animate for a short
    /// "pulse" after an event, then rest on a clean static frame (product option A).
    private func scheduleAmbientPulse(duration: TimeInterval = 2.0) {
        guard !reduceMotion else { return }
        ambientPulseActive = true
        ambientPulseTask?.cancel()
        ambientPulseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            ambientPulseActive = false
        }
    }

    private func needsAmbientTimeline() -> Bool {
        guard !reduceMotion else { return false }
        return inspectedGroup != nil || ambientPulseActive
    }

    private func timelineInterval() -> TimeInterval {
        // The animated layer now only draws halos / sparkles / previews (never the stones),
        // so a smooth 60 fps pulse is cheap and the board no longer looks choppy at 15 fps.
        if needsHighFPSTimeline() || needsAmbientTimeline() { return 1.0 / 60.0 }
        return 1.0
    }

    private func isTimelinePaused() -> Bool {
        !needsHighFPSTimeline() && !needsAmbientTimeline()
    }

    private var currentLastMovePoint: BoardPoint? {
        if case .place(let point) = boardState.lastMove { return point }
        return nil
    }

    /// Keeps the freshly placed stone out of the static layer for the short landing pop,
    /// then re-bakes it in. This is what lets the stone layer stay cached during animation.
    private func scheduleLandingAnimation() {
        guard !reduceMotion, currentLastMovePoint != nil else { return }
        landingAnimationActive = true
        landingAnimationTask?.cancel()
        landingAnimationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            landingAnimationActive = false
        }
    }

    /// Stable fingerprint of every input that should trigger a short ambient pulse.
    private var ambientPulseKey: Int {
        var hasher = Hasher()
        hasher.combine(boardState.moveCount)
        hasher.combine(boardState.koIndex)
        hasher.combine(aiSuggestions)
        hasher.combine(puzzleHintPoint)
        hasher.combine(pendingPoint)
        hasher.combine(unsealedWarningPoints)
        hasher.combine(highlightedPocketPoints)
        hasher.combine(markedDeadIndices)
        return hasher.finalize()
    }

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let region = effectiveRegion
            let palette = AppTheme.palette(for: theme)
            let resolved = analysis ?? GoBoardAnalysis.build(
                from: boardState,
                includeAtari: highlightAtari,
                includeTwoEye: showTwoEyeGlow,
                includeGroups: expressiveStones || showLiveLiberties
            )
            let atariSet = highlightAtari ? resolved.atariPoints : []
            let twoEyeAnalysis = (
                eyePoints: showTwoEyeGlow ? resolved.eyePoints : Set<BoardPoint>(),
                aliveStoneIndices: showTwoEyeGlow ? resolved.aliveStoneIndices : Set<Int>()
            )
            let cachedGroups = (expressiveStones || showLiveLiberties) ? resolved.groups : []
            let liveLibertyPoints = Self.liveLibertyPoints(
                from: cachedGroups,
                boardState: boardState,
                enabled: showLiveLiberties && inspectedGroup == nil && !isDeadStoneReviewMode
            )

            let interval = timelineInterval()
            let paused = isTimelinePaused()

            ZStack {
                // Static drop shadow: a fixed-shape layer behind the board. The shadow used to
                // be attached to the animating container, forcing a full-board offscreen blur
                // on every single animation frame.
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(palette.frameBorder)
                    .frame(width: side, height: side)
                    .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 12)
                    .offset(x: shakeOffset)
                    .allowsHitTesting(false)

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

                    // Cached stone layer: only re-renders when the position (or a static
                    // overlay such as territory / move numbers / dead marks) actually changes.
                    // Hover, drag and ambient animation never re-draw the 361 stones.
                    BoardStonesLayer(
                        boardState: boardState,
                        stoneStyle: stoneStyle,
                        region: region,
                        showCoordinates: showCoordinates,
                        side: side,
                        analysis: resolved,
                        showMoveNumbers: showMoveNumbers,
                        moveNumbers: moveNumbers,
                        expressiveStones: expressiveStones,
                        markedDeadIndices: markedDeadIndices,
                        territoryEstimate: territoryEstimate,
                        differentiateWithoutColor: differentiateWithoutColor,
                        suppressedStone: landingAnimationActive ? currentLastMovePoint : nil
                    )
                    .equatable()
                    .frame(width: side, height: side)
                    .allowsHitTesting(false)

                    TimelineView(.animation(minimumInterval: interval, paused: paused)) { timeline in
                        let now = timeline.date
                        Canvas { context, size in
                            drawDynamicBoard(
                                context: &context,
                                canvasSize: size,
                                region: region,
                                atariSet: atariSet,
                                twoEyeAnalysis: twoEyeAnalysis,
                                liveLibertyPoints: liveLibertyPoints,
                                now: now,
                                animated: needsHighFPSTimeline() || needsAmbientTimeline()
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
                .offset(x: shakeOffset)
            }
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
                                    noteContinuousMotion()
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
                        noteContinuousMotion()
                    } else {
                        dragHoverPoint = nil
                    }
                case .ended:
                    dragHoverPoint = nil
                    stopContinuousMotion()
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .accessibilityIgnoresInvertColors()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("GoBoardCanvas")
            .accessibilityLabel(Self.accessibilitySummary(for: boardState, l10n: boardL10n))
            .accessibilityHint(boardAccessibilityHint)
            .accessibilityChildren {
                if voiceOverEnabled {
                    GoBoardAccessibilityGrid(
                        boardState: boardState,
                        region: region,
                        side: side,
                        atariSet: atariSet,
                        pendingPoint: pendingPoint,
                        isInteractive: isInteractive,
                        isDeadStoneReviewMode: isDeadStoneReviewMode,
                        l10n: boardL10n,
                        metrics: computeMetrics(side: side, region: region),
                        onSelectPoint: onSelectPoint
                    )
                }
            }
            .accessibilityRotor(
                Text(boardL10n.localized(zh: "最后一手", en: "Last Move", ja: "最後の一手", ko: "마지막 수", zhHant: "最後一手")),
                entries: voiceOverEnabled ? lastMoveRotorEntries(in: region, atariSet: atariSet) : [],
                entryLabel: \.label
            )
            .accessibilityRotor(
                Text(boardL10n.localized(zh: "叫吃棋子", en: "Atari", ja: "アタリ", ko: "단수", zhHant: "叫吃棋子")),
                entries: voiceOverEnabled ? atariRotorEntries(in: region, atariSet: atariSet) : [],
                entryLabel: \.label
            )
            .accessibilityRotor(
                Text(boardL10n.localized(zh: "黑子", en: "Black Stones", ja: "黒石", ko: "흑돌", zhHant: "黑子")),
                entries: voiceOverEnabled ? stoneRotorEntries(color: .black, in: region, atariSet: atariSet) : [],
                entryLabel: \.label
            )
            .accessibilityRotor(
                Text(boardL10n.localized(zh: "白子", en: "White Stones", ja: "白石", ko: "백돌", zhHant: "白子")),
                entries: voiceOverEnabled ? stoneRotorEntries(color: .white, in: region, atariSet: atariSet) : [],
                entryLabel: \.label
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            #if canImport(UIKit)
            voiceOverEnabled = UIAccessibility.isVoiceOverRunning
            #endif
            // One short "hello" pulse so atari / two-eye / liberty highlights are introduced,
            // then the board rests instead of animating for the whole game.
            if showLiveLiberties || showTwoEyeGlow || highlightAtari {
                scheduleAmbientPulse()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIAccessibility.voiceOverStatusDidChangeNotification)) { _ in
            #if canImport(UIKit)
            voiceOverEnabled = UIAccessibility.isVoiceOverRunning
            #endif
        }
        .onChange(of: ambientPulseKey) { _, _ in
            scheduleAmbientPulse()
        }
        .onChange(of: isTouchActive) { _, active in
            if !active {
                dragHoverPoint = nil
                isDraggingAim = false
                inspectedGroup = nil
                inspectAnchorPoint = nil
                stopContinuousMotion()
            }
        }
        .onChange(of: boardState.moveCount) { _, _ in
            if case .place(let pt) = boardState.lastMove {
                lastMovePointCached = pt
                lastMoveTimestamp = Date()
                scheduleHighFPSBurst(duration: 0.50)
                scheduleLandingAnimation()
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
            stopContinuousMotion()
            ambientPulseTask?.cancel()
            ambientPulseTask = nil
            ambientPulseActive = false
            landingAnimationTask?.cancel()
            landingAnimationTask = nil
            landingAnimationActive = false
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

    fileprivate struct BoardMetrics {
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
        Self.metrics(side: side, region: region, showCoordinates: showCoordinates)
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
        let isIncreasedContrast = (colorSchemeContrast == .increased)
        let lineWidth: CGFloat = (boardState.size >= 19 ? 1.0 : 1.35) + (isIncreasedContrast ? 0.45 : 0)
        let gridStrokeColor: Color = isIncreasedContrast ? palette.starPoint : palette.gridLine
        context.stroke(gridPath, with: .color(gridStrokeColor), lineWidth: lineWidth)

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
        context.stroke(borderPath, with: .color(gridStrokeColor), lineWidth: lineWidth + 0.85)

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
            let coordColor: Color = isIncreasedContrast ? palette.starPoint : palette.coordText
            let coordWeight: Font.Weight = isIncreasedContrast ? .bold : .semibold
            for c in region.minCol...region.maxCol {
                let letter = c < BoardPoint.columnLetters.count ? String(BoardPoint.columnLetters[c]) : ""
                let x = m.originX + CGFloat(c - region.minCol) * m.cellStep
                let label = Text(letter).font(AppFont.rounded(size: fontSize, weight: coordWeight)).foregroundColor(coordColor)
                context.draw(label, at: CGPoint(x: x, y: m.padding * 0.44))
                context.draw(label, at: CGPoint(x: x, y: canvasSize.height - m.padding * 0.44))
            }
            for r in region.minRow...region.maxRow {
                let num = "\(boardState.size - r)"
                let y = m.originY + CGFloat(r - region.minRow) * m.cellStep
                let label = Text(num).font(AppFont.rounded(size: fontSize, weight: coordWeight)).foregroundColor(coordColor)
                context.draw(label, at: CGPoint(x: m.padding * 0.44, y: y))
                context.draw(label, at: CGPoint(x: canvasSize.width - m.padding * 0.44, y: y))
            }
        }
    }

    // MARK: - Static stone layer (cached)

    fileprivate static func metrics(
        side: CGFloat,
        region: BoardCropRegion,
        showCoordinates: Bool
    ) -> BoardMetrics {
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

    /// Draws everything that only changes when the position or a static overlay changes:
    /// territory, stones, expressive faces, move numbers, dead markers and the last-move ring.
    /// This layer is wrapped in an `.equatable()` view so hover / drag / ambient animation
    /// never re-rasterizes the 361 stones.
    fileprivate static func renderStonesLayer(
        context: inout GraphicsContext,
        canvasSize: CGSize,
        boardState: GoBoardState,
        stoneStyle: StoneStyle,
        region: BoardCropRegion,
        showCoordinates: Bool,
        side: CGFloat,
        analysis: GoBoardAnalysis,
        showMoveNumbers: Bool,
        moveNumbers: [BoardPoint: Int],
        expressiveStones: Bool,
        markedDeadIndices: Set<Int>,
        territoryEstimate: TerritoryEstimate?,
        differentiateWithoutColor: Bool,
        suppressedStone: BoardPoint?
    ) {
        let m = metrics(side: side, region: region, showCoordinates: showCoordinates)
        let stoneRadius = m.cellStep * BoardMetrics.stoneRadiusPerCell
        let atariSet = analysis.atariPoints
        let twoEyeAnalysis = (eyePoints: analysis.eyePoints, aliveStoneIndices: analysis.aliveStoneIndices)
        let lastMovePoint: BoardPoint? = {
            if case .place(let p) = boardState.lastMove { return p }
            return nil
        }()

        // 1. Territory overlay
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

        // 2. Hoisted group liberty counts for expressive stones
        var libertyCountByIndex: [Int: Int] = [:]
        if expressiveStones && !analysis.groups.isEmpty {
            for g in analysis.groups {
                let libCount = g.liberties.count
                for s in g.stones { libertyCountByIndex[s] = libCount }
            }
        }

        // 3. Stones (static)
        for r in region.minRow...region.maxRow {
            for c in region.minCol...region.maxCol {
                let pt = BoardPoint(row: r, col: c)
                guard let color = boardState.stone(at: pt) else { continue }
                if pt == suppressedStone { continue }
                let idx = boardState.index(row: r, col: c)
                let center = m.center(for: pt)
                let isMarkedDead = markedDeadIndices.contains(idx)

                drawStone(
                    context: &context,
                    center: center,
                    radius: stoneRadius,
                    color: color,
                    opacity: isMarkedDead ? 0.36 : 1.0,
                    lifted: false,
                    stoneStyle: stoneStyle
                )

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

                if expressiveStones && !showMoveNumbers && !isMarkedDead && stoneRadius >= 11 {
                    let libs = libertyCountByIndex[idx] ?? 3
                    let isTwoEyeAlive = twoEyeAnalysis.aliveStoneIndices.contains(idx)
                    drawExpressiveFace(
                        context: &context,
                        center: center,
                        radius: stoneRadius,
                        color: color,
                        liberties: libs,
                        isTwoEyeAlive: isTwoEyeAlive
                    )
                }

                if isMarkedDead {
                    let xr = stoneRadius * 0.42
                    var xPath = Path()
                    xPath.move(to: CGPoint(x: center.x - xr, y: center.y - xr))
                    xPath.addLine(to: CGPoint(x: center.x + xr, y: center.y + xr))
                    xPath.move(to: CGPoint(x: center.x + xr, y: center.y - xr))
                    xPath.addLine(to: CGPoint(x: center.x - xr, y: center.y + xr))
                    context.stroke(xPath, with: .color(AppTheme.coralBottom), style: StrokeStyle(lineWidth: max(2.2, stoneRadius * 0.16), lineCap: .round))
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
    }

    fileprivate static func liveLibertyPoints(
        from groups: [GoGroup],
        boardState: GoBoardState,
        enabled: Bool
    ) -> Set<BoardPoint> {
        guard enabled else { return [] }
        var points: Set<BoardPoint> = []
        for group in groups where group.liberties.count <= 2 {
            for libertyIndex in group.liberties {
                points.insert(boardState.point(for: libertyIndex))
            }
        }
        return points
    }

    // MARK: - Dynamic decorations (cheap 60 fps layer)

    private func drawDynamicBoard(
        context: inout GraphicsContext,
        canvasSize: CGSize,
        region: BoardCropRegion,
        atariSet: Set<BoardPoint>,
        twoEyeAnalysis: (eyePoints: Set<BoardPoint>, aliveStoneIndices: Set<Int>),
        liveLibertyPoints: Set<BoardPoint>,
        now: Date,
        animated: Bool
    ) {
        let rect = CGRect(origin: .zero, size: canvasSize)
        let m = computeMetrics(side: min(canvasSize.width, canvasSize.height), region: region)
        let timePhase = now.timeIntervalSinceReferenceDate
        let breathe = animated ? (0.5 + 0.5 * sin(timePhase * 4.4)) : 0.5
        let stoneRadius = m.cellStep * BoardMetrics.stoneRadiusPerCell

        // 1. Living Two-Eye Star Sparkles ("两眼活棋 · 真眼发光")
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

        // 2. Live beginner liberty dots
        if showLiveLiberties && !liveLibertyPoints.isEmpty && inspectedGroup == nil && !isDeadStoneReviewMode {
            for libPt in liveLibertyPoints where region.contains(libPt) && boardState.stone(at: libPt) == nil {
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

        // 3. Ko lock badge
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

        // 4. Capture burst
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

        // 5. Atari halos (only the halo animates; stones stay in the cached layer)
        if !atariSet.isEmpty {
            let haloR = stoneRadius * (1.12 + 0.10 * breathe)
            for pt in atariSet where region.contains(pt) {
                let idx = boardState.index(row: pt.row, col: pt.col)
                guard boardState.stone(at: pt) != nil, !markedDeadIndices.contains(idx) else { continue }
                let center = m.center(for: pt)
                let haloRect = CGRect(x: center.x - haloR, y: center.y - haloR, width: haloR * 2, height: haloR * 2)
                // Ring + soft outer glow only: the stone itself now lives in the cached layer
                // underneath, so a filled disc here would tint the stone pink.
                context.stroke(
                    Path(ellipseIn: haloRect.insetBy(dx: -1.6, dy: -1.6)),
                    with: .color(AppTheme.vermilionAccent.opacity(0.16 + 0.10 * breathe)),
                    lineWidth: 5.0
                )
                context.stroke(Path(ellipseIn: haloRect), with: .color(AppTheme.vermilionAccent.opacity(0.65 + 0.30 * breathe)), lineWidth: 2.2)
            }
        }

        // 6. Inspected group aura + firefly liberties
        if let group = inspectedGroup {
            for stoneIdx in group.stones where region.contains(boardState.point(for: stoneIdx)) {
                let center = m.center(for: boardState.point(for: stoneIdx))
                let auraR = stoneRadius * 1.16
                let auraRect = CGRect(x: center.x - auraR, y: center.y - auraR, width: auraR * 2, height: auraR * 2)
                context.stroke(Path(ellipseIn: auraRect), with: .color(AppTheme.starGold.opacity(0.90)), lineWidth: 2.8)
            }
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

        // 7. Illegal move flash
        let illAge = now.timeIntervalSince(illegalTimestamp)
        if let illPt = activeIllegalPoint, region.contains(illPt), illAge >= 0 && illAge < 0.80 {
            let p = illAge / 0.80
            let fade = p < 0.55 ? 1.0 : max(0.0, 1.0 - (p - 0.55) / 0.45)
            let pulse = 0.5 + 0.5 * sin(illAge * 26.0)
            let center = m.center(for: illPt)

            if illAge < 0.45 {
                let edgeFade = 1.0 - (illAge / 0.45)
                context.stroke(
                    Path(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 15),
                    with: .color(Color.red.opacity(0.65 * edgeFade)),
                    lineWidth: 6.0
                )
            }

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

        // 8. AI suggestions
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

        // 9. Puzzle hint beacon
        if let hintPt = puzzleHintPoint, region.contains(hintPt), boardState.stone(at: hintPt) == nil {
            let center = m.center(for: hintPt)
            let r = stoneRadius * (0.76 + 0.12 * breathe)
            let hintRect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
            context.fill(Path(ellipseIn: hintRect), with: .color(AppTheme.starGold.opacity(0.28 + 0.18 * breathe)))
            context.stroke(Path(ellipseIn: hintRect), with: .color(AppTheme.starGold), lineWidth: 3.0)
        }

        // 10. Highlighted territory pocket
        if !highlightedPocketPoints.isEmpty {
            let sq = m.cellStep * 0.56
            for pt in highlightedPocketPoints where region.contains(pt) {
                let center = m.center(for: pt)
                let sqRect = CGRect(x: center.x - sq / 2, y: center.y - sq / 2, width: sq, height: sq)
                context.fill(Path(roundedRect: sqRect, cornerRadius: 6), with: .color(AppTheme.sunTop.opacity(0.38 + 0.20 * breathe)))
                context.stroke(Path(roundedRect: sqRect, cornerRadius: 6), with: .color(AppTheme.sunBottom), lineWidth: 2.0)
            }
        }

        // 11. Unsealed endgame boundary warnings
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

        // 12. Board text labels (opening picker / PV variations)
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

        // 13. Landing pop for the freshly placed stone (excluded from the cached layer while active)
        if landingAnimationActive, !reduceMotion, let landingPoint = currentLastMovePoint,
           region.contains(landingPoint), let landingColor = boardState.stone(at: landingPoint) {
            let center = m.center(for: landingPoint)
            let landingAge = now.timeIntervalSince(lastMoveTimestamp)
            var renderRadius = stoneRadius
            var diveOffset: CGFloat = 0
            if landingAge >= 0 && landingAge < 0.36 {
                let t = landingAge / 0.36
                let ripR = stoneRadius * (0.95 + t * 0.75)
                let ripRect = CGRect(x: center.x - ripR, y: center.y - ripR, width: ripR * 2, height: ripR * 2)
                context.stroke(Path(ellipseIn: ripRect), with: .color(Color.white.opacity((1.0 - t) * 0.58)), lineWidth: max(1.0, 2.8 * (1.0 - t)))
                if landingAge < 0.085 {
                    let dropT = 1.0 - (landingAge / 0.085)
                    diveOffset = -stoneRadius * 0.24 * CGFloat(dropT * dropT)
                    renderRadius = stoneRadius * CGFloat(1.0 + 0.07 * dropT)
                } else if landingAge < 0.20 {
                    let st = (landingAge - 0.085) / 0.115
                    let bounce = 1.0 + 0.12 * exp(-st * 5.0) * cos(st * .pi * 2.0)
                    renderRadius = stoneRadius * CGFloat(bounce)
                }
            }
            Self.drawStone(
                context: &context,
                center: CGPoint(x: center.x, y: center.y + diveOffset),
                radius: renderRadius,
                color: landingColor,
                opacity: 1.0,
                lifted: diveOffset < -1.0,
                stoneStyle: stoneStyle
            )
        }

        // 14. Lifted pinched stone hover / pending confirm crosshair
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

            Self.drawStone(
                context: &context,
                center: center,
                radius: isDraggingAim ? stoneRadius * 1.08 : stoneRadius,
                color: previewColor,
                opacity: isDraggingAim ? 0.86 : 0.68,
                lifted: isDraggingAim,
                stoneStyle: stoneStyle
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

    fileprivate static func drawExpressiveFace(
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

    fileprivate static func drawStone(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: CGFloat,
        color: StoneColor,
        opacity: Double,
        lifted: Bool,
        stoneStyle: StoneStyle
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

    // MARK: - Full Board Accessibility (VoiceOver, Switch Control, Voice Control, Rotors)

    private var boardL10n: L10n {
        L10n(language: AppLanguage(rawValue: AppFont.activeLanguageCode) ?? .system)
    }

    static func accessibilitySummary(for boardState: GoBoardState, l10n: L10n) -> String {
        let turnLabel = boardState.currentTurn == .black ? l10n.t("stone.black") : l10n.t("stone.white")
        let lastLabel: String
        if case .place(let pt) = boardState.lastMove {
            lastLabel = pt.humanLabel(boardSize: boardState.size)
        } else if case .pass = boardState.lastMove {
            lastLabel = l10n.localized(zh: "停着", en: "Pass", ja: "パス", ko: "패스", zhHant: "停著")
        } else {
            lastLabel = l10n.localized(zh: "无", en: "None", ja: "なし", ko: "없음", zhHant: "無")
        }
        let size = boardState.size
        return l10n.localized(
            zh: "\(size)路围棋棋盘，轮到\(turnLabel)落子，第\(boardState.moveCount)手，最后一手\(lastLabel)，提子黑\(boardState.blackCaptures)子、白\(boardState.whiteCaptures)子。",
            en: "\(size) by \(size) Go board. \(turnLabel) to play. Move \(boardState.moveCount). Last move \(lastLabel). Captures: Black \(boardState.blackCaptures), White \(boardState.whiteCaptures).",
            ja: "\(size)路碁盤。\(turnLabel)の手番、\(boardState.moveCount)手目、最後の一手\(lastLabel)。アゲハマ黒\(boardState.blackCaptures)、白\(boardState.whiteCaptures)。",
            ko: "\(size)줄 바둑판. \(turnLabel) 차례, \(boardState.moveCount)수, 마지막 수 \(lastLabel). 따낸 돌 흑 \(boardState.blackCaptures), 백 \(boardState.whiteCaptures).",
            zhHant: "\(size)路圍棋棋盤，輪到\(turnLabel)落子，第\(boardState.moveCount)手，最後一手\(lastLabel)，提子黑\(boardState.blackCaptures)子、白\(boardState.whiteCaptures)子。"
        )
    }

    static func accessibilityPointLabel(
        for pt: BoardPoint,
        boardState: GoBoardState,
        isPending: Bool = false,
        isAtari: Bool = false,
        l10n: L10n
    ) -> String {
        let coord = pt.humanLabel(boardSize: boardState.size)
        if let stone = boardState.stone(at: pt) {
            let colorName = stone == .black ? l10n.t("stone.black") : l10n.t("stone.white")
            let idx = boardState.index(row: pt.row, col: pt.col)
            let libs = boardState.groupAndLiberties(at: idx)?.liberties.count ?? 0
            var parts: [String] = [
                coord,
                l10n.localized(
                    zh: "\(colorName)子，\(libs)气",
                    en: "\(colorName) stone, \(libs) liberties",
                    ja: "\(colorName)石、\(libs)呼吸点",
                    ko: "\(colorName)돌, 활로 \(libs)개",
                    zhHant: "\(colorName)子，\(libs)氣"
                )
            ]
            if isAtari {
                parts.append(l10n.localized(zh: "叫吃", en: "Atari", ja: "アタリ", ko: "단수", zhHant: "叫吃"))
            }
            if boardState.lastMove == .place(pt) {
                parts.append(l10n.localized(zh: "最后一手", en: "last move", ja: "最後の一手", ko: "마지막 수", zhHant: "最後一手"))
            }
            return parts.joined(separator: ", ")
        }
        if boardState.koPoint == pt {
            return l10n.localized(
                zh: "\(coord)，打劫禁着点",
                en: "\(coord), Ko forbidden",
                ja: "\(coord)、コウ禁止点",
                ko: "\(coord), 패 금지점",
                zhHant: "\(coord)，打劫禁著點"
            )
        }
        if isPending {
            return l10n.localized(
                zh: "\(coord)，待确认落子点",
                en: "\(coord), pending placement",
                ja: "\(coord)、着手確認待ち",
                ko: "\(coord), 착수 확인 대기",
                zhHant: "\(coord)，待確認落子點"
            )
        }
        return l10n.localized(
            zh: "\(coord)，空点",
            en: "\(coord), empty",
            ja: "\(coord)、空点",
            ko: "\(coord), 빈 점",
            zhHant: "\(coord)，空點"
        )
    }
    private var boardAccessibilityHint: String {
        guard isInteractive else {
            return boardL10n.localized(
                zh: "可逐点浏览当前盘面，或使用转子快速跳到最后一手、叫吃和黑白棋子。",
                en: "Explore board intersections or use the rotor to jump to the last move, atari, or stones.",
                ja: "各交点を確認するか、ローターで最後の一手やアタリ、黒石・白石へ移動できます。",
                ko: "교차점을 탐색하거나 로터로 마지막 수, 단수, 흑돌·백돌로 바로 이동할 수 있습니다.",
                zhHant: "可逐點瀏覽目前盤面，或使用轉輪快速跳到最後一手、叫吃與黑白棋子。"
            )
        }
        return boardL10n.localized(
            zh: "选择交叉点落子，或使用转子快速跳到最后一手、叫吃和黑白棋子。",
            en: "Activate an intersection to place a stone, or use the rotor to jump to the last move, atari, or stones.",
            ja: "交点を選択して着手するか、ローターで最後の一手やアタリへ移動できます。",
            ko: "교차점을 선택해 착수하거나 로터로 마지막 수와 단수 지점으로 이동할 수 있습니다.",
            zhHant: "選擇交叉點落子，或使用轉輪快速跳到最後一手、叫吃與黑白棋子。"
        )
    }

    private func rotorEntry(for pt: BoardPoint, atariSet: Set<BoardPoint>) -> GoBoardRotorEntry {
        GoBoardRotorEntry(
            id: pt,
            label: Self.accessibilityPointLabel(
                for: pt,
                boardState: boardState,
                isPending: pendingPoint == pt,
                isAtari: atariSet.contains(pt),
                l10n: boardL10n
            )
        )
    }

    private func lastMoveRotorEntries(in region: BoardCropRegion, atariSet: Set<BoardPoint>) -> [GoBoardRotorEntry] {
        guard case .place(let pt) = boardState.lastMove, region.contains(pt) else { return [] }
        return [rotorEntry(for: pt, atariSet: atariSet)]
    }

    private func atariRotorEntries(in region: BoardCropRegion, atariSet: Set<BoardPoint>) -> [GoBoardRotorEntry] {
        guard !atariSet.isEmpty else { return [] }
        var entries: [GoBoardRotorEntry] = []
        for r in region.minRow...region.maxRow {
            for c in region.minCol...region.maxCol {
                let pt = BoardPoint(row: r, col: c)
                if atariSet.contains(pt) {
                    entries.append(rotorEntry(for: pt, atariSet: atariSet))
                }
            }
        }
        return entries
    }

    private func stoneRotorEntries(color: StoneColor, in region: BoardCropRegion, atariSet: Set<BoardPoint>) -> [GoBoardRotorEntry] {
        var entries: [GoBoardRotorEntry] = []
        for r in region.minRow...region.maxRow {
            for c in region.minCol...region.maxCol {
                let pt = BoardPoint(row: r, col: c)
                if boardState.stone(at: pt) == color {
                    entries.append(rotorEntry(for: pt, atariSet: atariSet))
                }
            }
        }
        return entries
    }
}

/// Equatable wrapper around the cached stone layer. As long as the position and the static
/// overlays are unchanged, SwiftUI skips its body entirely — so hover / drag / ambient
/// animation never re-rasterize the stones.
private struct BoardStonesLayer: View, Equatable {
    let boardState: GoBoardState
    let stoneStyle: StoneStyle
    let region: BoardCropRegion
    let showCoordinates: Bool
    let side: CGFloat
    let analysis: GoBoardAnalysis
    let showMoveNumbers: Bool
    let moveNumbers: [BoardPoint: Int]
    let expressiveStones: Bool
    let markedDeadIndices: Set<Int>
    let territoryEstimate: TerritoryEstimate?
    let differentiateWithoutColor: Bool
    let suppressedStone: BoardPoint?

    var body: some View {
        Canvas { context, size in
            GoBoardView.renderStonesLayer(
                context: &context,
                canvasSize: size,
                boardState: boardState,
                stoneStyle: stoneStyle,
                region: region,
                showCoordinates: showCoordinates,
                side: side,
                analysis: analysis,
                showMoveNumbers: showMoveNumbers,
                moveNumbers: moveNumbers,
                expressiveStones: expressiveStones,
                markedDeadIndices: markedDeadIndices,
                territoryEstimate: territoryEstimate,
                differentiateWithoutColor: differentiateWithoutColor,
                suppressedStone: suppressedStone
            )
        }
    }
}

private struct GoBoardRotorEntry: Identifiable, Hashable {
    let id: BoardPoint
    let label: String
}

private struct GoBoardAccessibilityGrid: View {
    let boardState: GoBoardState
    let region: BoardCropRegion
    let side: CGFloat
    let atariSet: Set<BoardPoint>
    let pendingPoint: BoardPoint?
    let isInteractive: Bool
    let isDeadStoneReviewMode: Bool
    let l10n: L10n
    let metrics: GoBoardView.BoardMetrics
    let onSelectPoint: ((BoardPoint) -> Void)?

    private var allPoints: [BoardPoint] {
        var points: [BoardPoint] = []
        points.reserveCapacity(region.rowCount * region.colCount)
        for r in region.minRow...region.maxRow {
            for c in region.minCol...region.maxCol {
                points.append(BoardPoint(row: r, col: c))
            }
        }
        return points
    }

    private func pointLabel(_ pt: BoardPoint) -> String {
        GoBoardView.accessibilityPointLabel(
            for: pt,
            boardState: boardState,
            isPending: pendingPoint == pt,
            isAtari: atariSet.contains(pt),
            l10n: l10n
        )
    }

    private func pointHint(_ pt: BoardPoint) -> String {
        guard isInteractive else { return "" }
        if isDeadStoneReviewMode {
            return boardState.stone(at: pt) != nil
                ? l10n.localized(zh: "切换此子死活标记", en: "Toggle dead stone mark", ja: "死石マークを切り替え", ko: "사석 표시 전환", zhHant: "切換此子死活標記")
                : ""
        }
        if boardState.stone(at: pt) == nil && boardState.koPoint != pt {
            return l10n.localized(zh: "落子", en: "Place a stone", ja: "ここに打つ", ko: "착수", zhHant: "落子")
        }
        return ""
    }

    @ViewBuilder
    private func intersectionNode(for pt: BoardPoint, hitSize: CGFloat) -> some View {
        let center = metrics.center(for: pt)
        let coord = pt.humanLabel(boardSize: boardState.size)
        let label = pointLabel(pt)
        let hint = pointHint(pt)
        let traits: AccessibilityTraits = ((pendingPoint == pt) || (boardState.lastMove == .place(pt))) ? .isSelected : []

        Group {
            if isInteractive {
                Button {
                    onSelectPoint?(pt)
                } label: {
                    Color.clear.frame(width: hitSize, height: hitSize)
                }
                .accessibilityHint(hint)
            } else {
                Color.clear
                    .frame(width: hitSize, height: hitSize)
                    .accessibilityElement()
            }
        }
        .id(pt)
        .position(x: center.x, y: center.y)
        .accessibilityLabel(label)
        .accessibilityInputLabels([coord])
        .accessibilityAddTraits(traits)
    }

    var body: some View {
        let hitSize = max(18, metrics.cellStep)
        ZStack {
            ForEach(allPoints, id: \.self) { pt in
                intersectionNode(for: pt, hitSize: hitSize)
            }
        }
        .frame(width: side, height: side)
    }
}

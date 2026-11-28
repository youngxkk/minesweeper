//
//  PuzzleHubView.swift
//  StarYi Go — Continuous Horizontally Scrollable 4-Sea × 20-Island Connected World Map
//  Each sea has its own diorama artwork set in a continuous ocean with
//  cross-sea flight arcs, swipe navigation, edge "Fly to Next Sea" portals, Skip Gates & SRS Ghosts!
//

import SwiftUI

struct PuzzleHubView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let initialMistakesOnly: Bool

    @State private var scrolledSeaId: String? = "sea-1"
    @State private var selectedIslandId: String = "s1-reef"
    @State private var programmaticScrollNonce: Int = 0
    @State private var programmaticScrollAnimated: Bool = true
    @State private var hasInitializedScroll: Bool = false
    @State private var showPlacementSheet: Bool = false
    @State private var activePulse: Bool = false
    @State private var flightBob: Bool = false
    @State private var newlyUnlockedIslandIDs: Set<String> = []
    @State private var shakeCounters: [String: CGFloat] = [:]
    @State private var lockedToastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var hasEnteredMap: Bool = false

    /// Home-style staggered entrance choreography for map elements on first push.
    private func mapEntrance(
        _ delay: Double,
        x: CGFloat = 0,
        y: CGFloat = 0,
        scale: CGFloat = 1,
        animation: Animation = MotionToken.homePortalEntrance,
        fades: Bool = true
    ) -> StaggeredEntranceModifier {
        StaggeredEntranceModifier(
            appeared: hasEnteredMap,
            delay: MotionToken.screenEntranceBaseDelay + delay,
            reduceMotion: reduceMotion,
            offsetY: y,
            initialScale: scale,
            animation: animation,
            offsetX: x,
            fades: fades
        )
    }

    /// Islands pop onto the map one after another within each sea.
    private func islandEntranceDelay(_ island: CampaignIsland) -> Double {
        let siblings = StarYiCampaign.allIslands.filter { $0.seaId == island.seaId }
        let order = siblings.firstIndex(where: { $0.id == island.id }) ?? 0
        return 0.16 + Double(min(order, 8)) * MotionToken.itemStagger
    }

    private var l10n: L10n { appState.l10n }
    private var seas: [CampaignSea] { StarYiCampaign.allSeas }

    private var activeSeaIndex: Int {
        if let id = scrolledSeaId, let sea = StarYiCampaign.sea(withId: id) {
            return sea.index
        }
        return 0
    }

    private var activeSea: CampaignSea {
        seas[min(max(0, activeSeaIndex), seas.count - 1)]
    }

    private var isSeaUnlocked: Bool {
        StarYiCampaign.isSeaUnlocked(activeSea, progress: appState.puzzleProgress)
    }

    /// Currently focused unlocked island inside the visible region (powers the Hero Pawn & Expedition Card).
    private var focusedIslandInActiveSea: CampaignIsland? {
        if let current = activeSea.islands.first(where: { $0.id == selectedIslandId }),
           StarYiCampaign.unlockState(for: current, progress: appState.puzzleProgress).isUnlocked {
            return current
        }
        // Prefer the active frontier island in this region, or the last cleared island.
        if let activeFrontier = activeSea.islands.first(where: {
            StarYiCampaign.unlockState(for: $0, progress: appState.puzzleProgress) == .active
        }) {
            return activeFrontier
        }
        return activeSea.islands.last(where: {
            StarYiCampaign.unlockState(for: $0, progress: appState.puzzleProgress).isUnlocked
        })
    }

    var body: some View {
        ScrollViewReader { scrollProxy in
            ZStack {
                // MARK: - Continuous 4-Sea Panoramic Scrollable World
                GeometryReader { fullGeo in
                    let pageW = fullGeo.size.width
                    let pageH = fullGeo.size.height
                    let totalW = worldWidth(pageW: pageW, pageH: pageH)

                    ScrollView(.horizontal, showsIndicators: false) {
                        // Each sea retains a full-width scroll target; seas are separated by an open-ocean strait.
                        HStack(spacing: seaGapW(pageW: pageW, pageH: pageH)) {
                            ForEach(seas) { sea in
                                Color.clear
                                    .frame(width: pageW, height: pageH)
                                    .id(sea.id)
                            }
                        }
                        .scrollTargetLayout()
                        .background(alignment: .leading) {
                            seaMapArtwork(pageW: pageW, pageH: pageH, totalW: totalW)
                        }
                        .overlay(alignment: .leading) {
                            ZStack(alignment: .leading) {
                                // Biome-specific ambient atmosphere per region (dandelions, bamboo leaves, sakura, snow, embers)
                                ForEach(seas) { sea in
                                    let centerX = seaOriginX(sea.index, pageW: pageW, pageH: pageH) + pageW / 2
                                    let art = seaArtSize(pageW: pageW, pageH: pageH)
                                    BiomeAtmosphereOverlay(seaIndex: sea.index, reduceMotion: reduceMotion)
                                        .frame(width: art.width, height: art.height)
                                        .position(x: centerX, y: pageH / 2)
                                }

                                // Nintendo Go-Stone Star Roads & Cross-Sea Flight Arcs
                                Canvas { context, _ in
                                    let progress = appState.puzzleProgress
                                    let allIslands = StarYiCampaign.allIslands

                                    for (source, destination) in zip(allIslands, allIslands.dropFirst()) {
                                        let isCrossSea = (source.seaId != destination.seaId)
                                        let isOpen = StarYiCampaign.unlockState(for: destination, progress: progress).isUnlocked

                                        if isCrossSea {
                                            let route = worldRoute(from: source, to: destination, pageW: pageW, pageH: pageH)
                                            let dash: [CGFloat] = isOpen ? [10, 8] : [6, 12]
                                            context.stroke(
                                                route,
                                                with: .color(isOpen ? AppTheme.skyRim.opacity(0.45) : AppTheme.inkPrimary.opacity(0.40)),
                                                style: StrokeStyle(lineWidth: isOpen ? 12 : 7, lineCap: .round, dash: dash)
                                            )
                                            context.stroke(
                                                route,
                                                with: .linearGradient(
                                                    Gradient(colors: isOpen ? [AppTheme.sunTop, Color.white, AppTheme.skyTop] : [Color.white.opacity(0.85), Color.white.opacity(0.65)]),
                                                    startPoint: worldPoint(for: source, pageW: pageW, pageH: pageH),
                                                    endPoint: worldPoint(for: destination, pageW: pageW, pageH: pageH)
                                                ),
                                                style: StrokeStyle(lineWidth: isOpen ? 6.5 : 3.5, lineCap: .round, dash: dash)
                                            )
                                        } else {
                                            let controlPts = intraSeaControlPoints(from: source, to: destination, pageW: pageW, pageH: pageH)
                                            let spline = OverworldSpline.smoothPath(through: controlPts)

                                            // Subtle warm road bed glow underneath Go-stone stepping pips
                                            context.stroke(
                                                spline,
                                                with: .color(isOpen ? AppTheme.sunRim.opacity(0.32) : Color.black.opacity(0.18)),
                                                style: StrokeStyle(lineWidth: isOpen ? 11 : 6, lineCap: .round, lineJoin: .round)
                                            )
                                            if isOpen {
                                                context.stroke(
                                                    spline,
                                                    with: .color(Color(red: 1.0, green: 0.95, blue: 0.72).opacity(0.68)),
                                                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
                                                )
                                            }

                                            // Nintendo-style evenly spaced Go-stone stepping pips along the spline!
                                            let pips = OverworldSpline.sampledPoints(through: controlPts, spacing: 26, endTrim: 34)
                                            for (idx, pt) in pips.enumerated() {
                                                let r: CGFloat = isOpen ? 5.2 : 3.6
                                                let shadowRect = CGRect(x: pt.x - r, y: pt.y - r + 2.0, width: r * 2, height: r * 2)
                                                context.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.28)))

                                                let stoneRect = CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)
                                                if isOpen {
                                                    let isGold = (idx % 2 == 0)
                                                    context.fill(
                                                        Path(ellipseIn: stoneRect),
                                                        with: .color(isGold ? AppTheme.sunTop : Color.white)
                                                    )
                                                    context.stroke(
                                                        Path(ellipseIn: stoneRect),
                                                        with: .color(AppTheme.sunRim.opacity(0.85)),
                                                        lineWidth: 1.5
                                                    )
                                                } else {
                                                    context.fill(
                                                        Path(ellipseIn: stoneRect),
                                                        with: .color(Color.white.opacity(0.68))
                                                    )
                                                    context.stroke(
                                                        Path(ellipseIn: stoneRect),
                                                        with: .color(Color.black.opacity(0.28)),
                                                        lineWidth: 1.0
                                                    )
                                                }
                                            }
                                        }
                                    }
                                }
                                .frame(width: totalW, height: pageH)
                                .allowsHitTesting(false)

                                // Cross-sea flight entrances
                                ForEach(0..<(seas.count - 1), id: \.self) { idx in
                                    let nextSea = seas[idx + 1]
                                    crossSeaFlightPin(to: nextSea, scrollProxy: scrollProxy)
                                        .offset(y: flightBob ? -5 : 5)
                                        .visualEffect { content, proxy in
                                            let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                                            let clearance = min(frame.minX, pageW - frame.maxX)
                                            return content.opacity(Double(min(1, max(0, clearance / 24))))
                                        }
                                        .position(x: straitCenterX(beforeSea: idx + 1, pageW: pageW, pageH: pageH), y: pageH * 0.44)
                                }

                                // Full-island elliptical hit zones covering the entire illustrated clearing/landmark
                                ForEach(StarYiCampaign.allIslands) { island in
                                    let hitFrame = islandHitArea(for: island, pageW: pageW, pageH: pageH)
                                    Button {
                                        handleIslandTap(island)
                                    } label: {
                                        Color.clear
                                            .frame(width: hitFrame.width, height: hitFrame.height)
                                            .contentShape(Ellipse())
                                    }
                                    .buttonStyle(.plain)
                                    .position(x: hitFrame.midX, y: hitFrame.midY)
                                    .accessibilityHidden(true)
                                }

                                // 2.5D Grounded Go-Stone Stage Pedestals
                                ForEach(StarYiCampaign.allIslands) { island in
                                    islandMapPin(island)
                                        .phaseAnimator([0, 1, 2], trigger: newlyUnlockedIslandIDs.contains(island.id)) { pin, phase in
                                            pin.scaleEffect(!reduceMotion && phase == 1 ? 1.16 : 1)
                                        } animation: { _ in
                                            .spring(response: 0.29, dampingFraction: 0.72)
                                        }
                                        .modifier(mapEntrance(islandEntranceDelay(island), y: -18, scale: 0.55))
                                        .position(worldPoint(for: island, pageW: pageW, pageH: pageH))
                                }

                                // Live Nintendo Hero Pawn standing on the focused unlocked stage & hopping smoothly!
                                if let focused = focusedIslandInActiveSea {
                                    let heroPos = worldPoint(for: focused, pageW: pageW, pageH: pageH)
                                    OverworldHeroPawn(bobbing: activePulse, reduceMotion: reduceMotion)
                                        .modifier(mapEntrance(0.42, y: -56, scale: 0.7))
                                        .position(x: heroPos.x, y: heroPos.y - 34)
                                        .animation(
                                            reduceMotion ? nil : .spring(response: 0.44, dampingFraction: 0.72),
                                            value: focused.id
                                        )
                                }
                            }
                            .frame(width: totalW, height: pageH)
                        }
                    }
                    .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                    .modifier(
                        CampaignSeaScrollPositionModifier(
                            scrolledSeaId: $scrolledSeaId,
                            scrollNonce: programmaticScrollNonce,
                            targetX: seaOriginX(activeSeaIndex, pageW: pageW, pageH: pageH),
                            animated: programmaticScrollAnimated && !reduceMotion
                        )
                    )
                    .frame(width: pageW, height: pageH)
                    .modifier(mapEntrance(0, scale: 1.06, animation: MotionToken.screenBackdropSettle, fades: false))
                }
                .ignoresSafeArea()

                // MARK: - Floating Left / Right "Fly to Previous / Next Sea" Edge Portals
                HStack {
                    if activeSeaIndex > 0 {
                        edgeFlyButton(targetSea: seas[activeSeaIndex - 1], direction: .previous, scrollProxy: scrollProxy)
                            .padding(.leading, 12)
                            .modifier(mapEntrance(0.30, x: -64, scale: 0.9))
                    }
                    Spacer()
                    if activeSeaIndex + 1 < seas.count {
                        edgeFlyButton(targetSea: seas[activeSeaIndex + 1], direction: .next, scrollProxy: scrollProxy)
                            .padding(.trailing, 12)
                            .modifier(mapEntrance(0.30, x: 64, scale: 0.9))
                    }
                }
                .allowsHitTesting(true)

                // MARK: - Top HUD & Bottom Adventure Dock
                VStack(spacing: verticalSizeClass == .compact ? 4 : 8) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, verticalSizeClass == .compact ? 8 : 12)
                        .modifier(mapEntrance(0.02, y: -72, scale: 0.94, animation: MotionToken.homeTopBarEntrance))

                    seaCompassStrip(scrollProxy: scrollProxy)
                        .padding(.horizontal, 20)
                        .modifier(mapEntrance(0.09, y: -60, scale: 0.92, animation: MotionToken.homeTopBarEntrance))

                    Spacer()

                    if let toast = lockedToastMessage {
                        lockedToastPill(toast)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !isSeaUnlocked {
                        lockedSeaSkipGateDock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .modifier(mapEntrance(0.20, y: 80, scale: 0.94))
                    } else {
                        bottomAdventureDock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .modifier(mapEntrance(0.20, y: 80, scale: 0.94))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPlacementSheet) {
                placementSelectionSheet(scrollProxy: scrollProxy)
            }
            .onAppear {
                if !hasEnteredMap {
                    hasEnteredMap = true
                }
                let freshUnlocks = appState.consumeIslandUnlocks()
                newlyUnlockedIslandIDs.formUnion(freshUnlocks)
                if !hasInitializedScroll {
                    hasInitializedScroll = true
                    if let highestUnlocked = seas.last(where: { StarYiCampaign.isSeaUnlocked($0, progress: appState.puzzleProgress) }) {
                        scrolledSeaId = highestUnlocked.id
                        syncFocusedIsland(for: highestUnlocked)
                        programmaticScrollAnimated = false
                        programmaticScrollNonce += 1
                        scrollProxy.scrollTo(highestUnlocked.id, anchor: .leading)
                    }
                } else if let newlyUnlockedId = freshUnlocks.first,
                          let newlyUnlockedIsland = StarYiCampaign.island(withId: newlyUnlockedId) {
                    selectedIslandId = newlyUnlockedId
                    if newlyUnlockedIsland.seaId != scrolledSeaId {
                        scrolledSeaId = newlyUnlockedIsland.seaId
                        programmaticScrollAnimated = !reduceMotion
                        programmaticScrollNonce += 1
                        scrollProxy.scrollTo(newlyUnlockedIsland.seaId, anchor: .leading)
                    }
                }
                if !reduceMotion {
                    if !activePulse {
                        withAnimation(.easeInOut(duration: 1.45).repeatForever(autoreverses: true)) {
                            activePulse = true
                        }
                    }
                    if !flightBob {
                        withAnimation(.easeInOut(duration: 1.85).repeatForever(autoreverses: true)) {
                            flightBob = true
                        }
                    }
                }
            }
            .onChange(of: scrolledSeaId) { _, _ in
                syncFocusedIsland(for: activeSea)
            }
            .onDisappear {
                toastDismissTask?.cancel()
            }
        }
    }

    // MARK: - Smooth Camera Flight Helper

    private func flyToSea(_ sea: CampaignSea, scrollProxy: ScrollViewProxy) {
        SoundAndHapticsManager.shared.playUITap()
        withAnimation(reduceMotion ? nil : .spring(response: 0.54, dampingFraction: 0.84)) {
            scrolledSeaId = sea.id
            programmaticScrollAnimated = !reduceMotion
            programmaticScrollNonce += 1
            if #unavailable(iOS 18.0) {
                scrollProxy.scrollTo(sea.id, anchor: .leading)
            }
            lockedToastMessage = nil
        }
    }

    // MARK: - Biome World Artwork

    private func seaMapArtwork(pageW: CGFloat, pageH: CGFloat, totalW: CGFloat) -> some View {
        let art = seaArtSize(pageW: pageW, pageH: pageH)
        let gap = seaGapW(pageW: pageW, pageH: pageH)
        let slotW = pageW + gap
        let overlap = min(slotW * 0.30, pageH * 0.58)
        let backdropW = slotW + overlap
        let fadeEnd = overlap / max(1, backdropW)

        return ZStack(alignment: .leading) {
            // Blend adjacent landscape edges behind the sharp, tappable map artwork.
            ForEach(seas) { sea in
                let centerX = seaOriginX(sea.index, pageW: pageW, pageH: pageH) + pageW / 2
                Image(sea.mapImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: backdropW, height: pageH)
                    .clipped()
                    .blur(radius: 12, opaque: true)
                    .mask {
                        if sea.index == 0 {
                            Rectangle()
                        } else {
                            LinearGradient(stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .white.opacity(0.15), location: fadeEnd * 0.25),
                                .init(color: .white.opacity(0.85), location: fadeEnd * 0.75),
                                .init(color: .white, location: fadeEnd)
                            ], startPoint: .leading, endPoint: .trailing)
                        }
                    }
                    .position(x: centerX, y: pageH / 2)
            }

            ForEach(seas) { sea in
                let centerX = seaOriginX(sea.index, pageW: pageW, pageH: pageH) + pageW / 2
                Image(sea.mapImageName)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: art.width, height: art.height)
                    .mask { seaArtEdgeFade(from: .leading, to: .trailing) }
                    .mask { seaArtEdgeFade(from: .top, to: .bottom) }
                    .position(x: centerX, y: pageH / 2)
            }
        }
        .frame(width: totalW, height: pageH)
        .clipped()
        .accessibilityIgnoresInvertColors()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func seaArtEdgeFade(from start: UnitPoint, to end: UnitPoint) -> some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .white.opacity(0.5), location: 0.025),
                .init(color: .white, location: 0.06),
                .init(color: .white, location: 0.94),
                .init(color: .white.opacity(0.5), location: 0.975),
                .init(color: .clear, location: 1)
            ],
            startPoint: start,
            endPoint: end
        )
    }

    private func crossSeaFlightPin(to nextSea: CampaignSea, scrollProxy: ScrollViewProxy) -> some View {
        let unlocked = StarYiCampaign.isSeaUnlocked(nextSea, progress: appState.puzzleProgress)
        return Button {
            flyToSea(nextSea, scrollProxy: scrollProxy)
        } label: {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: unlocked ? [AppTheme.sunTop, AppTheme.sunBottom] : [AppTheme.skyTop, AppTheme.skyBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                        .shadow(color: (unlocked ? AppTheme.sunRim : AppTheme.skyRim).opacity(0.45), radius: 8, y: 4)
                    Text(unlocked ? "✈️" : "🔑")
                        .font(AppFont.rounded(size: 22, weight: .regular))
                }
                Text(unlocked
                     ? l10n.localized(
                         zh: "飞往\(shortRegionName(nextSea.index))",
                         en: "Fly Area \(nextSea.index + 1)",
                         ja: "\(shortRegionName(nextSea.index))へ飛ぶ",
                         ko: "\(shortRegionName(nextSea.index)) 이동",
                         zhHant: "飛往\(shortRegionName(nextSea.index))"
                     )
                     : l10n.localized(
                         zh: "跳级\(shortRegionName(nextSea.index))",
                         en: "Skip Area \(nextSea.index + 1)",
                         ja: "\(shortRegionName(nextSea.index))へ飛び級",
                         ko: "\(shortRegionName(nextSea.index)) 월반",
                         zhHant: "跳級\(shortRegionName(nextSea.index))"
                     ))
                    .font(AppFont.rounded(size: 10.5, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.95)).overlay(Capsule().strokeBorder(.white, lineWidth: 1.5)))
                    .shadow(color: Color.black.opacity(0.14), radius: 5, y: 2)
            }
        }
        .buttonStyle(TactileButtonStyle(pressedScale: 0.92, playTapSound: false))
    }

    private enum EdgeDirection { case previous, next }

    private func edgeFlyButton(targetSea: CampaignSea, direction: EdgeDirection, scrollProxy: ScrollViewProxy) -> some View {
        let unlocked = StarYiCampaign.isSeaUnlocked(targetSea, progress: appState.puzzleProgress)
        let isNext = (direction == .next)
        let pal: GlossyPalette = isNext ? (unlocked ? seaPalette(targetSea.index) : .sun) : .snow

        return Button {
            flyToSea(targetSea, scrollProxy: scrollProxy)
        } label: {
            VStack(spacing: 4) {
                HStack(spacing: 4) {
                    if !isNext {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                    Text(isNext ? (unlocked ? "✈️" : "🔑") : targetSea.emoji)
                        .font(AppFont.rounded(size: 18, weight: .regular))
                    if isNext {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                    }
                }
                .foregroundColor(isNext ? .white : AppTheme.inkPrimary)

                Text(isNext
                     ? l10n.localized(
                         zh: "飞往\(shortRegionName(targetSea.index))",
                         en: "Area \(targetSea.index + 1)",
                         ja: "\(shortRegionName(targetSea.index))へ",
                         ko: "\(shortRegionName(targetSea.index))로",
                         zhHant: "飛往\(shortRegionName(targetSea.index))"
                     )
                     : l10n.localized(
                         zh: shortRegionName(targetSea.index),
                         en: "Area \(targetSea.index + 1)",
                         ja: shortRegionName(targetSea.index),
                         ko: shortRegionName(targetSea.index),
                         zhHant: shortRegionName(targetSea.index)
                     ))
                    .font(AppFont.rounded(size: 10.5, weight: .black))
                    .foregroundColor(isNext ? .white : AppTheme.inkPrimary)

                Text(targetSea.rankRange)
                    .font(AppFont.rounded(size: 9, weight: .heavy))
                    .foregroundColor(isNext ? .white.opacity(0.92) : AppTheme.skyBottom)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 22, rimHeight: 3, whiteBorderWidth: 3, playTapSound: false))
        .accessibilityIdentifier(isNext ? "FlyNextSeaButton" : "FlyPrevSeaButton")
    }

    // MARK: - Top Bar & Live Syncing Sea Compass Strip

    private var topBar: some View {
        let clearedNodes = StarYiCampaign.totalClearedNodes(progress: appState.puzzleProgress)
        let totalNodes = StarYiCampaign.allNodes.count

        return ZStack {
            GameTitleCrest(
                title: activeSea.localizedName(l10n),
                subtitle: l10n.localized(
                    zh: "\(activeSea.rankRange) · 左右滑动探索 \(seas.count) 大世界 · 已通 \(clearedNodes)/\(totalNodes) 关",
                    en: "\(activeSea.rankRange) · Swipe across \(seas.count) Worlds · \(clearedNodes)/\(totalNodes) Cleared",
                    ja: "\(activeSea.rankRange) · スワイプで\(seas.count)つの世界を冒険 · \(clearedNodes)/\(totalNodes) クリア",
                    ko: "\(activeSea.rankRange) · 스와이프로 \(seas.count)대 세계 탐험 · \(clearedNodes)/\(totalNodes) 완료",
                    zhHant: "\(activeSea.rankRange) · 左右滑動探索 \(seas.count) 大世界 · 已通 \(clearedNodes)/\(totalNodes) 關"
                )
            )
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("CampaignMapTitle")

            HStack {
                topBarBackButton
                Spacer()
                puzzleRushButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var topBarBackButton: some View {
        GameBackButton(title: l10n.t("common.back")) {
            appState.popRoute()
        }
    }

    /// Compact live-syncing mini-compass showing where you are in the 4-Sea ocean chain.
    private func seaCompassStrip(scrollProxy: ScrollViewProxy) -> some View {
        HStack(spacing: 6) {
            ForEach(Array(seas.enumerated()), id: \.element.id) { idx, sea in
                let isSelected = (sea.index == activeSeaIndex)
                let unlocked = StarYiCampaign.isSeaUnlocked(sea, progress: appState.puzzleProgress)

                Button {
                    flyToSea(sea, scrollProxy: scrollProxy)
                } label: {
                    HStack(spacing: 5) {
                        Text(unlocked ? sea.emoji : "🔒").font(AppFont.rounded(size: 12.5, weight: .regular))
                        Text(isSelected
                             ? l10n.localized(
                                 zh: "\(shortRegionName(idx)) · \(sea.rankRange)",
                                 en: "Sea \(idx + 1) · \(sea.rankRange)",
                                 ja: "\(shortRegionName(idx)) · \(sea.rankRange)",
                                 ko: "\(shortRegionName(idx)) · \(sea.rankRange)",
                                 zhHant: "\(shortRegionName(idx)) · \(sea.rankRange)"
                             )
                             : sea.rankRange)
                            .font(AppFont.rounded(size: 11.5, weight: .black))
                            .foregroundColor(isSelected ? .white : AppTheme.inkPrimary)
                    }
                    .padding(.horizontal, isSelected ? 13 : 10)
                    .padding(.vertical, 6)
                    .frame(minHeight: AppTheme.buttonFaceHeight)
                    .background(
                        Capsule().fill(
                            isSelected
                                ? AnyShapeStyle(LinearGradient(colors: [seaPalette(idx).top, seaPalette(idx).bottom], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.white.opacity(0.88))
                        )
                    )
                    .overlay(Capsule().strokeBorder(.white, lineWidth: isSelected ? 2 : 1.5))
                }
                .tactileButton(scale: 0.95, sound: false)
                .accessibilityIdentifier("SeaTab_\(sea.id)")

                if idx + 1 < seas.count {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule().fill(Color.black.opacity(0.18)))
    }

    private func shortRegionName(_ index: Int) -> String {
        switch index {
        case 0: return l10n.localized(zh: "草地", en: "Meadow", ja: "草原", ko: "초원", zhHant: "草地")
        case 1: return l10n.localized(zh: "森林", en: "Forest", ja: "森", ko: "숲", zhHant: "森林")
        case 2: return l10n.localized(zh: "湖泊", en: "Lake", ja: "湖", ko: "호수", zhHant: "湖泊")
        case 3: return l10n.localized(zh: "雪山", en: "Snow", ja: "雪山", ko: "설산", zhHant: "雪山")
        default: return l10n.localized(zh: "火山", en: "Volcano", ja: "火山", ko: "화산", zhHant: "火山")
        }
    }

    private func seaPalette(_ index: Int) -> GlossyPalette {
        switch index {
        case 0: return .sky
        case 1: return .mint
        case 2: return .sun
        case 3: return .grape
        default: return .coral
        }
    }

    // MARK: - World Coordinates & Continuous 25-Stage Routes

    private func seaIndex(for island: CampaignIsland) -> Int {
        StarYiCampaign.sea(withId: island.seaId)?.index ?? 0
    }

    /// Pixel aspect ratio of every ultra-HD region artwork (2400 × 1792).
    private static let seaArtAspect: CGFloat = 2400.0 / 1792.0

    /// On-screen size of one sea artwork tailored for iPad Landscape (4:3 / 1.34:1).
    /// Keeps the artwork's true 4:3 aspect ratio so pedestals and Go-stone roads align with millimeter precision.
    private func seaArtSize(pageW: CGFloat, pageH: CGFloat) -> CGSize {
        let h = min(pageH * 1.02, pageW / Self.seaArtAspect)
        return CGSize(width: h * Self.seaArtAspect, height: h)
    }

    private func syncFocusedIsland(for sea: CampaignSea) {
        if let active = sea.islands.first(where: {
            StarYiCampaign.unlockState(for: $0, progress: appState.puzzleProgress) == .active
        }) {
            selectedIslandId = active.id
        } else if let lastUnlocked = sea.islands.last(where: {
            StarYiCampaign.unlockState(for: $0, progress: appState.puzzleProgress).isUnlocked
        }) {
            selectedIslandId = lastUnlocked.id
        }
    }

    /// World-space control points (start -> waypoints -> destination) for intra-region Go-stone star roads.
    private func intraSeaControlPoints(from source: CampaignIsland, to destination: CampaignIsland, pageW: CGFloat, pageH: CGFloat) -> [CGPoint] {
        let sIdx = seaIndex(for: source)
        var pts: [CGPoint] = [worldPoint(for: source, pageW: pageW, pageH: pageH)]
        for wp in source.pathToNextWaypoints {
            pts.append(artPoint(sea: sIdx, x: wp.x, y: wp.y, pageW: pageW, pageH: pageH))
        }
        pts.append(worldPoint(for: destination, pageW: pageW, pageH: pageH))
        return pts
    }

    /// Include the water already visible in each page's side margins.
    private func seaGapW(pageW: CGFloat, pageH: CGFloat) -> CGFloat {
        let margin = pageW - seaArtSize(pageW: pageW, pageH: pageH).width
        return max(0, min(300, pageW * 0.5) - margin)
    }

    private func seaOriginX(_ index: Int, pageW: CGFloat, pageH: CGFloat) -> CGFloat {
        CGFloat(index) * (pageW + seaGapW(pageW: pageW, pageH: pageH))
    }

    /// Horizontal centre of the strait that sits in front of sea `index` (index >= 1).
    private func straitCenterX(beforeSea index: Int, pageW: CGFloat, pageH: CGFloat) -> CGFloat {
        seaOriginX(index, pageW: pageW, pageH: pageH) - seaGapW(pageW: pageW, pageH: pageH) / 2
    }

    private func worldWidth(pageW: CGFloat, pageH: CGFloat) -> CGFloat {
        CGFloat(seas.count) * pageW + CGFloat(max(0, seas.count - 1)) * seaGapW(pageW: pageW, pageH: pageH)
    }

    /// Converts normalised artwork coordinates (0...1 inside a sea painting) into world coordinates.
    private func artPoint(sea index: Int, x: CGFloat, y: CGFloat, pageW: CGFloat, pageH: CGFloat) -> CGPoint {
        let art = seaArtSize(pageW: pageW, pageH: pageH)
        return CGPoint(
            x: seaOriginX(index, pageW: pageW, pageH: pageH) + pageW / 2 + (x - 0.5) * art.width,
            y: pageH / 2 + (y - 0.5) * art.height
        )
    }

    private func worldPoint(for island: CampaignIsland, pageW: CGFloat, pageH: CGFloat) -> CGPoint {
        artPoint(sea: seaIndex(for: island), x: island.mapX, y: island.mapY, pageW: pageW, pageH: pageH)
    }

    private func islandHitArea(for island: CampaignIsland, pageW: CGFloat, pageH: CGFloat) -> CGRect {
        let art = seaArtSize(pageW: pageW, pageH: pageH)
        let center = worldPoint(for: island, pageW: pageW, pageH: pageH)
        let width = max(44, art.width * 0.20)
        let height = max(44, art.height * 0.20)
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    private func handleIslandTap(_ island: CampaignIsland) {
        let unlockState = StarYiCampaign.unlockState(for: island, progress: appState.puzzleProgress)
        switch unlockState {
        case .active, .cleared:
            lockedToastMessage = nil
            if selectedIslandId == island.id {
                SoundAndHapticsManager.shared.playUITap()
                appState.navigationPath.append(.islandDetail(islandId: island.id))
            } else {
                SoundAndHapticsManager.shared.playStonePlace()
                withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.74)) {
                    selectedIslandId = island.id
                }
            }
        case .locked:
            let islandSea = StarYiCampaign.sea(withId: island.seaId) ?? activeSea
            let seaUnlocked = StarYiCampaign.isSeaUnlocked(islandSea, progress: appState.puzzleProgress)
            let msg: String
            if !seaUnlocked {
                let seaName = islandSea.localizedName(l10n)
                msg = l10n.localized(
                    zh: "点下方「🔑 跳级试炼门」答对 \(islandSea.skipGatePassCount)/\(islandSea.skipGatePuzzleIds.count) 题即可直接解锁\(seaName)！",
                    en: "Tap the Skip Gate below (pass \(islandSea.skipGatePassCount)/\(islandSea.skipGatePuzzleIds.count)) to unlock \(seaName) immediately!",
                    ja: "下の「🔑 飛び級試験」で \(islandSea.skipGatePassCount)/\(islandSea.skipGatePuzzleIds.count) 問正解すると「\(seaName)」をすぐ解放できます！",
                    ko: "아래 「🔑 월반 시험」에서 \(islandSea.skipGatePassCount)/\(islandSea.skipGatePuzzleIds.count)문제를 맞히면 \(seaName)을(를) 바로 해금할 수 있어요!",
                    zhHant: "點下方「🔑 跳級試煉門」答對 \(islandSea.skipGatePassCount)/\(islandSea.skipGatePuzzleIds.count) 題即可直接解鎖\(seaName)！"
                )
            } else {
                let prevName = islandSea.islands[max(0, island.orderInSea - 1)].localizedName(l10n)
                msg = l10n.localized(
                    zh: "通关「\(prevName)」即可解锁本岛！",
                    en: "Clear \(prevName) to unlock this island!",
                    ja: "「\(prevName)」をクリアするとこの島が解放されます！",
                    ko: "「\(prevName)」을(를) 클리어하면 이 섬이 해금됩니다!",
                    zhHant: "通關「\(prevName)」即可解鎖本島！"
                )
            }
            triggerLockedFeedback(islandId: island.id, message: msg)
        }
    }

    private func worldRoute(from source: CampaignIsland, to destination: CampaignIsland, pageW: CGFloat, pageH: CGFloat) -> Path {
        let start = worldPoint(for: source, pageW: pageW, pageH: pageH)
        let end = worldPoint(for: destination, pageW: pageW, pageH: pageH)

        var route = Path()
        route.move(to: start)

        if source.seaId != destination.seaId {
            // Sweeping cross-sea flight arc from Island 5 (top-right) over the open strait to Island 1 of the next sea.
            let borderX = straitCenterX(beforeSea: seaIndex(for: destination), pageW: pageW, pageH: pageH)
            let span = end.x - start.x
            let ctrl1 = CGPoint(x: borderX - span * 0.12, y: start.y - pageH * 0.10)
            let ctrl2 = CGPoint(x: borderX + span * 0.12, y: end.y + pageH * 0.02)
            route.addCurve(to: end, control1: ctrl1, control2: ctrl2)
        } else {
            let midX = (start.x + end.x) / 2
            route.addCurve(to: end, control1: CGPoint(x: midX, y: start.y),
                           control2: CGPoint(x: midX, y: end.y))
        }
        return route
    }

    // MARK: - 2.5D Embedded Go-Stone Stage Pedestal Pin

    @ViewBuilder
    private func islandMapPin(_ island: CampaignIsland) -> some View {
        let unlockState = StarYiCampaign.unlockState(for: island, progress: appState.puzzleProgress)
        let pal = GlossyPalette.forIsland(island.id)
        let shakeCount = shakeCounters[island.id] ?? 0
        let dueGhosts = StarYiCampaign.dueMistakeGhosts(for: island, progress: appState.puzzleProgress)
        let bossDefeated = StarYiCampaign.isBossDefeated(for: island, progress: appState.puzzleProgress)
        let earned = StarYiCampaign.earnedStars(for: island, progress: appState.puzzleProgress)
        let maxS = StarYiCampaign.maxStars(for: island)
        let worldNumber = seaIndex(for: island) + 1
        let stageCode = "\(worldNumber)-\(island.orderInSea + 1)"
        let isSelected = (focusedIslandInActiveSea?.id == island.id) && unlockState.isUnlocked

        GoStonePedestalPin(
            island: island,
            stageCode: stageCode,
            displayName: island.localizedName(l10n),
            unlockState: unlockState,
            isSelected: isSelected,
            isBossDefeated: bossDefeated,
            earnedStars: earned,
            maxStars: maxS,
            dueGhostCount: dueGhosts.count,
            palette: pal,
            activePulse: activePulse,
            shakeCount: shakeCount,
            onTap: { handleIslandTap(island) }
        )
    }

    // MARK: - Bottom Docks (Locked Sea Skip Gate vs Active Adventure Dock)

    private var lockedSeaSkipGateDock: some View {
        let compact = verticalSizeClass == .compact
        let seaNumber = activeSea.index + 1
        let compactTitle = l10n.localized(
            zh: "海域\(seaNumber)跳级试炼",
            en: "Sea \(seaNumber) Skip Gate",
            ja: "海域\(seaNumber)の飛び級試験",
            ko: "해역 \(seaNumber) 월반 시험",
            zhHant: "海域\(seaNumber)跳級試煉"
        )
        let compactSubtitle = l10n.localized(
            zh: "答对 4/5 题解锁",
            en: "Pass 4/5 to unlock",
            ja: "4問正解で解放（全5問）",
            ko: "5문제 중 4문제 정답 시 해금",
            zhHant: "答對 4/5 題解鎖"
        )

        return HStack(spacing: 14) {
            Button {
                appState.navigationPath.append(.seaSkipGate(seaId: activeSea.id))
            } label: {
                HStack(spacing: 12) {
                    Text("🔑").font(AppFont.rounded(size: 26, weight: .regular))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(compact ? compactTitle : l10n.localized(
                            zh: "开启「\(activeSea.localizedName(l10n))」跳级试炼门",
                            en: "Challenge Skip Gate for \(activeSea.localizedName(l10n))",
                            ja: "「\(activeSea.localizedName(l10n))」飛び級試験に挑戦",
                            ko: "「\(activeSea.localizedName(l10n))」 월반 시험 도전",
                            zhHant: "開啟「\(activeSea.localizedName(l10n))」跳級試煉門"
                        ))
                            .font(AppFont.rounded(size: 16, weight: .black))
                            .foregroundColor(.white)
                        Text(compact ? compactSubtitle : l10n.localized(
                            zh: "水平够强不想从头刷？无辅助答对 4/5 题直接空降本海域！",
                            en: "Strong player? Pass 4/5 exam puzzles to jump straight here!",
                            ja: "実力に自信あり？ヒントなしで5問中4問正解してこの海域へ飛び級！",
                            ko: "실력에 자신 있나요? 힌트 없이 5문제 중 4문제를 맞혀 이 해역으로 바로 점프!",
                            zhHant: "水平夠強不想從頭刷？無輔助答對 4/5 題直接空降本海域！"
                        ))
                            .font(AppFont.rounded(size: 12, weight: .bold))
                            .foregroundColor(.white.opacity(0.94))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, compact ? 8 : 14)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 30, rimHeight: 4, whiteBorderWidth: 3.5, showStripeSheen: true))
            .accessibilityIdentifier("CampaignSkipGateButton")
        }
        .frame(maxWidth: 780)
    }

    private var bottomAdventureDock: some View {
        let solved = StarterBootcamp.solvedCount(progress: appState.puzzleProgress)
        let total = StarterBootcamp.puzzles.count
        let nextLesson = StarterBootcamp.nextUnsolved(progress: appState.puzzleProgress)

        return HStack(spacing: 12) {
            // Nintendo-Style Focused Stage Expedition Card (shows Boss, progress & juicy Enter Stage button)
            if let focused = focusedIslandInActiveSea {
                focusedStageExpeditionCard(focused)
            }

            if activeSeaIndex == 0 {
                Button {
                    appState.navigationPath.append(.puzzlePlay(puzzleId: nextLesson.id, isDailyChallenge: false, isStarterBootcamp: true))
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(l10n.t("islands.starterDock.title")) (\(solved)/\(total))")
                                .font(AppFont.rounded(size: 12.5, weight: .black))
                                .foregroundColor(AppTheme.inkPrimary)
                            Text(l10n.localized(zh: "零基础5路启蒙", en: "5×5 Starter", ja: "5路盤・入門", ko: "5줄 바둑 입문", zhHant: "零基礎5路啟蒙"))
                                .font(AppFont.rounded(size: 10, weight: .bold))
                                .foregroundColor(AppTheme.inkSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 3, whiteBorderWidth: 3))
            }
        }
    }

    private func focusedStageExpeditionCard(_ island: CampaignIsland) -> some View {
        let cleared = StarYiCampaign.clearedNodeCount(for: island, progress: appState.puzzleProgress)
        let total = island.nodes.count
        let bossDefeated = StarYiCampaign.isBossDefeated(for: island, progress: appState.puzzleProgress)
        let pal = GlossyPalette.forIsland(island.id)
        let stageCode = "W\(seaIndex(for: island) + 1)-\(island.orderInSea + 1)"

        return HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                CharacterAvatarView(character: island.boss.difficulty, mood: bossDefeated ? .cheering : .greeting, size: 46)
                if bossDefeated {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(AppTheme.sunBottom).overlay(Circle().strokeBorder(.white, lineWidth: 1.5)))
                        .offset(x: 4, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(stageCode)
                        .font(AppFont.rounded(size: 10.5, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom)))
                    Text(island.localizedName(l10n))
                        .font(AppFont.rounded(size: 15, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .lineLimit(1)
                }
                Text(l10n.localized(
                    zh: "\(island.rankRange) · 已通 \(cleared)/\(total) 关 · \(island.descZh)",
                    en: "\(island.rankRange) · \(cleared)/\(total) Cleared · \(island.descEn)",
                    ja: "\(island.rankRange) · \(cleared)/\(total) 関クリア",
                    ko: "\(island.rankRange) · \(cleared)/\(total) 관 완료",
                    zhHant: "\(island.rankRange) · 已通 \(cleared)/\(total) 關 · \(island.descZh)"
                ))
                .font(AppFont.rounded(size: 11, weight: .bold))
                .foregroundColor(AppTheme.inkSecondary)
                .lineLimit(1)
            }

            Button {
                SoundAndHapticsManager.shared.playUITap()
                appState.navigationPath.append(.islandDetail(islandId: island.id))
            } label: {
                HStack(spacing: 5) {
                    Text(l10n.localized(zh: "进入闯关", en: "Enter", ja: "出発", ko: "도전", zhHant: "進入闖關"))
                        .font(AppFont.rounded(size: 13.5, weight: .black))
                        .foregroundColor(.white)
                    Image(systemName: "play.fill")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2.5, playTapSound: false))
            .accessibilityIdentifier("EnterFocusedStageButton")
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.95))
                .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
                .shadow(color: Color.black.opacity(0.18), radius: 12, y: 5)
        )
    }

    private var puzzleRushButton: some View {
        let best = appState.puzzleProgress.bestPuzzleRushScore
        return Button {
            appState.navigationPath.append(.puzzleRush)
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13.5, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(
                            LinearGradient(
                                colors: [AppTheme.sunTop, AppTheme.sunBottom],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(l10n.localized(
                        zh: "无尽冲关 · 30K→5D",
                        en: "Puzzle Rush · 30K→5D",
                        ja: "連続挑戦 · 30K→5D",
                        ko: "연속 도전 · 30K→5D",
                        zhHant: "無盡衝關 · 30K→5D"
                    ))
                        .font(AppFont.rounded(size: 13, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(best > 0
                         ? l10n.localized(
                             zh: "纪录：\(best)题 (\(appState.puzzleProgress.bestPuzzleRushRank))",
                             en: "Best: \(best) (\(appState.puzzleProgress.bestPuzzleRushRank))",
                             ja: "記録：\(best)問 (\(appState.puzzleProgress.bestPuzzleRushRank))",
                             ko: "기록: \(best)문제 (\(appState.puzzleProgress.bestPuzzleRushRank))",
                             zhHant: "紀錄：\(best)題 (\(appState.puzzleProgress.bestPuzzleRushRank))"
                         )
                         : l10n.localized(
                             zh: "3颗心测真实上限！",
                             en: "3 ❤️ Test Your Limit!",
                             ja: "ハート3つで限界に挑戦！",
                             ko: "하트 3개로 한계 도전!",
                             zhHant: "3顆心測真實上限！"
                         ))
                        .font(AppFont.rounded(size: 10.5, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 15)
            .padding(.vertical, 7)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 2.5, whiteBorderWidth: 2.5))
    }

    // MARK: - Placement Level Picker Sheet

    private func placementSelectionSheet(scrollProxy: ScrollViewProxy) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("🧭").font(AppFont.rounded(size: 48, weight: .regular))
                    Text(l10n.localized(
                        zh: "选择你当前的围棋水平",
                        en: "Choose Your Starting Go Level",
                        ja: "現在の囲碁レベルを選択",
                        ko: "현재 바둑 실력을 선택하세요",
                        zhHant: "選擇你當前的圍棋水平"
                    ))
                        .font(AppFont.rounded(size: 22, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(l10n.localized(
                        zh: "选定后立刻飞往对应海域起航！前面的基础海域也会保留开放，随时可以回去刷星拿皇冠。",
                        en: "Fly straight to the Sea that matches your real strength! Earlier Seas stay open for bonus stars anytime.",
                        ja: "選択するとすぐに対応する海域へ移動します！前の基礎海域も開放されたままなので、いつでも星や王冠を集めに戻れます。",
                        ko: "선택하면 실력에 맞는 해역으로 바로 이동합니다! 이전 기초 해역도 계속 열려 있어 언제든 별과 왕관을 모을 수 있어요.",
                        zhHant: "選定後立刻飛往對應海域起航！前面的基礎海域也會保留開放，隨時可以回去刷星拿皇冠。"
                    ))
                        .font(AppFont.rounded(size: 13.5, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)

                    ForEach(StarYiCampaign.placementOptions) { opt in
                        Button {
                            appState.applyPlacementChoice(opt)
                            showPlacementSheet = false
                            SoundAndHapticsManager.shared.playSuccess()
                            if let sea = StarYiCampaign.sea(withId: opt.targetSeaId) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                    flyToSea(sea, scrollProxy: scrollProxy)
                                }
                            }
                        } label: {
                            HStack(spacing: 14) {
                                Text(opt.emoji).font(AppFont.rounded(size: 32, weight: .regular))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(localizedPlacementTitle(opt))
                                            .font(AppFont.rounded(size: 16, weight: .black))
                                            .foregroundColor(AppTheme.inkPrimary)
                                        Text(opt.rankLabel)
                                            .font(AppFont.rounded(size: 11.5, weight: .black))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(AppTheme.skyBottom))
                                    }
                                    Text(localizedPlacementDesc(opt))
                                        .font(AppFont.rounded(size: 12.5, weight: .semibold))
                                        .foregroundColor(AppTheme.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .black, design: .rounded))
                                    .foregroundColor(AppTheme.skyBottom)
                            }
                            .padding(16)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 24, rimHeight: 2.5, whiteBorderWidth: 2.5, pressStyle: .card))
                    }
                }
                .padding(20)
            }
            .background(AppTheme.brightArenaBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l10n.t("common.cancel")) {
                        showPlacementSheet = false
                    }
                }
            }
        }
    }

    private func localizedPlacementTitle(_ opt: PlacementOption) -> String {
        switch opt.id {
        case "pl-30k":
            return l10n.localized(zh: opt.titleZh, en: opt.titleEn, ja: "囲碁ビギナー入門", ko: "바둑 입문 초보", zhHant: "萌新啟蒙")
        case "pl-18k":
            return l10n.localized(zh: opt.titleZh, en: opt.titleEn, ja: "石取りステップアップ（約15K）", ko: "따내기 중급 (약 15K)", zhHant: "吃子進階（約15K）")
        case "pl-10k":
            return l10n.localized(zh: opt.titleZh, en: opt.titleEn, ja: "中級・級位者（14K–8K）", ko: "급수 실력자 (14K–8K)", zhHant: "級位高手（14K–8K）")
        case "pl-5k":
            return l10n.localized(zh: opt.titleZh, en: opt.titleEn, ja: "上級・初段目前（7K–1K）", ko: "고급·단위 준비 (7K–1K)", zhHant: "高段預備（7K–1K）")
        case "pl-1d":
            return l10n.localized(zh: opt.titleZh, en: opt.titleEn, ja: "有段者チャレンジ（1D–5D+）", ko: "아마추어 유단자 (1D–5D+)", zhHant: "業餘段位煉獄")
        default:
            return l10n.localized(zh: opt.titleZh, en: opt.titleEn)
        }
    }

    private func localizedPlacementDesc(_ opt: PlacementOption) -> String {
        switch opt.id {
        case "pl-30k":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "盤面・呼吸点・石取りを学び、第1海域・風車の草原から楽しくスタート", ko: "바둑판, 활로, 따내기부터 제1해역 바람개비 초원에서 가볍게 시작", zhHant: "剛認識棋盤、氣與提子，從第一區域·風起棋丘輕鬆起步")
        case "pl-18k":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "両アタリやシチョウが分かる方は、第2海域・翡翠の森へ直行！", ko: "양단수와 축을 알고 있다면 제2해역 비취 숲으로 바로 이동!", zhHant: "已會雙打吃與征子，直接飛往第二區域·翡翠森林")
        case "pl-10k":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "詰碁や攻め合いに慣れている方は、第3海域・双月の鏡湖へ！", ko: "사활과 수상전에 익숙하다면 제3해역 쌍월 거울호수으로!", zhHant: "熟悉死活與對殺，直奔第三區域·雙月鏡湖")
        case "pl-5k":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "有段を目指す実力者は、第4海域・白銀雪山へ挑戦！", ko: "아마추어 단위에 도전한다면 제4해역 백은 설산으로!", zhHant: "衝刺業餘段位，直闖第四區域·凜冬雪山")
        case "pl-1d":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "19路盤の定石と深い読みに精通する有段者は、第5海域・紅蓮火山へ！", ko: "19줄 정석과 정밀한 수읽기에 능통하다면 제5해역 용암 화산 최종 시련으로!", zhHant: "精通19路定式與精算，直闖第五區域·熔岩火山終極試煉")
        default:
            return l10n.localized(zh: opt.descZh, en: opt.descEn)
        }
    }

    // MARK: - Locked Feedback Toast & Mistake Drawer

    private func triggerLockedFeedback(islandId: String, message: String) {
        SoundAndHapticsManager.shared.playLockedDoor()
        SoundAndHapticsManager.shared.playVoice(.locked, delay: 0.08, cooldown: 2.0)
        if !reduceMotion {
            withAnimation(.easeInOut(duration: 0.25)) {
                shakeCounters[islandId, default: 0] += 2
            }
        }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            lockedToastMessage = message
        }
        toastDismissTask?.cancel()
        toastDismissTask = Task {
            try? await Task.sleep(nanoseconds: 2_600_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) {
                    lockedToastMessage = nil
                }
            }
        }
    }

    private func lockedToastPill(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(red: 0.46, green: 0.51, blue: 0.59)))
            Text(message)
                .font(AppFont.rounded(size: 14.5, weight: .heavy))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: Color.black.opacity(0.20), radius: 14, y: 6))
        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
    }
}

/// Bridges SwiftUI's ScrollView programmatic navigation cleanly across iOS 18+ (`ScrollPosition`)
/// and iOS 17 (`scrollPosition(id:)`), ensuring edge buttons and compass tabs always scroll the map.
private struct CampaignSeaScrollPositionModifier: ViewModifier {
    @Binding var scrolledSeaId: String?
    let scrollNonce: Int
    let targetX: CGFloat
    let animated: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.modifier(
                SeaScrollPositionBridge(
                    scrolledSeaId: $scrolledSeaId,
                    scrollNonce: scrollNonce,
                    targetX: targetX,
                    animated: animated
                )
            )
        } else {
            content.scrollPosition(id: $scrolledSeaId, anchor: .leading)
        }
    }
}

@available(iOS 18.0, *)
private struct SeaScrollPositionBridge: ViewModifier {
    @Binding var scrolledSeaId: String?
    let scrollNonce: Int
    let targetX: CGFloat
    let animated: Bool

    @State private var position = ScrollPosition(idType: String.self)

    func body(content: Content) -> some View {
        content
            .scrollPosition($position, anchor: .leading)
            .onAppear {
                position.scrollTo(x: targetX)
            }
            .onChange(of: position.viewID(type: String.self)) { _, newID in
                if let newID, newID != scrolledSeaId {
                    scrolledSeaId = newID
                }
            }
            .onChange(of: scrollNonce) { _, _ in
                if animated {
                    withAnimation(.spring(response: 0.54, dampingFraction: 0.84)) {
                        position.scrollTo(x: targetX)
                    }
                } else {
                    position.scrollTo(x: targetX)
                }
            }
    }
}

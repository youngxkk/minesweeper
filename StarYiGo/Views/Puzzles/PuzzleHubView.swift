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
    @State private var programmaticScrollNonce: Int = 0
    @State private var programmaticScrollAnimated: Bool = true
    @State private var hasInitializedScroll: Bool = false
    @State private var showMistakesDrawer: Bool = false
    @State private var showPlacementSheet: Bool = false
    @State private var activePulse: Bool = false
    @State private var flightBob: Bool = false
    @State private var newlyUnlockedIslandIDs: Set<String> = []
    @State private var shakeCounters: [String: CGFloat] = [:]
    @State private var lockedToastMessage: String?
    @State private var toastDismissTask: Task<Void, Never>?

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

    private var mistakePuzzles: [GoPuzzle] {
        appState.puzzleProgress.mistakeBookIds.compactMap { appState.findAnyPuzzle(withId: $0) }
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
                                // Sailing and cross-sea flight routes
                                Canvas { context, _ in
                                    let progress = appState.puzzleProgress
                                    let allIslands = StarYiCampaign.allIslands

                                    for (source, destination) in zip(allIslands, allIslands.dropFirst()) {
                                        let isCrossSea = (source.seaId != destination.seaId)
                                        let isOpen = StarYiCampaign.unlockState(for: destination, progress: progress).isUnlocked
                                        let route = worldRoute(from: source, to: destination, pageW: pageW, pageH: pageH)

                                        if isCrossSea {
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
                                            let dash: [CGFloat] = isOpen ? [] : [5, 12]
                                            context.stroke(
                                                route,
                                                with: .color(isOpen ? AppTheme.sunRim.opacity(0.70) : AppTheme.inkPrimary.opacity(0.52)),
                                                style: StrokeStyle(lineWidth: isOpen ? 7 : 5.5, lineCap: .round, dash: dash)
                                            )
                                            context.stroke(
                                                route,
                                                with: .color(isOpen ? Color(red: 1, green: 0.93, blue: 0.67) : .white.opacity(0.92)),
                                                style: StrokeStyle(lineWidth: isOpen ? 4.5 : 3, lineCap: .round, dash: dash)
                                            )
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

                                // Full-island elliptical hit zones covering the entire illustrated island artwork
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

                                // Interactive island pins
                                ForEach(StarYiCampaign.allIslands) { island in
                                    islandMapPin(island)
                                        .phaseAnimator([0, 1, 2], trigger: newlyUnlockedIslandIDs.contains(island.id)) { pin, phase in
                                            pin.scaleEffect(!reduceMotion && phase == 1 ? 1.13 : 1)
                                        } animation: { _ in
                                            .spring(response: 0.29, dampingFraction: 0.72)
                                        }
                                        .scaleEffect(pageH < 470 ? 0.78 : 1)
                                        .position(worldPoint(for: island, pageW: pageW, pageH: pageH))
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
                }
                .ignoresSafeArea()

                // MARK: - Floating Left / Right "Fly to Previous / Next Sea" Edge Portals
                HStack {
                    if activeSeaIndex > 0 {
                        edgeFlyButton(targetSea: seas[activeSeaIndex - 1], direction: .previous, scrollProxy: scrollProxy)
                            .padding(.leading, 12)
                    }
                    Spacer()
                    if activeSeaIndex + 1 < seas.count {
                        edgeFlyButton(targetSea: seas[activeSeaIndex + 1], direction: .next, scrollProxy: scrollProxy)
                            .padding(.trailing, 12)
                    }
                }
                .allowsHitTesting(true)

                // MARK: - Top HUD & Bottom Adventure Dock
                VStack(spacing: verticalSizeClass == .compact ? 4 : 8) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, verticalSizeClass == .compact ? 8 : 12)

                    seaCompassStrip(scrollProxy: scrollProxy)
                        .padding(.horizontal, 20)

                    Spacer()

                    if showMistakesDrawer {
                        mistakesDock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if let toast = lockedToastMessage {
                        lockedToastPill(toast)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else if !isSeaUnlocked {
                        lockedSeaSkipGateDock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    } else {
                        bottomAdventureDock
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showPlacementSheet) {
                placementSelectionSheet(scrollProxy: scrollProxy)
            }
            .onAppear {
                if initialMistakesOnly {
                    showMistakesDrawer = true
                }
                let freshUnlocks = appState.consumeIslandUnlocks()
                newlyUnlockedIslandIDs.formUnion(freshUnlocks)
                if !hasInitializedScroll {
                    hasInitializedScroll = true
                    if let highestUnlocked = seas.last(where: { StarYiCampaign.isSeaUnlocked($0, progress: appState.puzzleProgress) }) {
                        scrolledSeaId = highestUnlocked.id
                        programmaticScrollAnimated = false
                        programmaticScrollNonce += 1
                        scrollProxy.scrollTo(highestUnlocked.id, anchor: .leading)
                    }
                } else if let newlyUnlockedSeaId = freshUnlocks
                    .compactMap({ StarYiCampaign.island(withId: $0)?.seaId })
                    .first(where: { $0 != scrolledSeaId }) {
                    scrolledSeaId = newlyUnlockedSeaId
                    programmaticScrollAnimated = !reduceMotion
                    programmaticScrollNonce += 1
                    scrollProxy.scrollTo(newlyUnlockedSeaId, anchor: .leading)
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
            showMistakesDrawer = false
            lockedToastMessage = nil
        }
    }

    // MARK: - Biome World Artwork & Nintendo Cloud-Bank Transitions

    private func seaMapArtwork(pageW: CGFloat, pageH: CGFloat, totalW: CGFloat) -> some View {
        let art = seaArtSize(pageW: pageW, pageH: pageH)
        let gap = seaGapW(pageW: pageW, pageH: pageH)
        let slotW = pageW + gap
        let cloudBankW = max(240, pageW * 0.36)

        return ZStack(alignment: .leading) {
            // 1. Each biome fills its full page slot with a matching ambient extension + razor-sharp 2400×1792 diorama centerpiece.
            ForEach(seas) { sea in
                let centerX = seaOriginX(sea.index, pageW: pageW, pageH: pageH) + pageW / 2
                ZStack {
                    Image(sea.mapImageName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: slotW + 24, height: pageH + 24)
                        .blur(radius: 18)
                        .scaleEffect(1.06)
                        .clipped()

                    Image(sea.mapImageName)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: art.width, height: art.height)
                        .mask { seaArtEdgeFade(from: .leading, to: .trailing) }
                        .mask { seaArtEdgeFade(from: .top, to: .bottom) }
                }
                .frame(width: slotW, height: pageH)
                .clipped()
                .position(x: centerX, y: pageH / 2)
            }

            // 2. ~1/3-screen-wide Nintendo fluffy 3D cloud banks seamlessly bridging each adjacent biome!
            ForEach(0..<max(0, seas.count - 1), id: \.self) { idx in
                cloudSeamBank(seamIndex: idx, width: cloudBankW, height: pageH)
                    .position(
                        x: straitCenterX(beforeSea: idx + 1, pageW: pageW, pageH: pageH),
                        y: pageH / 2
                    )
            }
        }
        .frame(width: totalW, height: pageH)
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func cloudSeamBank(seamIndex: Int, width: CGFloat, height: CGFloat) -> some View {
        let undersideTint: Color = {
            switch seamIndex {
            case 0: return Color(red: 0.78, green: 0.90, blue: 0.98) // Island -> Forest: airy sky tint
            case 1: return Color(red: 0.98, green: 0.92, blue: 0.80) // Forest -> Desert: warm sunlit cream
            case 2: return Color(red: 0.82, green: 0.92, blue: 1.00) // Desert -> Snow: crisp alpine blue
            default: return Color(red: 0.96, green: 0.82, blue: 0.76) // Snow -> Volcano: ember-kissed dusk
            }
        }()

        let drift: CGFloat = reduceMotion ? 0 : (flightBob ? -5 : 5)

        return ZStack {
            // Soft full-height mist veil that completely erases the biome boundary
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Color.white.opacity(0.45), location: 0.16),
                    .init(color: Color.white.opacity(0.92), location: 0.36),
                    .init(color: Color.white.opacity(0.96), location: 0.50),
                    .init(color: Color.white.opacity(0.92), location: 0.64),
                    .init(color: Color.white.opacity(0.45), location: 0.84),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            // Layered vector Nintendo cloud puffs (infinitely sharp on Retina iPad Pro!)
            Canvas { context, size in
                let w = size.width
                let h = size.height
                let puffCount = 11

                // Layer A: Outer soft-edge puffs (gives organic wavy cloud silhouette on both sides)
                for i in 0..<puffCount {
                    let t = CGFloat(i) / CGFloat(puffCount - 1)
                    let y = t * h
                    let wave = sin(Double(i) * 1.65 + Double(seamIndex) * 1.1)
                    let leftX = w * (0.28 + 0.08 * CGFloat(wave))
                    let rightX = w * (0.72 - 0.08 * CGFloat(cos(Double(i) * 1.4 + Double(seamIndex))))
                    let rOuter = max(w * 0.23, h * 0.095)

                    let leftRect = CGRect(x: leftX - rOuter, y: y - rOuter, width: rOuter * 2, height: rOuter * 2)
                    let rightRect = CGRect(x: rightX - rOuter, y: y - rOuter, width: rOuter * 2, height: rOuter * 2)
                    context.fill(Path(ellipseIn: leftRect), with: .color(undersideTint.opacity(0.58)))
                    context.fill(Path(ellipseIn: rightRect), with: .color(undersideTint.opacity(0.58)))
                }

                // Layer B: Shaded volumetric cloud undersides
                for i in 0..<(puffCount + 2) {
                    let t = (CGFloat(i) - 0.5) / CGFloat(puffCount)
                    let y = t * h + 10
                    let xJitter = CGFloat(sin(Double(i) * 2.1 + Double(seamIndex) * 0.7)) * w * 0.14
                    let cx = w * 0.50 + xJitter
                    let rx = max(w * 0.25, h * 0.105)
                    let ry = rx * 0.88
                    let rect = CGRect(x: cx - rx, y: y - ry, width: rx * 2, height: ry * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(undersideTint.opacity(0.88)))
                }

                // Layer C: Bright sunlit pure-white Nintendo cloud crests
                for i in 0..<(puffCount + 2) {
                    let t = (CGFloat(i) - 0.5) / CGFloat(puffCount)
                    let y = t * h - 3
                    let xJitter = CGFloat(sin(Double(i) * 2.1 + Double(seamIndex) * 0.7)) * w * 0.13
                    let cx = w * 0.50 + xJitter
                    let rx = max(w * 0.22, h * 0.092)
                    let ry = rx * 0.84
                    let rect = CGRect(x: cx - rx, y: y - ry, width: rx * 2, height: ry * 2)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .linearGradient(
                            Gradient(colors: [.white, Color.white.opacity(0.95), undersideTint.opacity(0.35)]),
                            startPoint: CGPoint(x: cx, y: rect.minY),
                            endPoint: CGPoint(x: cx, y: rect.maxY)
                        )
                    )
                }

                // Layer D: Center puffy pillow highlights
                for i in 0..<8 {
                    let t = (CGFloat(i) + 0.5) / 8.0
                    let y = t * h
                    let xOff = CGFloat(cos(Double(i) * 1.9 + Double(seamIndex))) * w * 0.09
                    let cx = w * 0.50 + xOff
                    let r = max(w * 0.16, h * 0.072)
                    let rect = CGRect(x: cx - r, y: y - r, width: r * 2, height: r * 2)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.96)))
                }
            }
            .offset(y: drift)
        }
        .frame(width: width, height: height + 60)
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
                        .font(.system(size: 22))
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
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
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
                            .font(.system(size: 13, weight: .black))
                    }
                    Text(isNext ? (unlocked ? "✈️" : "🔑") : targetSea.emoji)
                        .font(.system(size: 18))
                    if isNext {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .black))
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
                    .font(.system(size: 10.5, weight: .black, design: .rounded))
                    .foregroundColor(isNext ? .white : AppTheme.inkPrimary)

                Text(targetSea.rankRange)
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .foregroundColor(isNext ? .white.opacity(0.92) : AppTheme.skyBottom)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 10)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: pal, cornerRadius: 22, rimHeight: 5, whiteBorderWidth: 3, playTapSound: false))
        .accessibilityIdentifier(isNext ? "FlyNextSeaButton" : "FlyPrevSeaButton")
    }

    // MARK: - Top Bar & Live Syncing Sea Compass Strip

    private var topBar: some View {
        let clearedNodes = StarYiCampaign.totalClearedNodes(progress: appState.puzzleProgress)
        let totalNodes = StarYiCampaign.allNodes.count

        return HStack(spacing: 10) {
            // Reserve the same width on both sides so button labels cannot move the title.
            ZStack(alignment: .leading) {
                topBarActions.hidden().accessibilityHidden(true)
                topBarBackButton
            }

            Spacer(minLength: 0)

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

            Spacer(minLength: 0)

            ZStack(alignment: .trailing) {
                topBarBackButton.hidden().accessibilityHidden(true)
                topBarActions
            }
        }
    }

    private var topBarBackButton: some View {
        GameBackButton(title: l10n.t("common.back")) {
            appState.popRoute()
        }
    }

    private var topBarActions: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    showMistakesDrawer.toggle()
                }
            } label: {
                topBarLabel(
                    l10n.t("home.puzzleCard.mistakes", appState.puzzleProgress.mistakeBookIds.count),
                    systemImage: "bookmark.fill"
                )
                .font(.system(size: 13.5, weight: .black, design: .rounded))
                .foregroundColor(showMistakesDrawer ? .white : AppTheme.coralBottom)
                .padding(.horizontal, 15)
                .padding(.vertical, 10)
            }
            .buttonStyle(
                GlossyCapsuleButtonStyle(
                    palette: showMistakesDrawer ? .coral : .snow,
                    cornerRadius: 999,
                    rimHeight: 5,
                    whiteBorderWidth: 3
                )
            )
        }
    }

    @ViewBuilder
    private func topBarLabel(_ title: String, systemImage: String) -> some View {
        if verticalSizeClass == .compact {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .accessibilityLabel(title)
        } else {
            Label(title, systemImage: systemImage)
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
                        Text(unlocked ? sea.emoji : "🔒").font(.system(size: 12.5))
                        Text(isSelected
                             ? l10n.localized(
                                 zh: "\(shortRegionName(idx)) · \(sea.rankRange)",
                                 en: "Sea \(idx + 1) · \(sea.rankRange)",
                                 ja: "\(shortRegionName(idx)) · \(sea.rankRange)",
                                 ko: "\(shortRegionName(idx)) · \(sea.rankRange)",
                                 zhHant: "\(shortRegionName(idx)) · \(sea.rankRange)"
                             )
                             : sea.rankRange)
                            .font(.system(size: 11.5, weight: .black, design: .rounded))
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
                        .font(.system(size: 9, weight: .black))
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
        case 0: return l10n.localized(zh: "海岛", en: "Islands", ja: "海島", ko: "해섬", zhHant: "海島")
        case 1: return l10n.localized(zh: "森林", en: "Forest", ja: "森", ko: "숲", zhHant: "森林")
        case 2: return l10n.localized(zh: "沙漠", en: "Desert", ja: "砂漠", ko: "사막", zhHant: "沙漠")
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

    /// On-screen size of one sea artwork. The art keeps its true aspect ratio (never cropped
    /// differently per device), so island pins always sit exactly on top of the painted islands.
    private func seaArtSize(pageW: CGFloat, pageH: CGFloat) -> CGSize {
        let heightScale: CGFloat = pageH < 470 ? 0.88 : 1.08
        let h = min(pageH * heightScale, pageW / Self.seaArtAspect)
        return CGSize(width: h * Self.seaArtAspect, height: h)
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

    /// Bounding rect in world coordinates matching the full painted island footprint for each of the 5 slots.
    private func islandHitArea(for island: CampaignIsland, pageW: CGFloat, pageH: CGFloat) -> CGRect {
        let art = seaArtSize(pageW: pageW, pageH: pageH)
        let normCenter: (CGFloat, CGFloat)
        let normSize: (CGFloat, CGFloat)
        switch island.orderInSea {
        case 0:
            normCenter = (0.195, 0.66)
            normSize = (0.29, 0.34)
        case 1:
            normCenter = (0.305, 0.27)
            normSize = (0.29, 0.30)
        case 2:
            normCenter = (0.515, 0.48)
            normSize = (0.31, 0.33)
        case 3:
            normCenter = (0.78, 0.68)
            normSize = (0.30, 0.34)
        default:
            normCenter = (0.795, 0.28)
            normSize = (0.25, 0.33)
        }
        let center = artPoint(sea: seaIndex(for: island), x: normCenter.0, y: normCenter.1, pageW: pageW, pageH: pageH)
        let width = max(110, normSize.0 * art.width)
        let height = max(110, normSize.1 * art.height)
        return CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    private func handleIslandTap(_ island: CampaignIsland) {
        let unlockState = StarYiCampaign.unlockState(for: island, progress: appState.puzzleProgress)
        switch unlockState {
        case .active, .cleared:
            SoundAndHapticsManager.shared.playUITap()
            showMistakesDrawer = false
            appState.navigationPath.append(.islandDetail(islandId: island.id))
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
            let index = seaIndex(for: source)
            let controls: (CGPoint, CGPoint)
            switch (source.orderInSea, destination.orderInSea) {
            case (0, 1):
                controls = (CGPoint(x: 0.34, y: 0.54), CGPoint(x: 0.16, y: 0.43))
            case (1, 2):
                controls = (CGPoint(x: 0.52, y: 0.27), CGPoint(x: 0.40, y: 0.46))
            case (2, 3):
                controls = (CGPoint(x: 0.51, y: 0.73), CGPoint(x: 0.66, y: 0.75))
            case (3, 4):
                controls = (CGPoint(x: 0.95, y: 0.58), CGPoint(x: 0.91, y: 0.39))
            default:
                let midX = (source.mapX + destination.mapX) / 2
                controls = (CGPoint(x: midX, y: source.mapY), CGPoint(x: midX, y: destination.mapY))
            }
            route.addCurve(
                to: end,
                control1: artPoint(sea: index, x: controls.0.x, y: controls.0.y, pageW: pageW, pageH: pageH),
                control2: artPoint(sea: index, x: controls.1.x, y: controls.1.y, pageW: pageW, pageH: pageH)
            )
        }
        return route
    }

    // MARK: - Island Map Pin (Active / Cleared / Locked + SRS Mistake Ghost Badge!)

    @ViewBuilder
    private func islandMapPin(_ island: CampaignIsland) -> some View {
        let cleared = StarYiCampaign.clearedNodeCount(for: island, progress: appState.puzzleProgress)
        let total = island.nodes.count
        let unlockState = StarYiCampaign.unlockState(for: island, progress: appState.puzzleProgress)
        let pal = GlossyPalette.forIsland(island.id)
        let shakeCount = shakeCounters[island.id] ?? 0
        let dueGhosts = StarYiCampaign.dueMistakeGhosts(for: island, progress: appState.puzzleProgress)

        switch unlockState {
        case .active:
            Button {
                handleIslandTap(island)
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(pal.top.opacity(activePulse ? 0.44 : 0.20))
                            .frame(width: activePulse ? 90 : 78, height: activePulse ? 90 : 78)

                        Circle()
                            .stroke(Color.white.opacity(activePulse ? 0.90 : 0.45), lineWidth: 3)
                            .frame(width: activePulse ? 76 : 68, height: activePulse ? 76 : 68)

                        CharacterAvatarView(character: island.boss.difficulty, mood: .greeting, size: 58)

                        if !dueGhosts.isEmpty {
                            ghostBadge(count: dueGhosts.count)
                                .offset(x: 26, y: -22)
                        }
                    }

                    VStack(spacing: 2) {
                        HStack(spacing: 4) {
                            Text(island.localizedName(l10n))
                                .font(.system(size: 13.5, weight: .black, design: .rounded))
                                .foregroundColor(.white)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .black))
                                .foregroundColor(.white.opacity(0.92))
                        }

                        Text(l10n.localized(
                            zh: "\(island.rankRange) · \(cleared)/\(total)关",
                            en: "\(island.rankRange) · \(cleared)/\(total)Q",
                            ja: "\(island.rankRange) · \(cleared)/\(total)関",
                            ko: "\(island.rankRange) · \(cleared)/\(total)관",
                            zhHant: "\(island.rankRange) · \(cleared)/\(total)關"
                        ))
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(.white.opacity(0.95))
                    }
                    .padding(.horizontal, 13)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [pal.top, pal.bottom], startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                            .shadow(color: pal.glow.opacity(0.40), radius: 10, y: 5)
                    )
                }
                .scaleEffect(1.04)
            }
            .buttonStyle(TactileButtonStyle(pressedScale: 0.96, playTapSound: false))
            .accessibilityIdentifier("IslandPin_\(island.id)")

        case .cleared:
            let bossDefeated = StarYiCampaign.isBossDefeated(for: island, progress: appState.puzzleProgress)
            Button {
                handleIslandTap(island)
            } label: {
                VStack(spacing: 5) {
                    ZStack(alignment: .topTrailing) {
                        CharacterAvatarView(character: island.boss.difficulty, mood: bossDefeated ? .cheering : .calm, size: 56)

                        if !dueGhosts.isEmpty {
                            ghostBadge(count: dueGhosts.count)
                                .offset(x: 8, y: -6)
                        } else {
                            Image(systemName: bossDefeated ? "trophy.fill" : "crown.fill")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(
                                    Circle()
                                        .fill(LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom))
                                        .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                                )
                                .offset(x: 6, y: -5)
                        }
                    }

                    VStack(spacing: 1) {
                        Text(island.localizedName(l10n))
                            .font(.system(size: 12.5, weight: .black, design: .rounded))
                            .foregroundColor(AppTheme.inkPrimary)
                        Text(bossDefeated ? "🏆 \(island.rankRange)" : "★ \(cleared)/\(total)")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.sunBottom)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.96))
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 2.5))
                            .shadow(color: Color.black.opacity(0.16), radius: 8, y: 4)
                    )
                }
            }
            .buttonStyle(TactileButtonStyle(pressedScale: 0.96, playTapSound: false))
            .accessibilityIdentifier("IslandPin_\(island.id)")

        case .locked:
            Button {
                handleIslandTap(island)
            } label: {
                VStack(spacing: 5) {
                    ZStack(alignment: .bottomTrailing) {
                        CharacterAvatarView(character: island.boss.difficulty, mood: .calm, size: 52, isLocked: true)

                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.44, green: 0.49, blue: 0.56))
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.92), lineWidth: 2))
                            )
                            .offset(x: 4, y: 4)
                            .modifier(LockedShakeEffect(shakes: shakeCount, amplitude: 3))
                    }

                    VStack(spacing: 1) {
                        Text(island.localizedName(l10n))
                            .font(.system(size: 11.5, weight: .heavy, design: .rounded))
                            .foregroundColor(Color(red: 0.42, green: 0.47, blue: 0.54))
                        Text(island.rankRange)
                            .font(.system(size: 9.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color(red: 0.50, green: 0.55, blue: 0.62))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color(red: 0.86, green: 0.89, blue: 0.93).opacity(0.94))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
                    )
                }
                .scaleEffect(0.92)
            }
            .buttonStyle(TactileButtonStyle(pressedScale: 0.96, playTapSound: false))
            .accessibilityIdentifier("IslandPinLocked_\(island.id)")
        }
    }

    private func ghostBadge(count: Int) -> some View {
        HStack(spacing: 2) {
            Text("👻").font(.system(size: 11))
            Text("\(count)")
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(AppTheme.coralBottom).overlay(Capsule().strokeBorder(.white, lineWidth: 1.5)))
        .shadow(color: AppTheme.coralRim.opacity(0.4), radius: 4, y: 2)
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
                    Text("🔑").font(.system(size: 26))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(compact ? compactTitle : l10n.localized(
                            zh: "开启「\(activeSea.localizedName(l10n))」跳级试炼门",
                            en: "Challenge Skip Gate for \(activeSea.localizedName(l10n))",
                            ja: "「\(activeSea.localizedName(l10n))」飛び級試験に挑戦",
                            ko: "「\(activeSea.localizedName(l10n))」 월반 시험 도전",
                            zhHant: "開啟「\(activeSea.localizedName(l10n))」跳級試煉門"
                        ))
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text(compact ? compactSubtitle : l10n.localized(
                            zh: "水平够强不想从头刷？无辅助答对 4/5 题直接空降本海域！",
                            en: "Strong player? Pass 4/5 exam puzzles to jump straight here!",
                            ja: "実力に自信あり？ヒントなしで5問中4問正解してこの海域へ飛び級！",
                            ko: "실력에 자신 있나요? 힌트 없이 5문제 중 4문제를 맞혀 이 해역으로 바로 점프!",
                            zhHant: "水平夠強不想從頭刷？無輔助答對 4/5 題直接空降本海域！"
                        ))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.94))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, compact ? 8 : 14)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .sun, cornerRadius: 30, rimHeight: 6, whiteBorderWidth: 3.5, showStripeSheen: true))
            .accessibilityIdentifier("CampaignSkipGateButton")

            puzzleRushButton
        }
        .frame(maxWidth: 980)
    }

    private var bottomAdventureDock: some View {
        let solved = StarterBootcamp.solvedCount(progress: appState.puzzleProgress)
        let total = StarterBootcamp.puzzles.count
        let nextLesson = StarterBootcamp.nextUnsolved(progress: appState.puzzleProgress)

        return HStack(spacing: 10) {
            puzzleRushButton

            if activeSeaIndex == 0 {
                Button {
                    appState.navigationPath.append(.puzzlePlay(puzzleId: nextLesson.id, isDailyChallenge: false, isStarterBootcamp: true))
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(LinearGradient(colors: [AppTheme.mintTop, AppTheme.mintBottom], startPoint: .top, endPoint: .bottom)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(l10n.t("islands.starterDock.title")) (\(solved)/\(total))")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                                .foregroundColor(AppTheme.inkPrimary)
                            Text(l10n.localized(zh: "零基础5路启蒙", en: "5×5 Starter", ja: "5路盤・入門", ko: "5줄 바둑 입문", zhHant: "零基礎5路啟蒙"))
                                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.inkSecondary)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }

            Button {
                appState.navigationPath.append(.trainingDojo)
            } label: {
                Label(
                    l10n.localized(
                        zh: "\(DojoPuzzleBank.fullCatalog.count)+道场/定式/考级",
                        en: "\(DojoPuzzleBank.fullCatalog.count)+ Dojo & Exams",
                        ja: "\(DojoPuzzleBank.fullCatalog.count)+ 道場・定石・級位認定",
                        ko: "\(DojoPuzzleBank.fullCatalog.count)+ 도장·정석·급수시험",
                        zhHant: "\(DojoPuzzleBank.fullCatalog.count)+道場/定式/考級"
                    ),
                    systemImage: "rosette"
                )
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(GlossyCapsuleButtonStyle(palette: .grape, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
        }
    }

    private var puzzleRushButton: some View {
        let best = appState.puzzleProgress.bestPuzzleRushScore
        return Button {
            appState.navigationPath.append(.puzzleRush)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
                VStack(alignment: .leading, spacing: 1) {
                    Text(l10n.localized(
                        zh: "无尽冲关 · 30K→5D",
                        en: "Puzzle Rush · 30K→5D",
                        ja: "連続挑戦 · 30K→5D",
                        ko: "연속 도전 · 30K→5D",
                        zhHant: "無盡衝關 · 30K→5D"
                    ))
                        .font(.system(size: 13.5, weight: .black, design: .rounded))
                        .foregroundColor(.white)
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
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundColor(.white.opacity(0.94))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .coral, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3, showStripeSheen: true))
    }

    // MARK: - Placement Level Picker Sheet

    private func placementSelectionSheet(scrollProxy: ScrollViewProxy) -> some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    Text("🧭").font(.system(size: 48))
                    Text(l10n.localized(
                        zh: "选择你当前的围棋水平",
                        en: "Choose Your Starting Go Level",
                        ja: "現在の囲碁レベルを選択",
                        ko: "현재 바둑 실력을 선택하세요",
                        zhHant: "選擇你當前的圍棋水平"
                    ))
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text(l10n.localized(
                        zh: "选定后立刻飞往对应海域起航！前面的基础海域也会保留开放，随时可以回去刷星拿皇冠。",
                        en: "Fly straight to the Sea that matches your real strength! Earlier Seas stay open for bonus stars anytime.",
                        ja: "選択するとすぐに対応する海域へ移動します！前の基礎海域も開放されたままなので、いつでも星や王冠を集めに戻れます。",
                        ko: "선택하면 실력에 맞는 해역으로 바로 이동합니다! 이전 기초 해역도 계속 열려 있어 언제든 별과 왕관을 모을 수 있어요.",
                        zhHant: "選定後立刻飛往對應海域起航！前面的基礎海域也會保留開放，隨時可以回去刷星拿皇冠。"
                    ))
                        .font(.system(size: 13.5, weight: .bold, design: .rounded))
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
                                Text(opt.emoji).font(.system(size: 32))
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 8) {
                                        Text(localizedPlacementTitle(opt))
                                            .font(.system(size: 16, weight: .black, design: .rounded))
                                            .foregroundColor(AppTheme.inkPrimary)
                                        Text(opt.rankLabel)
                                            .font(.system(size: 11.5, weight: .black, design: .rounded))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 3)
                                            .background(Capsule().fill(AppTheme.skyBottom))
                                    }
                                    Text(localizedPlacementDesc(opt))
                                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                        .foregroundColor(AppTheme.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .black))
                                    .foregroundColor(AppTheme.skyBottom)
                            }
                            .padding(16)
                        }
                        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 24, rimHeight: 4, whiteBorderWidth: 2.5, pressStyle: .card))
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
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "盤面・呼吸点・石取りを学び、第1海域・碧の海島から楽しくスタート", ko: "바둑판, 활로, 따내기부터 제1해역 푸른 해섬에서 가볍게 시작", zhHant: "剛認識棋盤、氣與提子，從第一區域·碧藍海島輕鬆起步")
        case "pl-18k":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "両アタリやシチョウが分かる方は、第2海域・翡翠の森へ直行！", ko: "양단수와 축을 알고 있다면 제2해역 비취 숲으로 바로 이동!", zhHant: "已會雙打吃與征子，直接飛往第二區域·翡翠森林")
        case "pl-10k":
            return l10n.localized(zh: opt.descZh, en: opt.descEn, ja: "詰碁や攻め合いに慣れている方は、第3海域・黄金砂漠へ！", ko: "사활과 수상전에 익숙하다면 제3해역 황금 사막으로!", zhHant: "熟悉死活與對殺，直奔第三區域·金色沙漠")
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
            showMistakesDrawer = false
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
                .font(.system(size: 14, weight: .black))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(red: 0.46, green: 0.51, blue: 0.59)))
            Text(message)
                .font(.system(size: 14.5, weight: .heavy, design: .rounded))
                .foregroundColor(AppTheme.inkPrimary)
        }
        .padding(.leading, 10)
        .padding(.trailing, 20)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.white.opacity(0.96)).shadow(color: Color.black.opacity(0.20), radius: 14, y: 6))
        .overlay(Capsule().strokeBorder(.white, lineWidth: 3))
    }

    private var mistakesDock: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(l10n.t("puzzle.category.mistakes"), systemImage: "bookmark.fill")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.coralBottom)
                Spacer()
                GameCircleButton(icon: "xmark", palette: .snow, tint: AppTheme.inkSecondary, size: 36) {
                    withAnimation { showMistakesDrawer = false }
                }
            }

            if mistakePuzzles.isEmpty {
                HStack(spacing: 10) {
                    Text("🌟").font(.system(size: 28))
                    Text(l10n.t("puzzle.mistakes.empty"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.inkSecondary)
                }
                .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(mistakePuzzles.enumerated()), id: \.element.id) { idx, puzzle in
                            mistakePuzzleTile(number: idx + 1, puzzle: puzzle)
                                .frame(width: 196)
                        }
                    }
                }
            }
        }
        .padding(18)
        .warmCard(cornerRadius: 30, padding: 0)
    }

    private func mistakePuzzleTile(number: Int, puzzle: GoPuzzle) -> some View {
        let stars = appState.puzzleProgress.starsByPuzzleId[puzzle.id] ?? 0
        let solved = stars > 0

        return Button {
            appState.navigationPath.append(.puzzlePlay(puzzleId: puzzle.id, isDailyChallenge: false, isStarterBootcamp: false))
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(solved ? AppTheme.mintBottom : AppTheme.coralBottom))
                    Text(puzzle.rankBadge)
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(AppTheme.skyBottom)
                    Spacer()
                }
                Text(puzzle.title(l10n))
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(1)
                HStack(spacing: 3) {
                    ForEach(1...3, id: \.self) { idx in
                        Image(systemName: idx <= stars ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(idx <= stars ? AppTheme.sunBottom : AppTheme.subtleBorder)
                    }
                    Spacer()
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
        }
        .buttonStyle(GlossyCapsuleButtonStyle(palette: .snow, cornerRadius: 22, rimHeight: 5, whiteBorderWidth: 3, pressStyle: .card))
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

//
//  NintendoOverworldComponents.swift
//  StarYi Go — Nintendo-Style Overworld Pedestals, Hero Pawn, Go-Stone Star Roads & Biome Atmosphere
//

import SwiftUI

// MARK: - Smooth Catmull-Rom Path Builder & Sampler

enum OverworldSpline {
    /// Builds a smooth Catmull-Rom spline passing through all control points.
    static func smoothPath(through points: [CGPoint], tension: CGFloat = 0.5) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        guard points.count >= 2 else { return path }
        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]

            let c1 = CGPoint(
                x: p1.x + (p2.x - p0.x) * (tension / 3.0),
                y: p1.y + (p2.y - p0.y) * (tension / 3.0)
            )
            let c2 = CGPoint(
                x: p2.x - (p3.x - p1.x) * (tension / 3.0),
                y: p2.y - (p3.y - p1.y) * (tension / 3.0)
            )
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    /// Samples evenly spaced points along a Catmull-Rom spline for Go-stone stepping pips.
    static func sampledPoints(through points: [CGPoint], spacing: CGFloat, endTrim: CGFloat = 30) -> [CGPoint] {
        guard points.count >= 2 else { return [] }
        // Dense polyline approximation first
        var dense: [CGPoint] = []
        let substeps = 18
        for i in 0..<(points.count - 1) {
            let p0 = points[max(0, i - 1)]
            let p1 = points[i]
            let p2 = points[i + 1]
            let p3 = points[min(points.count - 1, i + 2)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6.0, y: p1.y + (p2.y - p0.y) / 6.0)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6.0, y: p2.y - (p3.y - p1.y) / 6.0)

            for s in 0..<substeps {
                let t = CGFloat(s) / CGFloat(substeps)
                dense.append(cubicPoint(p1, c1, c2, p2, t: t))
            }
        }
        dense.append(points.last!)

        // Compute cumulative arc lengths
        var lengths: [CGFloat] = [0]
        lengths.reserveCapacity(dense.count)
        for i in 1..<dense.count {
            let dx = dense[i].x - dense[i - 1].x
            let dy = dense[i].y - dense[i - 1].y
            lengths.append(lengths[i - 1] + hypot(dx, dy))
        }
        guard let totalLen = lengths.last, totalLen > endTrim * 2 else { return [] }

        let usable = totalLen - endTrim * 2
        let count = max(2, Int(floor(usable / max(12, spacing))))
        let step = usable / CGFloat(count)

        var result: [CGPoint] = []
        result.reserveCapacity(count + 1)
        var cursor = 1
        for k in 0...count {
            let targetDist = endTrim + CGFloat(k) * step
            while cursor < lengths.count - 1 && lengths[cursor] < targetDist {
                cursor += 1
            }
            let prevDist = lengths[cursor - 1]
            let nextDist = lengths[cursor]
            let segLen = max(0.0001, nextDist - prevDist)
            let frac = (targetDist - prevDist) / segLen
            let a = dense[cursor - 1]
            let b = dense[cursor]
            result.append(CGPoint(x: a.x + (b.x - a.x) * frac, y: a.y + (b.y - a.y) * frac))
        }
        return result
    }

    private static func cubicPoint(_ p0: CGPoint, _ c1: CGPoint, _ c2: CGPoint, _ p3: CGPoint, t: CGFloat) -> CGPoint {
        let u = 1 - t
        let tt = t * t
        let uu = u * u
        let uuu = uu * u
        let ttt = tt * t
        let x = uuu * p0.x + 3 * uu * t * c1.x + 3 * u * tt * c2.x + ttt * p3.x
        let y = uuu * p0.y + 3 * uu * t * c1.y + 3 * u * tt * c2.y + ttt * p3.y
        return CGPoint(x: x, y: y)
    }
}

// MARK: - 2.5D Embedded Go-Stone Stage Pedestal

struct GoStonePedestalPin: View {
    let island: CampaignIsland
    let stageCode: String
    let displayName: String
    let unlockState: IslandUnlockState
    let isSelected: Bool
    let isBossDefeated: Bool
    let earnedStars: Int
    let maxStars: Int
    let dueGhostCount: Int
    let palette: GlossyPalette
    let activePulse: Bool
    let shakeCount: CGFloat
    let onTap: () -> Void

    private var starFraction: Int {
        guard maxStars > 0 else { return 0 }
        let ratio = Double(earnedStars) / Double(maxStars)
        if ratio >= 0.90 { return 3 }
        if ratio >= 0.55 { return 2 }
        if earnedStars > 0 { return 1 }
        return 0
    }

    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Grounded perspective contact shadow
                Ellipse()
                    .fill(Color.black.opacity(unlockState == .locked ? 0.24 : 0.34))
                    .frame(width: isSelected ? 82 : 70, height: isSelected ? 34 : 28)
                    .blur(radius: 4)
                    .offset(y: 12)

                // Breathing selection / frontier aura ring (or subtle dashed arcane seal ring when locked)
                if unlockState == .active || isSelected {
                    Ellipse()
                        .stroke(
                            isSelected ? Color.white.opacity(0.95) : palette.top.opacity(activePulse ? 0.92 : 0.40),
                            lineWidth: isSelected ? 3.5 : 2.5
                        )
                        .frame(
                            width: (isSelected ? 86 : 76) + (activePulse ? 8 : 0),
                            height: (isSelected ? 40 : 34) + (activePulse ? 4 : 0)
                        )
                        .offset(y: 4)
                } else if unlockState == .locked {
                    Ellipse()
                        .stroke(
                            Color.white.opacity(0.55),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [4, 5])
                        )
                        .frame(width: 72, height: 36)
                        .offset(y: 4)
                }

                // 2.5D Pedestal Base (3D extruded rim + glossy Go-stone top surface)
                ZStack {
                    // Extruded stone thickness (bottom rim)
                    Ellipse()
                        .fill(rimColor)
                        .frame(width: pedestalWidth, height: pedestalHeight)
                        .offset(y: 6)

                    // White Nintendo candy outline
                    Ellipse()
                        .strokeBorder(
                            unlockState == .locked
                                ? Color(red: 0.86, green: 0.91, blue: 1.0).opacity(0.88)
                                : Color.white.opacity(0.96),
                            lineWidth: isSelected ? 3.2 : 2.4
                        )
                        .background(
                            Ellipse().fill(
                                LinearGradient(
                                    colors: topGradientColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        )
                        .frame(width: pedestalWidth, height: pedestalHeight)

                    // Inner Go-board star-point engraving / specular gleam
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(unlockState == .locked ? 0.26 : 0.42), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .frame(width: pedestalWidth - 12, height: pedestalHeight - 8)
                        .offset(y: -2)

                    // Center icon on the pedestal face
                    pedestalCenterMark
                }
                .modifier(LockedShakeEffect(shakes: shakeCount, amplitude: 3))

                // Cleared Nintendo Flag or Boss Trophy rising from the pedestal
                if unlockState == .cleared {
                    clearedBannerBadge
                        .offset(x: 24, y: -20)
                } else if unlockState == .locked {
                    lockedSealMedallion
                        .offset(x: 23, y: -15)
                }

                // 3-Star arc pips on the front rim for cleared / in-progress stages
                if unlockState != .locked && (earnedStars > 0 || unlockState == .cleared) {
                    HStack(spacing: 2) {
                        ForEach(1...3, id: \.self) { idx in
                            Image(systemName: idx <= starFraction ? "star.fill" : "star")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundColor(idx <= starFraction ? AppTheme.sunTop : Color.white.opacity(0.65))
                                .shadow(color: Color.black.opacity(0.45), radius: 1.5, y: 1)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.46)))
                    .offset(y: 22)
                }

                // Compact stage name plate (subtle & crisp, never bulky)
                stageLabelPill
                    .offset(y: (unlockState != .locked && (earnedStars > 0 || unlockState == .cleared)) ? 40 : 30)

                // Floating SRS Mistake Ghost orbiting nearby
                if dueGhostCount > 0 && unlockState != .locked {
                    HStack(spacing: 2) {
                        Text("👻").font(AppFont.rounded(size: 11, weight: .regular))
                        Text("\(dueGhostCount)")
                            .font(AppFont.rounded(size: 10, weight: .black))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Capsule().fill(AppTheme.coralBottom).overlay(Capsule().strokeBorder(.white, lineWidth: 1.5)))
                    .shadow(color: AppTheme.coralRim.opacity(0.45), radius: 4, y: 2)
                    .offset(x: -28, y: activePulse ? -24 : -18)
                }
            }
            .frame(width: 110, height: 96)
            .contentShape(Rectangle())
            .scaleEffect(isSelected ? 1.08 : (unlockState == .locked ? 0.90 : 1.0))
        }
        .buttonStyle(TactileButtonStyle(pressedScale: 0.93, playTapSound: false))
        .accessibilityLabel("\(stageCode) \(displayName)")
        .accessibilityIdentifier(unlockState == .locked ? "IslandPinLocked_\(island.id)" : "IslandPin_\(island.id)")
    }

    private var pedestalWidth: CGFloat { isSelected ? 68 : 60 }
    private var pedestalHeight: CGFloat { isSelected ? 34 : 30 }

    private var rimColor: Color {
        switch unlockState {
        case .locked: return Color(red: 0.21, green: 0.27, blue: 0.40)
        case .active: return palette.rim
        case .cleared: return isBossDefeated ? AppTheme.sunRim : AppTheme.mintRim
        }
    }

    private var topGradientColors: [Color] {
        switch unlockState {
        case .locked:
            return [Color(red: 0.48, green: 0.56, blue: 0.72), Color(red: 0.30, green: 0.38, blue: 0.54)]
        case .active:
            return [palette.top, palette.bottom]
        case .cleared:
            return isBossDefeated
                ? [AppTheme.sunTop, AppTheme.sunBottom]
                : [AppTheme.mintTop, AppTheme.mintBottom]
        }
    }

    @ViewBuilder
    private var pedestalCenterMark: some View {
        switch unlockState {
        case .locked:
            Text(stageCode)
                .font(AppFont.rounded(size: 11, weight: .black))
                .foregroundColor(Color.white.opacity(0.84))
                .shadow(color: Color.black.opacity(0.32), radius: 1.5, y: 1)
        case .active:
            Text(stageCode)
                .font(AppFont.rounded(size: 12.5, weight: .black))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.30), radius: 1.5, y: 1)
        case .cleared:
            Image(systemName: isBossDefeated ? "crown.fill" : "checkmark")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.28), radius: 1.5, y: 1)
        }
    }

    private var lockedSealMedallion: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.99, green: 0.82, blue: 0.38), Color(red: 0.86, green: 0.56, blue: 0.16)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.28), radius: 4, y: 2)
            Image(systemName: "lock.fill")
                .font(.system(size: 9.5, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private var clearedBannerBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: isBossDefeated ? [AppTheme.sunTop, AppTheme.sunBottom] : [AppTheme.mintTop, AppTheme.mintBottom],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 24, height: 24)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                .shadow(color: Color.black.opacity(0.25), radius: 4, y: 2)
            Image(systemName: isBossDefeated ? "trophy.fill" : "flag.fill")
                .font(.system(size: 10.5, weight: .black, design: .rounded))
                .foregroundColor(.white)
        }
    }

    private var stageLabelPill: some View {
        Text(displayName)
            .font(AppFont.rounded(size: isSelected ? 12 : 10.5, weight: .black))
            .foregroundColor(unlockState == .locked ? Color(red: 0.93, green: 0.96, blue: 1.0) : (isSelected ? .white : AppTheme.inkPrimary))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, isSelected ? 10 : 8)
            .padding(.vertical, isSelected ? 3.5 : 2.5)
            .background(
                Capsule()
                    .fill(
                        unlockState == .locked
                            ? AnyShapeStyle(Color(red: 0.16, green: 0.22, blue: 0.35).opacity(0.76))
                            : (isSelected
                                ? AnyShapeStyle(LinearGradient(colors: [palette.top, palette.bottom], startPoint: .top, endPoint: .bottom))
                                : AnyShapeStyle(Color.white.opacity(0.92)))
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(unlockState == .locked ? 0.62 : 0.95), lineWidth: isSelected ? 2 : 1.2))
            )
            .shadow(color: Color.black.opacity(0.22), radius: 4, y: 2)
    }
}

// MARK: - Nintendo Overworld Hero Pawn (Player Avatar Standing on Active Stage)

struct OverworldHeroPawn: View {
    let bobbing: Bool
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Soft golden halo behind hero
                Circle()
                    .fill(AppTheme.sunTop.opacity(0.32))
                    .frame(width: 56, height: 56)
                    .blur(radius: 4)

                // Expressive StarYi Sprout Hero Mascot
                StarYiMascotView(character: .sprout, size: 46, mood: .happy, showRing: true)
                    .shadow(color: Color.black.opacity(0.28), radius: 6, y: 3)

                // Tiny golden star crown on top of hero pawn
                Image(systemName: "sparkle")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(AppTheme.sunTop)
                    .shadow(color: AppTheme.sunRim.opacity(0.6), radius: 2, y: 1)
                    .offset(x: 16, y: -18)
            }
            .offset(y: (!reduceMotion && bobbing) ? -5 : 1)

            // Cute pointer stem anchoring pawn to pedestal
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9, weight: .black))
                .foregroundColor(.white)
                .shadow(color: Color.black.opacity(0.35), radius: 2, y: 1)
                .offset(y: -2)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Biome-Specific Ambient Atmosphere Particle Overlay

struct BiomeAtmosphereOverlay: View {
    let seaIndex: Int
    let reduceMotion: Bool
    /// Ambient particles only tick for the sea currently on screen; every other sea keeps a
    /// static frame so a covered / off-screen map never burns GPU time.
    var isPaused: Bool = false

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: isPaused)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    drawAtmosphere(context: &context, size: size, time: t)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func drawAtmosphere(context: inout GraphicsContext, size: CGSize, time: TimeInterval) {
        let w = size.width
        let h = size.height
        guard w > 10, h > 10 else { return }

        switch seaIndex {
        case 0:
            // Region 1 (Meadow): drifting warm dandelion seeds & sunlit motes
            for i in 0..<14 {
                let seed = Double(i) * 1.73
                let speed = 0.025 + Double(i % 4) * 0.008
                let px = ((time * speed + seed * 0.37).truncatingRemainder(dividingBy: 1.0)) * w
                let baseY = (0.18 + Double(i % 7) * 0.10) * h
                let py = baseY + sin(time * 1.4 + seed) * 18
                let r = CGFloat(2.5 + Double(i % 3) * 1.2)
                context.fill(
                    Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                    with: .color(Color.white.opacity(0.62))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: px - r * 2, y: py - r * 2, width: r * 4, height: r * 4)),
                    with: .color(Color(red: 1.0, green: 0.96, blue: 0.65).opacity(0.22))
                )
            }
        case 1:
            // Region 2 (Emerald Forest): falling bamboo leaves + golden firefly motes
            for i in 0..<12 {
                let seed = Double(i) * 2.11
                let fall = (time * (0.04 + Double(i % 3) * 0.012) + seed * 0.29).truncatingRemainder(dividingBy: 1.0)
                let px = (0.08 + Double(i) / 12.0 * 0.84) * w + sin(time * 1.1 + seed) * 26
                let py = fall * h
                var leaf = Path()
                leaf.addEllipse(in: CGRect(x: -5, y: -2, width: 10, height: 4))
                var copy = context
                copy.translateBy(x: px, y: py)
                copy.rotate(by: .radians(sin(time * 1.5 + seed) * 0.8 + 0.5))
                copy.fill(leaf, with: .color(Color(red: 0.42, green: 0.86, blue: 0.42).opacity(0.55)))
            }
        case 2:
            // Region 3 (Mirror Lake): exclusive drifting sakura petals + water starlight glints
            for i in 0..<14 {
                let seed = Double(i) * 1.91
                let fall = (time * (0.038 + Double(i % 4) * 0.009) + seed * 0.31).truncatingRemainder(dividingBy: 1.0)
                let px = ((time * 0.022 + Double(i) / 14.0).truncatingRemainder(dividingBy: 1.0)) * w + sin(time * 1.3 + seed) * 18
                let py = fall * h
                var petal = Path()
                petal.addEllipse(in: CGRect(x: -4.5, y: -2.5, width: 9, height: 5))
                var copy = context
                copy.translateBy(x: px, y: py)
                copy.rotate(by: .radians(time * 0.9 + seed))
                copy.fill(petal, with: .color(Color(red: 1.0, green: 0.78, blue: 0.88).opacity(0.75)))
            }
            // Water glints
            for i in 0..<8 {
                let seed = Double(i) * 2.63
                let alpha = max(0, sin(time * 2.2 + seed)) * 0.65
                let gx = (0.14 + Double(i) * 0.10) * w
                let gy = (0.28 + Double(i % 4) * 0.14) * h
                let r: CGFloat = 3.0
                context.fill(Path(ellipseIn: CGRect(x: gx - r, y: gy - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(alpha)))
            }
        case 3:
            // Region 4 (Frost Peak): soft alpine snowflakes
            for i in 0..<20 {
                let seed = Double(i) * 1.57
                let fall = (time * (0.045 + Double(i % 5) * 0.01) + seed * 0.41).truncatingRemainder(dividingBy: 1.0)
                let px = (0.05 + Double(i) / 20.0 * 0.90) * w + sin(time * 1.0 + seed) * 16
                let py = fall * h
                let r = CGFloat(2.0 + Double(i % 3) * 1.1)
                context.fill(
                    Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                    with: .color(Color.white.opacity(0.72))
                )
            }
        default:
            // Region 5 (Volcano Peak): rising molten golden embers
            for i in 0..<18 {
                let seed = Double(i) * 1.83
                let rise = 1.0 - (time * (0.055 + Double(i % 4) * 0.015) + seed * 0.37).truncatingRemainder(dividingBy: 1.0)
                let px = (0.08 + Double(i) / 18.0 * 0.84) * w + sin(time * 1.8 + seed) * 14
                let py = rise * h
                let r = CGFloat(2.2 + Double(i % 3) * 1.0)
                let fade = min(1.0, rise * 1.8) * min(1.0, (1.0 - rise) * 2.5)
                context.fill(
                    Path(ellipseIn: CGRect(x: px - r * 1.8, y: py - r * 1.8, width: r * 3.6, height: r * 3.6)),
                    with: .color(Color(red: 1.0, green: 0.42, blue: 0.10).opacity(0.32 * fade))
                )
                context.fill(
                    Path(ellipseIn: CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)),
                    with: .color(Color(red: 1.0, green: 0.88, blue: 0.40).opacity(0.85 * fade))
                )
            }
        }
    }
}

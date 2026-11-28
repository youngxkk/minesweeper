//
//  SceneBackdrop.swift
//  StarYi Go — Simplified High-Key Nintendo-Style Vector Scene Backdrops
//

import SwiftUI

enum SceneBackdrop: View {
    case seasideRoom, tabletop, morningDojo, termAlbum, recordDesk, bambooPond, playerPassport, paperSettings, mistakeNotebook

    var body: some View {
        SceneBackdropView(kind: self)
    }
}

private struct SceneBackdropView: View {
    let kind: SceneBackdrop
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Group {
            if kind == .bambooPond {
                if reduceTransparency {
                    kind.baseGradient
                } else {
                    ZStack {
                        GeometryReader { geometry in
                            Image("PhotoJudgeBackdrop")
                                .resizable()
                                .scaledToFill()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .clipped()
                                .accessibilityIgnoresInvertColors()
                        }
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                .init(color: Color.clear, location: 0.30),
                                .init(color: Color.clear, location: 0.74),
                                .init(color: Color(red: 0.05, green: 0.25, blue: 0.45).opacity(0.16), location: 1.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
            } else {
                ZStack {
                    kind.baseGradient
                    if !reduceTransparency {
                        kind.ambientLighting
                        kind.patternLayer
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

private extension SceneBackdrop {

    // MARK: - Layer 1: High-Key Pastel Base Gradient (86%–98% Luminance)

    @ViewBuilder
    var baseGradient: some View {
        switch self {
        case .seasideRoom:
            // AI 对弈：清透冰川天蓝竞技台面
            LinearGradient(
                colors: [
                    Color(red: 0.878, green: 0.940, blue: 0.996),
                    Color(red: 0.922, green: 0.964, blue: 1.00),
                    Color(red: 0.860, green: 0.928, blue: 0.992)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .tabletop:
            // 双人同屏：温暖奶油薄荷客厅桌布
            LinearGradient(
                colors: [
                    Color(red: 0.915, green: 0.968, blue: 0.938),
                    Color(red: 0.965, green: 0.985, blue: 0.962),
                    Color(red: 0.890, green: 0.952, blue: 0.918)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .morningDojo:
            // 每日道场：清透浅樱粉和纸底（与主页柔樱粉按钮同色系）
            LinearGradient(
                colors: [
                    Color(red: 0.996, green: 0.948, blue: 0.962),
                    Color(red: 0.994, green: 0.966, blue: 0.974),
                    Color(red: 0.984, green: 0.928, blue: 0.948)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .termAlbum:
            // 招式图鉴：均匀清透的浅天蓝手账纸
            LinearGradient(
                colors: [
                    Color(red: 0.845, green: 0.926, blue: 0.995),
                    Color(red: 0.888, green: 0.950, blue: 0.998),
                    Color(red: 0.838, green: 0.920, blue: 0.992)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .recordDesk:
            // 棋谱书院 / 复盘馆：星光薰衣草回放馆
            LinearGradient(
                colors: [
                    Color(red: 0.938, green: 0.922, blue: 0.995),
                    Color(red: 0.968, green: 0.960, blue: 1.00),
                    Color(red: 0.912, green: 0.896, blue: 0.985)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .bambooPond:
            // 拍照判胜负：清晨竹影玉露柔光底
            LinearGradient(
                colors: [
                    Color(red: 0.905, green: 0.965, blue: 0.938),
                    Color(red: 0.955, green: 0.985, blue: 0.968),
                    Color(red: 0.885, green: 0.952, blue: 0.922)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .playerPassport:
            // 围棋航海护照：清透浅海碧蓝精装护照内页
            LinearGradient(
                colors: [
                    Color(red: 0.845, green: 0.938, blue: 0.968),
                    Color(red: 0.894, green: 0.958, blue: 0.978),
                    Color(red: 0.832, green: 0.926, blue: 0.958)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        case .paperSettings:
            // 设置：Switch 云白浅蓝灰
            LinearGradient(
                colors: [
                    Color(red: 0.942, green: 0.960, blue: 0.982),
                    Color(red: 0.968, green: 0.976, blue: 0.990)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

        case .mistakeNotebook:
            // 错题本：温润奶油杏色精装错题手账纸
            LinearGradient(
                colors: [
                    Color(red: 0.992, green: 0.958, blue: 0.902),
                    Color(red: 0.996, green: 0.974, blue: 0.935),
                    Color(red: 0.984, green: 0.940, blue: 0.874)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: - Layer 2: Soft Ambient Sunlit Spotlight & Edge Depth

    @ViewBuilder
    var ambientLighting: some View {
        switch self {
        case .seasideRoom:
            ZStack {
                // Soft center spotlight framing the Go board cleanly (no uneven corner blotches)
                RadialGradient(
                    colors: [Color.white.opacity(0.46), Color.white.opacity(0)],
                    center: UnitPoint(x: 0.50, y: 0.48),
                    startRadius: 30,
                    endRadius: 540
                )
            }

        case .tabletop:
            ZStack {
                // Warm tabletop center glow for face-to-face play
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.99, blue: 0.95).opacity(0.70), Color.clear],
                    center: UnitPoint(x: 0.50, y: 0.50),
                    startRadius: 20,
                    endRadius: 520
                )
                RadialGradient(
                    colors: [AppTheme.mintTop.opacity(0.11), AppTheme.mintTop.opacity(0)],
                    center: UnitPoint(x: 0.90, y: 0.14),
                    startRadius: 10,
                    endRadius: 380
                )
                RadialGradient(
                    colors: [AppTheme.sunTop.opacity(0.09), AppTheme.sunTop.opacity(0)],
                    center: UnitPoint(x: 0.10, y: 0.88),
                    startRadius: 10,
                    endRadius: 380
                )
            }

        case .morningDojo:
            ZStack {
                // Soft sunlit sakura-pink warmth (even and gentle)
                RadialGradient(
                    colors: [Color.white.opacity(0.50), Color.clear],
                    center: UnitPoint(x: 0.50, y: 0.48),
                    startRadius: 20,
                    endRadius: 520
                )
            }

        case .termAlbum:
            ZStack {
                // Gentle centered light lift only — no uneven corner halos
                RadialGradient(
                    colors: [Color.white.opacity(0.32), Color.clear],
                    center: UnitPoint(x: 0.50, y: 0.48),
                    startRadius: 30,
                    endRadius: 540
                )
            }

        case .recordDesk:
            ZStack {
                RadialGradient(
                    colors: [Color.white.opacity(0.50), Color.clear],
                    center: UnitPoint(x: 0.50, y: 0.50),
                    startRadius: 20,
                    endRadius: 520
                )
                RadialGradient(
                    colors: [AppTheme.grapeTop.opacity(0.11), Color.clear],
                    center: UnitPoint(x: 0.86, y: 0.14),
                    startRadius: 10,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [AppTheme.skyTop.opacity(0.08), Color.clear],
                    center: UnitPoint(x: 0.12, y: 0.88),
                    startRadius: 10,
                    endRadius: 380
                )
            }

        case .bambooPond:
            ZStack {
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.98, blue: 0.88).opacity(0.42), Color.clear],
                    center: UnitPoint(x: 0.16, y: 0.14),
                    startRadius: 10,
                    endRadius: 420
                )
                RadialGradient(
                    colors: [AppTheme.mintBottom.opacity(0.09), Color.clear],
                    center: UnitPoint(x: 0.88, y: 0.88),
                    startRadius: 10,
                    endRadius: 380
                )
            }

        case .playerPassport:
            ZStack {
                RadialGradient(
                    colors: [Color.white.opacity(0.32), Color.clear],
                    center: UnitPoint(x: 0.50, y: 0.45),
                    startRadius: 20,
                    endRadius: 520
                )
            }

        case .paperSettings:
            RadialGradient(
                colors: [Color.white.opacity(0.45), Color.clear],
                center: UnitPoint(x: 0.50, y: 0.35),
                startRadius: 10,
                endRadius: 480
            )

        case .mistakeNotebook:
            RadialGradient(
                colors: [Color.white.opacity(0.42), Color.clear],
                center: UnitPoint(x: 0.50, y: 0.45),
                startRadius: 20,
                endRadius: 540
            )
        }
    }

    // MARK: - Layer 3: Ultra-Subtle Nintendo Vector Patterns (3%–7% Opacity)

    @ViewBuilder
    var patternLayer: some View {
        switch self {
        case .seasideRoom:
            // AI 对弈：纯代码「星弈竞技六角蜂巢星阵」+ 交替星芒/棋星节点 + 竞技场细双线边框
            ZStack {
                // Layer A: Embossed hexagonal tactical lattice with subtle StarYi AI star-nodes
                Canvas { context, size in
                    let hexRadius: CGFloat = 34
                    let hexW = hexRadius * sqrt(3) // horizontal center-to-center
                    let rowStep = hexRadius * 1.5  // vertical center-to-center
                    let cols = Int(size.width / hexW) + 3
                    let rows = Int(size.height / rowStep) + 3

                    var hexPaths = Path()
                    var starNodes = Path()
                    var ringNodes = Path()

                    for row in -1...rows {
                        let xOffset: CGFloat = row.isMultiple(of: 2) ? 0 : hexW * 0.5
                        let cy = CGFloat(row) * rowStep
                        for col in -1...cols {
                            let cx = CGFloat(col) * hexW + xOffset

                            // Pointy-top hexagon
                            for i in 0..<6 {
                                let angle = CGFloat(i) * (.pi / 3.0) - (.pi / 6.0)
                                let pt = CGPoint(
                                    x: cx + cos(angle) * hexRadius,
                                    y: cy + sin(angle) * hexRadius
                                )
                                if i == 0 {
                                    hexPaths.move(to: pt)
                                } else {
                                    hexPaths.addLine(to: pt)
                                }
                            }
                            hexPaths.closeSubpath()

                            // Alternating AI StarYi 4-point star & miniature tactical ring at cell centers
                            if (row + col).isMultiple(of: 3) {
                                let arm: CGFloat = 5.2
                                let inner: CGFloat = 1.6
                                starNodes.move(to: CGPoint(x: cx, y: cy - arm))
                                starNodes.addLine(to: CGPoint(x: cx + inner, y: cy - inner))
                                starNodes.addLine(to: CGPoint(x: cx + arm, y: cy))
                                starNodes.addLine(to: CGPoint(x: cx + inner, y: cy + inner))
                                starNodes.addLine(to: CGPoint(x: cx, y: cy + arm))
                                starNodes.addLine(to: CGPoint(x: cx - inner, y: cy + inner))
                                starNodes.addLine(to: CGPoint(x: cx - arm, y: cy))
                                starNodes.addLine(to: CGPoint(x: cx - inner, y: cy - inner))
                                starNodes.closeSubpath()
                            } else if (row + col) % 3 == 1 || (row + col) % 3 == -2 {
                                let r: CGFloat = 2.6
                                ringNodes.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
                            }
                        }
                    }

                    // Dual-pass letterpress emboss (crisp white highlight + cool sky-blue tactical ink)
                    var emboss = context
                    emboss.translateBy(x: 0.8, y: 1.0)
                    emboss.stroke(hexPaths, with: .color(Color.white.opacity(0.55)), lineWidth: 1.1)
                    context.stroke(hexPaths, with: .color(AppTheme.skyBottom.opacity(0.135)), lineWidth: 1.0)

                    context.fill(starNodes, with: .color(AppTheme.skyBottom.opacity(0.16)))
                    context.stroke(ringNodes, with: .color(AppTheme.skyBottom.opacity(0.15)), lineWidth: 1.1)
                }
                .mask(edgeBreathingMask(centerOpacity: 0.32, edgeOpacity: 1.0))

                // Layer B: Crisp championship arena perimeter frame + subtle corner star brackets
                Canvas { context, size in
                    let inset: CGFloat = 16
                    let outerRect = CGRect(
                        x: inset,
                        y: inset,
                        width: max(0, size.width - inset * 2),
                        height: max(0, size.height - inset * 2)
                    )
                    let innerRect = outerRect.insetBy(dx: 5, dy: 5)

                    let outerPath = Path(roundedRect: outerRect, cornerRadius: 26, style: .continuous)
                    let innerPath = Path(roundedRect: innerRect, cornerRadius: 22, style: .continuous)

                    context.stroke(
                        Path(roundedRect: outerRect.offsetBy(dx: 0, dy: 1), cornerRadius: 26, style: .continuous),
                        with: .color(Color.white.opacity(0.58)),
                        lineWidth: 1.4
                    )
                    context.stroke(outerPath, with: .color(AppTheme.skyBottom.opacity(0.15)), lineWidth: 1.3)
                    context.stroke(
                        innerPath,
                        with: .color(AppTheme.skyBottom.opacity(0.09)),
                        style: StrokeStyle(lineWidth: 1.0, lineCap: .round, dash: [6, 7])
                    )
                }
            }

        case .tabletop:
            // 1. 双人同屏：任天堂《世界游戏大全 51》暖翠菱格桌游垫 + 黑白棋子交点 + 手工车缝滚边
            ZStack {
                Canvas { context, size in
                    let step: CGFloat = 56
                    let half = step / 2
                    let bandW: CGFloat = 18
                    let span = size.width + size.height

                    // Layer A: Soft 45° diagonal woven gingham bands
                    let weaveTint = Color(red: 0.14, green: 0.56, blue: 0.38).opacity(0.036)
                    let silkWhite = Color.white.opacity(0.24)
                    var d: CGFloat = -size.height
                    while d < span {
                        var bandA = Path()
                        bandA.move(to: CGPoint(x: d, y: 0))
                        bandA.addLine(to: CGPoint(x: d + bandW, y: 0))
                        bandA.addLine(to: CGPoint(x: d + bandW + size.height, y: size.height))
                        bandA.addLine(to: CGPoint(x: d + size.height, y: size.height))
                        bandA.closeSubpath()
                        context.fill(bandA, with: .color(weaveTint))

                        var bandB = Path()
                        bandB.move(to: CGPoint(x: d, y: size.height))
                        bandB.addLine(to: CGPoint(x: d + bandW, y: size.height))
                        bandB.addLine(to: CGPoint(x: d + bandW + size.height, y: 0))
                        bandB.addLine(to: CGPoint(x: d + size.height, y: 0))
                        bandB.closeSubpath()
                        context.fill(bandB, with: .color(silkWhite))

                        d += step
                    }

                    // Layer B: Fine diamond lattice with 1pt embossed highlight + alternating Go-stone intersection pips
                    var lattice = Path()
                    var latticeHighlight = Path()
                    var diag: CGFloat = -size.height
                    while diag < span {
                        lattice.move(to: CGPoint(x: diag, y: 0))
                        lattice.addLine(to: CGPoint(x: diag + size.height, y: size.height))
                        lattice.move(to: CGPoint(x: diag, y: size.height))
                        lattice.addLine(to: CGPoint(x: diag + size.height, y: 0))

                        latticeHighlight.move(to: CGPoint(x: diag + 1, y: 0))
                        latticeHighlight.addLine(to: CGPoint(x: diag + size.height + 1, y: size.height))
                        diag += step
                    }
                    context.stroke(latticeHighlight, with: .color(Color.white.opacity(0.32)), lineWidth: 1)
                    context.stroke(lattice, with: .color(Color(red: 0.14, green: 0.52, blue: 0.36).opacity(0.055)), lineWidth: 1)

                    // Alternating subtle white-ring & jade-dot Go stones on lattice intersections
                    let cols = Int(size.width / step) + 2
                    let rows = Int(size.height / step) + 2
                    let jadeStone = Color(red: 0.12, green: 0.50, blue: 0.34).opacity(0.075)
                    let whiteStone = Color.white.opacity(0.55)
                    for row in 0...rows {
                        for col in 0...cols {
                            let cx = CGFloat(col) * step + (row.isMultiple(of: 2) ? 0 : half)
                            let cy = CGFloat(row) * half
                            let r: CGFloat = 3.2
                            let rect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
                            if (row + col).isMultiple(of: 2) {
                                context.fill(Path(ellipseIn: rect), with: .color(jadeStone))
                            } else {
                                context.stroke(Path(ellipseIn: rect), with: .color(whiteStone), lineWidth: 1.4)
                            }
                        }
                    }
                }
                .mask(edgeBreathingMask(centerOpacity: 0.24, edgeOpacity: 1.0))

                // Layer C: Nintendo Crafted-World stitched tabletop mat perimeter border
                Canvas { context, size in
                    let inset: CGFloat = 16
                    let matRect = CGRect(x: inset, y: inset, width: max(0, size.width - inset * 2), height: max(0, size.height - inset * 2))
                    let stitchPath = Path(roundedRect: matRect, cornerRadius: 28, style: .continuous)
                    let highlightRect = matRect.offsetBy(dx: 0, dy: 1)
                    let highlightPath = Path(roundedRect: highlightRect, cornerRadius: 28, style: .continuous)

                    let dashStyle = StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [9, 8])
                    context.stroke(highlightPath, with: .color(Color.white.opacity(0.58)), style: dashStyle)
                    context.stroke(stitchPath, with: .color(Color(red: 0.14, green: 0.54, blue: 0.37).opacity(0.16)), style: dashStyle)
                }
            }

        case .morningDojo:
            // 2. 每日道场：晨光和纸 · 日式麻叶星纹 (Asanoha) + 朝阳斜光束 + 枯山水同心波纹
            ZStack {
                // Layer A: Authentic Japanese Asanoha (hemp-leaf) embossed geometric pattern
                Canvas { context, size in
                    let tileW: CGFloat = 68
                    let tileH: CGFloat = tileW * 0.8660254 // sqrt(3)/2
                    let cols = Int(size.width / tileW) + 3
                    let rows = Int(size.height / tileH) + 3

                    var pattern = Path()
                    for row in -1...rows {
                        for col in -1...cols {
                            let xOffset: CGFloat = row.isMultiple(of: 2) ? 0 : tileW / 2
                            let x0 = CGFloat(col) * tileW + xOffset
                            let y0 = CGFloat(row) * tileH

                            // Upward equilateral triangle + internal Asanoha star spokes
                            let a = CGPoint(x: x0, y: y0 + tileH)
                            let b = CGPoint(x: x0 + tileW, y: y0 + tileH)
                            let c = CGPoint(x: x0 + tileW / 2, y: y0)
                            let upCenter = CGPoint(x: (a.x + b.x + c.x) / 3, y: (a.y + b.y + c.y) / 3)
                            addAsanohaTriangle(to: &pattern, p1: a, p2: b, p3: c, center: upCenter)

                            // Downward equilateral triangle + internal Asanoha star spokes
                            let d = CGPoint(x: x0 + tileW * 1.5, y: y0)
                            let downCenter = CGPoint(x: (b.x + c.x + d.x) / 3, y: (b.y + c.y + d.y) / 3)
                            addAsanohaTriangle(to: &pattern, p1: c, p2: d, p3: b, center: downCenter)
                        }
                    }

                    // Dual-pass letterpress emboss (white highlight + soft sakura-pink ink matching Daily Dojo palette)
                    var embossed = context
                    embossed.translateBy(x: 0.8, y: 1.0)
                    embossed.stroke(pattern, with: .color(Color.white.opacity(0.56)), lineWidth: 1.1)
                    context.stroke(pattern, with: .color(Color(red: 0.86, green: 0.40, blue: 0.55).opacity(0.14)), lineWidth: 1.05)
                }
                .mask(edgeBreathingMask(centerOpacity: 0.46, edgeOpacity: 1.0))

                // Layer B & C: Soft morning shoji sunbeams + bottom-right Karesansui concentric Zen arcs
                Canvas { context, size in
                    let beams: [(CGFloat, CGFloat, Double)] = [
                        (0.03, 0.22, 0.34),
                        (0.32, 0.16, 0.24)
                    ]
                    for (startFrac, widthFrac, opacity) in beams {
                        let x0 = size.width * startFrac
                        let bw = size.width * widthFrac
                        let slant = size.height * 0.48
                        var beam = Path()
                        beam.move(to: CGPoint(x: x0, y: 0))
                        beam.addLine(to: CGPoint(x: x0 + bw, y: 0))
                        beam.addLine(to: CGPoint(x: x0 + bw + slant, y: size.height))
                        beam.addLine(to: CGPoint(x: x0 + slant, y: size.height))
                        beam.closeSubpath()
                        context.fill(
                            beam,
                            with: .linearGradient(
                                Gradient(colors: [
                                    Color.white.opacity(opacity),
                                    Color(red: 1.0, green: 0.94, blue: 0.96).opacity(opacity * 0.42),
                                    Color.white.opacity(0.0)
                                ]),
                                startPoint: CGPoint(x: x0, y: 0),
                                endPoint: CGPoint(x: x0 + slant, y: size.height)
                            )
                        )
                    }

                    // Bottom-right Karesansui (枯山水) raked Zen ripples watermark in matching soft sakura pink
                    let zenOrigin = CGPoint(x: size.width * 0.92, y: size.height * 0.90)
                    let zenInk = Color(red: 0.86, green: 0.40, blue: 0.55)
                    for i in 1...7 {
                        let r = CGFloat(i) * 34
                        let arcRect = CGRect(x: zenOrigin.x - r, y: zenOrigin.y - r, width: r * 2, height: r * 2)
                        let alpha = max(0.055, 0.155 - Double(i) * 0.014)
                        context.stroke(
                            Path(ellipseIn: arcRect.offsetBy(dx: 0, dy: 1)),
                            with: .color(Color.white.opacity(0.48)),
                            lineWidth: 1.5
                        )
                        context.stroke(
                            Path(ellipseIn: arcRect),
                            with: .color(zenInk.opacity(alpha)),
                            lineWidth: 1.4
                        )
                    }
                }
            }

        case .termAlbum:
            // 3. 招式图鉴：统一清透的浅蓝点阵手账纹理
            Canvas { context, size in
                let cell: CGFloat = 30
                let cols = Int(size.width / cell) + 1
                let rows = Int(size.height / cell) + 1
                let dotColor = AppTheme.skyBottom.opacity(0.18)
                let hoshiColor = AppTheme.skyBottom.opacity(0.28)
                let highlight = Color.white.opacity(0.58)

                for r in 1...rows {
                    for c in 1...cols {
                        let px = CGFloat(c) * cell
                        let py = CGFloat(r) * cell
                        if r.isMultiple(of: 4) && c.isMultiple(of: 4) {
                            // Delicate star-point cross
                            var cross = Path()
                            cross.move(to: CGPoint(x: px - 4.4, y: py))
                            cross.addLine(to: CGPoint(x: px + 4.4, y: py))
                            cross.move(to: CGPoint(x: px, y: py - 4.4))
                            cross.addLine(to: CGPoint(x: px, y: py + 4.4))
                            context.stroke(cross, with: .color(hoshiColor), lineWidth: 1.4)
                        } else {
                            let hiRect = CGRect(x: px - 1.4, y: py - 0.5, width: 2.8, height: 2.8)
                            context.fill(Path(ellipseIn: hiRect), with: .color(highlight))
                            let dotRect = CGRect(x: px - 1.4, y: py - 1.4, width: 2.8, height: 2.8)
                            context.fill(Path(ellipseIn: dotRect), with: .color(dotColor))
                        }
                    }
                }
            }
            .mask(edgeBreathingMask(centerOpacity: 0.55, edgeOpacity: 1.0))

        case .recordDesk:
            // 4. 棋谱书院 / 复盘馆：星光绫绢 · 青海波 (Seigaiha) + 名局星轨连线 + 藏书阁烫金角花
            ZStack {
                // Layer A: Authentic Seigaiha (overlapping silk wave fans) with dual-pass silk sheen
                Canvas { context, size in
                    let radius: CGFloat = 38
                    let colStep = radius * 2
                    let rowStep = radius * 0.56
                    let cols = Int(size.width / colStep) + 3
                    let rows = Int(size.height / rowStep) + 3
                    let silkInk = AppTheme.grapeBottom.opacity(0.056)
                    let silkHighlight = Color.white.opacity(0.38)

                    var arcs = Path()
                    for row in -1...rows {
                        let xOffset: CGFloat = row.isMultiple(of: 2) ? 0 : radius
                        let cy = CGFloat(row) * rowStep
                        for col in -1...cols {
                            let cx = CGFloat(col) * colStep + xOffset
                            let center = CGPoint(x: cx, y: cy)
                            for ring in 1...3 {
                                let r = radius * CGFloat(ring) / 3.0
                                arcs.move(to: CGPoint(x: cx - r, y: cy))
                                arcs.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                            }
                        }
                    }

                    var hi = context
                    hi.translateBy(x: 0, y: 1.2)
                    hi.stroke(arcs, with: .color(silkHighlight), lineWidth: 1.2)
                    context.stroke(arcs, with: .color(silkInk), lineWidth: 1.0)
                }
                .mask(edgeBreathingMask(centerOpacity: 0.25, edgeOpacity: 1.0))

                // Layer B & C: Master-Game Star-Chart Constellation + Champagne-Gold Library Corner Flourishes
                Canvas { context, size in
                    let goldInk = Color(red: 0.80, green: 0.63, blue: 0.28)
                    let lavenderInk = AppTheme.grapeBottom

                    // Constellation star-chart trails in top-right and bottom-left
                    let constellations: [[CGPoint]] = [
                        [
                            CGPoint(x: size.width * 0.78, y: size.height * 0.14),
                            CGPoint(x: size.width * 0.85, y: size.height * 0.21),
                            CGPoint(x: size.width * 0.92, y: size.height * 0.16),
                            CGPoint(x: size.width * 0.95, y: size.height * 0.28)
                        ],
                        [
                            CGPoint(x: size.width * 0.06, y: size.height * 0.74),
                            CGPoint(x: size.width * 0.12, y: size.height * 0.83),
                            CGPoint(x: size.width * 0.20, y: size.height * 0.88)
                        ]
                    ]
                    for trail in constellations {
                        var line = Path()
                        for (idx, pt) in trail.enumerated() {
                            if idx == 0 { line.move(to: pt) } else { line.addLine(to: pt) }
                        }
                        context.stroke(
                            line,
                            with: .color(goldInk.opacity(0.24)),
                            style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [4, 5])
                        )
                        for (idx, pt) in trail.enumerated() {
                            let starR: CGFloat = idx.isMultiple(of: 2) ? 9.0 : 6.0
                            let star = fourPointStarPath(center: pt, radius: starR, innerRatio: 0.26)
                            context.fill(star, with: .color(idx.isMultiple(of: 2) ? goldInk.opacity(0.32) : lavenderInk.opacity(0.20)))
                        }
                    }

                    // Minimalist Library Corner Flourishes in all 4 corners
                    let inset: CGFloat = 20
                    let arm: CGFloat = 34
                    let corners: [(CGPoint, CGFloat, CGFloat)] = [
                        (CGPoint(x: inset, y: inset), 1, 1),
                        (CGPoint(x: size.width - inset, y: inset), -1, 1),
                        (CGPoint(x: inset, y: size.height - inset), 1, -1),
                        (CGPoint(x: size.width - inset, y: size.height - inset), -1, -1)
                    ]
                    for (origin, dx, dy) in corners {
                        var bracket = Path()
                        bracket.move(to: CGPoint(x: origin.x, y: origin.y + dy * arm))
                        bracket.addLine(to: origin)
                        bracket.addLine(to: CGPoint(x: origin.x + dx * arm, y: origin.y))
                        context.stroke(bracket, with: .color(goldInk.opacity(0.26)), style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))

                        let accentCenter = CGPoint(x: origin.x + dx * 9, y: origin.y + dy * 9)
                        let miniStar = fourPointStarPath(center: accentCenter, radius: 4.5, innerRatio: 0.28)
                        context.fill(miniStar, with: .color(lavenderInk.opacity(0.18)))
                    }
                }
            }

        case .bambooPond:
            Canvas { context, size in
                // Ultra-faint concentric water ripples near bottom-right corner
                let center = CGPoint(x: size.width * 0.88, y: size.height * 0.86)
                for i in 1...5 {
                    let radius = CGFloat(i) * 58
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(
                        Path(ellipseIn: rect),
                        with: .color(AppTheme.mintBottom.opacity(0.048)),
                        lineWidth: 1.5
                    )
                }
            }

        case .playerPassport:
            Canvas { context, size in
                let oceanInk = Color(red: 0.06, green: 0.46, blue: 0.66)

                // Nautical passport-style embossed ocean guilloché wave watermarks
                let waveSpacing: CGFloat = 46
                let amplitude: CGFloat = 7.5
                let wavelength: CGFloat = 144
                var waves = Path()
                var y: CGFloat = 20
                while y < size.height + waveSpacing {
                    waves.move(to: CGPoint(x: 0, y: y))
                    var x: CGFloat = 0
                    while x <= size.width + 16 {
                        let dy = sin((x / wavelength) * .pi * 2) * amplitude
                        waves.addLine(to: CGPoint(x: x, y: y + dy))
                        x += 12
                    }
                    y += waveSpacing
                }
                var waveHighlight = context
                waveHighlight.translateBy(x: 0, y: 1.1)
                waveHighlight.stroke(waves, with: .color(Color.white.opacity(0.48)), lineWidth: 1.2)
                context.stroke(waves, with: .color(oceanInk.opacity(0.145)), lineWidth: 1.1)

                // Crisp nautical compass-rose line-art watermark tucked softly in bottom-right
                let compassCenter = CGPoint(x: size.width * 0.86, y: size.height * 0.82)
                let outerR: CGFloat = min(size.width, size.height) * 0.17
                let innerR = outerR * 0.68
                let compassInk = oceanInk.opacity(0.18)

                context.stroke(
                    Path(ellipseIn: CGRect(x: compassCenter.x - outerR, y: compassCenter.y - outerR, width: outerR * 2, height: outerR * 2)),
                    with: .color(compassInk),
                    lineWidth: 1.6
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: compassCenter.x - innerR, y: compassCenter.y - innerR, width: innerR * 2, height: innerR * 2)),
                    with: .color(oceanInk.opacity(0.13)),
                    lineWidth: 1.1
                )
                let star = fourPointStarPath(center: compassCenter, radius: outerR * 0.92, innerRatio: 0.20)
                context.fill(star, with: .color(oceanInk.opacity(0.06)))
                context.stroke(star, with: .color(compassInk), lineWidth: 1.4)
            }

        case .paperSettings:
            EmptyView()

        case .mistakeNotebook:
            // 错题本：温润手账横格 + 细微坐标网格 + 柔和折角书签水印
            Canvas { context, size in
                let amberInk = Color(red: 0.72, green: 0.48, blue: 0.18)
                let step: CGFloat = 34
                var grid = Path()
                var y: CGFloat = step
                while y < size.height {
                    grid.move(to: CGPoint(x: 0, y: y))
                    grid.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                var x: CGFloat = step
                while x < size.width {
                    grid.move(to: CGPoint(x: x, y: 0))
                    grid.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var hi = context
                hi.translateBy(x: 0, y: 1.0)
                hi.stroke(grid, with: .color(Color.white.opacity(0.48)), lineWidth: 1.0)
                context.stroke(grid, with: .color(amberInk.opacity(0.105)), lineWidth: 0.9)
            }
            .mask(edgeBreathingMask(centerOpacity: 0.48, edgeOpacity: 1.0))
        }
    }

    /// Keeps the center content / Go-board zone luminous & calm while revealing crisp tactile pattern near edges.
    private func edgeBreathingMask(centerOpacity: Double, edgeOpacity: Double) -> some View {
        RadialGradient(
            stops: [
                .init(color: .white.opacity(centerOpacity), location: 0.0),
                .init(color: .white.opacity(centerOpacity + 0.18), location: 0.42),
                .init(color: .white.opacity(edgeOpacity), location: 0.88),
                .init(color: .white.opacity(edgeOpacity), location: 1.0)
            ],
            center: .center,
            startRadius: 40,
            endRadius: 680
        )
    }

    private func addAsanohaTriangle(to path: inout Path, p1: CGPoint, p2: CGPoint, p3: CGPoint, center: CGPoint) {
        path.move(to: p1)
        path.addLine(to: p2)
        path.addLine(to: p3)
        path.closeSubpath()

        path.move(to: center)
        path.addLine(to: p1)
        path.move(to: center)
        path.addLine(to: p2)
        path.move(to: center)
        path.addLine(to: p3)
    }

    private func fourPointStarPath(center: CGPoint, radius: CGFloat, innerRatio: CGFloat = 0.28) -> Path {
        let inner = radius * innerRatio
        var path = Path()
        for i in 0..<8 {
            let angle = (CGFloat(i) * .pi / 4) - (.pi / 2)
            let r = (i % 2 == 0) ? radius : inner
            let pt = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 {
                path.move(to: pt)
            } else {
                path.addLine(to: pt)
            }
        }
        path.closeSubpath()
        return path
    }
}

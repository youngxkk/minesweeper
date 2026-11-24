//
//  PhotoJudgeBackdropView.swift
//  StarYi Go — Dedicated Full-Bleed Sunlit Go Veranda & Bamboo Courtyard Backdrop
//

import SwiftUI

/// Vibrant full-bleed stylized illustration backdrop designed specifically for the Photo Go Judge screen:
/// sunlit turquoise-to-golden sky, fluffy clouds, emerald hills, framing bamboo leaves,
/// and a warm kaya-wood veranda deck with subtle Go stones tucked into the lower corners.
struct PhotoJudgeBackdropView: View {
    var body: some View {
        ZStack {
            // 1. Radiant sunlit sky gradient
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.08, green: 0.56, blue: 0.94), location: 0.0),
                    .init(color: Color(red: 0.22, green: 0.74, blue: 0.96), location: 0.34),
                    .init(color: Color(red: 0.62, green: 0.92, blue: 0.91), location: 0.64),
                    .init(color: Color(red: 0.98, green: 0.95, blue: 0.78), location: 0.84),
                    .init(color: Color(red: 0.88, green: 0.66, blue: 0.36), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 2. Warm golden sun glow in the upper-center sky
            RadialGradient(
                colors: [
                    Color(red: 1.0, green: 0.98, blue: 0.84).opacity(0.65),
                    Color(red: 1.0, green: 0.92, blue: 0.65).opacity(0.22),
                    Color.clear
                ],
                center: UnitPoint(x: 0.52, y: 0.36),
                startRadius: 10,
                endRadius: 420
            )

            // 3. Layered stylized scenery (clouds, hills, bamboo groves, wooden veranda deck, corner Go stones)
            Canvas { ctx, size in
                let w = size.width
                let h = size.height

                // --- Fluffy stylized clouds along upper-left & upper-right ---
                drawCloudCluster(ctx: &ctx, origin: CGPoint(x: w * 0.06, y: h * 0.14), scale: min(w, h) * 0.0022)
                drawCloudCluster(ctx: &ctx, origin: CGPoint(x: w * 0.84, y: h * 0.12), scale: min(w, h) * 0.0024)
                drawCloudCluster(ctx: &ctx, origin: CGPoint(x: w * 0.94, y: h * 0.32), scale: min(w, h) * 0.0016)
                drawCloudCluster(ctx: &ctx, origin: CGPoint(x: w * 0.16, y: h * 0.38), scale: min(w, h) * 0.0014)

                // --- Soft distant turquoise mountains ---
                var farHill = Path()
                farHill.move(to: CGPoint(x: 0, y: h * 0.72))
                farHill.addQuadCurve(to: CGPoint(x: w * 0.38, y: h * 0.62), control: CGPoint(x: w * 0.18, y: h * 0.52))
                farHill.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.66), control: CGPoint(x: w * 0.58, y: h * 0.72))
                farHill.addQuadCurve(to: CGPoint(x: w, y: h * 0.58), control: CGPoint(x: w * 0.90, y: h * 0.56))
                farHill.addLine(to: CGPoint(x: w, y: h))
                farHill.addLine(to: CGPoint(x: 0, y: h))
                farHill.closeSubpath()
                ctx.fill(
                    farHill,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.36, green: 0.80, blue: 0.68).opacity(0.75),
                            Color(red: 0.22, green: 0.66, blue: 0.55).opacity(0.85)
                        ]),
                        startPoint: CGPoint(x: w * 0.5, y: h * 0.52),
                        endPoint: CGPoint(x: w * 0.5, y: h * 0.82)
                    )
                )

                // --- Bright emerald rolling meadow hills ---
                var nearHill = Path()
                nearHill.move(to: CGPoint(x: 0, y: h * 0.66))
                nearHill.addQuadCurve(to: CGPoint(x: w * 0.46, y: h * 0.76), control: CGPoint(x: w * 0.20, y: h * 0.60))
                nearHill.addQuadCurve(to: CGPoint(x: w, y: h * 0.64), control: CGPoint(x: w * 0.78, y: h * 0.82))
                nearHill.addLine(to: CGPoint(x: w, y: h))
                nearHill.addLine(to: CGPoint(x: 0, y: h))
                nearHill.closeSubpath()
                ctx.fill(
                    nearHill,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.48, green: 0.88, blue: 0.38),
                            Color(red: 0.20, green: 0.68, blue: 0.36)
                        ]),
                        startPoint: CGPoint(x: w * 0.5, y: h * 0.60),
                        endPoint: CGPoint(x: w * 0.5, y: h * 0.88)
                    )
                )

                // --- Framing Bamboo Stalks & Leaves (left & right edges) ---
                drawBambooGrove(ctx: &ctx, size: size, isLeft: true)
                drawBambooGrove(ctx: &ctx, size: size, isLeft: false)

                // --- Warm Kaya-Wood Veranda Deck (lower foreground) ---
                let deckTopY = h * 0.76
                let deckRect = CGRect(x: 0, y: deckTopY, width: w, height: h - deckTopY)
                ctx.fill(
                    Path(deckRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.96, green: 0.80, blue: 0.52),
                            Color(red: 0.86, green: 0.62, blue: 0.32),
                            Color(red: 0.72, green: 0.48, blue: 0.22)
                        ]),
                        startPoint: CGPoint(x: w * 0.5, y: deckTopY),
                        endPoint: CGPoint(x: w * 0.5, y: h)
                    )
                )

                // Wooden veranda railing / trim lip
                let trimRect = CGRect(x: 0, y: deckTopY - 6, width: w, height: 10)
                ctx.fill(
                    Path(trimRect),
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 1.0, green: 0.92, blue: 0.74),
                            Color(red: 0.84, green: 0.62, blue: 0.35)
                        ]),
                        startPoint: CGPoint(x: 0, y: trimRect.minY),
                        endPoint: CGPoint(x: 0, y: trimRect.maxY)
                    )
                )

                // Perspective plank seams on the warm wood veranda
                let plankCount = 12
                let vanishX = w * 0.5
                for i in 0...plankCount {
                    let t = CGFloat(i) / CGFloat(plankCount)
                    let topX = w * (0.04 + 0.92 * t)
                    let botX = vanishX + (topX - vanishX) * 1.45
                    var seam = Path()
                    seam.move(to: CGPoint(x: topX, y: deckTopY + 4))
                    seam.addLine(to: CGPoint(x: botX, y: h))
                    ctx.stroke(seam, with: .color(Color(red: 0.45, green: 0.26, blue: 0.08).opacity(0.24)), lineWidth: 1.4)
                }

                // Soft dappled sunlight shadows on the right veranda planks
                for idx in 0..<5 {
                    let cx = w * (0.64 + CGFloat(idx) * 0.08)
                    let cy = deckTopY + (h - deckTopY) * (0.28 + CGFloat(idx % 2) * 0.32)
                    let shadowOval = CGRect(x: cx - 36, y: cy - 10, width: 72, height: 20)
                    ctx.fill(
                        Path(ellipseIn: shadowOval),
                        with: .color(Color(red: 0.32, green: 0.18, blue: 0.05).opacity(0.10))
                    )
                }

                // --- Subtle artistic Go stones tucked into far lower corners ---
                drawDecorativeStone(ctx: &ctx, center: CGPoint(x: w * 0.045, y: h * 0.91), radius: 18, isBlack: true)
                drawDecorativeStone(ctx: &ctx, center: CGPoint(x: w * 0.085, y: h * 0.945), radius: 15, isBlack: false)
                drawDecorativeStone(ctx: &ctx, center: CGPoint(x: w * 0.955, y: h * 0.915), radius: 18, isBlack: false)
                drawDecorativeStone(ctx: &ctx, center: CGPoint(x: w * 0.915, y: h * 0.95), radius: 15, isBlack: true)
            }

            // 4. Cheerful sunlit bokeh sparkles in the sky
            SunlitBokehSparklesOverlay()
                .allowsHitTesting(false)

            // 5. Gentle top/bottom readability polish scrim
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.04, green: 0.22, blue: 0.44).opacity(0.16), location: 0.0),
                    .init(color: Color.clear, location: 0.22),
                    .init(color: Color.clear, location: 0.72),
                    .init(color: Color(red: 0.18, green: 0.10, blue: 0.03).opacity(0.26), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private func drawCloudCluster(ctx: inout GraphicsContext, origin: CGPoint, scale: CGFloat) {
        let s = max(0.7, scale)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [
            (-42 * s, 8 * s, 32 * s),
            (-10 * s, -6 * s, 44 * s),
            (32 * s, 4 * s, 36 * s),
            (60 * s, 14 * s, 26 * s)
        ]
        // Soft sky-tinted underside
        for (dx, dy, r) in puffs {
            let rect = CGRect(x: origin.x + dx - r, y: origin.y + dy - r + 6 * s, width: r * 2, height: r * 1.7)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color(red: 0.78, green: 0.92, blue: 1.0).opacity(0.55)))
        }
        // Bright sunlit cloud tops
        for (dx, dy, r) in puffs {
            let rect = CGRect(x: origin.x + dx - r, y: origin.y + dy - r, width: r * 2, height: r * 1.65)
            ctx.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.88)))
        }
    }

    private func drawBambooGrove(ctx: inout GraphicsContext, size: CGSize, isLeft: Bool) {
        let w = size.width
        let h = size.height
        let baseXs: [CGFloat] = isLeft
            ? [w * 0.015, w * 0.055, w * 0.095]
            : [w * 0.985, w * 0.945, w * 0.905]
        let widths: [CGFloat] = [14, 10, 7]
        let opacities: [Double] = [0.75, 0.52, 0.32]

        for idx in 0..<baseXs.count {
            let x = baseXs[idx]
            let stalkW = widths[idx]
            let lean: CGFloat = (isLeft ? 1 : -1) * CGFloat(idx + 1) * 14
            var stalk = Path()
            stalk.move(to: CGPoint(x: x, y: h * 0.78))
            stalk.addQuadCurve(
                to: CGPoint(x: x + lean, y: -20),
                control: CGPoint(x: x + lean * 0.35, y: h * 0.36)
            )
            ctx.stroke(
                stalk,
                with: .color(Color(red: 0.16, green: 0.56, blue: 0.30).opacity(opacities[idx])),
                style: StrokeStyle(lineWidth: stalkW, lineCap: .round)
            )

            // Stylized bamboo leaf sprigs
            let leafAnchorYs: [CGFloat] = [h * 0.16, h * 0.34, h * 0.52]
            for ay in leafAnchorYs {
                let dir: CGFloat = isLeft ? 1 : -1
                for leafAngle in [-0.42, 0.08, 0.52] {
                    let leafLen: CGFloat = 34 - CGFloat(idx) * 6
                    var leaf = Path()
                    let start = CGPoint(x: x + lean * (1 - ay / h) * 0.7, y: ay)
                    let tip = CGPoint(
                        x: start.x + dir * cos(leafAngle) * leafLen,
                        y: start.y + sin(leafAngle) * leafLen
                    )
                    let ctrl1 = CGPoint(x: (start.x + tip.x) * 0.5, y: (start.y + tip.y) * 0.5 - 8)
                    let ctrl2 = CGPoint(x: (start.x + tip.x) * 0.5, y: (start.y + tip.y) * 0.5 + 8)
                    leaf.move(to: start)
                    leaf.addQuadCurve(to: tip, control: ctrl1)
                    leaf.addQuadCurve(to: start, control: ctrl2)
                    leaf.closeSubpath()
                    ctx.fill(
                        leaf,
                        with: .color(Color(red: 0.24, green: 0.72, blue: 0.36).opacity(opacities[idx] + 0.1))
                    )
                }
            }
        }
    }

    private func drawDecorativeStone(ctx: inout GraphicsContext, center: CGPoint, radius: CGFloat, isBlack: Bool) {
        let shadowRect = CGRect(x: center.x - radius + 2, y: center.y - radius + 4, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: shadowRect), with: .color(Color.black.opacity(0.22)))

        let stoneRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        if isBlack {
            ctx.fill(
                Path(ellipseIn: stoneRect),
                with: .radialGradient(
                    Gradient(colors: [Color(white: 0.34), Color(white: 0.10)]),
                    center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3),
                    startRadius: 1,
                    endRadius: radius * 1.2
                )
            )
        } else {
            ctx.fill(
                Path(ellipseIn: stoneRect),
                with: .radialGradient(
                    Gradient(colors: [Color.white, Color(red: 0.86, green: 0.88, blue: 0.92)]),
                    center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3),
                    startRadius: 1,
                    endRadius: radius * 1.2
                )
            )
        }
    }
}

private struct SunlitBokehSparklesOverlay: View {
    private let dots: [(CGFloat, CGFloat, CGFloat, Double)] = [
        (0.24, 0.22, 14, 0.32),
        (0.38, 0.16, 9, 0.28),
        (0.62, 0.20, 16, 0.30),
        (0.74, 0.34, 11, 0.26),
        (0.46, 0.42, 18, 0.22),
        (0.28, 0.48, 10, 0.24),
        (0.68, 0.50, 12, 0.22)
    ]

    var body: some View {
        Canvas { ctx, size in
            for (nx, ny, radius, opacity) in dots {
                let cx = size.width * nx
                let cy = size.height * ny
                let rect = CGRect(x: cx - radius, y: cy - radius, width: radius * 2, height: radius * 2)
                ctx.fill(
                    Path(ellipseIn: rect),
                    with: .radialGradient(
                        Gradient(colors: [Color.white.opacity(opacity), Color.white.opacity(0)]),
                        center: CGPoint(x: cx, y: cy),
                        startRadius: 0,
                        endRadius: radius
                    )
                )
            }
        }
    }
}

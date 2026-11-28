//
//  GameChrome.swift
//  StarYi Go — Super Mario Party / Nintendo Switch Glossy Capsule UI Kit
//

import SwiftUI

/// Color preset for glossy Nintendo candy-capsule buttons.
struct GlossyPalette {
    let top: Color
    let bottom: Color
    let rim: Color
    let glow: Color

    static let sky = GlossyPalette(top: AppTheme.skyTop, bottom: AppTheme.skyBottom, rim: AppTheme.skyRim, glow: AppTheme.skyBottom)
    static let mint = GlossyPalette(top: AppTheme.mintTop, bottom: AppTheme.mintBottom, rim: AppTheme.mintRim, glow: AppTheme.mintBottom)
    static let sun = GlossyPalette(top: AppTheme.sunTop, bottom: AppTheme.sunBottom, rim: AppTheme.sunRim, glow: AppTheme.sunBottom)
    static let coral = GlossyPalette(top: AppTheme.coralTop, bottom: AppTheme.coralBottom, rim: AppTheme.coralRim, glow: AppTheme.coralBottom)
    static let grape = GlossyPalette(top: AppTheme.grapeTop, bottom: AppTheme.grapeBottom, rim: AppTheme.grapeRim, glow: AppTheme.grapeBottom)
    static let snow = GlossyPalette(
        top: Color.white,
        bottom: Color(red: 0.93, green: 0.96, blue: 1.00),
        rim: Color(red: 0.76, green: 0.83, blue: 0.92),
        glow: Color(red: 0.25, green: 0.42, blue: 0.65)
    )
    /// Nintendo-style muted cool stone-gray ("置灰") for locked worlds & locked stages.
    static let locked = GlossyPalette(
        top: Color(red: 0.80, green: 0.83, blue: 0.87),
        bottom: Color(red: 0.66, green: 0.70, blue: 0.76),
        rim: Color(red: 0.50, green: 0.54, blue: 0.61),
        glow: Color(red: 0.44, green: 0.48, blue: 0.55)
    )
    /// Soft matte stone-white surface for locked stage cards (desaturated & low-contrast).
    static let lockedCard = GlossyPalette(
        top: Color(red: 0.90, green: 0.92, blue: 0.95),
        bottom: Color(red: 0.82, green: 0.85, blue: 0.89),
        rim: Color(red: 0.69, green: 0.73, blue: 0.79),
        glow: Color(red: 0.52, green: 0.56, blue: 0.63)
    )

    static func forIsland(_ islandId: String) -> GlossyPalette {
        switch islandId {
        case "bamboo", "s1-reef", "s2-wind", "s3-pine", "s4-mist": return .mint
        case "canyon", "s1-shell", "s2-canyon", "s3-forge", "s4-flame": return .coral
        case "lake", "s1-lagoon", "s2-lake", "s3-river", "s4-azure": return .sky
        case "temple", "s1-harbor", "s2-temple", "s3-pagoda", "s4-citadel": return .sun
        default: return .grape
        }
    }
}

/// Playful Nintendo-style horizontal shake effect when tapping a locked world or locked stage.
struct LockedShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amplitude: CGFloat = 7

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = amplitude * sin(shakes * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

/// Rounded game button with a molded face and a stationary colored base.
struct GlossyCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.minimumButtonFaceHeight) private var minimumHeight

    enum PressStyle {
        case button, homeEntrance, card
    }

    var palette: GlossyPalette
    var cornerRadius: CGFloat = 999 // default true capsule
    var rimHeight: CGFloat = 6
    var whiteBorderWidth: CGFloat = 3.0
    var showStripeSheen: Bool = false
    var playTapSound: Bool = true

    var pressStyle: PressStyle = .button

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let depth: CGFloat = switch pressStyle {
        case .button: rimHeight * 0.85
        case .homeEntrance: min(5, rimHeight * 0.65)
        case .card: max(3, rimHeight * 0.55)
        }
        let travel = pressed && !reduceMotion ? depth : 0
        let release: Animation = switch pressStyle {
        case .button: MotionToken.buttonRelease
        case .homeEntrance: MotionToken.heroRelease
        case .card: MotionToken.cardRelease
        }
        let hapticWeight: UITapWeight = switch pressStyle {
        case .button: .standard
        case .homeEntrance: .heavy
        case .card: .card
        }
        let scaleX: CGFloat = {
            guard pressed && !reduceMotion else { return 1.0 }
            switch pressStyle {
            case .button: return 1.012
            case .homeEntrance: return 0.992
            case .card: return 0.975
            }
        }()
        let scaleY: CGFloat = {
            guard pressed && !reduceMotion else { return 1.0 }
            switch pressStyle {
            case .button: return 0.975
            case .homeEntrance: return 0.985
            case .card: return 0.975
            }
        }()
        let innerScale: CGFloat = {
            guard pressed && !reduceMotion else { return 1.0 }
            switch pressStyle {
            case .button: return 1.0
            case .homeEntrance: return 0.975
            case .card: return 0.985
            }
        }()

        configuration.label
            .scaleEffect(innerScale)
            .animation(
                reduceMotion ? nil : (pressed ? MotionToken.pressDown : MotionToken.innerParallaxRelease),
                value: pressed
            )
            .frame(minHeight: minimumHeight)
            .offset(y: travel)
            .background(
                glossyBodyBackground(pressed: pressed, travel: travel)
                    .allowsHitTesting(false)
            )
            .scaleEffect(x: scaleX, y: scaleY)
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .animation(
                reduceMotion ? nil : (pressed ? MotionToken.pressDown : release),
                value: pressed
            )
            .onChange(of: pressed) { _, isNowPressed in
                if isNowPressed && playTapSound {
                    SoundAndHapticsManager.shared.playUITap(weight: hapticWeight)
                }
            }
            .padding(.bottom, rimHeight)
    }

    @ViewBuilder
    private func glossyBodyBackground(pressed: Bool, travel: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        ZStack {
            // Grounded soft contact shadow tucked naturally beneath the rim
            shape
                .fill(palette.rim)
                .padding(.horizontal, 2)
                .shadow(
                    color: palette.glow.opacity(pressed ? 0.08 : 0.18),
                    radius: pressed ? 1.5 : 4,
                    y: pressed ? 0.5 : 2.5
                )
                .offset(y: rimHeight)

            shape
                .fill(palette.rim)
                .offset(y: rimHeight)

            ZStack {
                shape
                    .fill(
                        LinearGradient(
                            colors: [palette.top, palette.bottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                if showStripeSheen {
                    DiagonalGlossStripes()
                        .fill(Color.white.opacity(0.065))
                        .clipShape(shape)
                }

                shape
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(pressed ? 0.11 : 0.26), location: 0),
                                .init(color: .white.opacity(pressed ? 0.03 : 0.06), location: 0.26),
                                .init(color: .clear, location: 0.52)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                shape
                    .fill(Color.black.opacity(pressed ? 0.045 : 0))

                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(pressed ? 0.65 : 0.82), palette.rim.opacity(0.65)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: whiteBorderWidth * 0.55
                    )
            }
            .offset(y: travel)
        }
    }
}

/// Diagonal texture for the largest entry buttons.
struct DiagonalGlossStripes: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let stripeW: CGFloat = 22
        let gap: CGFloat = 46
        var x: CGFloat = -rect.height
        while x < rect.width + rect.height {
            path.move(to: CGPoint(x: x, y: rect.height))
            path.addLine(to: CGPoint(x: x + stripeW, y: rect.height))
            path.addLine(to: CGPoint(x: x + stripeW + rect.height * 0.65, y: 0))
            path.addLine(to: CGPoint(x: x + rect.height * 0.65, y: 0))
            path.closeSubpath()
            x += gap
        }
        return path
    }
}

/// Backwards-compatible wrapper mapping to the upgraded GlossyCapsuleButtonStyle.
struct GameBevelButtonStyle: ButtonStyle {
    var topColor: Color
    var bottomRimColor: Color
    var cornerRadius: CGFloat = 24
    var rimHeight: CGFloat = 5
    var playTapSound: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        let palette = GlossyPalette(
            top: topColor,
            bottom: topColor.opacity(0.88),
            rim: bottomRimColor,
            glow: bottomRimColor
        )
        return GlossyCapsuleButtonStyle(
            palette: palette,
            cornerRadius: cornerRadius,
            rimHeight: rimHeight,
            whiteBorderWidth: 2.5,
            playTapSound: playTapSound
        ).makeBody(configuration: configuration)
    }
}

/// Glossy light snow-white pill Back Button used consistently across all screens.
struct GameBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 14.5, weight: .black, design: .rounded))
                Text(title)
                    .font(AppFont.rounded(size: 15.5, weight: .heavy))
            }
            .foregroundColor(AppTheme.inkPrimary)
            .padding(.horizontal, 19)
            .padding(.vertical, 10.5)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: .snow,
                cornerRadius: 999,
                rimHeight: 5,
                whiteBorderWidth: 3
            )
        )
    }
}

/// Glossy Candy-Circle Game Icon Button (Settings, Sound, Tabletop Flip, Move Numbers).
struct GameCircleButton: View {
    @Environment(\.minimumButtonFaceHeight) private var minimumHeight
    let icon: String
    var palette: GlossyPalette = .snow
    var tint: Color = AppTheme.inkPrimary
    var size: CGFloat = 46
    var playTapSound: Bool = true
    let action: () -> Void

    var body: some View {
        let diameter = max(size, minimumHeight)
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: max(size * 0.42, diameter * 0.38), weight: .heavy, design: .rounded))
                .foregroundColor(tint)
                .frame(width: diameter, height: diameter)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: palette,
                cornerRadius: diameter / 2,
                rimHeight: 5,
                whiteBorderWidth: 3,
                playTapSound: playTapSound
            )
        )
    }
}

/// Playful glossy Nintendo floating capsule title banner with a unified height across all screens,
/// regardless of whether a subtitle is present.
struct GameTitleCrest: View {
    let title: String
    var subtitle: String? = nil
    var minHeight: CGFloat = AppTheme.titleCrestHeight

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)
                )

            VStack(spacing: 1) {
                Text(title)
                    .font(AppFont.rounded(size: 17, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(AppFont.rounded(size: 11, weight: .bold))
                        .foregroundColor(AppTheme.skyBottom)
                        .lineLimit(1)
                }
            }

            Image(systemName: "star.fill")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [AppTheme.sunTop, AppTheme.sunBottom], startPoint: .top, endPoint: .bottom)
                )
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 6)
        .frame(minHeight: minHeight)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(red: 0.94, green: 0.97, blue: 1.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: AppTheme.skyBottom.opacity(0.16), radius: 12, y: 5)
        )
        .overlay(
            Capsule().strokeBorder(.white, lineWidth: 3)
        )
        .overlay(
            Capsule().strokeBorder(AppTheme.skyTop.opacity(0.28), lineWidth: 1)
        )
    }
}

/// Glossy Toy-Style Go Stone Bowl (`棋笥`) visualizing captured opponent stones piled up!
struct WoodenGoBowlView: View {
    let capturedColor: StoneColor
    let count: Int

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.96, green: 0.72, blue: 0.36),
                            Color(red: 0.72, green: 0.45, blue: 0.16)
                        ],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 28
                    )
                )
                .frame(width: 44, height: 44)
                .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                .shadow(color: Color(red: 0.65, green: 0.40, blue: 0.12).opacity(0.32), radius: 6, y: 3)

            Circle()
                .fill(Color(red: 0.36, green: 0.22, blue: 0.10))
                .frame(width: 32, height: 32)

            let visibleCount = min(count, 7)
            ForEach(0..<visibleCount, id: \.self) { i in
                let angle = Double(i) * 1.15
                let dist: CGFloat = i == 0 ? 0 : 8.5
                Circle()
                    .fill(capturedColor == .black ? Color(white: 0.14) : Color.white)
                    .frame(width: 11, height: 11)
                    .overlay(Circle().stroke(Color.black.opacity(0.25), lineWidth: 0.6))
                    .offset(x: CGFloat(cos(angle)) * dist, y: CGFloat(sin(angle)) * dist)
            }

            if count > 0 {
                Text("\(count)")
                    .font(AppFont.rounded(size: 11, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(LinearGradient(colors: [AppTheme.coralTop, AppTheme.coralBottom], startPoint: .top, endPoint: .bottom))
                            .overlay(Capsule().strokeBorder(.white, lineWidth: 1.5))
                    )
                    .offset(x: 16, y: 16)
            }
        }
        .frame(width: 48, height: 48)
    }
}

/// Bespoke Nintendo-style Illustrated Mascot Portrait for all 6 Go Masters (replaces bare system emojis!).
/// Features character-unique silhouettes, glossy vinyl sticker borders, rosy cheeks, and live mood expressions.
struct CharacterAvatarView: View {
    let character: AIDifficulty
    var mood: CompanionMood = .calm
    var size: CGFloat = 54
    var isLocked: Bool = false

    private var palette: (top: Color, bottom: Color, accent: Color) {
        switch character {
        case .sprout:  return (AppTheme.mintTop, AppTheme.mintBottom, Color(red: 0.78, green: 0.98, blue: 0.62))
        case .rabbit:  return (Color(red: 1.0, green: 0.74, blue: 0.82), Color(red: 0.96, green: 0.45, blue: 0.62), .white)
        case .fox:     return (AppTheme.sunTop, AppTheme.coralBottom, Color(red: 1.0, green: 0.93, blue: 0.80))
        case .deer:    return (Color(red: 0.42, green: 0.86, blue: 0.74), Color(red: 0.08, green: 0.62, blue: 0.56), .white)
        case .panda:   return (AppTheme.skyTop, AppTheme.skyBottom, .white)
        case .crane:   return (Color(red: 0.98, green: 0.84, blue: 0.46), AppTheme.sunBottom, .white)
        case .tiger:   return (Color(red: 1.0, green: 0.66, blue: 0.18), Color(red: 0.88, green: 0.34, blue: 0.10), .white)
        case .dragon:  return (AppTheme.grapeTop, AppTheme.grapeBottom, AppTheme.sunTop)
        case .phoenix: return (Color(red: 1.0, green: 0.36, blue: 0.44), Color(red: 0.76, green: 0.12, blue: 0.34), AppTheme.sunTop)
        case .kirin:   return (Color(red: 0.44, green: 0.58, blue: 1.0), Color(red: 0.32, green: 0.20, blue: 0.86), AppTheme.sunTop)
        }
    }

    var body: some View {
        ZStack {
            // Glossy medallion background
            Circle()
                .fill(
                    LinearGradient(
                        colors: isLocked
                            ? [GlossyPalette.locked.top, GlossyPalette.locked.bottom]
                            : [palette.top, palette.bottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Subtle glossy top sheen
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                )
                .frame(width: size * 0.90, height: size * 0.90)
                .offset(y: -size * 0.04)

            // Bespoke vector-drawn Nintendo toy mascot face
            Canvas { ctx, sz in
                let w = sz.width
                let h = sz.height
                let cx = w * 0.5
                let cy = h * 0.56
                let headR = w * 0.30

                // Character-specific ears / horns / sprout leaves
                switch character {
                case .sprout:
                    // Twin cheerful sprout leaves on top
                    let leftLeaf = Path(ellipseIn: CGRect(x: cx - w * 0.22, y: cy - headR * 1.45, width: w * 0.22, height: w * 0.13))
                    let rightLeaf = Path(ellipseIn: CGRect(x: cx, y: cy - headR * 1.45, width: w * 0.22, height: w * 0.13))
                    ctx.fill(leftLeaf, with: .color(Color(red: 0.45, green: 0.92, blue: 0.42)))
                    ctx.fill(rightLeaf, with: .color(Color(red: 0.24, green: 0.82, blue: 0.34)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR, y: cy - headR, width: headR * 2, height: headR * 1.9)), with: .color(Color(red: 0.96, green: 1.0, blue: 0.86)))

                case .rabbit:
                    // Tall bouncy bunny ears
                    ctx.fill(Path(roundedRect: CGRect(x: cx - w * 0.22, y: h * 0.08, width: w * 0.14, height: h * 0.38), cornerRadius: w * 0.07), with: .color(.white))
                    ctx.fill(Path(roundedRect: CGRect(x: cx + w * 0.08, y: h * 0.08, width: w * 0.14, height: h * 0.38), cornerRadius: w * 0.07), with: .color(.white))
                    ctx.fill(Path(roundedRect: CGRect(x: cx - w * 0.19, y: h * 0.14, width: w * 0.08, height: h * 0.24), cornerRadius: w * 0.04), with: .color(Color(red: 1.0, green: 0.68, blue: 0.78)))
                    ctx.fill(Path(roundedRect: CGRect(x: cx + w * 0.11, y: h * 0.14, width: w * 0.08, height: h * 0.24), cornerRadius: w * 0.04), with: .color(Color(red: 1.0, green: 0.68, blue: 0.78)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR, y: cy - headR * 0.9, width: headR * 2, height: headR * 1.85)), with: .color(.white))

                case .fox:
                    // Pointy clever fox ears
                    var lEar = Path()
                    lEar.move(to: CGPoint(x: cx - headR * 0.95, y: cy - headR * 0.25))
                    lEar.addLine(to: CGPoint(x: cx - headR * 0.85, y: cy - headR * 1.35))
                    lEar.addLine(to: CGPoint(x: cx - headR * 0.15, y: cy - headR * 0.75))
                    lEar.closeSubpath()
                    var rEar = Path()
                    rEar.move(to: CGPoint(x: cx + headR * 0.95, y: cy - headR * 0.25))
                    rEar.addLine(to: CGPoint(x: cx + headR * 0.85, y: cy - headR * 1.35))
                    rEar.addLine(to: CGPoint(x: cx + headR * 0.15, y: cy - headR * 0.75))
                    rEar.closeSubpath()
                    ctx.fill(lEar, with: .color(Color(red: 1.0, green: 0.56, blue: 0.16)))
                    ctx.fill(rEar, with: .color(Color(red: 1.0, green: 0.56, blue: 0.16)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.05, y: cy - headR * 0.85, width: headR * 2.1, height: headR * 1.78)), with: .color(Color(red: 1.0, green: 0.58, blue: 0.18)))
                    // Cream cheeks
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.82, y: cy + headR * 0.02, width: headR * 1.64, height: headR * 0.90)), with: .color(Color(red: 1.0, green: 0.96, blue: 0.88)))

                case .panda:
                    // Round dark panda ears
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.02, y: cy - headR * 1.15, width: headR * 0.70, height: headR * 0.70)), with: .color(AppTheme.inkPrimary))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + headR * 0.32, y: cy - headR * 1.15, width: headR * 0.70, height: headR * 0.70)), with: .color(AppTheme.inkPrimary))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.02, y: cy - headR * 0.88, width: headR * 2.04, height: headR * 1.82)), with: .color(.white))
                    // Cute panda eye patches
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.72, y: cy - headR * 0.28, width: headR * 0.54, height: headR * 0.44)), with: .color(AppTheme.inkPrimary))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + headR * 0.18, y: cy - headR * 0.28, width: headR * 0.54, height: headR * 0.44)), with: .color(AppTheme.inkPrimary))

                case .crane:
                    // Red-crowned crane jewel crest + serene white face
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR, y: cy - headR * 0.92, width: headR * 2, height: headR * 1.86)), with: .color(.white))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.36, y: cy - headR * 1.10, width: headR * 0.72, height: headR * 0.44)), with: .color(AppTheme.coralBottom))

                case .dragon:
                    // Golden Star Dragon horns + royal scales
                    var lHorn = Path()
                    lHorn.move(to: CGPoint(x: cx - headR * 0.65, y: cy - headR * 0.70))
                    lHorn.addLine(to: CGPoint(x: cx - headR * 0.95, y: cy - headR * 1.40))
                    lHorn.addLine(to: CGPoint(x: cx - headR * 0.28, y: cy - headR * 0.90))
                    lHorn.closeSubpath()
                    var rHorn = Path()
                    rHorn.move(to: CGPoint(x: cx + headR * 0.65, y: cy - headR * 0.70))
                    rHorn.addLine(to: CGPoint(x: cx + headR * 0.95, y: cy - headR * 1.40))
                    rHorn.addLine(to: CGPoint(x: cx + headR * 0.28, y: cy - headR * 0.90))
                    rHorn.closeSubpath()
                    ctx.fill(lHorn, with: .color(AppTheme.sunTop))
                    ctx.fill(rHorn, with: .color(AppTheme.sunTop))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.05, y: cy - headR * 0.88, width: headR * 2.1, height: headR * 1.82)), with: .color(Color(red: 0.42, green: 0.86, blue: 0.78)))

                case .deer:
                    // Gentle Jade Antlers + warm fawn face
                    ctx.fill(Path(roundedRect: CGRect(x: cx - headR * 0.72, y: cy - headR * 1.42, width: headR * 0.22, height: headR * 0.65), cornerRadius: headR * 0.1), with: .color(Color(red: 0.68, green: 0.46, blue: 0.26)))
                    ctx.fill(Path(roundedRect: CGRect(x: cx + headR * 0.50, y: cy - headR * 1.42, width: headR * 0.22, height: headR * 0.65), cornerRadius: headR * 0.1), with: .color(Color(red: 0.68, green: 0.46, blue: 0.26)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.0, y: cy - headR * 0.88, width: headR * 2.0, height: headR * 1.85)), with: .color(Color(red: 0.93, green: 0.76, blue: 0.56)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.62, y: cy + headR * 0.08, width: headR * 1.24, height: headR * 0.78)), with: .color(Color(red: 1.0, green: 0.96, blue: 0.88)))

                case .tiger:
                    // Rounded fierce tiger ears + golden striped face
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.02, y: cy - headR * 1.12, width: headR * 0.62, height: headR * 0.62)), with: .color(Color(red: 0.96, green: 0.54, blue: 0.12)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx + headR * 0.40, y: cy - headR * 1.12, width: headR * 0.62, height: headR * 0.62)), with: .color(Color(red: 0.96, green: 0.54, blue: 0.12)))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.05, y: cy - headR * 0.88, width: headR * 2.1, height: headR * 1.84)), with: .color(Color(red: 1.0, green: 0.66, blue: 0.20)))
                    // Signature forehead stripes
                    ctx.fill(Path(roundedRect: CGRect(x: cx - headR * 0.34, y: cy - headR * 0.72, width: headR * 0.68, height: headR * 0.12), cornerRadius: 2), with: .color(AppTheme.inkPrimary))
                    ctx.fill(Path(roundedRect: CGRect(x: cx - headR * 0.24, y: cy - headR * 0.52, width: headR * 0.48, height: headR * 0.10), cornerRadius: 2), with: .color(AppTheme.inkPrimary))

                case .phoenix:
                    // Blazing crimson-gold crest feathers + radiant face
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.48, y: cy - headR * 1.44, width: headR * 0.96, height: headR * 0.76)), with: .color(AppTheme.sunTop))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.26, y: cy - headR * 1.50, width: headR * 0.52, height: headR * 0.66)), with: .color(AppTheme.coralBottom))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.0, y: cy - headR * 0.90, width: headR * 2.0, height: headR * 1.84)), with: .color(Color(red: 1.0, green: 0.94, blue: 0.84)))

                case .kirin:
                    // Celestial single golden horn + luminous starlight mane
                    var cHorn = Path()
                    cHorn.move(to: CGPoint(x: cx - headR * 0.22, y: cy - headR * 0.80))
                    cHorn.addLine(to: CGPoint(x: cx, y: cy - headR * 1.56))
                    cHorn.addLine(to: CGPoint(x: cx + headR * 0.22, y: cy - headR * 0.80))
                    cHorn.closeSubpath()
                    ctx.fill(cHorn, with: .color(AppTheme.sunTop))
                    ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 1.02, y: cy - headR * 0.88, width: headR * 2.04, height: headR * 1.82)), with: .color(Color(red: 0.92, green: 0.95, blue: 1.0)))
                }

                // Rosy Nintendo cheeks
                let blushColor = Color(red: 1.0, green: 0.48, blue: 0.56).opacity(0.45)
                ctx.fill(Path(ellipseIn: CGRect(x: cx - headR * 0.74, y: cy + headR * 0.14, width: headR * 0.34, height: headR * 0.20)), with: .color(blushColor))
                ctx.fill(Path(ellipseIn: CGRect(x: cx + headR * 0.40, y: cy + headR * 0.14, width: headR * 0.34, height: headR * 0.20)), with: .color(blushColor))

                // Expressive eyes adapting to CompanionMood
                let eyeY = cy - headR * 0.08
                let eyeDX = headR * 0.42
                let eyeColor: Color = (character == .panda) ? .white : AppTheme.inkPrimary
                let eyeR = headR * 0.14

                switch mood {
                case .cheering, .excited:
                    // Happy curved ^ ^ eyes
                    for dir in [-1.0, 1.0] {
                        var arc = Path()
                        let ex = cx + CGFloat(dir) * eyeDX
                        arc.move(to: CGPoint(x: ex - eyeR, y: eyeY + eyeR * 0.3))
                        arc.addQuadCurve(to: CGPoint(x: ex + eyeR, y: eyeY + eyeR * 0.3), control: CGPoint(x: ex, y: eyeY - eyeR * 1.2))
                        ctx.stroke(arc, with: .color(eyeColor), style: StrokeStyle(lineWidth: max(1.6, size * 0.042), lineCap: .round))
                    }
                case .surprised:
                    // Wide O O eyes
                    for dir in [-1.0, 1.0] {
                        let ex = cx + CGFloat(dir) * eyeDX
                        ctx.stroke(Path(ellipseIn: CGRect(x: ex - eyeR * 1.15, y: eyeY - eyeR * 1.15, width: eyeR * 2.3, height: eyeR * 2.3)), with: .color(eyeColor), lineWidth: max(1.5, size * 0.038))
                    }
                case .thinking:
                    // Side-glancing curious eyes
                    for dir in [-1.0, 1.0] {
                        let ex = cx + CGFloat(dir) * eyeDX + eyeR * 0.25
                        ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR * 0.85, width: eyeR * 2, height: eyeR * 1.7)), with: .color(eyeColor))
                    }
                default:
                    // Bright glossy eyes with sparkle highlight
                    for dir in [-1.0, 1.0] {
                        let ex = cx + CGFloat(dir) * eyeDX
                        ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR, y: eyeY - eyeR, width: eyeR * 2, height: eyeR * 2)), with: .color(eyeColor))
                        if character != .panda {
                            ctx.fill(Path(ellipseIn: CGRect(x: ex - eyeR * 0.45, y: eyeY - eyeR * 0.55, width: eyeR * 0.72, height: eyeR * 0.72)), with: .color(.white))
                        }
                    }
                }

                // Cute smile / beak
                if character == .crane || character == .phoenix {
                    var beak = Path()
                    beak.move(to: CGPoint(x: cx - headR * 0.22, y: cy + headR * 0.16))
                    beak.addLine(to: CGPoint(x: cx + headR * 0.22, y: cy + headR * 0.16))
                    beak.addLine(to: CGPoint(x: cx, y: cy + headR * 0.48))
                    beak.closeSubpath()
                    ctx.fill(beak, with: .color(AppTheme.sunBottom))
                } else {
                    var mouth = Path()
                    let my = cy + headR * 0.24
                    if mood == .surprised {
                        ctx.fill(Path(ellipseIn: CGRect(x: cx - eyeR * 0.8, y: my - eyeR * 0.5, width: eyeR * 1.6, height: eyeR * 1.6)), with: .color(AppTheme.coralBottom))
                    } else {
                        mouth.move(to: CGPoint(x: cx - headR * 0.22, y: my))
                        mouth.addQuadCurve(to: CGPoint(x: cx + headR * 0.22, y: my), control: CGPoint(x: cx, y: my + headR * 0.28))
                        ctx.stroke(mouth, with: .color(AppTheme.inkPrimary), style: StrokeStyle(lineWidth: max(1.4, size * 0.036), lineCap: .round))
                    }
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .saturation(isLocked ? 0.08 : 1.0)
            .opacity(isLocked ? 0.55 : 1.0)

            // Signature white Nintendo sticker rim
            Circle()
                .strokeBorder(Color.white.opacity(isLocked ? 0.78 : 0.98), lineWidth: max(2.2, size * 0.055))
                .frame(width: size, height: size)
        }
        .shadow(color: (isLocked ? Color.black.opacity(0.14) : palette.bottom.opacity(0.36)), radius: size * 0.14, y: size * 0.08)
    }
}

/// Joyful 60fps Nintendo Confetti Celebration Burst for puzzle solves, match wins, and Boss victories!
struct ConfettiBurstView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startDate = Date()
    @State private var isFinished = false

    private struct Piece {
        let angle: Double
        let speed: Double
        let size: CGFloat
        let color: Color
        let spinSpeed: Double
        let drift: Double
    }

    private let pieces: [Piece] = {
        let colors: [Color] = [
            AppTheme.sunTop, AppTheme.skyTop, AppTheme.mintTop,
            AppTheme.coralTop, AppTheme.grapeTop, .white
        ]
        return (0..<42).map { i in
            let seed = Double(i + 1)
            return Piece(
                angle: -Double.pi * 0.15 - fmod(seed * 0.43, Double.pi * 0.70),
                speed: 220 + fmod(seed * 97, 260),
                size: CGFloat(6 + fmod(seed * 3.1, 6)),
                color: colors[i % colors.count],
                spinSpeed: 3.0 + fmod(seed * 1.7, 6.0),
                drift: (i % 2 == 0 ? 1 : -1) * (15 + fmod(seed * 11, 35))
            )
        }
    }()

    var body: some View {
        Group {
            if !reduceMotion && !isFinished {
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: isFinished)) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(startDate)
                    if elapsed < 2.4 {
                        Canvas { context, size in
                            let origin = CGPoint(x: size.width * 0.5, y: size.height * 0.48)
                            let gravity = 360.0
                            let fade = max(0, min(1, 1.0 - max(0, elapsed - 1.5) / 0.9))

                            for p in pieces {
                                let x = origin.x + CGFloat(cos(p.angle) * p.speed * elapsed + sin(elapsed * 3.0) * p.drift)
                                let y = origin.y + CGFloat(sin(p.angle) * p.speed * elapsed + 0.5 * gravity * elapsed * elapsed)
                                let rect = CGRect(x: -p.size / 2, y: -p.size * 0.35, width: p.size, height: p.size * 0.7)

                                context.drawLayer { layerCtx in
                                    layerCtx.translateBy(x: x, y: y)
                                    layerCtx.rotate(by: .radians(elapsed * p.spinSpeed))
                                    layerCtx.fill(
                                        Path(roundedRect: rect, cornerRadius: 2),
                                        with: .color(p.color.opacity(fade))
                                    )
                                }
                            }
                        }
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .task {
            startDate = Date()
            isFinished = false
            guard !reduceMotion else {
                isFinished = true
                return
            }
            try? await Task.sleep(nanoseconds: 2_450_000_000)
            if !Task.isCancelled {
                isFinished = true
            }
        }
    }
}

/// Friendly tap-to-learn popover showing the REAL Go term alongside a 1-sentence kid explanation!
struct GoTermQuickCard: View {
    let entry: GoCodexEntry
    let l10n: L10n
    var onOpenCodex: (() -> Void)? = nil
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color(hex: entry.accentHex))
                            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.term(l10n))
                        .font(AppFont.rounded(size: 20, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                    Text("\(l10n.t(entry.tier.titleKey)) · \(entry.rankTag)")
                        .font(AppFont.rounded(size: 12, weight: .bold))
                        .foregroundColor(AppTheme.skyBottom)
                }

                Spacer()

                GameCircleButton(icon: "xmark", palette: .snow, tint: AppTheme.inkSecondary, size: 36) {
                    onDismiss()
                }
            }

            Text(entry.metaphor(l10n))
                .font(AppFont.rounded(size: 15, weight: .heavy))
                .foregroundColor(AppTheme.sunBottom)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(AppTheme.softGoldBg))

            Text(entry.explanation(l10n))
                .font(AppFont.rounded(size: 14, weight: .semibold))
                .foregroundColor(AppTheme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if let onOpenCodex {
                Button(action: onOpenCodex) {
                    Label(l10n.t("codex.openFull"), systemImage: "book.closed.fill")
                        .font(AppFont.rounded(size: 14, weight: .black))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            } else {
                Button(action: onDismiss) {
                    Text(l10n.localized(
                        zh: "知道了",
                        en: "Got it",
                        ja: "わかった",
                        ko: "알겠어요",
                        zhHant: "知道了"
                    ))
                    .font(AppFont.rounded(size: 14, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                }
                .buttonStyle(GlossyCapsuleButtonStyle(palette: .sky, cornerRadius: 999, rimHeight: 5, whiteBorderWidth: 3))
            }
        }
        .padding(20)
        .frame(maxWidth: 420)
        .warmCard(cornerRadius: 28, padding: 0)
    }
}

extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Custom Nintendo-Switch-Style Game Alert Dialog (High-Contrast, Kid-Friendly)

struct GameDialogAction: Identifiable {
    let id = UUID()
    let title: String
    let palette: GlossyPalette
    let isLightFace: Bool
    let action: () -> Void

    init(
        title: String,
        palette: GlossyPalette = .sky,
        isLightFace: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.palette = palette
        self.isLightFace = isLightFace
        self.action = action
    }

    static func primary(_ title: String, palette: GlossyPalette = .mint, action: @escaping () -> Void = {}) -> GameDialogAction {
        GameDialogAction(title: title, palette: palette, isLightFace: false, action: action)
    }

    static func secondary(_ title: String, action: @escaping () -> Void = {}) -> GameDialogAction {
        GameDialogAction(title: title, palette: .snow, isLightFace: true, action: action)
    }

    static func destructive(_ title: String, action: @escaping () -> Void = {}) -> GameDialogAction {
        GameDialogAction(title: title, palette: .coral, isLightFace: false, action: action)
    }
}

struct GameDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let icon: String
    let accentPalette: GlossyPalette
    let actions: [GameDialogAction]

    func body(content: Content) -> some View {
        ZStack {
            content

            if isPresented {
                Color(red: 0.05, green: 0.11, blue: 0.22)
                    .opacity(0.56)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(900)

                VStack(spacing: 16) {
                    // Top glossy emblem badge
                    ZStack {
                        Circle()
                            .fill(accentPalette.rim)
                            .frame(width: 66, height: 66)
                            .offset(y: 4)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [accentPalette.top, accentPalette.bottom],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 66, height: 66)
                            .overlay(Circle().strokeBorder(.white, lineWidth: 3.5))
                            .shadow(color: accentPalette.glow.opacity(0.35), radius: 10, y: 4)

                        Image(systemName: icon)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: accentPalette.rim.opacity(0.5), radius: 2, y: 1.5)
                    }

                    Text(title)
                        .font(AppFont.rounded(size: 22, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(AppFont.rounded(size: 15.5, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)

                    // Big, high-contrast glossy capsule buttons
                    HStack(spacing: 12) {
                        ForEach(actions) { item in
                            Button {
                                SoundAndHapticsManager.shared.playUITap()
                                withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                                    isPresented = false
                                }
                                item.action()
                            } label: {
                                Text(item.title)
                                    .font(AppFont.rounded(size: 16, weight: .black))
                                    .foregroundColor(item.isLightFace ? AppTheme.inkPrimary : .white)
                                    .shadow(
                                        color: item.isLightFace ? .clear : item.palette.rim.opacity(0.5),
                                        radius: 1.5,
                                        y: 1.5
                                    )
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                                    .frame(maxWidth: .infinity)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(
                                GlossyCapsuleButtonStyle(
                                    palette: item.palette,
                                    cornerRadius: 999,
                                    rimHeight: 5,
                                    whiteBorderWidth: 3,
                                    playTapSound: false
                                )
                            )
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .frame(maxWidth: 430)
                .background(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(red: 0.95, green: 0.98, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: Color(red: 0.04, green: 0.14, blue: 0.30).opacity(0.35), radius: 24, y: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(.white, lineWidth: 4)
                )
                .padding(.horizontal, 24)
                .transition(.scale(scale: 0.86).combined(with: .opacity))
                .zIndex(901)
                .accessibilityAddTraits(.isModal)
            }
        }
        .animation(.spring(response: 0.26, dampingFraction: 0.78), value: isPresented)
    }
}

extension View {
    /// Presents a high-contrast, kid-friendly Nintendo-Switch-style dialog matching StarYi Go's glossy aesthetic.
    func gameDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        icon: String = "exclamationmark.circle.fill",
        accentPalette: GlossyPalette = .sky,
        actions: [GameDialogAction]
    ) -> some View {
        modifier(
            GameDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                icon: icon,
                accentPalette: accentPalette,
                actions: actions
            )
        )
    }
}

//
//  StarYiMascotAssets.swift
//  StarYi Go — Bespoke Nintendo-Style Vector Character Mascots & Star Coin Assets
//  Replaces raw system emojis with consistent, expressive, brand-owned vector art.
//

import SwiftUI

enum MascotMood: Equatable, Sendable {
    case happy
    case thinking
    case surprised
    case proud
}

enum StarYiCharacter: String, CaseIterable, Identifiable, Sendable {
    case sprout
    case rabbit
    case fox
    case deer
    case panda
    case crane
    case tiger
    case dragon
    case phoenix
    case kirin
    case lion
    case owl
    case star
    case bamboo

    var id: String { rawValue }

    /// Maps legacy emoji keys & AIDifficulty identifiers to bespoke brand characters.
    static func from(key: String) -> StarYiCharacter {
        switch key {
        case "🌱", "sprout": return .sprout
        case "🐰", "rabbit": return .rabbit
        case "🦊", "fox": return .fox
        case "🦌", "deer": return .deer
        case "🐼", "panda": return .panda
        case "🦢", "crane": return .crane
        case "🐯", "tiger": return .tiger
        case "🐉", "dragon": return .dragon
        case "🦅", "phoenix": return .phoenix
        case "🦄", "kirin": return .kirin
        case "🦁", "lion": return .lion
        case "🦉", "owl": return .owl
        case "🌟", "star": return .star
        case "🎋", "bamboo": return .bamboo
        default: return .fox
        }
    }

    static func from(difficulty: AIDifficulty) -> StarYiCharacter {
        StarYiCharacter(rawValue: difficulty.rawValue) ?? .fox
    }

    var backdropColors: [Color] {
        switch self {
        case .sprout:  return [Color(red: 0.56, green: 0.92, blue: 0.58), Color(red: 0.22, green: 0.72, blue: 0.44)]
        case .rabbit:  return [Color(red: 1.00, green: 0.80, blue: 0.88), Color(red: 0.94, green: 0.48, blue: 0.68)]
        case .fox:     return [Color(red: 1.00, green: 0.82, blue: 0.42), Color(red: 0.96, green: 0.46, blue: 0.22)]
        case .deer:    return [Color(red: 0.96, green: 0.82, blue: 0.56), Color(red: 0.72, green: 0.48, blue: 0.26)]
        case .panda:   return [Color(red: 0.64, green: 0.90, blue: 0.86), Color(red: 0.24, green: 0.68, blue: 0.66)]
        case .crane:   return [Color(red: 0.74, green: 0.90, blue: 1.00), Color(red: 0.28, green: 0.58, blue: 0.94)]
        case .tiger:   return [Color(red: 1.00, green: 0.78, blue: 0.30), Color(red: 0.88, green: 0.38, blue: 0.14)]
        case .dragon:  return [Color(red: 0.42, green: 0.86, blue: 0.76), Color(red: 0.14, green: 0.48, blue: 0.58)]
        case .phoenix: return [Color(red: 1.00, green: 0.66, blue: 0.44), Color(red: 0.86, green: 0.18, blue: 0.30)]
        case .kirin:   return [Color(red: 0.82, green: 0.70, blue: 1.00), Color(red: 0.46, green: 0.28, blue: 0.88)]
        case .lion:    return [Color(red: 1.00, green: 0.84, blue: 0.46), Color(red: 0.84, green: 0.46, blue: 0.12)]
        case .owl:     return [Color(red: 0.76, green: 0.74, blue: 0.96), Color(red: 0.36, green: 0.34, blue: 0.68)]
        case .star:    return [Color(red: 1.00, green: 0.90, blue: 0.42), Color(red: 0.95, green: 0.62, blue: 0.12)]
        case .bamboo:  return [Color(red: 0.58, green: 0.92, blue: 0.68), Color(red: 0.16, green: 0.58, blue: 0.36)]
        }
    }

    var primaryFill: Color {
        switch self {
        case .sprout:  return Color(red: 0.34, green: 0.82, blue: 0.40)
        case .rabbit:  return Color(red: 0.99, green: 0.97, blue: 0.98)
        case .fox:     return Color(red: 0.98, green: 0.50, blue: 0.18)
        case .deer:    return Color(red: 0.82, green: 0.56, blue: 0.32)
        case .panda:   return Color(red: 0.98, green: 0.98, blue: 0.99)
        case .crane:   return Color(red: 0.99, green: 0.99, blue: 1.00)
        case .tiger:   return Color(red: 0.99, green: 0.62, blue: 0.16)
        case .dragon:  return Color(red: 0.22, green: 0.76, blue: 0.64)
        case .phoenix: return Color(red: 0.96, green: 0.32, blue: 0.24)
        case .kirin:   return Color(red: 0.96, green: 0.92, blue: 1.00)
        case .lion:    return Color(red: 0.98, green: 0.74, blue: 0.30)
        case .owl:     return Color(red: 0.58, green: 0.44, blue: 0.34)
        case .star:    return Color(red: 1.00, green: 0.86, blue: 0.24)
        case .bamboo:  return Color(red: 0.30, green: 0.74, blue: 0.38)
        }
    }

    var accentFill: Color {
        switch self {
        case .sprout:  return Color(red: 0.86, green: 0.99, blue: 0.76)
        case .rabbit:  return Color(red: 1.00, green: 0.64, blue: 0.76)
        case .fox:     return Color(red: 1.00, green: 0.95, blue: 0.88)
        case .deer:    return Color(red: 0.98, green: 0.90, blue: 0.76)
        case .panda:   return Color(red: 0.15, green: 0.18, blue: 0.24)
        case .crane:   return Color(red: 0.92, green: 0.22, blue: 0.24)
        case .tiger:   return Color(red: 0.20, green: 0.14, blue: 0.10)
        case .dragon:  return Color(red: 1.00, green: 0.84, blue: 0.30)
        case .phoenix: return Color(red: 1.00, green: 0.84, blue: 0.24)
        case .kirin:   return Color(red: 0.98, green: 0.78, blue: 0.26)
        case .lion:    return Color(red: 0.78, green: 0.38, blue: 0.12)
        case .owl:     return Color(red: 0.96, green: 0.90, blue: 0.78)
        case .star:    return Color(red: 1.00, green: 0.97, blue: 0.76)
        case .bamboo:  return Color(red: 0.74, green: 0.96, blue: 0.72)
        }
    }
}

/// Bespoke vector Nintendo-style mascot medallion with reactive facial expressions.
struct StarYiMascotView: View {
    let character: StarYiCharacter
    var size: CGFloat = 40
    var mood: MascotMood = .happy
    var showRing: Bool = true

    init(character: StarYiCharacter, size: CGFloat = 40, mood: MascotMood = .happy, showRing: Bool = true) {
        self.character = character
        self.size = size
        self.mood = mood
        self.showRing = showRing
    }

    init(emojiKey: String, size: CGFloat = 40, mood: MascotMood = .happy, showRing: Bool = true) {
        self.character = StarYiCharacter.from(key: emojiKey)
        self.size = size
        self.mood = mood
        self.showRing = showRing
    }

    init(difficulty: AIDifficulty, size: CGFloat = 40, mood: MascotMood = .happy, showRing: Bool = true) {
        self.character = StarYiCharacter.from(difficulty: difficulty)
        self.size = size
        self.mood = mood
        self.showRing = showRing
    }

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let cx = canvasSize.width / 2
            let cy = canvasSize.height / 2
            let r = s * 0.48

            // 1. Glossy medallion backdrop
            let bgRect = CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)
            context.fill(
                Path(ellipseIn: bgRect),
                with: .linearGradient(
                    Gradient(colors: character.backdropColors),
                    startPoint: CGPoint(x: cx, y: cy - r),
                    endPoint: CGPoint(x: cx, y: cy + r)
                )
            )

            // Soft top specular highlight on medallion
            let glossRect = CGRect(x: cx - r * 0.68, y: cy - r * 0.86, width: r * 1.36, height: r * 0.62)
            context.fill(Path(ellipseIn: glossRect), with: .color(.white.opacity(0.24)))

            // 2. Character-specific ears, horns, mane, or crest (behind head)
            drawHeadAccessories(context: &context, cx: cx, cy: cy, s: s)

            // 3. Cute rounded face/head silhouette
            if character == .star {
                let starPath = makeStarPath(center: CGPoint(x: cx, y: cy + s * 0.02), outerR: s * 0.34, innerR: s * 0.17, points: 5)
                context.fill(starPath, with: .color(character.primaryFill))
                context.stroke(starPath, with: .color(.white.opacity(0.7)), lineWidth: max(1, s * 0.03))
            } else if character == .bamboo {
                let stalk = CGRect(x: cx - s * 0.18, y: cy - s * 0.24, width: s * 0.36, height: s * 0.52)
                context.fill(Path(roundedRect: stalk, cornerRadius: s * 0.10), with: .color(character.primaryFill))
                let joint = CGRect(x: cx - s * 0.20, y: cy - s * 0.02, width: s * 0.40, height: s * 0.06)
                context.fill(Path(roundedRect: joint, cornerRadius: s * 0.03), with: .color(character.accentFill))
            } else {
                let headW = s * 0.60
                let headH = s * 0.52
                let headRect = CGRect(x: cx - headW / 2, y: cy - headH / 2 + s * 0.06, width: headW, height: headH)
                context.fill(Path(roundedRect: headRect, cornerRadius: headH * 0.46), with: .color(character.primaryFill))

                // Species markings (fox cheeks, panda patches, tiger stripes, crane red crown, owl belly)
                drawSpeciesMarkings(context: &context, cx: cx, cy: cy + s * 0.06, headW: headW, headH: headH, s: s)
            }

            // 4. Expressive Nintendo Eyes, Rosy Cheeks & Mouth
            drawExpression(context: &context, cx: cx, cy: cy + s * 0.08, s: s)

            // 5. Crisp white candy rim
            if showRing {
                context.stroke(Path(ellipseIn: bgRect.insetBy(dx: max(1, s * 0.03), dy: max(1, s * 0.03))), with: .color(.white.opacity(0.92)), lineWidth: max(1.5, s * 0.055))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func drawHeadAccessories(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, s: CGFloat) {
        switch character {
        case .fox, .tiger, .owl:
            // Pointed ears
            for sign in [-1.0, 1.0] {
                var ear = Path()
                ear.move(to: CGPoint(x: cx + CGFloat(sign) * s * 0.12, y: cy - s * 0.14))
                ear.addLine(to: CGPoint(x: cx + CGFloat(sign) * s * 0.28, y: cy - s * 0.34))
                ear.addLine(to: CGPoint(x: cx + CGFloat(sign) * s * 0.30, y: cy - s * 0.04))
                ear.closeSubpath()
                context.fill(ear, with: .color(character.primaryFill))

                var inner = Path()
                inner.move(to: CGPoint(x: cx + CGFloat(sign) * s * 0.16, y: cy - s * 0.14))
                inner.addLine(to: CGPoint(x: cx + CGFloat(sign) * s * 0.25, y: cy - s * 0.26))
                inner.addLine(to: CGPoint(x: cx + CGFloat(sign) * s * 0.26, y: cy - s * 0.09))
                inner.closeSubpath()
                context.fill(inner, with: .color(character.accentFill.opacity(0.85)))
            }
        case .rabbit:
            // Tall bunny ears
            for sign in [-1.0, 1.0] {
                let earRect = CGRect(x: cx + CGFloat(sign) * s * 0.15 - s * 0.08, y: cy - s * 0.42, width: s * 0.16, height: s * 0.32)
                context.fill(Path(roundedRect: earRect, cornerRadius: s * 0.08), with: .color(character.primaryFill))
                let innerRect = earRect.insetBy(dx: s * 0.035, dy: s * 0.05)
                context.fill(Path(roundedRect: innerRect, cornerRadius: s * 0.05), with: .color(character.accentFill))
            }
        case .panda:
            // Round dark ears
            for sign in [-1.0, 1.0] {
                let r = s * 0.11
                let rect = CGRect(x: cx + CGFloat(sign) * s * 0.22 - r, y: cy - s * 0.22 - r, width: r * 2, height: r * 2)
                context.fill(Path(ellipseIn: rect), with: .color(character.accentFill))
            }
        case .lion:
            // Fluffy scallop mane behind head
            for i in 0..<10 {
                let angle = Double(i) * (.pi * 2.0 / 10.0)
                let mx = cx + CGFloat(cos(angle)) * s * 0.28
                let my = cy + s * 0.05 + CGFloat(sin(angle)) * s * 0.25
                let mr = s * 0.11
                context.fill(Path(ellipseIn: CGRect(x: mx - mr, y: my - mr, width: mr * 2, height: mr * 2)), with: .color(character.accentFill))
            }
        case .deer, .dragon:
            // Golden antlers / horns
            for sign in [-1.0, 1.0] {
                var horn = Path()
                horn.move(to: CGPoint(x: cx + CGFloat(sign) * s * 0.12, y: cy - s * 0.16))
                horn.addQuadCurve(
                    to: CGPoint(x: cx + CGFloat(sign) * s * 0.24, y: cy - s * 0.36),
                    control: CGPoint(x: cx + CGFloat(sign) * s * 0.26, y: cy - s * 0.22)
                )
                context.stroke(horn, with: .color(character.accentFill), style: StrokeStyle(lineWidth: max(2, s * 0.07), lineCap: .round))
            }
        case .kirin:
            // Radiant golden horn
            var horn = Path()
            horn.move(to: CGPoint(x: cx - s * 0.06, y: cy - s * 0.16))
            horn.addLine(to: CGPoint(x: cx, y: cy - s * 0.40))
            horn.addLine(to: CGPoint(x: cx + s * 0.06, y: cy - s * 0.16))
            horn.closeSubpath()
            context.fill(horn, with: .color(character.accentFill))
        case .sprout, .bamboo:
            // Twin cheerful leaves on top
            for sign in [-1.0, 1.0] {
                let leaf = CGRect(x: cx + CGFloat(sign) * s * 0.11 - s * 0.10, y: cy - s * 0.34, width: s * 0.20, height: s * 0.13)
                context.fill(Path(ellipseIn: leaf), with: .color(Color(red: 0.42, green: 0.88, blue: 0.36)))
            }
        case .phoenix:
            // Three-plume fiery crest
            for dx in [-0.10, 0.0, 0.10] {
                let plume = CGRect(x: cx + CGFloat(dx) * s - s * 0.055, y: cy - s * 0.37, width: s * 0.11, height: s * 0.22)
                context.fill(Path(ellipseIn: plume), with: .color(character.accentFill))
            }
        case .crane:
            // Red-crowned crane jewel on forehead
            let crown = CGRect(x: cx - s * 0.09, y: cy - s * 0.24, width: s * 0.18, height: s * 0.10)
            context.fill(Path(ellipseIn: crown), with: .color(character.accentFill))
        case .star:
            break
        }
    }

    private func drawSpeciesMarkings(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, headW: CGFloat, headH: CGFloat, s: CGFloat) {
        switch character {
        case .fox:
            // Cream lower muzzle/cheeks
            let muzzle = CGRect(x: cx - headW * 0.42, y: cy + headH * 0.04, width: headW * 0.84, height: headH * 0.44)
            context.fill(Path(ellipseIn: muzzle), with: .color(character.accentFill))
        case .panda:
            // Iconic tilted dark eye patches
            for sign in [-1.0, 1.0] {
                let patch = CGRect(x: cx + CGFloat(sign) * s * 0.13 - s * 0.085, y: cy - s * 0.06, width: s * 0.17, height: s * 0.14)
                context.fill(Path(ellipseIn: patch), with: .color(character.accentFill))
            }
        case .tiger:
            // Forehead "王" / 3 stripes
            for dx in [-0.07, 0.0, 0.07] {
                let stripe = CGRect(x: cx + CGFloat(dx) * s - s * 0.018, y: cy - headH * 0.46, width: s * 0.036, height: s * 0.11)
                context.fill(Path(roundedRect: stripe, cornerRadius: s * 0.015), with: .color(character.accentFill))
            }
        case .crane, .phoenix:
            // Cute golden beak
            var beak = Path()
            beak.move(to: CGPoint(x: cx - s * 0.06, y: cy + s * 0.05))
            beak.addLine(to: CGPoint(x: cx + s * 0.06, y: cy + s * 0.05))
            beak.addLine(to: CGPoint(x: cx, y: cy + s * 0.15))
            beak.closeSubpath()
            context.fill(beak, with: .color(Color(red: 1.0, green: 0.78, blue: 0.22)))
        case .owl:
            let faceDisk = CGRect(x: cx - headW * 0.36, y: cy - headH * 0.24, width: headW * 0.72, height: headH * 0.56)
            context.fill(Path(ellipseIn: faceDisk), with: .color(character.accentFill))
        default:
            break
        }
    }

    private func drawExpression(context: inout GraphicsContext, cx: CGFloat, cy: CGFloat, s: CGFloat) {
        let eyeOffsetX = s * 0.125
        let eyeY = cy - s * 0.03
        let eyeColor: Color = (character == .panda) ? .white : Color(red: 0.14, green: 0.16, blue: 0.24)
        let strokeW = max(1.4, s * 0.048)

        switch mood {
        case .happy:
            for sign in [-1.0, 1.0] {
                let ex = cx + CGFloat(sign) * eyeOffsetX
                let er = s * 0.048
                context.fill(Path(ellipseIn: CGRect(x: ex - er, y: eyeY - er, width: er * 2, height: er * 2)), with: .color(eyeColor))
                // Specular eye catchlight
                let hl = er * 0.42
                context.fill(Path(ellipseIn: CGRect(x: ex - hl * 1.1, y: eyeY - hl * 1.1, width: hl * 1.2, height: hl * 1.2)), with: .color(.white))
            }
        case .proud:
            // Joyful ^ ^ curved eyes
            for sign in [-1.0, 1.0] {
                let ex = cx + CGFloat(sign) * eyeOffsetX
                var arc = Path()
                arc.move(to: CGPoint(x: ex - s * 0.055, y: eyeY + s * 0.015))
                arc.addQuadCurve(to: CGPoint(x: ex + s * 0.055, y: eyeY + s * 0.015), control: CGPoint(x: ex, y: eyeY - s * 0.065))
                context.stroke(arc, with: .color(eyeColor), style: StrokeStyle(lineWidth: strokeW, lineCap: .round))
            }
        case .thinking:
            // Focused eyes slightly looking up-right
            for sign in [-1.0, 1.0] {
                let ex = cx + CGFloat(sign) * eyeOffsetX
                let er = s * 0.044
                context.fill(Path(ellipseIn: CGRect(x: ex - er + s * 0.015, y: eyeY - er - s * 0.01, width: er * 2, height: er * 2)), with: .color(eyeColor))
            }
        case .surprised:
            // Wide O O eyes
            for sign in [-1.0, 1.0] {
                let ex = cx + CGFloat(sign) * eyeOffsetX
                let er = s * 0.056
                context.stroke(Path(ellipseIn: CGRect(x: ex - er, y: eyeY - er, width: er * 2, height: er * 2)), with: .color(eyeColor), lineWidth: strokeW)
            }
        }

        // Rosy Nintendo cheeks
        let cheekColor = Color(red: 1.0, green: 0.48, blue: 0.56).opacity(0.42)
        for sign in [-1.0, 1.0] {
            let rx = cx + CGFloat(sign) * s * 0.185
            let ry = cy + s * 0.045
            context.fill(Path(ellipseIn: CGRect(x: rx - s * 0.048, y: ry - s * 0.028, width: s * 0.096, height: s * 0.056)), with: .color(cheekColor))
        }

        // Cute smile (unless bird beak already drawn)
        if character != .crane && character != .phoenix {
            var mouth = Path()
            if mood == .surprised {
                let mr = s * 0.042
                context.fill(Path(ellipseIn: CGRect(x: cx - mr, y: cy + s * 0.045, width: mr * 2, height: mr * 2)), with: .color(Color(red: 0.25, green: 0.16, blue: 0.20)))
            } else {
                mouth.move(to: CGPoint(x: cx - s * 0.06, y: cy + s * 0.06))
                mouth.addQuadCurve(
                    to: CGPoint(x: cx + s * 0.06, y: cy + s * 0.06),
                    control: CGPoint(x: cx, y: cy + (mood == .thinking ? s * 0.06 : s * 0.13))
                )
                context.stroke(mouth, with: .color(Color(red: 0.22, green: 0.18, blue: 0.24)), style: StrokeStyle(lineWidth: max(1.2, s * 0.038), lineCap: .round))
            }
        }
    }

    private func makeStarPath(center: CGPoint, outerR: CGFloat, innerR: CGFloat, points: Int) -> Path {
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = (Double(i) * .pi / Double(points)) - (.pi / 2.0)
            let radius = (i % 2 == 0) ? outerR : innerR
            let pt = CGPoint(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}

/// Bespoke glossy 3D Nintendo-style Gold Star Coin replacing raw `🪙` emoji.
struct StarCoinBadgeView: View {
    var size: CGFloat = 18

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.92, blue: 0.42), Color(red: 0.96, green: 0.66, blue: 0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color(red: 0.78, green: 0.48, blue: 0.04), lineWidth: max(1, size * 0.09))
                )
                .overlay(
                    Circle()
                        .inset(by: max(1.5, size * 0.14))
                        .strokeBorder(Color.white.opacity(0.65), lineWidth: max(0.8, size * 0.06))
                )

            Image(systemName: "star.fill")
                .font(.system(size: size * 0.46, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.76, green: 0.44, blue: 0.02))
                .offset(y: size * 0.03)

            Image(systemName: "star.fill")
                .font(.system(size: size * 0.46, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 1.0, green: 0.98, blue: 0.78))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

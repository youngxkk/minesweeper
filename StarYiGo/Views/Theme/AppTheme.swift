//
//  AppTheme.swift
//  StarYi Go — Modern Vibrant Nintendo Switch Party Aesthetic
//

import SwiftUI

enum AppTheme {
    // Crisp, bright, modern Nintendo Switch Sports / Mario Party surface palette
    static let canvasTop = Color(red: 0.93, green: 0.97, blue: 1.00)           // Bright airy sky tint
    static let canvasBottom = Color(red: 0.97, green: 0.96, blue: 1.00)        // Soft cloud lavender-white
    static let canvasBackground = Color(red: 0.945, green: 0.972, blue: 0.996) // #F1F8FE
    static let cardBackground = Color.white
    static let cardElevated = Color.white
    static let subtleBorder = Color(red: 0.80, green: 0.88, blue: 0.96).opacity(0.85)

    // High-contrast crisp typography colors
    static let inkPrimary = Color(red: 0.12, green: 0.16, blue: 0.25)          // Deep crisp slate-navy #1F2940
    static let inkSecondary = Color(red: 0.42, green: 0.49, blue: 0.60)        // Cool modern slate #6B7D99

    // Vivid Nintendo Switch Party Glossy Candy Palette
    static let skyTop = Color(red: 0.08, green: 0.74, blue: 1.00)              // Electric Sky #14BDFF
    static let skyBottom = Color(red: 0.04, green: 0.49, blue: 0.96)           // Mario Blue #0A7DF5
    static let skyRim = Color(red: 0.02, green: 0.34, blue: 0.74)

    static let mintTop = Color(red: 0.16, green: 0.88, blue: 0.56)             // Yoshi Mint #29E08F
    static let mintBottom = Color(red: 0.02, green: 0.69, blue: 0.43)          // Emerald Pop #05B06E
    static let mintRim = Color(red: 0.01, green: 0.48, blue: 0.30)

    static let sunTop = Color(red: 1.00, green: 0.84, blue: 0.18)              // Star Gold #FFD62E
    static let sunBottom = Color(red: 1.00, green: 0.58, blue: 0.06)           // Sunny Tangerine #FF940F
    static let sunRim = Color(red: 0.78, green: 0.40, blue: 0.02)

    static let coralTop = Color(red: 1.00, green: 0.42, blue: 0.46)            // Joy-Con Coral #FF6B75
    static let coralBottom = Color(red: 0.95, green: 0.20, blue: 0.34)         // Party Berry #F23357
    static let coralRim = Color(red: 0.70, green: 0.11, blue: 0.23)

    static let grapeTop = Color(red: 0.65, green: 0.45, blue: 1.00)            // Starlight Violet #A673FF
    static let grapeBottom = Color(red: 0.45, green: 0.24, blue: 0.95)         // Royal Purple #733DF2
    static let grapeRim = Color(red: 0.30, green: 0.14, blue: 0.72)

    // Semantic aliases kept clean across the codebase
    static let jadeAccent = Color(red: 0.04, green: 0.58, blue: 0.96)          // Vibrant Nintendo Sky-Blue primary accent
    static let vermilionAccent = Color(red: 0.96, green: 0.25, blue: 0.36)     // Joy-Con Coral alert/highlight
    static let starGold = Color(red: 1.00, green: 0.66, blue: 0.06)            // Bright Star Gold
    static let softGoldBg = Color(red: 1.00, green: 0.96, blue: 0.82)

    static var brightArenaBackground: some View {
        LinearGradient(
            colors: [canvasTop, Color(red: 0.96, green: 0.98, blue: 1.0), canvasBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            ZStack {
                // Soft cheerful sunlit radial accents
                Circle()
                    .fill(skyTop.opacity(0.08))
                    .frame(width: 520, height: 520)
                    .blur(radius: 60)
                    .offset(x: -360, y: -240)
                Circle()
                    .fill(sunTop.opacity(0.09))
                    .frame(width: 460, height: 460)
                    .blur(radius: 60)
                    .offset(x: 380, y: 260)
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    struct BoardPalette {
        let boardBase: Color
        let boardGradientEnd: Color
        let grainColor: Color
        let frameBorder: Color
        let gridLine: Color
        let starPoint: Color
        let tengenGlow: Color
        let coordText: Color
    }

    static func palette(for theme: BoardTheme) -> BoardPalette {
        switch theme {
        case .kayaWood:
            return BoardPalette(
                boardBase: Color(red: 0.96, green: 0.81, blue: 0.51),
                boardGradientEnd: Color(red: 0.88, green: 0.69, blue: 0.37),
                grainColor: Color(red: 0.72, green: 0.51, blue: 0.20).opacity(0.13),
                frameBorder: Color(red: 0.62, green: 0.42, blue: 0.18),
                gridLine: Color(red: 0.26, green: 0.17, blue: 0.08).opacity(0.84),
                starPoint: Color(red: 0.24, green: 0.15, blue: 0.07),
                tengenGlow: Color(red: 1.0, green: 0.90, blue: 0.42).opacity(0.65),
                coordText: Color(red: 0.38, green: 0.25, blue: 0.11).opacity(0.85)
            )
        case .bambooJade:
            return BoardPalette(
                boardBase: Color(red: 0.78, green: 0.94, blue: 0.85),
                boardGradientEnd: Color(red: 0.64, green: 0.86, blue: 0.76),
                grainColor: Color(red: 0.22, green: 0.56, blue: 0.42).opacity(0.11),
                frameBorder: Color(red: 0.14, green: 0.56, blue: 0.42),
                gridLine: Color(red: 0.10, green: 0.28, blue: 0.22).opacity(0.80),
                starPoint: Color(red: 0.09, green: 0.26, blue: 0.20),
                tengenGlow: Color(red: 1.0, green: 0.92, blue: 0.46).opacity(0.55),
                coordText: Color(red: 0.14, green: 0.36, blue: 0.28).opacity(0.85)
            )
        case .midnightStar:
            return BoardPalette(
                boardBase: Color(red: 0.16, green: 0.20, blue: 0.38),
                boardGradientEnd: Color(red: 0.11, green: 0.13, blue: 0.27),
                grainColor: Color(red: 0.46, green: 0.62, blue: 0.96).opacity(0.09),
                frameBorder: Color(red: 0.38, green: 0.48, blue: 0.82),
                gridLine: Color(red: 0.74, green: 0.84, blue: 1.0).opacity(0.52),
                starPoint: Color(red: 1.0, green: 0.84, blue: 0.32),
                tengenGlow: Color(red: 1.0, green: 0.86, blue: 0.40).opacity(0.70),
                coordText: Color(red: 0.78, green: 0.86, blue: 1.0).opacity(0.85)
            )
        case .sakuraBlossom:
            return BoardPalette(
                boardBase: Color(red: 0.99, green: 0.89, blue: 0.91),
                boardGradientEnd: Color(red: 0.95, green: 0.78, blue: 0.83),
                grainColor: Color(red: 0.84, green: 0.42, blue: 0.56).opacity(0.11),
                frameBorder: Color(red: 0.85, green: 0.40, blue: 0.56),
                gridLine: Color(red: 0.42, green: 0.18, blue: 0.26).opacity(0.76),
                starPoint: Color(red: 0.76, green: 0.20, blue: 0.38),
                tengenGlow: Color(red: 1.0, green: 0.78, blue: 0.86).opacity(0.75),
                coordText: Color(red: 0.52, green: 0.22, blue: 0.34).opacity(0.86)
            )
        case .oceanCoral:
            return BoardPalette(
                boardBase: Color(red: 0.78, green: 0.93, blue: 0.99),
                boardGradientEnd: Color(red: 0.62, green: 0.84, blue: 0.96),
                grainColor: Color(red: 0.16, green: 0.54, blue: 0.78).opacity(0.11),
                frameBorder: Color(red: 0.08, green: 0.50, blue: 0.80),
                gridLine: Color(red: 0.09, green: 0.26, blue: 0.42).opacity(0.78),
                starPoint: Color(red: 0.07, green: 0.32, blue: 0.54),
                tengenGlow: Color(red: 1.0, green: 0.90, blue: 0.46).opacity(0.68),
                coordText: Color(red: 0.12, green: 0.34, blue: 0.52).opacity(0.86)
            )
        }
    }
}

/// Bouncy Nintendo Switch tactile press feedback for cards and non-beveled elements.
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pressedScale: CGFloat = 0.94
    var playTapSound: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? pressedScale : 1.0)
            .brightness(configuration.isPressed ? 0.03 : 0.0)
            .animation(
                reduceMotion ? nil : (configuration.isPressed ? .easeOut(duration: 0.07) : .spring(response: 0.22, dampingFraction: 0.74)),
                value: configuration.isPressed
            )
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && playTapSound {
                    SoundAndHapticsManager.shared.playUITap()
                }
            }
    }
}

/// Crisp, glossy floating white Nintendo card surface (replaces old beige parchment cards).
struct WarmCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 26
    var padding: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.96))
                        .shadow(color: Color(red: 0.14, green: 0.28, blue: 0.48).opacity(0.10), radius: 16, x: 0, y: 8)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white, lineWidth: 2.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AppTheme.subtleBorder, lineWidth: 1)
            )
    }
}

extension View {
    func warmCard(cornerRadius: CGFloat = 26, padding: CGFloat = 18) -> some View {
        modifier(WarmCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func tactileButton(scale: CGFloat = 0.94, sound: Bool = true) -> some View {
        buttonStyle(TactileButtonStyle(pressedScale: scale, playTapSound: sound))
    }
}

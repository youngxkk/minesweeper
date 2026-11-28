//
//  AppTheme.swift
//  StarYi Go — Modern Vibrant Nintendo Switch Party Aesthetic
//

import CoreText
import SwiftUI
import UIKit

/// Kid-friendly standard rounded CJK & Latin typography powered by Resource Han Rounded CN / JP / KR (SIL OFL 1.1).
enum AppFont {
    static let mediumPostScriptName = "Resource-Han-Rounded-CN-Medium"
    static let boldPostScriptName = "Resource-Han-Rounded-CN-Bold"

    static let jpMediumPostScriptName = "Resource-Han-Rounded-JP-Medium"
    static let jpBoldPostScriptName = "Resource-Han-Rounded-JP-Bold"

    static let krMediumPostScriptName = "Resource-Han-Rounded-KR-Medium"
    static let krBoldPostScriptName = "Resource-Han-Rounded-KR-Bold"

    private static let bundledFontFiles = [
        "ResourceHanRoundedCN-Medium",
        "ResourceHanRoundedCN-Bold",
        "ResourceHanRoundedJP-Medium",
        "ResourceHanRoundedJP-Bold",
        "ResourceHanRoundedKR-Medium",
        "ResourceHanRoundedKR-Bold",
    ]

    private static let stateLock = NSLock()
    private static var registeredFiles: Set<String> = []
    private static var _activeLanguageCode: String = AppLanguage.system.resolvedCode
    private static var descriptorCache: [String: UIFontDescriptor] = [:]
    private static let fontCache = NSCache<NSString, UIFont>()

    static var activeLanguageCode: String {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _activeLanguageCode
        }
        set {
            stateLock.lock()
            _activeLanguageCode = newValue
            stateLock.unlock()
        }
    }

    /// Registers all 6 subsetted CJK rounded fonts once (now compact ~10.9 MB total)
    /// so CJK cascade fallbacks (`ja` -> `cn/kr`, `ko` -> `cn/jp`) resolve instantaneously.
    static func registerBundledFonts() {
        var toRegister: [String] = []
        stateLock.lock()
        for name in bundledFontFiles where !registeredFiles.contains(name) {
            registeredFiles.insert(name)
            toRegister.append(name)
        }
        stateLock.unlock()

        guard !toRegister.isEmpty else { return }
        let subdirs: [String?] = ["Resources/Fonts", "Fonts", nil]
        for fileName in toRegister {
            for subdir in subdirs {
                if let url = Bundle.main.url(forResource: fileName, withExtension: "ttf", subdirectory: subdir) {
                    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
                    break
                }
            }
        }
    }

    private static func isBoldWeight(_ weight: Font.Weight) -> Bool {
        switch weight {
        case .ultraLight, .thin, .light, .regular, .medium, .semibold:
            return false
        default:
            return true
        }
    }

    static func postScriptName(for weight: Font.Weight = .bold, languageCode: String? = nil) -> String {
        let code = languageCode ?? activeLanguageCode
        let bold = isBoldWeight(weight)
        switch code {
        case "ja":
            return bold ? jpBoldPostScriptName : jpMediumPostScriptName
        case "ko":
            return bold ? krBoldPostScriptName : krMediumPostScriptName
        default:
            return bold ? boldPostScriptName : mediumPostScriptName
        }
    }

    private static func fallbackPostScriptNames(for weight: Font.Weight, languageCode: String) -> [String] {
        let bold = isBoldWeight(weight)
        let cn = bold ? boldPostScriptName : mediumPostScriptName
        let jp = bold ? jpBoldPostScriptName : jpMediumPostScriptName
        let kr = bold ? krBoldPostScriptName : krMediumPostScriptName
        switch languageCode {
        case "ja":
            return [cn, kr]
        case "ko":
            return [cn, jp]
        default:
            return [kr, jp]
        }
    }

    static func uiFont(size: CGFloat, weight: Font.Weight = .bold, languageCode: String? = nil) -> UIFont? {
        let code = languageCode ?? activeLanguageCode
        let primaryName = postScriptName(for: weight, languageCode: code)
        let fontKey = "\(primaryName)#\(code)#\(Int((size * 10).rounded()))" as NSString
        if let cachedFont = fontCache.object(forKey: fontKey) {
            return cachedFont
        }

        registerBundledFonts()

        let descKey = "\(primaryName)#\(code)"
        stateLock.lock()
        let cachedDescriptor = descriptorCache[descKey]
        stateLock.unlock()

        let descriptor: UIFontDescriptor
        if let cachedDescriptor {
            descriptor = cachedDescriptor
        } else {
            guard UIFont(name: primaryName, size: size) != nil else {
                return nil
            }
            let fallbacks = fallbackPostScriptNames(for: weight, languageCode: code)
                .filter { UIFont(name: $0, size: size) != nil }
                .map { UIFontDescriptor(name: $0, size: 0) }
            var attributes: [UIFontDescriptor.AttributeName: Any] = [.name: primaryName]
            if !fallbacks.isEmpty {
                attributes[.cascadeList] = fallbacks
            }
            let desc = UIFontDescriptor(fontAttributes: attributes)
            stateLock.lock()
            descriptorCache[descKey] = desc
            stateLock.unlock()
            descriptor = desc
        }

        let baseFont = UIFont(descriptor: descriptor, size: size)
        // Respect Dynamic Type with a layout-safe ceiling (+25%) for compact game chrome
        let scaled = UIFontMetrics(forTextStyle: .body).scaledFont(
            for: baseFont,
            maximumPointSize: size * 1.25
        )
        fontCache.setObject(scaled, forKey: fontKey)
        return scaled
    }

    static func rounded(size: CGFloat, weight: Font.Weight = .bold, languageCode: String? = nil) -> Font {
        if let font = uiFont(size: size, weight: weight, languageCode: languageCode) {
            return Font(font)
        }
        let psName = postScriptName(for: weight, languageCode: languageCode)
        return .custom(psName, size: size, relativeTo: .body)
    }
}

extension EnvironmentValues {
    @Entry var minimumButtonFaceHeight: CGFloat = AppTheme.buttonFaceHeight
    @Entry var zoomTransitionNamespace: Namespace.ID? = nil
}

enum AppTheme {
    static let buttonFaceHeight: CGFloat = 51
    static let titleCrestHeight: CGFloat = 56
    static let boardActionFaceHeight: CGFloat = 60

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
                // Soft cheerful sunlit radial accents (GPU-lightweight RadialGradients, zero offscreen blur passes)
                RadialGradient(
                    colors: [skyTop.opacity(0.11), skyTop.opacity(0)],
                    center: UnitPoint(x: 0.14, y: 0.18),
                    startRadius: 10,
                    endRadius: 340
                )
                RadialGradient(
                    colors: [sunTop.opacity(0.12), sunTop.opacity(0)],
                    center: UnitPoint(x: 0.86, y: 0.84),
                    startRadius: 10,
                    endRadius: 320
                )
            }
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    struct StonePalette {
        let blackColors: [Color]
        let whiteColors: [Color]
    }

    /// Single source of truth for collectible stone preview & rendering gradients.
    static func stonePalette(for style: StoneStyle) -> StonePalette {
        switch style {
        case .classicSlateShell:
            return StonePalette(
                blackColors: [Color(red: 0.34, green: 0.36, blue: 0.39), Color(red: 0.05, green: 0.06, blue: 0.07)],
                whiteColors: [.white, Color(red: 0.80, green: 0.82, blue: 0.85)]
            )
        case .coralPearl:
            return StonePalette(
                blackColors: [Color(red: 0.24, green: 0.46, blue: 0.56), Color(red: 0.04, green: 0.11, blue: 0.18)],
                whiteColors: [Color(red: 1.0, green: 0.96, blue: 0.94), Color(red: 0.96, green: 0.82, blue: 0.78)]
            )
        case .kyotoLacquer:
            return StonePalette(
                blackColors: [Color(red: 0.44, green: 0.24, blue: 0.18), Color(red: 0.07, green: 0.04, blue: 0.04)],
                whiteColors: [Color(red: 1.0, green: 0.97, blue: 0.88), Color(red: 0.91, green: 0.82, blue: 0.62)]
            )
        case .starlightJade:
            return StonePalette(
                blackColors: [Color(red: 0.18, green: 0.54, blue: 0.46), Color(red: 0.03, green: 0.12, blue: 0.14)],
                whiteColors: [Color(red: 0.92, green: 1.0, blue: 0.96), Color(red: 0.68, green: 0.92, blue: 0.82)]
            )
        }
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

/// Authored motion tokens inspired by physical damped springs (benjitaylor/skills):
/// critically damped on press-down (crisp, zero overshoot), lightly underdamped on release (~4% tactile bounce).
enum MotionToken {
    /// Crisp critically-damped press-down (zeta = 1.0 feel, zero overshoot)
    static let pressDown: Animation = .spring(duration: 0.095, bounce: 0.0)
    /// Snappy small/medium button release (~4% overshoot)
    static let buttonRelease: Animation = .spring(response: 0.22, dampingFraction: 0.64)
    /// Confident large hero / entrance button release
    static let heroRelease: Animation = .spring(response: 0.26, dampingFraction: 0.72)
    /// Grounded card release (tactile without wobbling)
    static let cardRelease: Animation = .spring(response: 0.27, dampingFraction: 0.76)
    /// Inner icon/mascot micro-parallax release (slightly livelier than outer shell)
    static let innerParallaxRelease: Animation = .spring(response: 0.25, dampingFraction: 0.60)
    /// Calm arrival curve for staggered cards and popovers
    static let cardEntrance: Animation = .spring(response: 0.42, dampingFraction: 0.82)
    /// Lively Nintendo title-screen bottom-up spring for home portal cards (slight playful settle)
    static let homePortalEntrance: Animation = .spring(response: 0.56, dampingFraction: 0.74)
    /// Graceful top-down cascade spring for home top-edge controls
    static let homeTopBarEntrance: Animation = .spring(response: 0.58, dampingFraction: 0.78)
    /// Stagger interval between grouped items (40–80ms)
    static let itemStagger: Double = 0.055
    /// Stagger interval between grid cards (80–120ms)
    static let gridStagger: Double = 0.085
}

/// Bouncy Nintendo Switch tactile press feedback for cards and non-beveled elements.
struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var pressedScale: CGFloat = 0.94
    var pressOffsetY: CGFloat = 0
    var playTapSound: Bool = true
    var hapticWeight: UITapWeight = .standard
    var releaseAnimation: Animation = MotionToken.buttonRelease

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .scaleEffect(pressed && !reduceMotion ? pressedScale : 1.0)
            .offset(y: pressed && !reduceMotion ? pressOffsetY : 0)
            .brightness(pressed ? -0.025 : 0.0)
            .animation(
                reduceMotion ? nil : (pressed ? MotionToken.pressDown : releaseAnimation),
                value: pressed
            )
            .onChange(of: pressed) { _, isPressed in
                if isPressed && playTapSound {
                    SoundAndHapticsManager.shared.playUITap(weight: hapticWeight)
                }
            }
    }
}

/// Calm staggered entrance modifier (inspired by benjitaylor/skills choreography timing).
struct StaggeredEntranceModifier: ViewModifier {
    let appeared: Bool
    let delay: Double
    let reduceMotion: Bool
    var offsetY: CGFloat = 12
    var initialScale: CGFloat = 1.0
    var animation: Animation = MotionToken.cardEntrance

    func body(content: Content) -> some View {
        content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : offsetY)
            .scaleEffect(appeared || reduceMotion ? 1.0 : initialScale)
            .animation(
                reduceMotion ? nil : animation.delay(delay),
                value: appeared
            )
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

    func tactileCard(sound: Bool = true) -> some View {
        buttonStyle(
            TactileButtonStyle(
                pressedScale: 0.978,
                pressOffsetY: 2.0,
                playTapSound: sound,
                hapticWeight: .card,
                releaseAnimation: MotionToken.cardRelease
            )
        )
    }

    func tactileButton(scale: CGFloat = 0.94, sound: Bool = true) -> some View {
        buttonStyle(
            TactileButtonStyle(
                pressedScale: scale,
                playTapSound: sound,
                hapticWeight: .light,
                releaseAnimation: MotionToken.buttonRelease
            )
        )
    }
}

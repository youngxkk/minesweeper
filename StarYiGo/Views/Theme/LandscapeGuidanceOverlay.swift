//
//  LandscapeGuidanceOverlay.swift
//  StarYi Go
//

import SwiftUI

/// Soft, kid-friendly portrait-to-landscape guidance overlay.
/// Keeps the underlying view hierarchy intact (zero game/puzzle progress loss),
/// pauses timed drills while visible, and provides a secondary "continue in portrait"
/// option to remain fully compliant with iPadOS 26+ resizable window guidelines (TN3192).
struct LandscapeGuidanceOverlay: View {
    let l10n: L10n
    let onContinueInPortrait: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var isRotatedToLandscape: Bool = false

    var body: some View {
        ZStack {
            if reduceTransparency {
                AppTheme.canvasBackground
                    .ignoresSafeArea()
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .overlay(AppTheme.canvasTop.opacity(0.46))
                    .ignoresSafeArea()
            }

            VStack(spacing: 20) {
                rotationGraphic

                VStack(spacing: 8) {
                    Text(l10n.t("orientation.portrait.title"))
                        .font(AppFont.rounded(size: 24, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .multilineTextAlignment(.center)

                    Text(l10n.t("orientation.portrait.subtitle"))
                        .font(AppFont.rounded(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onContinueInPortrait) {
                    Text(l10n.t("orientation.portrait.continueAnyway"))
                        .font(AppFont.rounded(size: 14, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.canvasBottom.opacity(0.75))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AppTheme.subtleBorder, lineWidth: 1.5)
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("portraitGuidanceContinueButton")
                .padding(.top, 4)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .shadow(color: AppTheme.skyBottom.opacity(0.18), radius: 28, y: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(AppTheme.skyTop.opacity(0.32), lineWidth: 2)
            )
            .padding(.horizontal, 28)
        }
        .accessibilityIdentifier("portraitGuidanceOverlay")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isRotatedToLandscape = true
            }
        }
    }

    private var rotationGraphic: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.skyTop.opacity(0.24), AppTheme.skyTop.opacity(0.02)],
                        center: .center,
                        startRadius: 12,
                        endRadius: 68
                    )
                )
                .frame(width: 132, height: 132)

            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 54, weight: .light))
                .foregroundColor(AppTheme.skyBottom.opacity(0.28))
                .offset(x: -2, y: 0)

            // Playful rounded iPad silhouette that smoothly turns into landscape
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.skyTop, AppTheme.skyBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 54, height: 74)
                    .shadow(color: AppTheme.skyBottom.opacity(0.30), radius: 10, y: 5)

                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .frame(width: 44, height: 60)

                // Mini 3x3 Go grid inside the iPad screen
                miniGoGrid
                    .frame(width: 24, height: 24)
            }
            .rotationEffect(.degrees(reduceMotion ? -90 : (isRotatedToLandscape ? -90 : 0)))
        }
        .frame(width: 132, height: 112)
    }

    private var miniGoGrid: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.95, green: 0.80, blue: 0.50))

            Path { path in
                for step in [6.0, 12.0, 18.0] {
                    path.move(to: CGPoint(x: step, y: 4))
                    path.addLine(to: CGPoint(x: step, y: 20))
                    path.move(to: CGPoint(x: 4, y: step))
                    path.addLine(to: CGPoint(x: 20, y: step))
                }
            }
            .stroke(Color(red: 0.36, green: 0.24, blue: 0.10).opacity(0.65), lineWidth: 1)

            Circle()
                .fill(AppTheme.inkPrimary)
                .frame(width: 5.5, height: 5.5)
                .position(x: 12, y: 12)

            Circle()
                .fill(Color.white)
                .overlay(Circle().strokeBorder(AppTheme.inkPrimary.opacity(0.35), lineWidth: 0.8))
                .frame(width: 5.5, height: 5.5)
                .position(x: 18, y: 6)
        }
    }
}

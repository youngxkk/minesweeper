//
//  ParentalGateSupport.swift
//  StarYi Go — Kid-Safe Parental Gate, Localized Legal/Support URLs & Share Sheet
//

import SwiftUI
import UIKit
import Combine

enum AppLegalLinks {
    private static func localePrefix(for language: AppLanguage) -> String {
        switch language.resolvedCode {
        case "zh-Hans": return "/zh-cn"
        case "zh-Hant": return "/zh-tw"
        case "ja": return "/ja"
        case "ko": return "/ko"
        default: return ""
        }
    }

    static func privacyPolicyURL(for language: AppLanguage) -> URL {
        URL(string: "https://maxc.cc\(localePrefix(for: language))/privacy-policy/")!
    }

    static func userAgreementURL(for language: AppLanguage) -> URL {
        URL(string: "https://maxc.cc\(localePrefix(for: language))/user-agreement/")!
    }

    static func termsOfUseURL(for language: AppLanguage) -> URL {
        URL(string: "https://maxc.cc\(localePrefix(for: language))/terms-of-use/")!
    }

    static func supportURL(for language: AppLanguage) -> URL {
        URL(string: "https://maxc.cc\(localePrefix(for: language))/staryi-go/")!
    }

    static var appVersionString: String {
        let shortVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "v\(shortVersion) (\(buildNumber))"
    }
}

struct ParentalGateChallenge: Equatable, Sendable {
    let lhs: Int
    let rhs: Int
    let addend: Int

    var expectedAnswer: Int {
        lhs * rhs + addend
    }

    var expressionText: String {
        "\(lhs) × \(rhs) + \(addend) = ?"
    }

    func matches(_ input: String) -> Bool {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return Int(trimmed) == expectedAnswer
    }

    /// Single-digit × teen number + addend within 50 (e.g. `7 × 16 + 38`):
    /// easy for a parent to do mentally, still beyond a young child.
    static func random() -> ParentalGateChallenge {
        ParentalGateChallenge(
            lhs: Int.random(in: 2...9),
            rhs: Int.random(in: 11...19),
            addend: Int.random(in: 10...50)
        )
    }
}

struct ParentalGateOverlay: View {
    let l10n: L10n
    var title: String? = nil
    var message: String? = nil
    var iconName: String = "lock.shield.fill"
    var accentPalette: GlossyPalette = .sky
    var confirmButtonTitle: String? = nil
    var allowsDismiss: Bool = true
    var onCancel: (() -> Void)? = nil
    let onSuccess: () -> Void

    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var challenge: ParentalGateChallenge = .random()
    @State private var answerText: String = ""
    @State private var showError: Bool = false

    private var resolvedTitle: String {
        title ?? l10n.localized(
            zh: "家长验证",
            en: "Parents Only",
            ja: "保護者確認",
            ko: "보호자 확인",
            zhHant: "家長驗證"
        )
    }

    private var resolvedMessage: String {
        message ?? l10n.localized(
            zh: "为保护小朋友安全，请家长输入下方算术题的结果后再继续：",
            en: "To keep kids safe, please ask a parent to solve this quick math check:",
            ja: "お子様の安全のため、保護者の方が次の計算の答えを入力してください：",
            ko: "어린이 보호를 위해 보호자께서 아래 계산의 답을 입력해 주세요:",
            zhHant: "為保護小朋友安全，請家長輸入下方算術題的結果後再繼續："
        )
    }

    private var resolvedConfirmTitle: String {
        confirmButtonTitle ?? l10n.t("common.ok")
    }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.11, blue: 0.22)
                .opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture {
                    if allowsDismiss {
                        onCancel?()
                    }
                }
                .transition(.opacity)

            VStack(spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [accentPalette.top, accentPalette.bottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 4) {
                    Text(resolvedTitle)
                        .font(AppFont.rounded(size: 20, weight: .black))
                        .foregroundColor(AppTheme.inkPrimary)
                        .multilineTextAlignment(.center)

                    Text(resolvedMessage)
                        .font(AppFont.rounded(size: 13, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(challenge.expressionText)
                    .font(AppFont.rounded(size: 25, weight: .black))
                    .foregroundColor(accentPalette.bottom)
                    .minimumScaleFactor(0.8)
                    .lineLimit(1)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(
                        Capsule().fill(accentPalette.top.opacity(0.14))
                    )
                    .accessibilityIdentifier("ParentalGateExpressionLabel")

                // Tappable Answer Field with embedded cursor
                HStack(spacing: 4) {
                    if answerText.isEmpty {
                        Text(
                            l10n.localized(
                                zh: "输入数字答案",
                                en: "Enter answer",
                                ja: "答えを入力",
                                ko: "답 입력",
                                zhHant: "輸入數字答案"
                            )
                        )
                        .font(AppFont.rounded(size: 16, weight: .bold))
                        .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast).opacity(0.55))
                    } else {
                        Text(answerText)
                            .font(AppFont.rounded(size: 20, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                            .monospacedDigit()
                    }

                    // Blinking friendly cursor
                    RoundedRectangle(cornerRadius: 1)
                        .fill(accentPalette.bottom)
                        .frame(width: 2.5, height: 20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.canvasBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(
                            showError ? AppTheme.coralBottom : accentPalette.bottom,
                            lineWidth: showError ? 2.5 : 1.8
                        )
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    answerText.isEmpty
                        ? l10n.localized(zh: "答案输入框，当前为空", en: "Answer input field, empty", ja: "答え入力欄、空", ko: "답 입력란, 비어있음", zhHant: "答案輸入框，目前為空")
                        : l10n.localized(zh: "答案：\(answerText)", en: "Answer: \(answerText)", ja: "答え：\(answerText)", ko: "답: \(answerText)", zhHant: "答案：\(answerText)")
                )
                .accessibilityIdentifier("ParentalGateAnswerField")

                if showError {
                    Text(
                        l10n.localized(
                            zh: "答案不太对，已换一道新题目，请再试一次。",
                            en: "Not quite right — try this new question.",
                            ja: "答えが違います。新しい問題でもう一度お試しください。",
                            ko: "정답이 아닙니다. 새 문제로 다시 시도해 주세요.",
                            zhHant: "答案不太對，已換一道新題目，請再試一次。"
                        )
                    )
                    .font(AppFont.rounded(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.coralBottom)
                    .multilineTextAlignment(.center)
                }

                // Dedicated Compact Game Number Pad (不会弹出系统大键盘，也不会遮挡或顶出内容)
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 8) {
                            ForEach(1...3, id: \.self) { col in
                                let digit = row * 3 + col
                                numpadKeyButton(label: "\(digit)") {
                                    appendDigit("\(digit)")
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            SoundAndHapticsManager.shared.playUITap(weight: .light)
                            answerText = ""
                        } label: {
                            Text(l10n.localized(zh: "清空", en: "C", ja: "C", ko: "C", zhHant: "清空"))
                                .font(AppFont.rounded(size: 14.5, weight: .heavy))
                                .foregroundColor(AppTheme.inkSecondary(for: colorSchemeContrast))
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(
                            GlossyCapsuleButtonStyle(
                                palette: .snow,
                                cornerRadius: 12,
                                rimHeight: 2,
                                whiteBorderWidth: 1.8,
                                playTapSound: false
                            )
                        )

                        numpadKeyButton(label: "0") {
                            appendDigit("0")
                        }

                        Button {
                            SoundAndHapticsManager.shared.playUITap(weight: .light)
                            if !answerText.isEmpty {
                                answerText.removeLast()
                            }
                        } label: {
                            Image(systemName: "delete.backward.fill")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(AppTheme.coralBottom)
                                .frame(maxWidth: .infinity)
                                .frame(height: 38)
                        }
                        .buttonStyle(
                            GlossyCapsuleButtonStyle(
                                palette: .snow,
                                cornerRadius: 12,
                                rimHeight: 2,
                                whiteBorderWidth: 1.8,
                                playTapSound: false
                            )
                        )
                    }
                }
                .padding(.top, 2)

                HStack(spacing: 12) {
                    if allowsDismiss {
                        Button {
                            SoundAndHapticsManager.shared.playUITap(weight: .light)
                            onCancel?()
                        } label: {
                            Text(l10n.t("common.cancel"))
                                .font(AppFont.rounded(size: 15.5, weight: .black))
                                .foregroundColor(AppTheme.inkPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10.5)
                        }
                        .buttonStyle(
                            GlossyCapsuleButtonStyle(
                                palette: .snow,
                                cornerRadius: 999,
                                rimHeight: 3,
                                whiteBorderWidth: 2.5,
                                playTapSound: false
                            )
                        )
                        .accessibilityIdentifier("ParentalGateCancelButton")
                    }

                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        verifyAnswer()
                    } label: {
                        Text(resolvedConfirmTitle)
                            .font(AppFont.rounded(size: 15.5, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10.5)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: .mint,
                            cornerRadius: 999,
                            rimHeight: 3,
                            whiteBorderWidth: 2.5,
                            playTapSound: false
                        )
                    )
                    .accessibilityIdentifier("ParentalGateConfirmButton")
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
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
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(.white, lineWidth: 3.5)
            )
            .padding(.horizontal, 20)
            .transition(.scale(scale: 0.88).combined(with: .opacity))
        }
        .zIndex(950)
        .accessibilityAddTraits(.isModal)
    }

    private func numpadKeyButton(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(AppFont.rounded(size: 19, weight: .heavy))
                .foregroundColor(AppTheme.inkPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(
            GlossyCapsuleButtonStyle(
                palette: .snow,
                cornerRadius: 12,
                rimHeight: 2,
                whiteBorderWidth: 1.8,
                playTapSound: false
            )
        )
    }

    private func appendDigit(_ digit: String) {
        SoundAndHapticsManager.shared.playUITap(weight: .light)
        if answerText.count < 6 {
            answerText.append(digit)
            showError = false
        }
    }

    private func verifyAnswer() {
        if challenge.matches(answerText) {
            onSuccess()
        } else {
            showError = true
            answerText = ""
            challenge = .random()
        }
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

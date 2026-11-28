//
//  ParentalGateSupport.swift
//  StarYi Go — Kid-Safe Parental Gate, Localized Legal/Support URLs & Share Sheet
//

import SwiftUI
import UIKit

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

struct ParentalGateOverlay: View {
    let l10n: L10n
    let onCancel: () -> Void
    let onSuccess: () -> Void

    @State private var lhs: Int = Int.random(in: 13...27)
    @State private var rhs: Int = Int.random(in: 12...19)
    @State private var answerText: String = ""
    @State private var showError: Bool = false
    @FocusState private var isInputFocused: Bool

    private var expectedAnswer: Int { lhs * rhs }

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.11, blue: 0.22)
                .opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
                .transition(.opacity)

            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AppTheme.skyTop, AppTheme.skyBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                VStack(spacing: 6) {
                    Text(
                        l10n.localized(
                            zh: "家长验证",
                            en: "Parents Only",
                            ja: "保護者確認",
                            ko: "보호자 확인",
                            zhHant: "家長驗證"
                        )
                    )
                    .font(AppFont.rounded(size: 21, weight: .black))
                    .foregroundColor(AppTheme.inkPrimary)

                    Text(
                        l10n.localized(
                            zh: "为保护小朋友安全，请家长输入下方算术题的结果后再继续：",
                            en: "To keep kids safe, please ask a parent to solve this quick math check:",
                            ja: "お子様の安全のため、保護者の方が次の計算の答えを入力してください：",
                            ko: "어린이 보호를 위해 보호자께서 아래 계산의 답을 입력해 주세요:",
                            zhHant: "為保護小朋友安全，請家長輸入下方算術題的結果後再繼續："
                        )
                    )
                    .font(AppFont.rounded(size: 13.5, weight: .bold))
                    .foregroundColor(AppTheme.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text("\(lhs) × \(rhs) = ?")
                    .font(AppFont.rounded(size: 28, weight: .black))
                    .foregroundColor(AppTheme.skyBottom)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(
                        Capsule().fill(AppTheme.skyTop.opacity(0.14))
                    )

                TextField(
                    l10n.localized(
                        zh: "输入数字答案",
                        en: "Enter answer",
                        ja: "答えを入力",
                        ko: "답 입력",
                        zhHant: "輸入數字答案"
                    ),
                    text: $answerText
                )
                .keyboardType(.numberPad)
                .font(AppFont.rounded(size: 18, weight: .heavy))
                .foregroundColor(AppTheme.inkPrimary)
                .multilineTextAlignment(.center)
                .focused($isInputFocused)
                .submitLabel(.done)
                .onSubmit { verifyAnswer() }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AppTheme.canvasBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            showError ? AppTheme.coralBottom : (isInputFocused ? AppTheme.skyBottom : AppTheme.skyTop.opacity(0.25)),
                            lineWidth: (showError || isInputFocused) ? 2.5 : 1.5
                        )
                )

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
                    .font(AppFont.rounded(size: 12, weight: .bold))
                    .foregroundColor(AppTheme.coralBottom)
                    .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button {
                        SoundAndHapticsManager.shared.playUITap(weight: .light)
                        onCancel()
                    } label: {
                        Text(l10n.t("common.cancel"))
                            .font(AppFont.rounded(size: 16, weight: .black))
                            .foregroundColor(AppTheme.inkPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: .snow,
                            cornerRadius: 999,
                            rimHeight: 5,
                            whiteBorderWidth: 3,
                            playTapSound: false
                        )
                    )

                    Button {
                        SoundAndHapticsManager.shared.playUITap()
                        verifyAnswer()
                    } label: {
                        Text(l10n.t("common.ok"))
                            .font(AppFont.rounded(size: 16, weight: .black))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(
                        GlossyCapsuleButtonStyle(
                            palette: .mint,
                            cornerRadius: 999,
                            rimHeight: 5,
                            whiteBorderWidth: 3,
                            playTapSound: false
                        )
                    )
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .frame(maxWidth: 420)
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
            .transition(.scale(scale: 0.88).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isInputFocused = true
                }
            }
        }
        .zIndex(950)
        .accessibilityAddTraits(.isModal)
    }

    private func verifyAnswer() {
        let trimmed = answerText.trimmingCharacters(in: .whitespacesAndNewlines)
        if Int(trimmed) == expectedAnswer {
            isInputFocused = false
            onSuccess()
        } else {
            showError = true
            answerText = ""
            lhs = Int.random(in: 13...27)
            rhs = Int.random(in: 12...19)
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

//
//  L10n.swift
//  StarYi Go
//

import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en = "en"
    case ja = "ja"
    case ko = "ko"

    var id: String { rawValue }

    var resolvedCode: String {
        switch self {
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.hasPrefix("zh-Hant") || preferred.hasPrefix("zh-TW") || preferred.hasPrefix("zh-HK") {
                return "zh-Hant"
            }
            if preferred.hasPrefix("zh") { return "zh-Hans" }
            if preferred.hasPrefix("ja") { return "ja" }
            if preferred.hasPrefix("ko") { return "ko" }
            return "en"
        }
    }

    var isChinese: Bool {
        resolvedCode == "zh-Hans" || resolvedCode == "zh-Hant"
    }

    var isTraditionalChinese: Bool {
        resolvedCode == "zh-Hant"
    }

    var isJapanese: Bool {
        resolvedCode == "ja"
    }

    var isKorean: Bool {
        resolvedCode == "ko"
    }

    var locale: Locale {
        Locale(identifier: resolvedCode)
    }

    var nativeDisplayName: String {
        switch self {
        case .system: return "System"
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }
}

struct L10n: Sendable {
    let language: AppLanguage

    init(language: AppLanguage = .system) {
        self.language = language
    }

    private var bundle: Bundle {
        let code = language.resolvedCode
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let localized = Bundle(path: path) {
            return localized
        }
        if let fallbackPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let fallback = Bundle(path: fallbackPath) {
            return fallback
        }
        return Bundle.main
    }

    func t(_ key: String) -> String {
        let val = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
        if val != "__MISSING__" {
            return val
        }
        // Graceful fallback to English bundle before falling back to key
        if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            let enVal = enBundle.localizedString(forKey: key, value: key, table: nil)
            return enVal
        }
        return key
    }

    func t(_ key: String, _ args: CVarArg...) -> String {
        let format = t(key)
        return String(format: format, locale: language.locale, arguments: args)
    }

    func bilingual(zh: String, en: String) -> String {
        language.isChinese ? zh : en
    }

    func localized(zh: String, en: String, ja: String? = nil, ko: String? = nil, zhHant: String? = nil) -> String {
        switch language.resolvedCode {
        case "zh-Hans": return zh
        case "zh-Hant": return zhHant ?? zh
        case "ja": return ja ?? en
        case "ko": return ko ?? en
        default: return en
        }
    }
}

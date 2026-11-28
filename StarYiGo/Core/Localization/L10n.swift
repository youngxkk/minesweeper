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

    static func resolvedCode(forPreferredLanguages preferredLanguages: [String]) -> String {
        guard let preferred = preferredLanguages.first?.lowercased(), !preferred.isEmpty else {
            return "en"
        }
        if preferred.hasPrefix("zh-hant") || preferred.hasPrefix("zh_hant")
            || preferred.hasPrefix("zh-tw") || preferred.hasPrefix("zh_tw")
            || preferred.hasPrefix("zh-hk") || preferred.hasPrefix("zh_hk")
            || preferred.hasPrefix("zh-mo") || preferred.hasPrefix("zh_mo") {
            return "zh-Hant"
        }
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        if preferred.hasPrefix("ja") { return "ja" }
        if preferred.hasPrefix("ko") { return "ko" }
        // English is the base/default language for all other locales (e.g. es, fr, de, etc.).
        return "en"
    }

    static func voiceLanguageCode(forResolvedCode code: String) -> String {
        let normalized = code.lowercased()
        if normalized.hasPrefix("zh") { return "zh" }
        if normalized.hasPrefix("ja") { return "ja" }
        if normalized.hasPrefix("ko") { return "ko" }
        return "en"
    }

    var resolvedCode: String {
        switch self {
        case .zhHans: return "zh-Hans"
        case .zhHant: return "zh-Hant"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .system:
            return Self.resolvedCode(forPreferredLanguages: Locale.preferredLanguages)
        }
    }

    /// Bundled kid-voice pack code (`"en"`, `"zh"`, `"ja"`, `"ko"`), always defaulting to `"en"`.
    var voiceLanguageCode: String {
        Self.voiceLanguageCode(forResolvedCode: resolvedCode)
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

private final class L10nBundleCache: @unchecked Sendable {
    static let shared = L10nBundleCache()
    private let lock = NSLock()
    private var cache: [String: Bundle] = [:]

    func bundle(for code: String) -> Bundle {
        lock.lock()
        if let existing = cache[code] {
            lock.unlock()
            return existing
        }
        lock.unlock()

        let resolved: Bundle
        if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
           let localized = Bundle(path: path) {
            resolved = localized
        } else if code != "en",
                  let fallbackPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
                  let fallback = Bundle(path: fallbackPath) {
            resolved = fallback
        } else {
            resolved = Bundle.main
        }

        lock.lock()
        cache[code] = resolved
        lock.unlock()
        return resolved
    }
}

struct L10n: Sendable {
    let language: AppLanguage

    init(language: AppLanguage = .system) {
        self.language = language
    }

    private var bundle: Bundle {
        L10nBundleCache.shared.bundle(for: language.resolvedCode)
    }

    func t(_ key: String) -> String {
        let val = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
        if val != "__MISSING__" {
            return val
        }
        // Graceful fallback to English bundle before falling back to key
        let enBundle = L10nBundleCache.shared.bundle(for: "en")
        return enBundle.localizedString(forKey: key, value: key, table: nil)
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

import Foundation

/// App-level display language. Persisted via `SettingsStore` (`language` key);
/// not part of per-profile settings.
enum AppLanguage: String, CaseIterable, Codable, Equatable {
    case system
    case english
    case chinese

    /// Self-describing label shown in the language picker itself
    /// (language names in their own language, per platform convention).
    var title: String {
        switch self {
        case .system:
            return L10n.t("Follow System", "跟随系统")
        case .english:
            return "English"
        case .chinese:
            return "中文"
        }
    }
}

/// Lightweight string resolver. Call sites pass both variants and the current
/// language is resolved at call time, so rebuilt UI picks up language changes
/// immediately.
///
/// The setting is read straight from `UserDefaults` (same key `SettingsStore`
/// writes) so the resolver stays dependency-free and callable from nonisolated
/// contexts (e.g. Carbon hot-key code paths).
enum L10n {
    /// Resolves the effective language: explicit choice wins, `.system` maps to
    /// Chinese when any preferred macOS language is Chinese, else English.
    static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: "language") ?? ""
        let setting = AppLanguage(rawValue: raw) ?? .system
        switch setting {
        case .english:
            return .english
        case .chinese:
            return .chinese
        case .system:
            let isChinesePreferred = Locale.preferredLanguages.contains { preferred in
                let lower = preferred.lowercased()
                return lower.hasPrefix("zh")
            }
            return isChinesePreferred ? .chinese : .english
        }
    }

    static func t(_ en: String, _ zh: String) -> String {
        current == .chinese ? zh : en
    }
}

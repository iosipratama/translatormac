//
//  LanguageCatalog.swift
//  TranslatorMac
//

import AppKit
import Foundation
// LanguageAvailability is not yet Sendable-audited, so Swift 6 rejects passing
// it to its own nonisolated async members. Each instance here is created
// locally, used once, and never shared, so the isolation is sound; drop the
// @preconcurrency once the Translation framework is annotated.
@preconcurrency import Translation

/// A language offered in the pickers: the value handed to the framework, plus
/// the name shown to the person using the app.
struct TranslationLanguage: Identifiable, Hashable, Sendable {
    /// The full language, script and region, as the framework reported it.
    var language: Locale.Language
    /// A short name such as "Danish" or "Chinese (Simplified)".
    var name: String

    var id: String { LanguageCatalog.identifier(for: language) }
}

/// The set of languages the Translation framework supports on this device.
///
/// This replaces the hand-maintained list of display names and the switch that
/// mapped them back to BCP-47 identifiers. Those two lists were maintained
/// independently and could disagree; asking the framework means a language
/// Apple adds in a later OS release shows up without a code change.
enum LanguageCatalog {

    /// Supported languages, collapsed to one entry per language-and-script and
    /// sorted by name.
    ///
    /// The framework reports every regional variant it has a model for — nine
    /// separate Englishes, three Spanishes — which makes the picker unreadable.
    /// Regions are collapsed to a single representative, and a qualifier is
    /// added only where a language genuinely appears in more than one script,
    /// so Chinese reads as "Chinese (Simplified)" and "Chinese (Traditional)"
    /// while everything else is just its own name.
    ///
    /// The calls that touch `LanguageAvailability` stay on the main actor; only
    /// the Sendable results cross out.
    static func supportedLanguages() async -> [TranslationLanguage] {
        let supported = await availability().supportedLanguages
        return catalog(from: supported)
    }

    // MARK: - Which models

    /// Availability for the models chosen in Settings (see `TranslationQuality`).
    ///
    /// The strategy is always passed explicitly. Apps built with the macOS 26.4
    /// SDK or later otherwise default to `.highFidelity`, the Apple Intelligence
    /// models, which report every language as installed — so with Fast chosen,
    /// Settings › Languages would claim all of them are "Ready" and the
    /// download prompts would never appear.
    static func availability() -> LanguageAvailability {
        if #available(macOS 26.4, *) {
            LanguageAvailability(preferredStrategy: TranslationQuality.effective.strategy)
        } else {
            LanguageAvailability()
        }
    }

    /// A session for the pair that uses the same models the availability checks
    /// look at, so a language the menu calls installed is the one that
    /// translates.
    static func configuration(source: Locale.Language?, target: Locale.Language?) -> TranslationSession.Configuration {
        var configuration = TranslationSession.Configuration(source: source, target: target)
        if #available(macOS 26.4, *) {
            configuration.preferredStrategy = TranslationQuality.effective.strategy
        }
        return configuration
    }

    /// Split out from `supportedLanguages()` so the grouping rules don't depend
    /// on the framework being reachable.
    nonisolated static func catalog(from supported: [Locale.Language]) -> [TranslationLanguage] {
        // Which scripts each language code actually appears in. A qualifier is
        // only worth showing when that count is greater than one.
        var scriptsByCode: [String: Set<String>] = [:]
        for language in supported {
            guard let code = language.languageCode?.identifier else { continue }
            scriptsByCode[code, default: []].insert(language.script?.identifier ?? "")
        }

        var representatives: [String: Locale.Language] = [:]
        for language in supported {
            guard language.languageCode != nil else { continue }
            let key = groupKey(for: language)
            if let existing = representatives[key] {
                representatives[key] = preferred(between: existing, and: language, key: key)
            } else {
                representatives[key] = language
            }
        }

        let languages = representatives.map { key, language -> TranslationLanguage in
            let code = language.languageCode?.identifier ?? key
            let needsScript = (scriptsByCode[code]?.count ?? 0) > 1
            return TranslationLanguage(
                language: language,
                name: name(for: language, qualifyByScript: needsScript)
            )
        }

        return languages.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Picks which regional variant stands in for the whole group: the person's
    /// own region when the framework supports it, otherwise the region CLDR
    /// considers standard for that language (en → US, pt → BR, zh-Hant → TW).
    private nonisolated static func preferred(
        between current: Locale.Language,
        and candidate: Locale.Language,
        key: String
    ) -> Locale.Language {
        if let homeRegion = Locale.current.region?.identifier {
            if candidate.region?.identifier == homeRegion { return candidate }
            if current.region?.identifier == homeRegion { return current }
        }

        let standard = Locale.Language(identifier: key).maximalIdentifier
        if identifier(for: candidate) == standard { return candidate }
        if identifier(for: current) == standard { return current }

        // Stable tie-break so the picker doesn't reshuffle between launches.
        return identifier(for: candidate) < identifier(for: current) ? candidate : current
    }

    /// "Danish", or "Chinese (Simplified)" when the script matters.
    ///
    /// Foundation renders a script-qualified identifier as "Chinese, Simplified";
    /// the comma becomes parentheses to match how translation apps present it.
    nonisolated static func name(for language: Locale.Language, qualifyByScript: Bool) -> String {
        let locale = Locale.current
        guard let code = language.languageCode?.identifier else {
            return identifier(for: language)
        }

        guard qualifyByScript, let script = language.script?.identifier else {
            return capitalizedFirst(locale.localizedString(forLanguageCode: code) ?? code)
        }

        let qualified = locale.localizedString(forIdentifier: "\(code)-\(script)")
            ?? locale.localizedString(forLanguageCode: code)
            ?? code
        return capitalizedFirst(parenthesized(qualified))
    }

    /// "Chinese, Simplified" → "Chinese (Simplified)". Names that already carry
    /// their qualifier in parentheses are left alone.
    private nonisolated static func parenthesized(_ name: String) -> String {
        guard let separator = name.range(of: ", ") else { return name }
        let base = name[name.startIndex..<separator.lowerBound]
        let qualifier = name[separator.upperBound...]
        return "\(base) (\(qualifier))"
    }

    private nonisolated static func capitalizedFirst(_ value: String) -> String {
        value.prefix(1).uppercased() + value.dropFirst()
    }

    /// A BCP-47 identifier built from the language's components. This is what
    /// gets persisted, so it keeps the region the framework reported.
    nonisolated static func identifier(for language: Locale.Language) -> String {
        var parts: [String] = []
        if let code = language.languageCode?.identifier { parts.append(code) }
        if let script = language.script?.identifier { parts.append(script) }
        if let region = language.region?.identifier { parts.append(region) }
        return parts.isEmpty ? language.minimalIdentifier : parts.joined(separator: "-")
    }

    /// Identifies the catalog entry a language belongs to, ignoring region, so a
    /// value persisted before the catalog changed still resolves.
    nonisolated static func groupKey(for language: Locale.Language) -> String {
        let code = language.languageCode?.identifier ?? ""
        guard let script = language.script?.identifier else { return code }
        return "\(code)-\(script)"
    }

    nonisolated static func language(forIdentifier id: String) -> Locale.Language {
        Locale.Language(identifier: id)
    }

    /// History stores "auto" when the source was detected but never resolved.
    nonisolated static let automaticIdentifier = "auto"

    /// A display name for a stored identifier, without needing the catalog.
    nonisolated static func name(forIdentifier id: String) -> String {
        let id = normalizedIdentifier(id)
        return id == automaticIdentifier
            ? String(localized: "Detected")
            : fallbackName(for: language(forIdentifier: id))
    }

    /// "EN", "JA": the two-letter code for compact labels.
    nonisolated static func abbreviation(forIdentifier id: String) -> String {
        let id = normalizedIdentifier(id)
        guard id != automaticIdentifier,
              let code = language(forIdentifier: id).languageCode?.identifier else {
            return String(localized: "Auto")
        }
        return code.uppercased()
    }

    /// Versions up to 1.1 stored the menu's display names in history rather
    /// than identifiers. Those names were a fixed English list, so they map
    /// back exactly; anything else is already an identifier.
    nonisolated static func normalizedIdentifier(_ stored: String) -> String {
        legacyNames[stored.lowercased()] ?? stored
    }

    private nonisolated static let legacyNames: [String: String] = [
        "auto": automaticIdentifier,
        "arabic": "ar",
        "chinese (simplified)": "zh-Hans",
        "chinese (traditional)": "zh-Hant",
        "dutch": "nl",
        "english (us)": "en-US",
        "english (uk)": "en-GB",
        "french": "fr",
        "german": "de",
        "hindi": "hi",
        "indonesian": "id",
        "italian": "it",
        "japanese": "ja",
        "korean": "ko",
        "polish": "pl",
        "portuguese (brazil)": "pt-BR",
        "russian": "ru",
        "spanish": "es",
        "thai": "th",
        "turkish": "tr",
        "ukrainian": "uk",
        "vietnamese": "vi",
    ]

    /// A name for a language that isn't in the catalog, such as one read back
    /// from history after the supported set changed.
    ///
    /// Without the catalog there's no way to know which languages appear in
    /// several scripts, so this qualifies only when the script isn't the one
    /// CLDR considers standard: "English", but "Chinese (Traditional)".
    nonisolated static func fallbackName(for language: Locale.Language) -> String {
        guard let code = language.languageCode?.identifier, let script = language.script?.identifier else {
            return name(for: language, qualifyByScript: false)
        }
        let standardScript = Locale.Language(identifier: code).maximalIdentifier
            .split(separator: "-")
            .dropFirst()
            .first
            .map(String.init)
        return name(for: language, qualifyByScript: script != standardScript)
    }

    /// Whether the pair is installed, merely supported, or not supported at all.
    static func status(from source: Locale.Language, to target: Locale.Language) async -> LanguageAvailability.Status {
        await availability().status(from: source, to: target)
    }

    /// Language models are downloaded in System Settings, under Language &
    /// Region → Translation Languages. There is no deeper link than the pane.
    static func openLanguageSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}

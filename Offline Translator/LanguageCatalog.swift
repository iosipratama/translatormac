//
//  LanguageCatalog.swift
//  TranslatorMac
//

import Foundation
// LanguageAvailability is not yet Sendable-audited, so Swift 6 rejects passing
// it to its own nonisolated async members. Each instance here is created
// locally, used once, and never shared, so the isolation is sound; drop the
// @preconcurrency once the Translation framework is annotated.
@preconcurrency import Translation

/// The set of languages the Translation framework supports on this device.
///
/// This replaces the hand-maintained list of display names and the switch that
/// mapped them back to BCP-47 identifiers. Those two lists were maintained
/// independently and could disagree; asking the framework means a language
/// Apple adds in a later OS release shows up without a code change.
enum LanguageCatalog {

    /// Supported languages, deduplicated and sorted by localized display name.
    ///
    /// The calls that touch `LanguageAvailability` stay on the main actor; only
    /// the Sendable results cross out.
    static func supportedLanguages() async -> [Locale.Language] {
        let supported = await LanguageAvailability().supportedLanguages
        var seen: Set<String> = []
        let unique = supported.filter { seen.insert(identifier(for: $0)).inserted }
        return unique.sorted {
            displayName(for: $0).localizedStandardCompare(displayName(for: $1)) == .orderedAscending
        }
    }

    /// A BCP-47 identifier built from the language's components.
    ///
    /// `minimalIdentifier` would collapse regional variants such as en-US and
    /// en-GB onto a single "en", and `maximalIdentifier` adds a script subtag
    /// that makes display names read badly ("English (Latin, United States)").
    nonisolated static func identifier(for language: Locale.Language) -> String {
        var parts: [String] = []
        if let code = language.languageCode?.identifier { parts.append(code) }
        if let script = language.script?.identifier { parts.append(script) }
        if let region = language.region?.identifier { parts.append(region) }
        return parts.isEmpty ? language.minimalIdentifier : parts.joined(separator: "-")
    }

    /// A localized, user-facing name such as "Chinese (Simplified)".
    nonisolated static func displayName(for language: Locale.Language) -> String {
        let id = identifier(for: language)
        guard let name = Locale.current.localizedString(forIdentifier: id) else { return id }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    nonisolated static func language(forIdentifier id: String) -> Locale.Language {
        Locale.Language(identifier: id)
    }

    /// Whether the pair is installed, merely supported, or not supported at all.
    static func status(from source: Locale.Language?, to target: Locale.Language) async -> LanguageAvailability.Status? {
        guard let source else { return nil }
        return await LanguageAvailability().status(from: source, to: target)
    }
}

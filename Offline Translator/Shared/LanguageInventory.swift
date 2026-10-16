//
//  LanguageInventory.swift
//  TranslatorMac
//

import Foundation
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Which of the framework's languages are on this Mac, and a way to download
/// one. Shared by Settings and the first-launch flow.
///
/// The framework only reports whether a *pair* is installed, so each language
/// is checked against the Mac's own language, and that one against English.
@Observable
final class LanguageInventory {

    struct Entry: Identifiable {
        var catalog: TranslationLanguage
        /// The language's name in itself, empty when it matches `name`.
        var nativeName: String
        var isInstalled: Bool

        var id: String { catalog.id }
        var name: String { catalog.name }
        var language: Locale.Language { catalog.language }

        /// The native name, marked with its language so VoiceOver reads
        /// 日本語 in Japanese rather than spelling it out in English.
        var spokenNativeName: AttributedString {
            var text = AttributedString(nativeName)
            text.languageIdentifier = LanguageCatalog.identifier(for: language)
            return text
        }
    }

    /// Every supported language, in catalog order. Empty until loaded.
    private(set) var entries: [Entry] = []
    var isLoading: Bool { entries.isEmpty }

    /// The Mac's own language, resolved to the catalog.
    private(set) var deviceLanguage: Locale.Language?

    /// The pair a download prompt is for; a view's translationTask drives it.
    private(set) var configuration: TranslationSession.Configuration?
    private var queue: [Locale.Language] = []
    private(set) var downloading: Locale.Language?

    private var catalog: [TranslationLanguage] = []

    // MARK: - Status

    /// Loads the catalog if needed and re-checks what's installed.
    func refresh() async {
        if catalog.isEmpty {
            catalog = await LanguageCatalog.supportedLanguages()
            guard !catalog.isEmpty else { return }
            deviceLanguage = resolve(Locale.current.language)
        }

        var built: [Entry] = []
        for item in catalog {
            let status = await LanguageCatalog.status(from: item.language, to: partner(for: item.language))
            built.append(Entry(
                catalog: item,
                nativeName: Self.nativeName(for: item),
                isInstalled: status == .installed
            ))
        }

        // The Mac's own language is the other half of every pair checked
        // above, so it's on this Mac whenever any of them is. Its own check
        // had to pick some other partner, which may be one that isn't
        // downloaded: on an English Mac, English was checked against Arabic.
        if let device = deviceLanguage,
           let index = built.firstIndex(where: { $0.language == device }),
           built.contains(where: \.isInstalled) {
            built[index].isInstalled = true
        }
        entries = built
    }

    /// Starts over from the catalog, for when the models in use change.
    func reload() async {
        catalog = []
        entries = []
        await refresh()
    }

    func entry(for language: Locale.Language) -> Entry? {
        entries.first { $0.language == language }
    }

    /// Finds the catalog entry representing a language, ignoring region.
    func resolve(_ language: Locale.Language) -> Locale.Language? {
        let key = LanguageCatalog.groupKey(for: language)
        if let exact = catalog.first(where: { LanguageCatalog.groupKey(for: $0.language) == key }) {
            return exact.language
        }
        guard let code = language.languageCode?.identifier else { return nil }
        return catalog.first { $0.language.languageCode?.identifier == code }?.language
    }

    /// The other half of the pair to check or download with a language: the
    /// Mac's own language, or English when the language is the Mac's.
    private func partner(for language: Locale.Language) -> Locale.Language {
        if let device = deviceLanguage, device != language { return device }
        return catalog.first { $0.language.languageCode?.identifier == "en" && $0.language != language }?.language
            ?? catalog.first { $0.language != language }?.language
            ?? language
    }

    /// "日本語", "Español"; empty for English, whose own name is the one shown.
    /// The script is only mentioned where the catalog mentions it, so English
    /// doesn't become "English (Latin)".
    private static func nativeName(for entry: TranslationLanguage) -> String {
        let language = entry.language
        let own = Locale(identifier: LanguageCatalog.identifier(for: language))
        guard let code = language.languageCode?.identifier else { return "" }

        let name: String?
        if entry.name.contains("("), let script = language.script?.identifier {
            name = own.localizedString(forIdentifier: "\(code)-\(script)")
        } else {
            name = own.localizedString(forLanguageCode: code)
        }
        guard let name else { return "" }
        let value = name.prefix(1).uppercased() + name.dropFirst()
        return value.caseInsensitiveCompare(entry.name) == .orderedSame ? "" : value
    }

    // MARK: - Downloads

    /// Queues the system download prompt for a language.
    func download(_ language: Locale.Language) {
        guard !queue.contains(language), downloading != language else { return }
        queue.append(language)
        advanceQueue()
    }

    func isDownloading(_ language: Locale.Language) -> Bool {
        downloading == language || queue.contains(language)
    }

    var isDownloadingAnything: Bool {
        downloading != nil
    }

    private func advanceQueue() {
        guard downloading == nil, !queue.isEmpty else { return }
        let next = queue.removeFirst()
        downloading = next

        let desired = LanguageCatalog.configuration(source: partner(for: next), target: next)
        if var current = configuration, current.source == desired.source, current.target == desired.target {
            current.invalidate()
            configuration = current
        } else {
            configuration = desired
        }
    }

    /// Called by a view's translationTask for each configuration. Returns
    /// whether the language is installed afterwards.
    @discardableResult
    func prepare(using session: TranslationSession) async -> Bool {
        guard let language = downloading else { return false }
        var succeeded = false
        do {
            try await session.prepareTranslation()
            succeeded = true
        } catch {
            // Declined or failed; the row stays downloadable.
        }
        if let index = entries.firstIndex(where: { $0.language == language }) {
            entries[index].isInstalled = succeeded || entries[index].isInstalled
        }
        downloading = nil
        advanceQueue()
        return succeeded
    }
}

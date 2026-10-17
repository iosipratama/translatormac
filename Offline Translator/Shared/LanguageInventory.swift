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

    /// Languages whose download the person accepted in iOS's sheet but that
    /// aren't finished yet. iOS reports the sheet as done as soon as the
    /// download starts, so these are checked until iOS says they're here.
    private(set) var inBackground: Set<Locale.Language> = []
    private var watchTask: Task<Void, Never>?

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
        // Downloads that finished while nobody was checking.
        inBackground = inBackground.filter { language in
            entries.first { $0.language == language }?.isInstalled != true
        }
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
    static func nativeName(for entry: TranslationLanguage) -> String {
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

    /// Waiting for its prompt, showing it, or downloading after it.
    func isDownloading(_ language: Locale.Language) -> Bool {
        downloading == language || queue.contains(language) || inBackground.contains(language)
    }

    /// Showing iOS's prompt, or downloading after it; not just waiting.
    func isActivelyDownloading(_ language: Locale.Language) -> Bool {
        downloading == language || inBackground.contains(language)
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
    /// whether the download went ahead: it may still be running, so a
    /// language only counts as installed once iOS confirms it.
    ///
    /// A pair that's already downloaded skips iOS's sheet entirely.
    @discardableResult
    func prepare(using session: TranslationSession) async -> Bool {
        guard let language = downloading else { return false }
        var accepted = false
        if await isInstalled(language) {
            accepted = true
        } else {
            do {
                try await session.prepareTranslation()
                accepted = true
            } catch {
                // Declined or failed; the row stays downloadable.
            }
        }
        if accepted {
            if await isInstalled(language) {
                markInstalled(language)
            } else {
                inBackground.insert(language)
                watchBackgroundDownloads()
            }
        }
        downloading = nil
        advanceQueue()
        return accepted
    }

    /// Whether iOS has the language's pair with its partner on this iPhone.
    func isInstalled(_ language: Locale.Language) async -> Bool {
        await LanguageCatalog.status(from: partner(for: language), to: language) == .installed
    }

    /// Checks the downloads still running, as when the app comes back.
    func refreshBackgroundDownloads() async {
        for language in inBackground where await isInstalled(language) {
            markInstalled(language)
        }
    }

    private func markInstalled(_ language: Locale.Language) {
        inBackground.remove(language)
        if let index = entries.firstIndex(where: { $0.language == language }) {
            entries[index].isInstalled = true
        }
    }

    /// Checks every few seconds until the accepted downloads are all here.
    private func watchBackgroundDownloads() {
        guard watchTask == nil else { return }
        watchTask = Task { [weak self] in
            while let self, !self.inBackground.isEmpty, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await self.refreshBackgroundDownloads()
            }
            self?.watchTask = nil
        }
    }
}

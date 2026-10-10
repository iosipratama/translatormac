//
//  OnboardingModel.swift
//  TranslatorMac
//

import Foundation
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// State for the first-launch flow: which step is showing, which languages
/// the person wants, and how their downloads went.
@Observable
final class OnboardingModel {

    static let didFinishKey = "didFinishOnboarding"

    static var didFinish: Bool {
        UserDefaults.standard.bool(forKey: didFinishKey)
    }

    enum Step: Int, CaseIterable {
        case welcome
        case languages
        case allSet
    }

    /// A language as the chooser shows it.
    struct Choice: Identifiable {
        var entry: TranslationLanguage
        var nativeName: String
        var isInstalled: Bool
        /// One of the Mac's preferred languages, so checked by default.
        var isPreferred: Bool

        var id: String { entry.id }
        var language: Locale.Language { entry.language }
    }

    enum DownloadResult {
        case ready
        case notDownloaded
    }

    private(set) var step: Step = .welcome

    /// Every language the framework supports, installed and preferred ones
    /// first. Empty until loaded.
    private(set) var choices: [Choice] = []
    var isLoadingChoices: Bool { choices.isEmpty }

    /// How many rows to show before "Show all languages…".
    static let shortListCount = 6
    var showsAllLanguages = false

    var visibleChoices: [Choice] {
        showsAllLanguages ? choices : Array(choices.prefix(Self.shortListCount))
    }

    /// Languages ticked for download, by catalog id.
    var selection: Set<String> = []

    var selectedCount: Int {
        selection.count
    }

    /// The pair the download prompt is for; the window's translationTask
    /// drives it.
    private(set) var configuration: TranslationSession.Configuration?
    private var downloadQueue: [Locale.Language] = []
    private var downloading: Locale.Language?

    /// The outcome per requested language, in the order they were requested.
    private(set) var requested: [Locale.Language] = []
    private(set) var results: [Locale.Language: DownloadResult] = [:]

    /// The first language that downloaded, for the main window's default pair.
    private(set) var firstDownloaded: Locale.Language?

    /// The Mac's own language, resolved to the catalog.
    private(set) var deviceLanguage: Locale.Language?

    // MARK: - Steps

    func goBack() {
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    func continueFromWelcome() {
        step = .languages
    }

    // MARK: - Languages

    func loadChoices() async {
        guard choices.isEmpty else { return }
        let catalog = await LanguageCatalog.supportedLanguages()
        guard !catalog.isEmpty else { return }

        let device = resolve(Locale.current.language, in: catalog)
        deviceLanguage = device

        // Installed is a property of pairs, so each language is checked
        // against the Mac's own language, and that one against English.
        let english = catalog.first { $0.language.languageCode?.identifier == "en" }?.language
        let pivot = device ?? english ?? catalog[0].language

        let preferred = Set(Locale.preferredLanguages.compactMap {
            resolve(Locale.Language(identifier: $0), in: catalog).map(LanguageCatalog.identifier(for:))
        })

        var built: [Choice] = []
        for entry in catalog {
            let partner = entry.language == pivot ? (english ?? catalog.first { $0.language != pivot }?.language ?? pivot) : pivot
            let status = await LanguageCatalog.status(from: entry.language, to: partner)
            built.append(Choice(
                entry: entry,
                nativeName: Self.nativeName(for: entry),
                isInstalled: status == .installed,
                isPreferred: preferred.contains(entry.id)
            ))
        }

        // The Mac's own languages that still need downloading come first —
        // they're the ones checked by default — then what's already here,
        // then everything else in catalog order.
        func rank(_ choice: Choice) -> Int {
            if choice.isPreferred && !choice.isInstalled { return 0 }
            if choice.isInstalled { return 1 }
            return 2
        }
        built.sort { rank($0) < rank($1) }
        choices = built
        selection = Set(built.filter { $0.isPreferred && !$0.isInstalled }.map(\.id))
    }

    private func resolve(_ language: Locale.Language, in catalog: [TranslationLanguage]) -> Locale.Language? {
        let key = LanguageCatalog.groupKey(for: language)
        if let exact = catalog.first(where: { LanguageCatalog.groupKey(for: $0.language) == key }) {
            return exact.language
        }
        guard let code = language.languageCode?.identifier else { return nil }
        return catalog.first { $0.language.languageCode?.identifier == code }?.language
    }

    /// The language's name in itself: "日本語", "Español". Empty when it's the
    /// same as the name already shown. The script is only mentioned where the
    /// catalog mentions it, so English doesn't become "English (Latin)".
    private static func nativeName(for entry: TranslationLanguage) -> String {
        let language = entry.language
        let identifier = LanguageCatalog.identifier(for: language)
        let own = Locale(identifier: identifier)
        guard let code = language.languageCode?.identifier else { return "" }

        let qualifiesScript = entry.name.contains("(")
        let name: String?
        if qualifiesScript, let script = language.script?.identifier {
            name = own.localizedString(forIdentifier: "\(code)-\(script)")
        } else {
            name = own.localizedString(forLanguageCode: code)
        }
        guard let name else { return "" }
        let value = name.prefix(1).uppercased() + name.dropFirst()
        return value.caseInsensitiveCompare(entry.name) == .orderedSame ? "" : value
    }

    func toggle(_ choice: Choice) {
        if selection.contains(choice.id) {
            selection.remove(choice.id)
        } else {
            selection.insert(choice.id)
        }
    }

    // MARK: - Downloads

    /// Starts the system download prompt for each selected language in turn.
    func startDownloads() {
        requested = choices.filter { selection.contains($0.id) }.map(\.language)
        results = [:]
        downloadQueue = requested
        step = .allSet
        advanceQueue()
    }

    func retry(_ language: Locale.Language) {
        results[language] = nil
        downloadQueue.append(language)
        if downloading == nil {
            advanceQueue()
        }
    }

    private func advanceQueue() {
        guard downloading == nil, let next = downloadQueue.first else { return }
        downloadQueue.removeFirst()
        downloading = next

        let desired = TranslationSession.Configuration(source: partner(for: next), target: next)
        if var current = configuration, current.source == desired.source, current.target == desired.target {
            current.invalidate()
            configuration = current
        } else {
            configuration = desired
        }
    }

    /// The other half of the pair to download with a language: the Mac's own
    /// language, or English when the language is the Mac's.
    private func partner(for language: Locale.Language) -> Locale.Language? {
        if let device = deviceLanguage, device != language { return device }
        return choices.first { $0.language.languageCode?.identifier == "en" && $0.language != language }?.language
            ?? choices.first { $0.language != language }?.language
    }

    /// Called by the window's translationTask for each configuration.
    func prepare(using session: TranslationSession) async {
        guard let language = downloading else { return }
        do {
            try await session.prepareTranslation()
            results[language] = .ready
            if firstDownloaded == nil { firstDownloaded = language }
        } catch {
            // Declined or failed; the all-set step offers another go.
            results[language] = .notDownloaded
        }
        downloading = nil
        advanceQueue()
    }

    var isDownloading: Bool {
        downloading != nil
    }

    /// Languages still being prepared show no result yet.
    func result(for language: Locale.Language) -> DownloadResult? {
        results[language]
    }

    func name(for language: Locale.Language) -> String {
        choices.first { $0.language == language }?.entry.name
            ?? LanguageCatalog.fallbackName(for: language)
    }

    // MARK: - Finishing

    /// Records completion and the pair the translate screen should open with.
    func finish() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.didFinishKey)

        guard let target = firstDownloaded else { return }
        if let device = deviceLanguage, device != target {
            defaults.set(LanguageCatalog.identifier(for: device), forKey: "sourceLanguage")
        } else {
            defaults.removeObject(forKey: "sourceLanguage")
        }
        defaults.set(LanguageCatalog.identifier(for: target), forKey: "targetLanguage")
    }
}

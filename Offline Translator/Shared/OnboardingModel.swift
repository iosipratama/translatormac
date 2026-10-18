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
        var entry: LanguageInventory.Entry
        /// One of the Mac's preferred languages, so checked by default.
        var isPreferred: Bool

        var id: String { entry.id }
        var name: String { entry.name }
        var nativeName: String { entry.nativeName }
        var isInstalled: Bool { entry.isInstalled }
        var language: Locale.Language { entry.language }
    }

    enum DownloadResult {
        case ready
        case notDownloaded
    }

    private(set) var step: Step = .welcome

    let inventory = LanguageInventory()

    /// Every language the framework supports, the useful ones first. Empty
    /// until loaded.
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

    /// The languages asked for, in order.
    private(set) var requested: [Locale.Language] = []
    /// Languages whose download was declined or failed. Readiness comes from
    /// the inventory, which only says installed once iOS confirms it.
    private var failures: Set<Locale.Language> = []

    /// The first requested language that's really here, for the opening pair.
    var firstDownloaded: Locale.Language? {
        requested.first { inventory.entry(for: $0)?.isInstalled == true }
    }

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
        await inventory.refresh()
        guard !inventory.entries.isEmpty else { return }

        let preferred = Set(Locale.preferredLanguages.compactMap {
            inventory.resolve(Locale.Language(identifier: $0)).map(LanguageCatalog.identifier(for:))
        })

        var built = inventory.entries.map { entry in
            Choice(entry: entry, isPreferred: preferred.contains(entry.id))
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
        failures = []
        step = .allSet
        for language in requested {
            inventory.download(language)
        }
    }

    func retry(_ language: Locale.Language) {
        failures.remove(language)
        inventory.download(language)
    }

    /// Called by the window's translationTask for each configuration.
    func prepare(using session: TranslationSession) async {
        guard let language = inventory.downloading else { return }
        let accepted = await inventory.prepare(using: session)
        if !accepted {
            failures.insert(language)
        }
    }

    var isDownloading: Bool {
        inventory.isDownloadingAnything
    }

    /// At least one requested language didn't download.
    var hasFailedDownloads: Bool {
        !failures.isEmpty
    }

    /// Languages still being prepared or downloading show no result yet.
    func result(for language: Locale.Language) -> DownloadResult? {
        if failures.contains(language) { return .notDownloaded }
        if inventory.entry(for: language)?.isInstalled == true { return .ready }
        return nil
    }

    /// Every requested language has finished one way or the other.
    var isFinished: Bool {
        requested.allSatisfy { result(for: $0) != nil }
    }

    func name(for language: Locale.Language) -> String {
        inventory.entry(for: language)?.name ?? LanguageCatalog.fallbackName(for: language)
    }

    /// The language each new one downloads with, since iOS only downloads
    /// pairs: the device's own language, or English when it's the one chosen.
    func partner(for language: Locale.Language) -> Locale.Language {
        inventory.partner(for: language)
    }

    /// The device's own language, the usual other half of every pair.
    var baseLanguageName: String? {
        inventory.deviceLanguage.map(name(for:))
    }

    // MARK: - Finishing

    /// Records completion and the pair the translate screen should open with.
    func finish() {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: Self.didFinishKey)

        guard let target = firstDownloaded else { return }
        if let device = inventory.deviceLanguage, device != target {
            defaults.set(LanguageCatalog.identifier(for: device), forKey: "sourceLanguage")
        } else {
            defaults.removeObject(forKey: "sourceLanguage")
        }
        defaults.set(LanguageCatalog.identifier(for: target), forKey: "targetLanguage")
    }
}

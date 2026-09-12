//
//  TranslationModel.swift
//  TranslatorMac
//

import Foundation
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// State and rules for the translate screen, kept out of the view.
@Observable
final class TranslationModel {

    /// One value for what the screen is doing, so a result and an error message
    /// can't both be live at once — previously an error was written into the
    /// same string as a translation and could be saved to history.
    enum Phase: Equatable {
        case idle
        case translating
        case translated(String)
        case failed(String)

        var translation: String? {
            if case .translated(let text) = self { return text }
            return nil
        }

        var errorMessage: String? {
            if case .failed(let message) = self { return message }
            return nil
        }

        var isTranslating: Bool { self == .translating }
    }

    private enum DefaultsKey {
        static let source = "sourceLanguage"
        static let target = "targetLanguage"
    }

    /// Loaded from the framework on appear; empty until then.
    var supportedLanguages: [TranslationLanguage] = []

    var isLoadingLanguages: Bool { supportedLanguages.isEmpty }

    var inputText = "" {
        didSet {
            guard trimmedInput.isEmpty, !phase.isTranslating else { return }
            phase = .idle
        }
    }

    var phase: Phase = .idle

    /// `nil` means "detect automatically". The framework does the detection when
    /// a configuration carries no source language, which is why this app no
    /// longer links NaturalLanguage or applies its own confidence threshold.
    var sourceLanguage: Locale.Language? {
        didSet {
            guard sourceLanguage != oldValue else { return }
            store(sourceLanguage, forKey: DefaultsKey.source)
            invalidateResult()
        }
    }

    var targetLanguage: Locale.Language {
        didSet {
            guard targetLanguage != oldValue else { return }
            store(targetLanguage, forKey: DefaultsKey.target)
            invalidateResult()
        }
    }

    /// Whether the selected pair needs downloading before it can be used.
    var availability: LanguageAvailability.Status?

    init() {
        let defaults = UserDefaults.standard
        sourceLanguage = defaults.string(forKey: DefaultsKey.source)
            .map(LanguageCatalog.language(forIdentifier:))
        targetLanguage = defaults.string(forKey: DefaultsKey.target)
            .map(LanguageCatalog.language(forIdentifier:))
            ?? Locale.current.language
    }

    /// `LanguageAvailability.supportedLanguages` is async, so the pickers start
    /// empty and fill in once the framework answers.
    func loadSupportedLanguages() async {
        let languages = await LanguageCatalog.supportedLanguages()
        supportedLanguages = languages

        // A Picker shows no selection when the bound value matches none of its
        // tags, so both ends have to be pinned to an entry that is really in the
        // catalog. The stored value may differ from the catalog entry only by
        // region — either from an earlier launch, or because the device language
        // carries a region the framework has no model for.
        targetLanguage = resolve(targetLanguage)
            ?? resolve(Locale.current.language)
            ?? languages.first { $0.language.languageCode?.identifier == "en" }?.language
            ?? languages.first?.language
            ?? targetLanguage

        if let source = sourceLanguage {
            sourceLanguage = resolve(source)
        }
    }

    /// Finds the catalog entry representing a language, ignoring region.
    private func resolve(_ language: Locale.Language) -> Locale.Language? {
        let key = LanguageCatalog.groupKey(for: language)
        if let exact = supportedLanguages.first(where: { LanguageCatalog.groupKey(for: $0.language) == key }) {
            return exact.language
        }
        // A stored value may have no script where the catalog entry has one.
        guard let code = language.languageCode?.identifier else { return nil }
        return supportedLanguages.first { $0.language.languageCode?.identifier == code }?.language
    }

    func name(for language: Locale.Language) -> String {
        supportedLanguages.first { $0.language == language }?.name
            ?? LanguageCatalog.fallbackName(for: language)
    }

    var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canTranslate: Bool {
        !trimmedInput.isEmpty && !phase.isTranslating
    }

    /// Swapping is only meaningful when both ends are known languages.
    var canSwapLanguages: Bool {
        sourceLanguage != nil
    }

    func swapLanguages() {
        guard let source = sourceLanguage else { return }
        let translation = phase.translation
        sourceLanguage = targetLanguage
        targetLanguage = source
        // Carry the previous result across so the swap reads as a continuation.
        if let translation { inputText = translation }
    }

    func refreshAvailability() async {
        availability = await LanguageCatalog.status(from: sourceLanguage, to: targetLanguage)
    }

    private func invalidateResult() {
        if !phase.isTranslating { phase = .idle }
    }

    private func store(_ language: Locale.Language?, forKey key: String) {
        let defaults = UserDefaults.standard
        if let language {
            defaults.set(LanguageCatalog.identifier(for: language), forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}

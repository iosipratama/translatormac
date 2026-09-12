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
    var supportedLanguages: [Locale.Language] = []

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

    /// `LanguageAvailability.supportedLanguages` is async, so the picker starts
    /// empty and fills in once the framework answers.
    func loadSupportedLanguages() async {
        let languages = await LanguageCatalog.supportedLanguages()
        supportedLanguages = languages

        // Fall back if the persisted target is no longer offered, or if this is
        // a first launch and the device language isn't translatable.
        let identifiers = Set(languages.map(LanguageCatalog.identifier(for:)))
        if !identifiers.contains(LanguageCatalog.identifier(for: targetLanguage)) {
            targetLanguage = languages.first { $0.languageCode == Locale.current.language.languageCode }
                ?? languages.first { $0.languageCode?.identifier == "en" }
                ?? languages.first
                ?? targetLanguage
        }
        if let source = sourceLanguage,
           !identifiers.contains(LanguageCatalog.identifier(for: source)) {
            sourceLanguage = nil
        }
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

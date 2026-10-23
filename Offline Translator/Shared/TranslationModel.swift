//
//  TranslationModel.swift
//  TranslatorMac
//

import Foundation
import SwiftData
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation
import os

/// State and rules for the translate screen, kept out of the view.
///
/// Translation is live: the screen translates shortly after typing pauses,
/// keeps the previous result visible while the next one is in flight, and
/// once the person has settled on a translation, counts it toward the free
/// plan's daily limit and records it to Recent.
///
/// A translation is finished, and counts, the first time any of these
/// happens to a result: ⌘⏎ (Done on iPhone), Copy, Speak, Save, showing it
/// to someone, or typing pausing for 2 seconds. Each text counts once,
/// however much it's edited; a new text starts when the old one is cleared
/// or replaced in one go (see `TextSession`). Changing or swapping languages
/// and opening an entry from Recent don't count again.
@Observable
final class TranslationModel {

    /// What the result pane shows. One value, so a result and an error message
    /// can't both be live at once.
    enum Outcome: Equatable {
        case translated(TranslationResult)
        case failed(TranslationFailure)

        var result: TranslationResult? {
            if case .translated(let result) = self { return result }
            return nil
        }
    }

    private enum DefaultsKey {
        static let source = "sourceLanguage"
        static let target = "targetLanguage"
    }

    private enum Timing {
        /// How long typing has to pause before translating.
        static let debounce: Duration = .milliseconds(400)
        /// How long a translation can take before the screen says so.
        static let indicatorDelay: Duration = .milliseconds(300)
        /// How long typing has to pause before the translation counts as made.
        static let pauseBeforeRecording: Duration = .seconds(2)
        static let copiedFeedback: Duration = .seconds(1.5)
    }

    private let modelContext: ModelContext
    private let purchases: PurchaseStore

    /// Owned here so the Translation menu can reach it through the model.
    @ObservationIgnored private(set) lazy var speaker = TranslationSpeaker()

    // MARK: Languages

    /// Loaded from the framework on appear; empty until then.
    private(set) var supportedLanguages: [TranslationLanguage] = []

    var isLoadingLanguages: Bool { supportedLanguages.isEmpty }

    /// `nil` means "detect automatically". The framework does the detection when
    /// a configuration carries no source language.
    var sourceLanguage: Locale.Language? {
        didSet {
            guard sourceLanguage != oldValue, !isAdjustingLanguages else { return }
            // Choosing the current target as the source swaps the pair.
            if let source = sourceLanguage, source == targetLanguage {
                isAdjustingLanguages = true
                targetLanguage = oldValue ?? alternativeTarget(to: source)
                isAdjustingLanguages = false
            }
            languagesDidChange()
        }
    }

    var targetLanguage: Locale.Language {
        didSet {
            guard targetLanguage != oldValue, !isAdjustingLanguages else { return }
            // Choosing the current source as the target swaps the pair.
            if targetLanguage == sourceLanguage {
                isAdjustingLanguages = true
                sourceLanguage = oldValue
                isAdjustingLanguages = false
            }
            languagesDidChange()
        }
    }

    /// Set while the pair is being changed as a unit, so the `didSet` rules
    /// above don't react to the intermediate state.
    private var isAdjustingLanguages = false

    /// Per-language availability for the two menus, relative to the language
    /// chosen on the other side. Empty until the first check finishes.
    private(set) var sourceStatuses: [Locale.Language: LanguageAvailability.Status] = [:]
    private(set) var targetStatuses: [Locale.Language: LanguageAvailability.Status] = [:]

    /// Set when the person picks a language, so the next availability check
    /// can offer the download prompt for a pair that isn't installed. Not set
    /// at launch: a restored pair shouldn't prompt before anyone types.
    private var wantsDownloadCheck = false

    /// Ask the session to download the pair before translating.
    private var needsPreparation = false

    // MARK: Text

    var inputText = "" {
        didSet { inputDidChange(from: oldValue) }
    }

    var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private(set) var outcome: Outcome?

    /// A translation of the current text is in flight. The previous result
    /// stays on screen, dimmed, until it arrives.
    private(set) var isTranslating = false

    /// Shown only once a translation has taken noticeably long, so quick ones
    /// don't flash a label.
    private(set) var showsTranslatingIndicator = false

    /// Driving translation through a configuration rather than constructing a
    /// `TranslationSession` directly lets the framework prompt to download a
    /// missing language pair instead of failing with an error.
    private(set) var configuration: TranslationSession.Configuration?

    /// Identifies the latest request, so a slow translation that finishes
    /// after a newer one started can't overwrite the newer result.
    private var requestID = 0

    private var debounceTask: Task<Void, Never>?
    private var indicatorTask: Task<Void, Never>?
    private var recordTask: Task<Void, Never>?
    private var copiedTask: Task<Void, Never>?

    // MARK: Recent

    /// The Recent record for what's on screen. One record per editing session,
    /// updated in place as the text settles, so Recent doesn't fill up with
    /// every pause while typing.
    private(set) var currentRecord: TranslationHistory?

    /// A pause ended before the translation arrived; record it when it does.
    private var wantsRecord = false

    /// Whether this text has been counted toward the free plan's daily
    /// limit. Live translation re-translates on every pause, so counting per
    /// request would burn the allowance while typing one sentence.
    private var sessionCounted = false

    private(set) var justCopied = false

    // MARK: - Setup

    init(modelContext: ModelContext, purchases: PurchaseStore) {
        self.modelContext = modelContext
        self.purchases = purchases

        let defaults = UserDefaults.standard
        sourceLanguage = defaults.string(forKey: DefaultsKey.source)
            .map(LanguageCatalog.language(forIdentifier:))
        targetLanguage = defaults.string(forKey: DefaultsKey.target)
            .map(LanguageCatalog.language(forIdentifier:))
            ?? Locale.current.language
    }

    /// `LanguageAvailability.supportedLanguages` is async, so the menus start
    /// empty and fill in once the framework answers.
    func loadSupportedLanguages() async {
        guard supportedLanguages.isEmpty else { return }
        let languages = await LanguageCatalog.supportedLanguages()
        supportedLanguages = languages

        // A menu shows no selection when the bound value matches none of its
        // entries, so both ends have to be pinned to an entry that is really in
        // the catalog. The stored value may differ from the catalog entry only
        // by region — either from an earlier launch, or because the device
        // language carries a region the framework has no model for.
        isAdjustingLanguages = true
        targetLanguage = resolve(targetLanguage)
            ?? resolve(Locale.current.language)
            ?? languages.first { $0.language.languageCode?.identifier == "en" }?.language
            ?? languages.first?.language
            ?? targetLanguage
        if let source = sourceLanguage {
            sourceLanguage = resolve(source)
        }
        isAdjustingLanguages = false
        storeLanguages()
    }

    /// Picks a pair when none was chosen yet, as on a first iPhone launch:
    /// from the device's language to the first other language whose pair is
    /// already downloaded, so the first translation works offline. The Mac
    /// keeps Detect Language instead, so only the iPhone calls this.
    func chooseStartingPair() async {
        guard sourceLanguage == nil, !supportedLanguages.isEmpty else { return }
        let english = supportedLanguages.first { $0.language.languageCode?.identifier == "en" }?.language
        guard let source = resolve(Locale.current.language) ?? english ?? supportedLanguages.first?.language else { return }

        var target: Locale.Language?
        if targetLanguage != source, UserDefaults.standard.string(forKey: DefaultsKey.target) != nil {
            // A target chosen earlier stays.
            target = targetLanguage
        } else {
            for entry in supportedLanguages where entry.language != source {
                if await LanguageCatalog.status(from: source, to: entry.language) == .installed {
                    target = entry.language
                    break
                }
            }
        }
        // Nothing downloaded yet: a widely used language, to be downloaded
        // on first use.
        let spanish = supportedLanguages.first { $0.language.languageCode?.identifier == "es" }?.language
        target = target ?? (source == english ? spanish : english)
        guard sourceLanguage == nil, let target, target != source else { return }

        isAdjustingLanguages = true
        sourceLanguage = source
        targetLanguage = target
        isAdjustingLanguages = false
        storeLanguages()
    }

    /// Settings › General › Quality changed. The other models support a
    /// different set of languages and report different ones as installed, so
    /// start again from the catalog and translate what's on screen again.
    func translationQualityDidChange() async {
        configuration = nil
        sourceStatuses = [:]
        targetStatuses = [:]
        supportedLanguages = []
        await loadSupportedLanguages()
        if !trimmedInput.isEmpty {
            requestTranslation()
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

    /// The source pane's title: the chosen language, or what was detected.
    var sourceTitle: String {
        if let source = sourceLanguage { return name(for: source) }
        if let detected = outcome?.result?.detectedSource {
            return String(localized: "\(name(for: detected)) (detected)")
        }
        return String(localized: "Detect Language")
    }

    // MARK: - Languages

    /// Changes to either language also re-run the availability check.
    var languagePairID: String {
        let source = sourceLanguage.map(LanguageCatalog.identifier(for:)) ?? LanguageCatalog.automaticIdentifier
        return "\(source)→\(LanguageCatalog.identifier(for: targetLanguage))"
    }

    /// Availability also has to be re-checked once the catalog arrives.
    var availabilityKey: String {
        "\(languagePairID)|\(supportedLanguages.count)|\(TranslationQuality.effective.rawValue)"
    }

    /// Swapping is only meaningful when both ends are known languages.
    var canSwapLanguages: Bool {
        sourceLanguage != nil
    }

    /// Swaps the pair and carries the translation across as the new input, so
    /// the swap reads as a continuation.
    func swapLanguages() {
        guard let source = sourceLanguage else { return }
        let translation = outcome?.result?.text

        isAdjustingLanguages = true
        sourceLanguage = targetLanguage
        targetLanguage = source
        isAdjustingLanguages = false

        // The reverse translation is a new entry in Recent, not an edit of the
        // one it came from, but not a new text to count.
        currentRecord = nil
        if let translation {
            let counted = sessionCounted
            inputText = translation
            sessionCounted = counted
        }
        languagesDidChange()
    }

    private func languagesDidChange() {
        storeLanguages()
        wantsDownloadCheck = true
        speaker.stop()

        // A saved translation is frozen; changing it starts a new record.
        if currentRecord?.isSaved == true {
            currentRecord = nil
        }

        if trimmedInput.isEmpty {
            outcome = nil
        } else {
            requestTranslation()
        }
    }

    /// When the chosen source matches the target and there is no previous
    /// source to swap in, pick the person's own language, or failing that the
    /// first other language in the catalog.
    private func alternativeTarget(to source: Locale.Language) -> Locale.Language {
        let candidates = [resolve(Locale.current.language)].compactMap { $0 }
            + supportedLanguages.map(\.language)
        return candidates.first { $0 != source } ?? source
    }

    /// Refreshes which languages are installed for each menu, and offers the
    /// download prompt when the person just picked a pair that isn't.
    func refreshAvailability() async {
        guard !supportedLanguages.isEmpty else { return }
        let source = sourceLanguage
        let target = targetLanguage
        let pair = languagePairID

        if wantsDownloadCheck {
            wantsDownloadCheck = false
            if let source, await LanguageCatalog.status(from: source, to: target) == .supported {
                needsPreparation = true
                requestTranslation(allowEmptyInput: true)
            }
        }

        var sources: [Locale.Language: LanguageAvailability.Status] = [:]
        for entry in supportedLanguages {
            sources[entry.language] = await status(forSourceCandidate: entry.language, source: source, target: target)
        }
        guard !Task.isCancelled, pair == languagePairID else { return }
        sourceStatuses = sources

        var targets: [Locale.Language: LanguageAvailability.Status] = [:]
        for entry in supportedLanguages {
            targets[entry.language] = await status(forTargetCandidate: entry.language, source: source, target: target)
        }
        guard !Task.isCancelled, pair == languagePairID else { return }
        targetStatuses = targets
    }

    /// Picking the current target as a source swaps the pair, so that entry
    /// reports the status of the swapped pair.
    private func status(
        forSourceCandidate candidate: Locale.Language,
        source: Locale.Language?,
        target: Locale.Language
    ) async -> LanguageAvailability.Status {
        if candidate == target {
            guard let source else { return .installed }
            return await LanguageCatalog.status(from: target, to: source)
        }
        return await LanguageCatalog.status(from: candidate, to: target)
    }

    /// With Detect Language there is no source to check against, so the last
    /// detected language stands in, then the person's own language.
    private func status(
        forTargetCandidate candidate: Locale.Language,
        source: Locale.Language?,
        target: Locale.Language
    ) async -> LanguageAvailability.Status {
        let from = source
            ?? outcome?.result?.detectedSource
            ?? resolve(Locale.current.language)
            ?? Locale.current.language
        if candidate == from {
            return await LanguageCatalog.status(from: target, to: candidate)
        }
        return await LanguageCatalog.status(from: from, to: candidate)
    }

    // MARK: - Typing

    private func inputDidChange(from oldValue: String) {
        guard inputText != oldValue else { return }
        debounceTask?.cancel()
        recordTask?.cancel()

        // A saved translation is frozen; editing it starts a new record.
        if currentRecord?.isSaved == true {
            currentRecord = nil
        }

        let text = trimmedInput
        guard !text.isEmpty else {
            endSession()
            return
        }

        if TextSession.isNewText(from: oldValue, to: inputText) {
            // Started from empty, or the old text was replaced in one go.
            sessionCounted = false
            currentRecord = nil
        }

        if outcome?.result?.sourceText == text {
            // Only whitespace changed; the result on screen still applies.
            finishTranslating()
        } else if !translatesAsYouType {
            // Typing waits for ⌘⏎; a stale result shouldn't linger as if live.
            outcome = nil
            finishTranslating()
        } else {
            debounceTask = Task { [weak self] in
                try? await Task.sleep(for: Timing.debounce)
                guard !Task.isCancelled else { return }
                self?.requestTranslation()
            }
        }

        recordTask = Task { [weak self] in
            try? await Task.sleep(for: Timing.pauseBeforeRecording)
            guard !Task.isCancelled else { return }
            self?.recordToRecent()
        }
    }

    func clearInput() {
        inputText = ""
    }

    /// The person is done typing (⌘⏎ on the Mac, Done on the iPhone
    /// keyboard): translate now if needed, and count the translation as
    /// finished.
    func settle() {
        guard !trimmedInput.isEmpty else { return }
        recordTask?.cancel()
        if currentResult == nil, !isTranslating || !translatesAsYouType {
            requestTranslation()
        }
        recordToRecent()
    }

    /// Shows the system download prompt for the current pair, then
    /// translates what's on screen once it's there.
    func downloadCurrentPair() {
        needsPreparation = true
        requestTranslation(allowEmptyInput: true)
    }

    /// Settings › General › "Translate as you type".
    var translatesAsYouType: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.liveTranslate)
    }

    /// Settings › General › "Keep a history of translations".
    private var keepsHistory: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.keepHistory)
    }

    private func endSession() {
        requestID += 1
        indicatorTask?.cancel()
        isTranslating = false
        showsTranslatingIndicator = false
        outcome = nil
        configuration = nil
        currentRecord = nil
        sessionCounted = false
        wantsRecord = false
        wantsSpeech = false
        speaker.stop()
    }

    // MARK: - Translating

    /// Whether the free plan's limit blocks this text. A text that has
    /// already been counted keeps working after the allowance runs out, so
    /// nobody is cut off while editing it.
    var needsPro: Bool {
        !trimmedInput.isEmpty && !sessionCounted && !purchases.canTranslate
    }

    var canTranslateNow: Bool {
        !trimmedInput.isEmpty && !needsPro
    }

    /// Translates the current text right away; typing normally gets here after
    /// the debounce. Pass `allowEmptyInput` to start a session with nothing to
    /// translate, which is how the download prompt is shown.
    func requestTranslation(allowEmptyInput: Bool = false) {
        debounceTask?.cancel()
        let text = trimmedInput

        if text.isEmpty {
            guard allowEmptyInput, needsPreparation else { return }
        } else {
            guard !needsPro else {
                finishTranslating()
                return
            }
            requestID += 1
            isTranslating = true
            indicatorTask?.cancel()
            indicatorTask = Task { [weak self] in
                try? await Task.sleep(for: Timing.indicatorDelay)
                guard !Task.isCancelled, let self, self.isTranslating else { return }
                self.showsTranslatingIndicator = true
            }
        }

        let desired = LanguageCatalog.configuration(
            source: sourceLanguage,
            target: targetLanguage
        )

        // Re-running with the same pair needs invalidate(); a configuration that
        // compares equal would not retrigger translationTask.
        if var current = configuration, current.source == desired.source, current.target == desired.target {
            current.invalidate()
            configuration = current
        } else {
            configuration = desired
        }
    }

    /// Called by the view's `translationTask` whenever the configuration changes.
    func translate(using session: TranslationSession) async {
        if needsPreparation {
            needsPreparation = false
            do {
                try await session.prepareTranslation()
            } catch {
                // Declining the download is fine; the pair stays selected and
                // the prompt returns the next time a translation is attempted.
                Log.translation.notice("Preparation ended: \(String(describing: error), privacy: .public)")
            }
        }

        let text = trimmedInput
        guard !text.isEmpty else { return }
        let id = requestID

        do {
            let response = try await session.translate(text)
            guard id == requestID else { return }

            outcome = .translated(
                TranslationResult(
                    sourceText: text,
                    text: response.targetText,
                    pronunciation: Pronunciation.latinTranscription(of: response.targetText, in: targetLanguage),
                    detectedSource: sourceLanguage == nil ? session.sourceLanguage : nil
                )
            )
            finishTranslating()

            if wantsRecord {
                recordToRecent()
            }
            if wantsSpeech {
                wantsSpeech = false
                toggleSpeech()
            }
        } catch is CancellationError {
            // Superseded by a newer request.
        } catch {
            guard id == requestID else { return }
            let failure = TranslationFailure.from(error, from: sourceLanguage, to: targetLanguage)
            Log.translation.error("Translation failed: \(String(describing: error), privacy: .public)")
            outcome = failure.map(Outcome.failed)
            finishTranslating()
        }
    }

    private func finishTranslating() {
        indicatorTask?.cancel()
        isTranslating = false
        showsTranslatingIndicator = false
    }

    /// The result for exactly the text on screen; `nil` while a newer
    /// translation is pending, so actions never act on a stale result.
    var currentResult: TranslationResult? {
        guard let result = outcome?.result, result.sourceText == trimmedInput else { return nil }
        return result
    }

    // MARK: - Actions

    func copyTranslation() {
        guard let result = currentResult else { return }
        Clipboard.copy(result.text)
        recordToRecent()

        justCopied = true
        copiedTask?.cancel()
        copiedTask = Task { [weak self] in
            try? await Task.sleep(for: Timing.copiedFeedback)
            guard !Task.isCancelled else { return }
            self?.justCopied = false
        }
    }

    var canSpeak: Bool {
        currentResult != nil && speaker.canSpeak(targetLanguage)
    }

    /// Reading at half the speed set in Settings, for the phrase being read.
    /// Each new reading starts at normal speed again.
    private(set) var speaksSlowly = false

    func toggleSpeech() {
        if speaker.isSpeaking {
            speaker.stop()
        } else if let result = currentResult {
            speaksSlowly = false
            speaker.speak(result.text, in: targetLanguage)
            recordToRecent()
        }
    }

    /// Switches between normal and slow, restarting the reading at the new speed.
    func toggleSpeechSpeed() {
        speaksSlowly.toggle()
        guard speaker.isSpeaking, let result = currentResult else { return }
        speaker.speak(result.text, in: targetLanguage, rateMultiplier: speaksSlowly ? 0.5 : 1)
    }

    /// Set while waiting to read a translation that's still on its way.
    private var wantsSpeech = false

    /// Reads the translation aloud as soon as it's ready, as after speaking
    /// on iPhone.
    func speakWhenTranslated() {
        if currentResult != nil {
            if !speaker.isSpeaking { toggleSpeech() }
        } else {
            wantsSpeech = true
        }
    }

    /// The translation was shown full-screen to someone: it counts as made.
    func noteShownToSomeone() {
        recordToRecent()
    }

    var isCurrentSaved: Bool {
        currentRecord?.isSaved ?? false
    }

    /// Returns `false` when the free plan's saved limit is reached and the
    /// star stays empty; the caller offers Pro.
    @discardableResult
    func toggleSaved() -> Bool {
        if let record = currentRecord, record.isSaved {
            history.setSaved(record, false)
            return true
        }
        guard history.canSave(limit: purchases.savedLimit) else { return false }
        recordToRecent(force: true)
        guard let record = currentRecord else { return true }
        history.setSaved(record, true)
        return true
    }

    // MARK: - Recent

    /// The translation on screen is finished: counts it toward the daily
    /// limit the first time, and writes it to Recent, updating this session's
    /// record if there is one. Waits for the translation if it hasn't arrived.
    /// With history off nothing is written unless forced, which saving does:
    /// a starred entry has to exist somewhere.
    private func recordToRecent(force: Bool = false) {
        guard let result = currentResult else {
            wantsRecord = true
            return
        }
        wantsRecord = false
        if !sessionCounted {
            sessionCounted = true
            purchases.recordTranslation()
        }
        guard keepsHistory || force else { return }

        // Record identifiers, not localized display names, so history stays
        // meaningful if the app language changes.
        let sourceID = (result.detectedSource ?? sourceLanguage)
            .map(LanguageCatalog.identifier(for:)) ?? LanguageCatalog.automaticIdentifier
        let targetID = LanguageCatalog.identifier(for: targetLanguage)

        if let record = currentRecord {
            // A saved record is frozen and already matches what's on screen.
            guard !record.isSaved else { return }
            // This session's record is replaced rather than edited so the
            // store can fold it into an older entry with the same text.
            modelContext.delete(record)
        }
        currentRecord = history.record(
            sourceText: result.sourceText,
            translatedText: result.text,
            sourceLanguage: sourceID,
            targetLanguage: targetID
        )
    }

    /// Puts a history entry on the translate screen: its languages, text and
    /// translation, with the entry itself as the session's record so the star
    /// reflects it. It was already counted when it was made.
    func load(_ record: TranslationHistory) {
        speaker.stop()

        isAdjustingLanguages = true
        if record.sourceLanguageID == LanguageCatalog.automaticIdentifier {
            sourceLanguage = nil
        } else {
            let source = LanguageCatalog.language(forIdentifier: record.sourceLanguageID)
            sourceLanguage = resolve(source) ?? source
        }
        let target = LanguageCatalog.language(forIdentifier: record.targetLanguageID)
        targetLanguage = resolve(target) ?? target
        isAdjustingLanguages = false
        storeLanguages()

        // The result goes in first so the text change sees it already covers
        // the input and doesn't schedule a fresh translation.
        outcome = .translated(
            TranslationResult(
                sourceText: record.sourceText,
                text: record.translatedText,
                pronunciation: Pronunciation.latinTranscription(of: record.translatedText, in: targetLanguage),
                detectedSource: nil
            )
        )
        inputText = record.sourceText
        currentRecord = record
        sessionCounted = true
    }

    /// History entries are about to be deleted. If the one on screen is
    /// among them, let go of it so the screen never holds a deleted record;
    /// the text stays and is recorded afresh if the person carries on.
    func historyWillDelete(_ entries: [TranslationHistory]) {
        guard let record = currentRecord, entries.contains(where: { $0 === record }) else { return }
        currentRecord = nil
    }

    /// Recent is about to be cleared; saved entries survive it.
    func historyWillClear() {
        if currentRecord?.isSaved == false {
            currentRecord = nil
        }
    }

    private var history: HistoryStore {
        HistoryStore(context: modelContext)
    }

    // MARK: - Persistence

    private func storeLanguages() {
        store(sourceLanguage, forKey: DefaultsKey.source)
        store(targetLanguage, forKey: DefaultsKey.target)
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

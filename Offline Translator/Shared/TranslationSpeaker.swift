//
//  TranslationSpeaker.swift
//  TranslatorMac
//

import AVFoundation
import Foundation

/// Reads a translation aloud with the system voice for the target language.
@Observable
final class TranslationSpeaker {

    private(set) var isSpeaking = false

    /// The part of the text being spoken right now, for highlighting.
    private(set) var spokenRange: NSRange?

    /// How far through the text the reading is, from 0 to 1.
    private(set) var progress: Double = 0

    /// What's being read, so ranges can be turned into progress.
    private var spokenLength = 0

    /// The utterance being read. Callbacks for any other one are late news
    /// from a reading that was replaced, and are ignored.
    private var currentUtterance: ObjectIdentifier?

    private let synthesizer = AVSpeechSynthesizer()
    private let relay = Relay()

    init() {
        relay.onStop = { [weak self] utterance in
            guard let self, utterance == self.currentUtterance else { return }
            self.didStop()
        }
        relay.onRange = { [weak self] range, utterance in
            guard let self, utterance == self.currentUtterance else { return }
            self.willSpeak(range)
        }
        synthesizer.delegate = relay
    }

    /// Whether this Mac has a voice that can read the language.
    func canSpeak(_ language: Locale.Language) -> Bool {
        Self.voice(for: language) != nil
    }

    /// Reads `text` at the speed set in Settings, scaled by `rateMultiplier`.
    func speak(_ text: String, in language: Locale.Language, rateMultiplier: Float = 1) {
        guard let voice = Self.voice(for: language) else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        let rate = Self.rate(forSetting: UserDefaults.standard.double(forKey: SettingsKey.speechRate)) * rateMultiplier
        utterance.rate = max(rate, AVSpeechUtteranceMinimumSpeechRate)
        spokenLength = (text as NSString).length
        spokenRange = nil
        progress = 0
        isSpeaking = true
        currentUtterance = ObjectIdentifier(utterance)
        activateAudioSession()
        synthesizer.speak(utterance)
    }

    /// Maps the 0…1 "Slow ↔ Fast" setting onto the synthesizer's range.
    static func rate(forSetting value: Double) -> Float {
        let clamped = Float(min(max(value, 0), 1))
        return AVSpeechUtteranceMinimumSpeechRate
            + clamped * (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceMinimumSpeechRate)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        didStop()
    }

    private func willSpeak(_ range: NSRange) {
        spokenRange = range
        if spokenLength > 0 {
            progress = Double(range.location + range.length) / Double(spokenLength)
        }
    }

    private func didStop() {
        guard isSpeaking else { return }
        isSpeaking = false
        currentUtterance = nil
        spokenRange = nil
        progress = 0
        deactivateAudioSession()
    }

    // MARK: - Audio session

    /// On iPhone, reading aloud plays even with the silent switch on, and
    /// lowers other audio rather than stopping it.
    private func activateAudioSession() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
        #endif
    }

    private func deactivateAudioSession() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    /// Voices are keyed by language-and-region ("ja-JP"), so try the catalog's
    /// region first, then any voice for the language.
    private static func voice(for language: Locale.Language) -> AVSpeechSynthesisVoice? {
        guard let code = language.languageCode?.identifier else { return nil }

        if let region = language.region?.identifier,
           let voice = AVSpeechSynthesisVoice(language: "\(code)-\(region)") {
            return voice
        }
        if let voice = AVSpeechSynthesisVoice(language: code) {
            return voice
        }
        return AVSpeechSynthesisVoice.speechVoices().first {
            $0.language.hasPrefix("\(code)-") || $0.language == code
        }
    }

    /// Receives the synthesizer's callbacks, which arrive on no particular
    /// thread, and hands them to the main actor. Kept separate so the speaker
    /// itself stays a plain observable model; the delegate protocol requires
    /// `Sendable`, which main-actor isolation provides. The isolation has to be
    /// spelled out: an `NSObject` subclass doesn't inherit the module default.
    @MainActor
    private final class Relay: NSObject, AVSpeechSynthesizerDelegate {
        var onStop: ((ObjectIdentifier) -> Void)?
        var onRange: ((NSRange, ObjectIdentifier) -> Void)?

        nonisolated func speechSynthesizer(
            _ synthesizer: AVSpeechSynthesizer,
            willSpeakRangeOfSpeechString characterRange: NSRange,
            utterance: AVSpeechUtterance
        ) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor in self.onRange?(characterRange, id) }
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor in self.onStop?(id) }
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            let id = ObjectIdentifier(utterance)
            Task { @MainActor in self.onStop?(id) }
        }
    }
}

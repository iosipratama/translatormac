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

    private let synthesizer = AVSpeechSynthesizer()
    private let relay = Relay()

    init() {
        relay.onStop = { [weak self] in self?.isSpeaking = false }
        synthesizer.delegate = relay
    }

    /// Whether this Mac has a voice that can read the language.
    func canSpeak(_ language: Locale.Language) -> Bool {
        Self.voice(for: language) != nil
    }

    func speak(_ text: String, in language: Locale.Language) {
        guard let voice = Self.voice(for: language) else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
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
        var onStop: (() -> Void)?

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            Task { @MainActor in self.onStop?() }
        }

        nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
            Task { @MainActor in self.onStop?() }
        }
    }
}

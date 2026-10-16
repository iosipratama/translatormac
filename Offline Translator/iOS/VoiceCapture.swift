//
//  VoiceCapture.swift
//  TranslatorMac
//

import AVFoundation
// SFSpeechRecognizer and its requests aren't Sendable-audited. Each request
// here is created, fed from the audio tap, and ended by this class alone.
@preconcurrency import Speech
import os

/// Hold-to-talk speech recognition, entirely on this iPhone.
///
/// Speech is only ever recognized on-device: a language without an
/// on-device model is reported as unavailable rather than quietly sent to a
/// server.
@Observable
final class VoiceCapture {

    enum Permission {
        case notAsked
        case granted
        case denied
    }

    private enum Timing {
        /// Listening ends on its own after this long.
        static let limit: Duration = .seconds(60)
        /// Once someone has spoken, this much quiet ends listening.
        static let silence: Duration = .seconds(2)
        /// How long to wait for the recognizer's final wording after letting go.
        static let finalResult: Duration = .seconds(1)
    }

    private(set) var permission: Permission = VoiceCapture.currentPermission
    private(set) var isListening = false

    /// Let go and waiting for the final wording; no new stop can start.
    private var isFinishing = false

    /// Words the recognizer has settled on.
    private(set) var settledText = ""
    /// The newest words, which may still change.
    private(set) var pendingText = ""

    var transcript: String { settledText + pendingText }

    /// Recent input levels from 0 to 1, oldest first, for the waveform.
    private(set) var levels: [Float] = Array(repeating: 0, count: VoiceCapture.levelCount)
    static let levelCount = 28

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var limitTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?
    private var finalContinuation: CheckedContinuation<Void, Never>?

    private var onTranscript: ((String) -> Void)?
    private var onAutoStop: (() -> Void)?

    // MARK: - Permission

    private static var currentPermission: Permission {
        let microphone = AVAudioApplication.shared.recordPermission
        let speech = SFSpeechRecognizer.authorizationStatus()
        if microphone == .denied || speech == .denied || speech == .restricted {
            return .denied
        }
        if microphone == .granted && speech == .authorized {
            return .granted
        }
        return .notAsked
    }

    /// Re-reads the system's answer, as after a visit to Settings.
    func refreshPermission() {
        permission = Self.currentPermission
    }

    /// Asks for the microphone, then speech recognition, back to back.
    func requestPermission() async {
        let microphone = await AVAudioApplication.requestRecordPermission()
        if microphone, SFSpeechRecognizer.authorizationStatus() == .notDetermined {
            _ = await Self.requestSpeechAuthorization()
        }
        refreshPermission()
    }

    private nonisolated static func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Languages

    /// Whether speech in this language can be recognized without a network.
    func isAvailableOffline(for language: Locale.Language) -> Bool {
        Self.recognizer(for: language)?.supportsOnDeviceRecognition ?? false
    }

    /// Recognizers are keyed by language and region ("en-US"), so prefer the
    /// person's own region, then any region for the language.
    private static func recognizer(for language: Locale.Language) -> SFSpeechRecognizer? {
        guard let code = language.languageCode?.identifier else { return nil }
        let supported = SFSpeechRecognizer.supportedLocales()
        let candidates = supported.filter { $0.language.languageCode?.identifier == code }
        let script = language.script
        let matching = candidates.filter { script == nil || $0.language.script == nil || $0.language.script == script }
        let region = language.region ?? Locale.current.region
        let locale = matching.first { $0.region == region }
            ?? matching.first { $0.region == Locale.current.region }
            ?? matching.first
        return locale.flatMap(SFSpeechRecognizer.init(locale:))
    }

    // MARK: - Listening

    /// Starts listening right away. `onTranscript` receives the whole
    /// transcript so far as it changes; `onAutoStop` fires when listening ends
    /// by itself, after a pause or the time limit.
    func start(
        in language: Locale.Language,
        onTranscript: @escaping (String) -> Void,
        onAutoStop: @escaping () -> Void
    ) throws {
        cancel()
        guard let recognizer = Self.recognizer(for: language), recognizer.supportsOnDeviceRecognition else {
            throw VoiceError.unavailableOffline
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format, block: Self.tap(feeding: request) { [weak self] level in
            Task { @MainActor in self?.didMeasure(level) }
        })
        engine.prepare()
        try engine.start()

        self.request = request
        self.onTranscript = onTranscript
        self.onAutoStop = onAutoStop
        settledText = ""
        pendingText = ""
        levels = Array(repeating: 0, count: Self.levelCount)
        isListening = true

        task = recognizer.recognitionTask(with: request, resultHandler: Self.resultHandler { [weak self] update in
            Task { @MainActor in self?.didRecognize(update) }
        })

        limitTask = Task { [weak self] in
            try? await Task.sleep(for: Timing.limit)
            guard !Task.isCancelled else { return }
            self?.autoStop()
        }
    }

    /// Stops listening and returns what was said, waiting briefly for the
    /// recognizer's final wording.
    func finish() async -> String {
        guard isListening, !isFinishing else { return transcript }
        isFinishing = true
        stopAudio()
        request?.endAudio()

        await withCheckedContinuation { continuation in
            finalContinuation = continuation
            Task { [weak self] in
                try? await Task.sleep(for: Timing.finalResult)
                self?.resumeFinal()
            }
        }

        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        tearDown()
        return text
    }

    /// Stops without a result, as when the finger slides away.
    func cancel() {
        guard isListening || task != nil else { return }
        stopAudio()
        task?.cancel()
        settledText = ""
        pendingText = ""
        resumeFinal()
        tearDown()
    }

    private func stopAudio() {
        guard engine.isRunning else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
    }

    private func tearDown() {
        limitTask?.cancel()
        silenceTask?.cancel()
        task = nil
        request = nil
        onTranscript = nil
        onAutoStop = nil
        isListening = false
        isFinishing = false
        levels = Array(repeating: 0, count: Self.levelCount)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resumeFinal() {
        finalContinuation?.resume()
        finalContinuation = nil
    }

    private func autoStop() {
        guard isListening, !isFinishing else { return }
        onAutoStop?()
    }

    // MARK: - Updates

    private func didMeasure(_ level: Float) {
        guard isListening else { return }
        levels.removeFirst()
        levels.append(level)
    }

    private func didRecognize(_ update: RecognitionUpdate) {
        if let text = update.text {
            settledText = update.isFinal ? text : String(text.prefix(update.settledLength))
            pendingText = update.isFinal ? "" : String(text.dropFirst(update.settledLength))
            onTranscript?(transcript)

            // Quiet after speech ends listening, as letting go would.
            silenceTask?.cancel()
            silenceTask = Task { [weak self] in
                try? await Task.sleep(for: Timing.silence)
                guard !Task.isCancelled else { return }
                self?.autoStop()
            }
        }
        if let error = update.error {
            Log.translation.notice("Speech recognition ended: \(error, privacy: .public)")
        }
        if update.isFinal || update.failed {
            resumeFinal()
        }
    }

    // MARK: - Off the main actor

    /// What the recognizer reported, reduced to values that can cross to the
    /// main actor.
    private struct RecognitionUpdate: Sendable {
        var text: String?
        /// How much of `text` is settled; the rest is the newest words.
        var settledLength: Int
        var isFinal: Bool
        var failed: Bool
        var error: String?
    }

    /// Built outside the main actor: the recognizer calls it on its own queue.
    private nonisolated static func resultHandler(
        _ deliver: @escaping @Sendable (RecognitionUpdate) -> Void
    ) -> (SFSpeechRecognitionResult?, (any Error)?) -> Void {
        { result, error in
            guard let result else {
                deliver(RecognitionUpdate(text: nil, settledLength: 0, isFinal: false, failed: error != nil, error: error?.localizedDescription))
                return
            }
            let transcription = result.bestTranscription
            let text = transcription.formattedString
            // The last segment is the one still being worked out.
            let settled = transcription.segments.last.map { segment in
                let location = min(segment.substringRange.location, (text as NSString).length)
                return String((text as NSString).substring(to: location)).count
            } ?? text.count
            deliver(RecognitionUpdate(text: text, settledLength: settled, isFinal: result.isFinal, failed: false, error: nil))
        }
    }

    /// Built outside the main actor: the audio engine calls it on its
    /// real-time thread.
    private nonisolated static func tap(
        feeding request: SFSpeechAudioBufferRecognitionRequest,
        level: @escaping @Sendable (Float) -> Void
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            request.append(buffer)
            level(Self.level(of: buffer))
        }
    }

    /// A 0…1 loudness for the waveform, from the buffer's RMS in decibels.
    private nonisolated static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) {
            sum += samples[index] * samples[index]
        }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        let decibels = 20 * log10(max(rms, 0.000_01))
        return max(0, min(1, (decibels + 50) / 50))
    }
}

enum VoiceError: Error {
    case unavailableOffline
}

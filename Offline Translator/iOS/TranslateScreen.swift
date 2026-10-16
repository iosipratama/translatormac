//
//  TranslateScreen.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI
import os

/// The root screen: type, speak or point the camera, and read the
/// translation. Library and Settings push from its toolbar.
///
/// One text field serves every state: empty with recent translations under
/// it, typing with the live translation below, and the finished result with
/// its actions once the keyboard goes away.
struct TranslateScreen: View {
    var model: TranslationModel
    var open: (AppRoute) -> Void

    @Environment(ProPresentation.self) private var pro
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    @Query(Self.recentDescriptor) private var recent: [TranslationHistory]

    @FocusState private var isEditing: Bool
    @State private var pickerSide: LanguageSide?
    @State private var isShowingToSomeone = false
    @State private var isShowingCamera = false
    @State private var toast: ToastMessage?
    @State private var savedCount = 0
    @State private var copiedCount = 0

    @State private var voice = VoiceCapture()
    /// Whether the source language has an on-device speech model.
    @State private var isVoiceAvailable = true
    /// The text on screen was spoken, until it's edited.
    @State private var isSpoken = false
    @State private var voiceNotice: VoiceNotice?
    @State private var pressedAt: Date?
    @State private var listenCount = 0

    @AppStorage(SettingsKey.showPronunciation) private var showsPronunciation = true
    @AppStorage(SettingsKey.autoSpeakVoice) private var speaksAfterVoice = true

    /// What the source area says after a voice attempt that didn't work.
    private enum VoiceNotice {
        case noSpeech
        case micOff
    }

    private static var recentDescriptor: FetchDescriptor<TranslationHistory> {
        var descriptor = FetchDescriptor<TranslationHistory>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = 3
        return descriptor
    }

    private var hasInput: Bool { !model.trimmedInput.isEmpty }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sourceSection

                if hasInput {
                    resultSection
                } else if !isEditing, !recent.isEmpty {
                    RecentPreview(entries: recent) {
                        open(.library(.recent))
                    } select: { entry in
                        model.load(entry)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(.snappy, value: isEditing)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(.canvas)
        .toast($toast, bottomPadding: 12)
        .safeAreaBar(edge: .bottom) {
            if !isEditing {
                VStack(spacing: 22) {
                    LanguagePairCard(model: model) { pickerSide = $0 }
                    BottomControls(mic: micMode) {
                        isEditing = true
                    } camera: {
                        isShowingCamera = true
                    } press: {
                        pressMic()
                    } release: {
                        releaseMic()
                    } cancel: {
                        cancelMic()
                    } explainMic: {
                        explainMic()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }
        }
        .navigationTitle(isEditing ? "" : "Translate")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar { toolbar }
        .sheet(item: $pickerSide) { side in
            LanguagePickerSheet(model: model, side: side)
        }
        .fullScreenCover(isPresented: $isShowingToSomeone) {
            ShowToSomeoneView(model: model)
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraScreen(model: model)
        }
        .onChange(of: isEditing) { _, isEditing in
            if isEditing {
                // Typed text is no longer what was spoken.
                isSpoken = false
                voiceNotice = nil
                return
            }
            // Done, or a tap outside the field: the translation counts as made.
            guard hasInput else { return }
            model.settle()
            if model.needsPro { pro.present() }
        }
        .task(id: model.languagePairID) {
            isVoiceAvailable = model.sourceLanguage.map(voice.isAvailableOffline(for:)) ?? false
        }
        .onChange(of: scenePhase) { _, phase in
            // Listening stops when the app leaves the screen; permissions may
            // have changed in Settings meanwhile.
            if phase == .active {
                voice.refreshPermission()
                if voice.permission != .denied, voiceNotice == .micOff { voiceNotice = nil }
            } else if voice.isListening {
                cancelMic()
            }
        }
        .onDisappear {
            if voice.isListening { cancelMic() }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: listenCount)
        .sensoryFeedback(.success, trigger: savedCount)
        .sensoryFeedback(.success, trigger: copiedCount)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    pickerSide = .source
                } label: {
                    HStack(spacing: 8) {
                        Text(model.sourceTitle)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.textMuted)
                        Text(model.name(for: model.targetLanguage))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .padding(.horizontal, 6)
                }
                .accessibilityLabel("\(model.sourceTitle) to \(model.name(for: model.targetLanguage))")
                .accessibilityHint("Choose languages")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Cancel") {
                    model.clearInput()
                    isEditing = false
                }
            }
        } else {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.library(nil)) {
                    Label("Library", systemImage: "bookmark")
                }
                .tint(.textPrimary)
                NavigationLink(value: AppRoute.settings) {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
                .tint(.textPrimary)
            }
        }
    }

    // MARK: - Source

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(sourceLabel)
                Spacer()
                if hasInput, !voice.isListening {
                    Button {
                        model.clearInput()
                        isEditing = true
                    } label: {
                        Label("Clear text", systemImage: "xmark")
                            .labelStyle(.iconOnly)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.textMuted)
                            .frame(width: 28, height: 28)
                            .background(.raised, in: .circle)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 28)

            if voice.isListening {
                listeningTranscript
            } else if voiceNotice == .noSpeech, !hasInput, !isEditing {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Didn’t catch that")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                    Text("Hold the button while you talk, then let go. Speak close to your iPhone if it’s noisy.")
                        .font(.body)
                        .foregroundStyle(.textMuted)
                }
            } else {
                TextField("Text to translate", text: input, prompt: Text("Enter text").foregroundStyle(.textFaint), axis: .vertical)
                    .font(sourceFont)
                    .foregroundStyle(isEditing || !hasInput ? AnyShapeStyle(.textPrimary) : AnyShapeStyle(.textSecondary))
                    .tint(Color.accent)
                    .lineLimit(1...8)
                    .focused($isEditing)
                    .submitLabel(.done)
            }

            if voiceNotice == .micOff, !hasInput, !voice.isListening {
                micOffCard
                    .padding(.top, 14)
            }
        }
        .padding(.bottom, hasInput ? 20 : 24)
        .frame(minHeight: hasInput ? nil : 150, alignment: .top)
        .contentShape(.rect)
        .onTapGesture {
            guard !voice.isListening else { return }
            if voiceNotice == .noSpeech {
                // The field comes back first, then takes focus.
                voiceNotice = nil
                Task { isEditing = true }
            } else {
                isEditing = true
            }
        }
    }

    /// "ENGLISH", "ENGLISH · ● LISTENING", "ENGLISH · SPOKEN".
    private var sourceLabel: Text {
        let name = model.sourceTitle
        if voice.isListening {
            return Text("\(name) · \(Text("● Listening").foregroundStyle(.danger))")
        }
        if isSpoken, hasInput {
            return Text("\(name) · Spoken")
        }
        return Text(name)
    }

    /// Settled words in full ink, the newest ones still being worked out in
    /// grey, over the waveform.
    private var listeningTranscript: some View {
        VStack(alignment: .leading, spacing: 14) {
            if voice.transcript.isEmpty {
                Text("Listening…")
                    .foregroundStyle(.textFaint)
            } else {
                Text("\(Text(voice.settledText).foregroundStyle(.textPrimary))\(Text(voice.pendingText).foregroundStyle(.textMuted))")
            }
            VoiceWaveform(levels: voice.levels)
        }
        .font(.title.weight(.semibold))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(voice.transcript.isEmpty ? Text("Listening") : Text(voice.transcript))
    }

    private var micOffCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Microphone is off")
                .font(.headline)
                .foregroundStyle(.textPrimary)
            Text("To translate by voice, turn on Microphone and Speech Recognition for Translate Offline in Settings. You can still type or use the camera.")
                .font(.subheadline)
                .foregroundStyle(.textMuted)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            } label: {
                Text("Open Settings")
                    .font(.headline)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glassProminent)
            .tint(.inverse)
            .foregroundStyle(.onInverse)
            .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface, in: .rect(cornerRadius: 22))
    }

    /// Large while writing; a step smaller once the translation takes over.
    private var sourceFont: Font {
        isEditing || !hasInput ? .title.weight(.semibold) : .title2.weight(.semibold)
    }

    /// The input, with Return taken as Done: a field that grows to several
    /// lines would otherwise insert a line break.
    private var input: Binding<String> {
        Binding {
            model.inputText
        } set: { newValue in
            let old = model.inputText
            let addedOneCharacter = newValue.count == old.count + 1
            if addedOneCharacter, newValue.filter(\.isNewline).count > old.filter(\.isNewline).count {
                isEditing = false
                return
            }
            model.inputText = newValue
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Rectangle().fill(.line).frame(height: 1)
                .padding(.bottom, 8)

            SectionLabel(targetLabel)

            if case .failed(let failure) = model.outcome {
                failureMessage(failure)
            } else if model.needsPro {
                limitMessage
            } else if let result = model.outcome?.result {
                translation(result)
            } else {
                Text(placeholder)
                    .font(.title3)
                    .foregroundStyle(.textFaint)
            }

            if voice.isListening {
                Text("Slide your finger away to cancel.")
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .padding(.top, 12)
            }
        }
    }

    private var placeholder: LocalizedStringKey {
        if voice.isListening { return "The translation appears as you speak." }
        return model.translatesAsYouType ? "The translation appears as you type." : "Tap Done to translate."
    }

    private var targetLabel: Text {
        let name = model.name(for: model.targetLanguage)
        guard model.speaker.isSpeaking else { return Text(name) }
        return Text("\(name) · \(Text("Reading aloud").foregroundStyle(.accentForeground))")
    }

    private func translation(_ result: TranslationResult) -> some View {
        // A result for older text stays up, dimmed, until the new one lands.
        let isStale = result.sourceText != model.trimmedInput

        return VStack(alignment: .leading, spacing: 12) {
            Text(highlighted(result.text))
                .font(.largeTitle.bold())
                .foregroundStyle(.textPrimary)
                .typesettingLanguage(model.targetLanguage)
                .textSelection(.enabled)

            if showsPronunciation, let pronunciation = result.pronunciation {
                Text(pronunciation)
                    .font(.body)
                    .foregroundStyle(.textMuted)
            }

            if !isEditing, !isStale, !voice.isListening {
                ActionBar(model: model) {
                    isShowingToSomeone = true
                } toggleSaved: {
                    toggleSaved()
                } copy: {
                    copy()
                }
                .padding(.top, 8)
                .transition(.opacity)
            }
        }
        .opacity(isStale ? 0.5 : 1)
        .animation(.smooth, value: isStale)
    }

    /// The translation with the words being read aloud picked out.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        guard model.speaker.isSpeaking,
              let spoken = model.speaker.spokenRange,
              let range = Range(spoken, in: attributed) else { return attributed }
        attributed[range].foregroundColor = .accentForeground
        attributed[range].backgroundColor = .accentTint
        return attributed
    }

    private func failureMessage(_ failure: TranslationFailure) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if failure.offersDownload {
                Text("\(model.name(for: model.targetLanguage)) isn’t on this iPhone yet.")
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                Button("Download", systemImage: "arrow.down.circle", action: model.downloadCurrentPair)
                    .buttonStyle(.glass)
            } else {
                Label(failure.message, systemImage: "exclamationmark.triangle.fill")
                    .font(.body)
                    .foregroundStyle(.danger)
            }
        }
    }

    private var limitMessage: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("You’ve used today’s \(PlanLimits.freeTranslationsPerDay) free translations. Pro translates without a limit.")
                .font(.body)
                .foregroundStyle(.textSecondary)
            Button("Get Pro") { pro.present() }
                .buttonStyle(.glassProminent)
                .tint(Color.accent)
                .foregroundStyle(.onAccent)
        }
    }

    // MARK: - Actions

    private func toggleSaved() {
        let wasSaved = model.isCurrentSaved
        guard model.toggleSaved() else {
            pro.present()
            return
        }
        guard !wasSaved else { return }
        savedCount += 1
        toast = ToastMessage(
            text: "Saved to Library",
            systemImage: "star.fill",
            action: .init(title: "View") { open(.library(.saved)) }
        )
    }

    private func copy() {
        model.copyTranslation()
        copiedCount += 1
        toast = ToastMessage(
            text: "Copied \(model.name(for: model.targetLanguage)) text",
            systemImage: "checkmark"
        )
    }

    // MARK: - Voice

    private var micMode: HoldToTalkButton.Mode {
        if voice.isListening { return .listening(level: voice.levels.last ?? 0) }
        if voice.permission == .denied { return .off }
        if !isVoiceAvailable { return .unavailable }
        return recent.isEmpty && !hasInput ? .readyWithHint : .ready
    }

    /// Starts listening the moment the button goes down. The first press asks
    /// for the microphone and speech recognition instead.
    private func pressMic() {
        guard !voice.isListening else { return }
        switch voice.permission {
        case .denied:
            voiceNotice = .micOff
            return
        case .notAsked:
            Task {
                await voice.requestPermission()
                if voice.permission == .denied { voiceNotice = .micOff }
            }
            return
        case .granted:
            break
        }
        guard let source = model.sourceLanguage, isVoiceAvailable else {
            explainMic()
            return
        }

        isEditing = false
        model.speaker.stop()
        model.clearInput()
        voiceNotice = nil
        pressedAt = .now
        do {
            try voice.start(in: source) { text in
                model.inputText = text
            } onAutoStop: {
                releaseMic()
            }
            isSpoken = true
            listenCount += 1
        } catch {
            Log.translation.error("Couldn’t start listening: \(String(describing: error), privacy: .public)")
            toast = ToastMessage(text: "Couldn’t start listening. Try again.")
        }
    }

    /// Letting go translates what was said, and reads it aloud if Settings
    /// says so. A quick tap explains that the button needs holding.
    private func releaseMic() {
        guard voice.isListening else { return }
        if let pressedAt, Date.now.timeIntervalSince(pressedAt) < 0.3 {
            cancelMic()
            toast = ToastMessage(text: "Hold to talk", systemImage: "microphone.fill")
            return
        }
        Task {
            let text = await voice.finish()
            guard !text.isEmpty else {
                model.clearInput()
                isSpoken = false
                voiceNotice = .noSpeech
                return
            }
            model.inputText = text
            model.settle()
            if model.needsPro {
                pro.present()
            } else if speaksAfterVoice {
                model.speakWhenTranslated()
            }
        }
    }

    /// Sliding away: nothing is translated or kept.
    private func cancelMic() {
        voice.cancel()
        model.clearInput()
        isSpoken = false
    }

    private func explainMic() {
        if voice.permission == .denied {
            voiceNotice = .micOff
        } else if !isVoiceAvailable {
            let name = model.sourceLanguage.map(model.name(for:)) ?? ""
            toast = ToastMessage(text: "Voice isn’t available offline for \(name) yet. You can still type.")
        }
    }
}

//
//  ResultPane.swift
//  TranslatorMac
//

import SwiftUI

/// The right pane: the translation, its reading, and what to do with it.
struct ResultPane: View {
    var model: TranslationModel

    @Environment(ProPresentation.self) private var pro
    @AppStorage(SettingsKey.showPronunciation) private var showsPronunciation = true
    @AppStorage(SettingsKey.liveTranslate) private var translatesAsYouType = true

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: model.name(for: model.targetLanguage)) {
                if model.showsTranslatingIndicator {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.mini)
                        Text("Translating…")
                    }
                    .foregroundStyle(.tertiary)
                    .transition(.opacity)
                }
            }
            .animation(.smooth, value: model.showsTranslatingIndicator)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            PaneFooter {
                actions
            }
        }
        .background(.background.secondary)
    }

    @ViewBuilder
    private var content: some View {
        if model.needsPro {
            PaneMessage(
                systemImage: "bolt.fill",
                title: "You’ve used today’s free translations",
                description: "Unlock Pro for unlimited translations. Free translations come back tomorrow."
            ) {
                Button("Unlock Pro") {
                    pro.present()
                }
                .accentProminentButton()
            }
        } else if let outcome = model.outcome {
            switch outcome {
            case .translated(let result):
                translation(result)
            case .failed(let message):
                PaneMessage(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t translate",
                    description: LocalizedStringKey(message)
                )
            }
        } else if model.trimmedInput.isEmpty {
            PaneMessage(
                systemImage: "character.bubble",
                title: translatesAsYouType ? "The translation appears as you type" : "Press ⌘⏎ to translate",
                description: "Everything runs on this Mac. Nothing you type is sent anywhere."
            )
        } else if !translatesAsYouType, !model.isTranslating {
            PaneMessage(
                systemImage: "return",
                title: "Press ⌘⏎ to translate",
                description: "Translate as you type is off in Settings."
            )
        } else {
            // The first translation of a session is on its way; the header
            // says so if it takes long.
            Color.clear
        }
    }

    private func translation(_ result: TranslationResult) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(result.text)
                    .font(.system(size: 19))
                    .lineSpacing(6)
                    .textSelection(.enabled)

                if showsPronunciation, let pronunciation = result.pronunciation {
                    Text(pronunciation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .accessibilityLabel("Pronunciation: \(pronunciation)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PaneMetrics.inset)
            .padding(.bottom, 16)
        }
        // The previous result stays readable while the next one is in flight.
        .opacity(model.isTranslating ? 0.5 : 1)
        .animation(.smooth, value: model.isTranslating)
    }

    @ViewBuilder
    private var actions: some View {
        let hasResult = model.currentResult != nil
        let isSpeaking = model.speaker.isSpeaking

        Button(model.justCopied ? "Copied" : "Copy", systemImage: model.justCopied ? "checkmark" : "document.on.document") {
            model.copyTranslation()
        }
        .labelStyle(.titleOnly)
        .accentProminentButton()
        .disabled(!hasResult)
        .help("Copy the translation")
        .animation(.smooth, value: model.justCopied)

        Button(isSpeaking ? "Stop Speaking" : "Speak", systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2") {
            model.toggleSpeech()
        }
        .labelStyle(.iconOnly)
        .disabled(!model.canSpeak && !isSpeaking)
        .help(speakHelp)

        Toggle("Save", systemImage: model.isCurrentSaved ? "star.fill" : "star", isOn: Binding(
            get: { model.isCurrentSaved },
            set: { _ in
                if !model.toggleSaved() { pro.present() }
            }
        ))
        .toggleStyle(.button)
        .labelStyle(.iconOnly)
        .disabled(!hasResult)
        .help(model.isCurrentSaved ? "Remove from Saved" : "Save this translation")
    }

    private var speakHelp: LocalizedStringKey {
        if model.speaker.isSpeaking { return "Stop speaking" }
        if model.currentResult != nil, !model.canSpeak {
            return "No voice for \(model.name(for: model.targetLanguage)) is installed on this Mac"
        }
        return "Read the translation aloud"
    }
}

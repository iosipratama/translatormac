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
                title: "You’ve used today’s \(PlanLimits.freeTranslationsPerDay) free translations",
                description: Text("Your text is still here. Free translations reset at midnight, and Pro removes the daily limit.")
            ) {
                Button("Upgrade to Pro…") {
                    pro.present()
                }
                .accentProminentButton()
            }
        } else if let outcome = model.outcome {
            switch outcome {
            case .translated(let result):
                translation(result)
            case .failed(let failure):
                PaneMessage(
                    systemImage: "exclamationmark.triangle",
                    title: "Couldn’t translate",
                    description: Text(verbatim: failure.message)
                ) {
                    if failure.offersDownload {
                        Button("Download") {
                            model.downloadCurrentPair()
                        }
                        .accentProminentButton()
                    }
                }
            }
        } else if model.trimmedInput.isEmpty {
            PaneMessage(
                systemImage: "character.bubble",
                title: translatesAsYouType ? "Translations appear as you type" : "Press ⌘⏎ to translate",
                description: Text("Nothing you type leaves this Mac.")
            )
        } else if !translatesAsYouType, !model.isTranslating {
            PaneMessage(
                systemImage: "return",
                title: "Press ⌘⏎ to translate",
                description: Text("“Translate as you type” is off in Settings.")
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
                    PronunciationLine(pronunciation: pronunciation)
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
        .help("Copy the translation (⇧⌘C)")
        .animation(.smooth, value: model.justCopied)

        if model.unlocksPro || isSpeaking {
            Button(isSpeaking ? "Stop" : "Speak", systemImage: isSpeaking ? "stop.fill" : "speaker.wave.2") {
                model.toggleSpeech()
            }
            .labelStyle(.iconOnly)
            .disabled(!model.canSpeak && !isSpeaking)
            .help(speakHelp)
        } else {
            ProTag(feature: "Read aloud", systemImage: "speaker.wave.2")
        }

        if model.unlocksPro || model.isCurrentSaved {
            // Removing a star always works, so a phrase saved during the free
            // days can still be taken out of Saved.
            Toggle(model.isCurrentSaved ? "Remove from Saved" : "Save", systemImage: model.isCurrentSaved ? "star.fill" : "star", isOn: Binding(
                get: { model.isCurrentSaved },
                set: { _ in model.toggleSaved() }
            ))
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .disabled(!hasResult)
            .help(model.isCurrentSaved ? "Remove from Saved (⌘D)" : "Save (⌘D)")
        } else {
            ProTag(feature: "Saved phrases", systemImage: "star")
        }
    }

    private var speakHelp: LocalizedStringKey {
        if model.speaker.isSpeaking { return "Stop speaking" }
        if model.currentResult != nil, !model.canSpeak {
            return "No \(model.name(for: model.targetLanguage)) voice is on this Mac. Add one in System Settings › Accessibility › Read & Speak."
        }
        return "Speak the translation (⌥⌘S)"
    }
}

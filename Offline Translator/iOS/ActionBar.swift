//
//  ActionBar.swift
//  TranslatorMac
//

import SwiftUI

/// What to do with a finished translation: read it aloud, show it
/// full-screen, save it, copy it. While reading, a speed chip joins them.
struct ActionBar: View {
    var model: TranslationModel
    var showToSomeone: () -> Void
    var toggleSaved: () -> Void
    var copy: () -> Void

    var body: some View {
        let speaker = model.speaker

        HStack(spacing: 12) {
            RoundIconButton(
                title: speaker.isSpeaking ? "Stop" : "Read aloud",
                systemImage: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                isProminent: true,
                action: model.toggleSpeech
            )
            .overlay {
                if speaker.isSpeaking {
                    Circle()
                        .trim(from: 0, to: speaker.progress)
                        .stroke(Color.accent, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .padding(-4)
                        .animation(.smooth, value: speaker.progress)
                        .accessibilityHidden(true)
                }
            }
            .disabled(!model.canSpeak)

            RoundIconButton(title: "Show full-screen", systemImage: "arrow.up.left.and.arrow.down.right", action: showToSomeone)

            RoundIconButton(
                title: model.isCurrentSaved ? "Remove from Saved" : "Save",
                systemImage: model.isCurrentSaved ? "star.fill" : "star",
                iconColor: model.isCurrentSaved ? .accentForeground : .textPrimary,
                action: toggleSaved
            )

            RoundIconButton(
                title: "Copy",
                systemImage: model.justCopied ? "checkmark" : "document.on.document",
                action: copy
            )
            .contentTransition(.symbolEffect(.replace))

            Spacer(minLength: 0)

            if speaker.isSpeaking {
                Button(model.speaksSlowly ? "0.5× Speed" : "1× Speed", action: model.toggleSpeechSpeed)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .accessibilityLabel(model.speaksSlowly ? "Speed: slow" : "Speed: normal")
                    .accessibilityHint("Switches between normal and slow")
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.snappy, value: speaker.isSpeaking)
    }
}

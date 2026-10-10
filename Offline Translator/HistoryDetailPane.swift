//
//  HistoryDetailPane.swift
//  TranslatorMac
//

import AppKit
import SwiftData
import SwiftUI

/// The selected history entry in full: original and translation side by
/// side, like the translate screen, at a fixed height so the table above
/// never jumps as the selection changes.
struct HistoryDetailPane: View {
    var entry: TranslationHistory
    var speaker: TranslationSpeaker
    var onOpen: () -> Void
    var onDelete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var justCopied = false
    @State private var copiedTask: Task<Void, Never>?

    private let height: CGFloat = 236

    private var targetLanguage: Locale.Language {
        LanguageCatalog.language(forIdentifier: entry.targetLanguageID)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                column(
                    title: LanguageCatalog.name(forIdentifier: entry.sourceLanguageID),
                    text: entry.sourceText,
                    pronunciation: nil
                )
                Divider()
                    .padding(.top, 12)
                column(
                    title: LanguageCatalog.name(forIdentifier: entry.targetLanguageID),
                    text: entry.translatedText,
                    pronunciation: Pronunciation.latinTranscription(of: entry.translatedText, in: targetLanguage)
                )
            }

            footer
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(.background.secondary)
        .overlay(alignment: .top) {
            Divider()
        }
        .onChange(of: entry.id) {
            speaker.stop()
        }
    }

    private func column(title: String, text: String, pronunciation: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.system(size: 15))
                        .lineSpacing(4)
                        .textSelection(.enabled)

                    if let pronunciation {
                        Text(pronunciation)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .accessibilityLabel("Pronunciation: \(pronunciation)")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 12)
        .padding(.horizontal, PaneMetrics.inset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button("Open in Translate", action: onOpen)
                .help("Load this translation on the translate screen")
            Text("or double-click the row")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()

            Button(justCopied ? "Copied" : "Copy", systemImage: justCopied ? "checkmark" : "document.on.document", action: copy)
                .labelStyle(.titleOnly)
                .buttonStyle(.borderedProminent)
                .help("Copy the translation")
                .animation(.smooth, value: justCopied)

            Button(
                speaker.isSpeaking ? "Stop Speaking" : "Speak",
                systemImage: speaker.isSpeaking ? "stop.fill" : "speaker.wave.2",
                action: toggleSpeech
            )
            .labelStyle(.iconOnly)
            .disabled(!speaker.isSpeaking && !speaker.canSpeak(targetLanguage))
            .help(speaker.isSpeaking ? "Stop speaking" : "Read the translation aloud")

            Toggle("Save", systemImage: entry.isSaved ? "star.fill" : "star", isOn: Binding(
                get: { entry.isSaved },
                set: { isSaved in
                    entry.isSaved = isSaved
                    HistoryStore(context: modelContext).save()
                }
            ))
            .toggleStyle(.button)
            .labelStyle(.iconOnly)
            .help(entry.isSaved ? "Remove from Saved" : "Save this translation")

            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
                .labelStyle(.iconOnly)
                .help("Remove from history")
        }
        .padding(.horizontal, PaneMetrics.inset)
        .frame(height: PaneMetrics.footerHeight)
    }

    // MARK: - Actions

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(entry.translatedText, forType: .string)

        justCopied = true
        copiedTask?.cancel()
        copiedTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            justCopied = false
        }
    }

    private func toggleSpeech() {
        if speaker.isSpeaking {
            speaker.stop()
        } else {
            speaker.speak(entry.translatedText, in: targetLanguage)
        }
    }
}

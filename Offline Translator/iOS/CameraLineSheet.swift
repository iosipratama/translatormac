//
//  CameraLineSheet.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI

/// One line from a photo: the original with its reading, the translation,
/// and the actions that apply to it.
struct CameraLineSheet: View {
    var line: CameraLine
    var source: Locale.Language
    var target: Locale.Language
    var model: TranslationModel
    var needsPro: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ReviewPrompter.self) private var reviews

    @State private var savedEntry: TranslationHistory?
    @State private var justCopied = false
    @State private var feedback = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                SectionLabel(model.name(for: source))
                Spacer()
                RoundIconButton(title: "Close", systemImage: "xmark", diameter: 32) {
                    dismiss()
                }
            }

            Text(line.text)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.textSecondary)
                .typesettingLanguage(source)
                .textSelection(.enabled)
            if let reading = Pronunciation.latinTranscription(of: line.text, in: source) {
                Text(reading)
                    .font(.body)
                    .foregroundStyle(.textMuted)
            }

            Rectangle().fill(.line).frame(height: 1)
                .padding(.vertical, 8)

            SectionLabel(model.name(for: target))
            Text(translation)
                .font(.largeTitle.bold())
                .foregroundStyle(.textPrimary)
                .typesettingLanguage(target)
                .textSelection(.enabled)

            HStack(spacing: 12) {
                RoundIconButton(
                    title: model.speaker.isSpeaking ? "Stop" : "Read aloud",
                    systemImage: model.speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                    isProminent: true
                ) {
                    if model.speaker.isSpeaking {
                        model.speaker.stop()
                    } else {
                        model.speaker.speak(translation, in: target)
                    }
                }
                .disabled(!model.speaker.canSpeak(target))

                RoundIconButton(
                    title: isSaved ? "Remove from Library" : "Save",
                    systemImage: isSaved ? "star.fill" : "star",
                    iconColor: isSaved ? .accentForeground : .textPrimary,
                    action: toggleSaved
                )

                RoundIconButton(title: "Copy", systemImage: justCopied ? "checkmark" : "document.on.document") {
                    Clipboard.copy(translation)
                    justCopied = true
                    feedback += 1
                }
                .contentTransition(.symbolEffect(.replace))
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.canvas)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sensoryFeedback(.success, trigger: feedback)
        .onDisappear { model.speaker.stop() }
    }

    private var translation: String {
        line.translation ?? line.text
    }

    private var isSaved: Bool {
        savedEntry?.isSaved == true
    }

    /// Saving keeps just this line, as its own entry in Library.
    private func toggleSaved() {
        let store = HistoryStore(context: modelContext)
        if let entry = savedEntry, entry.isSaved {
            store.setSaved(entry, false)
            return
        }
        guard purchases.canSaveNew else {
            dismiss()
            needsPro()
            return
        }
        let entry = store.record(
            sourceText: line.text,
            translatedText: translation,
            sourceLanguage: LanguageCatalog.identifier(for: source),
            targetLanguage: LanguageCatalog.identifier(for: target)
        )
        store.setSaved(entry, true)
        savedEntry = entry
        feedback += 1
        reviews.noteSaved(total: store.savedCount())
    }
}

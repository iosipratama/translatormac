//
//  LibraryRow.swift
//  TranslatorMac
//

import SwiftUI

/// One translation in Library: the translation over the original, with the
/// star and the language pair on the right.
struct LibraryRow: View {
    var entry: TranslationHistory
    var open: () -> Void
    var toggleSaved: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.translatedText)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                        .typesettingLanguage(LanguageCatalog.language(forIdentifier: entry.targetLanguageID))
                    Text(entry.sourceText)
                        .font(.subheadline)
                        .foregroundStyle(.textMuted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens in Translate")

            VStack(alignment: .trailing, spacing: 8) {
                Button(action: toggleSaved) {
                    Label(entry.isSaved ? "Remove from Saved" : "Save", systemImage: entry.isSaved ? "star.fill" : "star")
                        .labelStyle(.iconOnly)
                        .font(.body)
                        .foregroundStyle(entry.isSaved ? AnyShapeStyle(Color.accent) : AnyShapeStyle(.textFaint))
                        .frame(width: 32, height: 28, alignment: .trailing)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)

                Text(pair)
                    .font(.caption.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.textMuted)
                    .accessibilityLabel(spokenPair)
            }
        }
        .padding(.vertical, 8)
    }

    private var pair: String {
        "\(LanguageCatalog.abbreviation(forIdentifier: entry.sourceLanguageID)) → \(LanguageCatalog.abbreviation(forIdentifier: entry.targetLanguageID))"
    }

    private var spokenPair: Text {
        Text("\(LanguageCatalog.name(forIdentifier: entry.sourceLanguageID)) to \(LanguageCatalog.name(forIdentifier: entry.targetLanguageID))")
    }
}

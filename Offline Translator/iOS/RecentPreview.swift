//
//  RecentPreview.swift
//  TranslatorMac
//

import SwiftUI

/// The last three translations, under an empty field, to pick one up again.
struct RecentPreview: View {
    var entries: [TranslationHistory]
    var seeAll: () -> Void
    var select: (TranslationHistory) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Recent")
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("See All", action: seeAll)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.bottom, 10)

            ForEach(entries) { entry in
                Rectangle().fill(.line).frame(height: 1)
                Button {
                    select(entry)
                } label: {
                    row(entry)
                }
                .buttonStyle(.plain)
            }
            Rectangle().fill(.line).frame(height: 1)
        }
    }

    private func row(_ entry: TranslationHistory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(entry.sourceText)
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    if entry.isSaved {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accent)
                            .accessibilityLabel("Saved")
                    }
                    Text(HistoryDate.label(for: entry.createdAt))
                        .font(.caption)
                        .foregroundStyle(.textMuted)
                }
            }
            Text(entry.translatedText)
                .font(.title3.weight(.medium))
                .foregroundStyle(.textPrimary)
                .lineLimit(2)
                .typesettingLanguage(LanguageCatalog.language(forIdentifier: entry.targetLanguageID))
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

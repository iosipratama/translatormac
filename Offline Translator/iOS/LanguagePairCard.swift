//
//  LanguagePairCard.swift
//  TranslatorMac
//

import SwiftUI

/// Which end of the pair a picker or control is about.
enum LanguageSide: String, Identifiable {
    case source
    case target

    var id: Self { self }
}

/// The pair, "EN English ⇄ JA Japanese": each side opens the language
/// picker on that side, and the middle swaps them.
struct LanguagePairCard: View {
    var model: TranslationModel
    var pick: (LanguageSide) -> Void

    var body: some View {
        HStack(spacing: 4) {
            side(.source, language: model.sourceLanguage)

            Button {
                withAnimation(.snappy) { model.swapLanguages() }
            } label: {
                Label("Swap languages", systemImage: "arrow.left.arrow.right")
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .frame(width: 56, height: 56)
                    .background(.raised, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .disabled(!model.canSwapLanguages)

            side(.target, language: model.targetLanguage)
        }
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func side(_ side: LanguageSide, language: Locale.Language?) -> some View {
        let id = language.map(LanguageCatalog.identifier(for:)) ?? LanguageCatalog.automaticIdentifier
        let name = side == .source ? model.sourceTitle : model.name(for: model.targetLanguage)

        return Button {
            pick(side)
        } label: {
            VStack(spacing: 2) {
                Text(LanguageCatalog.abbreviation(forIdentifier: id))
                    .font(.title3.bold())
                    .foregroundStyle(.textPrimary)
                Text(name)
                    .font(.caption)
                    .foregroundStyle(.textMuted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(side == .source ? Text("From \(name)") : Text("To \(name)"))
        .accessibilityHint("Choose a language")
    }
}

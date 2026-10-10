//
//  TranslateView.swift
//  TranslatorMac
//

import SwiftUI

/// The translate screen: two panes, with the language controls in the toolbar.
struct TranslateView: View {
    @Bindable var model: TranslationModel

    var body: some View {
        HStack(spacing: 0) {
            SourcePane(model: model)
            Divider()
            ResultPane(model: model)
        }
        .toolbar(removing: .title)
        .toolbar {
            ToolbarItemGroup(placement: .principal) {
                LanguageMenu(
                    title: "Translate From",
                    selection: $model.sourceLanguage,
                    selectedName: model.sourceLanguage.map(model.name(for:)) ?? "Detect Language",
                    languages: model.supportedLanguages,
                    statuses: model.sourceStatuses,
                    allowsDetection: true
                )

                Button("Swap Languages", systemImage: "arrow.left.arrow.right") {
                    withAnimation(.snappy) { model.swapLanguages() }
                }
                .disabled(!model.canSwapLanguages)
                .help(model.canSwapLanguages
                      ? "Swap the source and target languages"
                      : "Choose a source language to swap")

                LanguageMenu(
                    title: "Translate To",
                    selection: targetSelection,
                    selectedName: model.name(for: model.targetLanguage),
                    languages: model.supportedLanguages,
                    statuses: model.targetStatuses,
                    allowsDetection: false
                )
            }
        }
    }

    /// The target can't be "detect", but the menu is shared with the source
    /// side, so it speaks optional.
    private var targetSelection: Binding<Locale.Language?> {
        Binding {
            model.targetLanguage
        } set: { language in
            if let language { model.targetLanguage = language }
        }
    }
}

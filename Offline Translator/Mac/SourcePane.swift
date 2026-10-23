//
//  SourcePane.swift
//  TranslatorMac
//

import SwiftUI

/// The left pane: where the text to translate is typed.
struct SourcePane: View {
    @Bindable var model: TranslationModel

    @Environment(PurchaseStore.self) private var purchases
    @FocusState private var isEditorFocused: Bool

    /// Points of the editor's own text inset, so the placeholder and the typed
    /// text start on the same column as the header.
    private let editorTextInset: CGFloat = 5

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: model.sourceTitle) {
                if !model.inputText.isEmpty {
                    Button("Clear Text", systemImage: "xmark.circle.fill") {
                        model.clearInput()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .help("Clear the text")
                    .transition(.opacity)
                }
            }
            .animation(.smooth, value: model.inputText.isEmpty)

            editor

            PaneFooter {
                Text("^[\(model.inputText.count) character](inflect: true)")
                    .foregroundStyle(.tertiary)
                    .contentTransition(.numericText())

                Spacer()

                if !purchases.access.unlocksPro {
                    freeTierStatus
                }
            }
            .font(.subheadline)
        }
        .background(.background)
        .onAppear {
            isEditorFocused = true
        }
    }

    private var editor: some View {
        TextEditor(text: $model.inputText)
            .font(.system(size: 17))
            .lineSpacing(4)
            .scrollContentBackground(.hidden)
            .focused($isEditorFocused)
            .padding(.horizontal, PaneMetrics.inset - editorTextInset)
            .overlay(alignment: .topLeading) {
                if model.inputText.isEmpty {
                    Text("Type or paste text")
                        .font(.system(size: 17))
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, PaneMetrics.inset)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel("Text to translate")
    }

    /// Only on the free plan; Pro and the free days have no limit to show.
    private var freeTierStatus: some View {
        Text("\(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay) left today")
            .foregroundStyle(.tertiary)
            .lineLimit(1)
            .contentTransition(.numericText())
            .accessibilityLabel("\(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay) free translations left today")
    }
}

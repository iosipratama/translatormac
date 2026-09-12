//
//  ContentView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import AppKit
import SwiftUI
import SwiftData
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation
import os

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @State private var model = TranslationModel()

    /// Driving translation through a configuration rather than constructing a
    /// `TranslationSession` directly lets the framework prompt to download a
    /// missing language pair instead of failing with an error.
    @State private var configuration: TranslationSession.Configuration?

    var body: some View {
        VStack(spacing: 16) {
            languageBar
            editors
            translateButton
        }
        .padding()
        .frame(minWidth: 760, minHeight: 380)
        .translationTask(configuration) { session in
            await translate(using: session)
        }
        .task {
            await model.loadSupportedLanguages()
        }
        .task(id: languagePairID) {
            await model.refreshAvailability()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("History", systemImage: "clock.arrow.circlepath") {
                    openWindow(id: "history")
                }
                .help("Open History")
            }
        }
    }

    // MARK: - Language selection

    private var languageBar: some View {
        HStack(spacing: 12) {
            Picker("Translate from", selection: $model.sourceLanguage) {
                Text("Detect Language").tag(Locale.Language?.none)
                Divider()
                ForEach(model.supportedLanguages, id: \.self) { language in
                    Text(LanguageCatalog.displayName(for: language))
                        .tag(Locale.Language?.some(language))
                }
            }
            .labelsHidden()
            .accessibilityLabel("Translate from")
            .frame(width: 220)

            Button("Swap languages", systemImage: "arrow.left.arrow.right") {
                withAnimation(.snappy) { model.swapLanguages() }
            }
            .labelStyle(.iconOnly)
            .disabled(!model.canSwapLanguages)
            .help(model.canSwapLanguages
                  ? "Swap the source and target languages"
                  : "Choose a source language to swap")

            Picker("Translate to", selection: $model.targetLanguage) {
                ForEach(model.supportedLanguages, id: \.self) { language in
                    Text(LanguageCatalog.displayName(for: language)).tag(language)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Translate to")
            .frame(width: 220)
        }
        .overlay(alignment: .bottomLeading) {
            if model.availability == .supported {
                Label("This language pair downloads the first time you translate.",
                      systemImage: "arrow.down.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .offset(y: 20)
            }
        }
    }

    // MARK: - Text

    private var editors: some View {
        HStack(spacing: 12) {
            sourceEditor
            resultPane
        }
    }

    private var sourceEditor: some View {
        ZStack(alignment: .topLeading) {
            if model.inputText.isEmpty {
                Text("Type or paste text and ⌘↵ to translate")
                    .foregroundStyle(.tertiary)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $model.inputText)
                .padding(.leading, -4)
                .frame(minHeight: 180)
                .scrollContentBackground(.hidden)
                .background(.clear)
                .accessibilityLabel("Text to translate")
        }
        .font(.body)
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private var resultPane: some View {
        ZStack(alignment: .topLeading) {
            switch model.phase {
            case .idle:
                Text("Translation")
                    .foregroundStyle(.tertiary)

            case .translating:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .translated(let text):
                ScrollView {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }

            case .failed(let message):
                ScrollView {
                    Text(message)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                }
            }
        }
        .frame(minHeight: 180, maxHeight: .infinity, alignment: .topLeading)
        .font(.body)
        .padding(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        .overlay(alignment: .bottomTrailing) {
            if let translation = model.phase.translation {
                Button("Copy translation", systemImage: "document.on.document") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translation, forType: .string)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .padding(8)
                .help("Copy the translation")
            }
        }
        .animation(.smooth, value: model.phase)
    }

    private var translateButton: some View {
        Button("Translate", action: requestTranslation)
            .buttonStyle(.borderedProminent)
            .disabled(!model.canTranslate)
            .keyboardShortcut(.return, modifiers: [.command])
            .help("Translate source → result (⌘↩)")
    }

    // MARK: - Translation

    /// Changes to either language also re-run the availability check.
    private var languagePairID: String {
        let source = model.sourceLanguage.map(LanguageCatalog.identifier(for:)) ?? "auto"
        return "\(source)→\(LanguageCatalog.identifier(for: model.targetLanguage))"
    }

    private func requestTranslation() {
        guard model.canTranslate else { return }
        model.phase = .translating

        let desired = TranslationSession.Configuration(
            source: model.sourceLanguage,
            target: model.targetLanguage
        )

        // Re-running with the same pair needs invalidate(); a configuration that
        // compares equal would not retrigger translationTask.
        if var current = configuration, current.source == desired.source, current.target == desired.target {
            current.invalidate()
            configuration = current
        } else {
            configuration = desired
        }
    }

    private func translate(using session: TranslationSession) async {
        let text = model.trimmedInput
        guard !text.isEmpty else {
            model.phase = .idle
            return
        }

        do {
            let response = try await session.translate(text)
            model.phase = .translated(response.targetText)
            save(source: text, translated: response.targetText, resolvedSource: session.sourceLanguage)
        } catch {
            let message = TranslationFailure.message(
                for: error,
                from: model.sourceLanguage,
                to: model.targetLanguage
            )
            Log.translation.error("Translation failed: \(String(describing: error), privacy: .public)")
            model.phase = message.isEmpty ? .idle : .failed(message)
        }
    }

    private func save(source: String, translated: String, resolvedSource: Locale.Language?) {
        // Record identifiers, not localized display names, so history stays
        // meaningful if the app language changes.
        let sourceID = (resolvedSource ?? model.sourceLanguage)
            .map(LanguageCatalog.identifier(for:)) ?? "auto"

        modelContext.insert(
            TranslationHistory(
                sourceText: source,
                translatedText: translated,
                sourceLanguage: sourceID,
                targetLanguage: LanguageCatalog.identifier(for: model.targetLanguage)
            )
        )

        do {
            try modelContext.save()
        } catch {
            Log.history.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }
}

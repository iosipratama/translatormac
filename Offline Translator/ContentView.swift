//
//  ContentView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \TranslationHistory.createdAt, order: .reverse)
    private var historyItems: [TranslationHistory]

    @State private var inputText = ""
    @State private var outputText = ""
    @State private var fromLanguage = "Auto"
    @State private var toLanguage = "Indonesian"

    private let languages = [
        "Auto",
        "Arabic",
        "Chinese (Simplified)",
        "Chinese (Traditional)",
        "Dutch",
        "English (US)",
        "English (UK)",
        "French",
        "German",
        "Hindi",
        "Indonesian",
        "Italian",
        "Korean",
        "Polish",
        "Portuguese (Brazil)",
        "Russian",
        "Spanish",
        "Thai",
        "Turkish",
        "Ukrainian",
        "Vietnamese"
    ]

    private enum EditedSide { case source, result }
    @State private var lastEdited: EditedSide = .source

    // Small service instance; keeping it here avoids global singletons
    private let translationService = AppleTranslationService()

    private func saveHistory(source: String, translated: String, from: String, to: String) {
        // Persist the actual direction used for this translation
        let item = TranslationHistory(
            sourceText: source,
            translatedText: translated,
            sourceLanguage: from,
            targetLanguage: to,
            createdAt: .now
        )
        modelContext.insert(item)
        try? modelContext.save()
    }

    private func triggerTranslate() {
        // Decide direction based on which editor was last edited
        let textToTranslate: String
        let fromLang: String
        let toLang: String

        switch lastEdited {
        case .source:
            textToTranslate = inputText
            fromLang = fromLanguage
            toLang = toLanguage
        case .result:
            textToTranslate = outputText
            fromLang = toLanguage
            toLang = fromLanguage
        }

        Task {
            do {
                let translated = try await translationService.translate(textToTranslate, from: fromLang, to: toLang)

                // Write result to the opposite side
                switch lastEdited {
                case .source:
                    outputText = translated
                case .result:
                    inputText = translated
                }

                saveHistory(source: textToTranslate, translated: translated, from: fromLang, to: toLang)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                switch lastEdited {
                case .source:
                    outputText = message
                case .result:
                    inputText = message
                }
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Language control
            HStack {
                Picker("", selection: $fromLanguage) {
                    ForEach(languages, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 200)

                Button("Swap") {
                    (fromLanguage, toLanguage) = (toLanguage, fromLanguage)
                }

                Picker("", selection: $toLanguage) {
                    ForEach(languages, id: \.self) { Text($0).tag($0) }
                }
                .frame(width: 200)
            }

            HStack {
                // Source editor
                ZStack(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text("Type or paste text and ⌘↵ to translate")
                            .foregroundStyle(.tertiary)
                            .allowsHitTesting(false)
                    }

                    TextEditor(text: $inputText)
                        .padding(.leading, -4)
                        .frame(minHeight: 180)
                        .scrollContentBackground(.hidden)
                        .background(.clear)
                        .onChange(of: inputText) { _, _ in lastEdited = .source }
                }
                .font(.body)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))

                // Result editor
                ZStack(alignment: .topLeading) {
                    if outputText.isEmpty {
                        Text("Translation")
                            .foregroundStyle(.tertiary)
                    }

                    TextEditor(text: $outputText)
                        .padding(.leading, -4)
                        .frame(minHeight: 180)
                        .background(.clear)
                        .scrollContentBackground(.hidden)
                        .onChange(of: outputText) { _, _ in lastEdited = .result }
                }
                .font(.body)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
            }
            .onChange(of: inputText) { _, newValue in
                // Clear result when source is cleared
                if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    outputText = ""
                }
                lastEdited = .source
            }

            let isDisabled: Bool = {
                switch lastEdited {
                case .source:
                    return inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                case .result:
                    return outputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }
            }()

            Button("Translate", action: triggerTranslate)
                .buttonStyle(.borderedProminent)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.4 : 1.0)
                .keyboardShortcut(.return, modifiers: [.command])
                .help(lastEdited == .source ? "Translate source → result (⌘↩)" : "Translate result → source (⌘↩)")
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    openWindow(id: "history")
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .help("Open History")
            }
        }
        .onAppear {
            // Quick sanity check for data flow; remove if noisy
            print("ContentView sees history count:", historyItems.count)
        }
        .padding()
        .frame(minWidth: 760, minHeight: 360)
    }
}

#Preview {
    ContentView()
}


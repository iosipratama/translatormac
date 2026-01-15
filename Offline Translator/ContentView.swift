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
        "Japanese",
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
        let textToTranslate = inputText
        let fromLang = fromLanguage
        let toLang = toLanguage

        Task {
            do {
                let translated = try await translationService.translate(textToTranslate, from: fromLang, to: toLang)
                // Always write to result
                outputText = translated
                saveHistory(source: textToTranslate, translated: translated, from: fromLang, to: toLang)
            } catch {
                let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                outputText = message
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
                    let trimmedOutput = outputText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedOutput.isEmpty {
                        // Move previous translation into source, clear result, then re-translate in new direction
                        inputText = outputText
                        outputText = ""
                        triggerTranslate()
                    } else {
                        // No previous translation; behave like before
                        let trimmedInput = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedInput.isEmpty {
                            outputText = ""
                        } else {
                            triggerTranslate()
                        }
                    }
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

                    ScrollView {
                        Text(outputText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                    }
                    .frame(minHeight: 180)
                    .background(.clear)
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
            }

            let isDisabled: Bool = inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            Button("Translate", action: triggerTranslate)
                .buttonStyle(.borderedProminent)
                .disabled(isDisabled)
                .opacity(isDisabled ? 0.4 : 1.0)
                .keyboardShortcut(.return, modifiers: [.command])
                .help("Translate source → result (⌘↩)")
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


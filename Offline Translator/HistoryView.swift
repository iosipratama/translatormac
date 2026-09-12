//
//  HistoryView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 29/12/25.
//

import AppKit
import SwiftUI
import SwiftData
import os

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showClearConfirm = false
    /// Loaded so history rows use the same names as the pickers.
    @State private var catalog: [TranslationLanguage] = []

    @Query(sort: \TranslationHistory.createdAt, order: .reverse)
    private var items: [TranslationHistory]

    // Small helper to centralize deletion and saving
    private func deleteAll() {
        for item in items { modelContext.delete(item) }
        do {
            try modelContext.save()
            Log.history.notice("Cleared all history")
        } catch {
            Log.history.error("Failed to clear history: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func delete(at offsets: IndexSet) {
        // Support row deletion from the list
        for index in offsets { modelContext.delete(items[index]) }
        do { try modelContext.save() } catch {
            Log.history.error("Failed to delete items: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// History stores BCP-47 identifiers, so render them for display here.
    private func name(forIdentifier id: String) -> String {
        let language = LanguageCatalog.language(forIdentifier: id)
        let key = LanguageCatalog.groupKey(for: language)
        return catalog.first { LanguageCatalog.groupKey(for: $0.language) == key }?.name
            ?? LanguageCatalog.fallbackName(for: language)
    }

    private func languagePair(for item: TranslationHistory) -> String {
        let source = item.sourceLanguage == "auto" ? "Detected" : name(forIdentifier: item.sourceLanguage)
        return "\(source) → \(name(forIdentifier: item.targetLanguage))"
    }

    @ViewBuilder
    private func row(for item: TranslationHistory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(languagePair(for: item))
                Spacer()
                Text(item.createdAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.tertiary)

            Text(item.sourceText)
                .font(.headline)
            Text(item.translatedText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Copy Translation", systemImage: "document.on.document") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(item.translatedText, forType: .string)
            }
        }
    }

    var body: some View {
        VStack {
            if items.isEmpty {
                // Convey empty state clearly
                ContentUnavailableView("No history yet", systemImage: "clock")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(items) { item in
                        row(for: item)
                    }
                    .onDelete(perform: delete)
                }
                .textSelection(.enabled)
            }
        }
        .task {
            catalog = await LanguageCatalog.supportedLanguages()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
                .disabled(items.isEmpty)
                .help("Delete all history")
            }
        }
        .confirmationDialog(
            "Clear all translation history?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete All", role: .destructive, action: deleteAll)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}


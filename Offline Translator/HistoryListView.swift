//
//  HistoryListView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 29/12/25.
//

import AppKit
import SwiftUI
import SwiftData
import os

/// Recent and Saved share one store and one list; Saved is the starred subset.
struct HistoryListView: View {
    enum Scope {
        case recent
        case saved

        var title: LocalizedStringKey {
            switch self {
            case .recent: "Recent"
            case .saved: "Saved"
            }
        }
    }

    var scope: Scope

    @Environment(\.modelContext) private var modelContext
    @State private var showClearConfirm = false
    /// Loaded so history rows use the same names as the menus.
    @State private var catalog: [TranslationLanguage] = []

    @Query private var items: [TranslationHistory]

    init(scope: Scope) {
        self.scope = scope
        switch scope {
        case .recent:
            _items = Query(sort: \TranslationHistory.createdAt, order: .reverse)
        case .saved:
            _items = Query(
                filter: #Predicate<TranslationHistory> { $0.isSaved },
                sort: \TranslationHistory.createdAt,
                order: .reverse
            )
        }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(items) { item in
                        row(for: item)
                    }
                }
                .textSelection(.enabled)
            }
        }
        .navigationTitle(scope.title)
        .task {
            catalog = await LanguageCatalog.supportedLanguages()
        }
        .toolbar {
            if scope == .recent {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear Recent", systemImage: "trash", role: .destructive) {
                        showClearConfirm = true
                    }
                    .disabled(items.allSatisfy(\.isSaved))
                    .help("Remove everything that isn’t saved")
                }
            }
        }
        .confirmationDialog(
            "Clear recent translations?",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Clear Recent", role: .destructive, action: clearRecent)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Saved translations are kept. This can’t be undone.")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        switch scope {
        case .recent:
            ContentUnavailableView(
                "No Recent Translations",
                systemImage: "clock",
                description: Text("Translations you make show up here.")
            )
        case .saved:
            ContentUnavailableView(
                "No Saved Translations",
                systemImage: "star",
                description: Text("Star a translation to keep it here.")
            )
        }
    }

    @ViewBuilder
    private func row(for item: TranslationHistory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(languagePair(for: item))
                Spacer()
                if item.isSaved {
                    Image(systemName: "star.fill")
                        .accessibilityLabel("Saved")
                }
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
            Button(item.isSaved ? "Remove from Saved" : "Save", systemImage: item.isSaved ? "star.slash" : "star") {
                item.isSaved.toggle()
                save()
            }
            Divider()
            Button("Delete", systemImage: "trash", role: .destructive) {
                modelContext.delete(item)
                save()
            }
        }
    }

    // MARK: - Data

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

    private func clearRecent() {
        for item in items where !item.isSaved {
            modelContext.delete(item)
        }
        save()
        Log.history.notice("Cleared recent translations")
    }

    private func save() {
        do {
            try modelContext.save()
        } catch {
            Log.history.error("Failed to save history: \(error.localizedDescription, privacy: .public)")
        }
    }
}

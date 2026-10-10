//
//  HistoryContent.swift
//  TranslatorMac
//

import AppKit
import SwiftData
import SwiftUI

/// The table of history entries with the selected one shown in full below.
struct HistoryContent: View {
    var scope: HistoryListView.Scope
    var searchText: String
    @Binding var selection: TranslationHistory.ID?
    var openInTranslate: (TranslationHistory?) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var speaker = TranslationSpeaker()

    @Query private var items: [TranslationHistory]

    init(
        scope: HistoryListView.Scope,
        searchText: String,
        selection: Binding<TranslationHistory.ID?>,
        openInTranslate: @escaping (TranslationHistory?) -> Void
    ) {
        self.scope = scope
        self.searchText = searchText
        _selection = selection
        self.openInTranslate = openInTranslate

        let text = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate: Predicate<TranslationHistory>
        switch (scope, text.isEmpty) {
        case (.recent, true):
            predicate = #Predicate { _ in true }
        case (.recent, false):
            predicate = #Predicate {
                $0.sourceText.localizedStandardContains(text)
                    || $0.translatedText.localizedStandardContains(text)
            }
        case (.saved, true):
            predicate = #Predicate { $0.isSaved }
        case (.saved, false):
            predicate = #Predicate {
                $0.isSaved
                    && ($0.sourceText.localizedStandardContains(text)
                        || $0.translatedText.localizedStandardContains(text))
            }
        }
        _items = Query(filter: predicate, sort: \TranslationHistory.createdAt, order: .reverse)
    }

    private var store: HistoryStore {
        HistoryStore(context: modelContext)
    }

    private var selectedEntry: TranslationHistory? {
        items.first { $0.id == selection }
    }

    var body: some View {
        Group {
            if items.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    table
                    if let entry = selectedEntry {
                        HistoryDetailPane(entry: entry, speaker: speaker) {
                            openInTranslate(entry)
                        } onDelete: {
                            delete([entry])
                        }
                    }
                    statusBar
                }
            }
        }
        // Something is always selected while there are rows, so the detail
        // pane never sits empty.
        .onChange(of: items.map(\.id), initial: true) { _, ids in
            if let selection, ids.contains(selection) { return }
            selection = ids.first
        }
        .focusedSceneValue(\.copyTranslation, selectedEntry.map { entry in
            CopyTranslationAction(text: entry.translatedText) { copy(entry.translatedText) }
        })
    }

    // MARK: - Table

    private var table: some View {
        Table(items, selection: $selection) {
            TableColumn("") { entry in
                SaveStar(entry: entry)
            }
            .width(24)

            TableColumn("Original") { entry in
                Text(entry.sourceText)
                    .lineLimit(1)
            }

            TableColumn("Translation") { entry in
                Text(entry.translatedText)
                    .lineLimit(1)
            }

            TableColumn("Languages") { entry in
                Text(pair(for: entry))
                    .foregroundStyle(.secondary)
            }
            .width(84)

            TableColumn("When") { entry in
                Text(HistoryDate.label(for: entry.createdAt))
                    .foregroundStyle(.secondary)
            }
            .width(96)
        }
        .alternatingRowBackgrounds()
        .contextMenu(forSelectionType: TranslationHistory.ID.self) { ids in
            contextMenu(for: entries(ids))
        } primaryAction: { ids in
            if let entry = entries(ids).first {
                openInTranslate(entry)
            }
        }
        .onDeleteCommand {
            if let entry = selectedEntry {
                delete([entry])
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for entries: [TranslationHistory]) -> some View {
        if let entry = entries.first, entries.count == 1 {
            Button("Open in Translate") {
                openInTranslate(entry)
            }
            Divider()
            Button("Copy Translation") {
                copy(entry.translatedText)
            }
            Button("Copy Original") {
                copy(entry.sourceText)
            }
            Divider()
            Button(entry.isSaved ? "Remove from Saved" : "Save") {
                entry.isSaved.toggle()
                store.save()
            }
            Divider()
        }
        if !entries.isEmpty {
            Button("Delete", role: .destructive) {
                delete(entries)
            }
        }
    }

    private func entries(_ ids: Set<TranslationHistory.ID>) -> [TranslationHistory] {
        items.filter { ids.contains($0.id) }
    }

    private func pair(for entry: TranslationHistory) -> String {
        "\(LanguageCatalog.abbreviation(forIdentifier: entry.sourceLanguageID)) → \(LanguageCatalog.abbreviation(forIdentifier: entry.targetLanguageID))"
    }

    // MARK: - Actions

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    /// Moves the selection to the next row so the keyboard flow isn't lost.
    private func delete(_ entries: [TranslationHistory]) {
        let ids = Set(entries.map(\.id))
        if let selection, ids.contains(selection) {
            let remaining = items.filter { !ids.contains($0.id) }
            let index = items.firstIndex { $0.id == selection } ?? 0
            self.selection = remaining[safe: index]?.id ?? remaining.last?.id
        }
        store.delete(entries)
    }

    // MARK: - Chrome

    private var statusBar: some View {
        HStack {
            if searchText.isEmpty {
                Text("^[\(items.count) translation](inflect: true) · kept on this Mac only")
            } else {
                Text("^[\(items.count) result](inflect: true)")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !searchText.isEmpty {
            ContentUnavailableView.search(text: searchText)
        } else {
            switch scope {
            case .recent:
                ContentUnavailableView {
                    Label("No translations yet", systemImage: "clock")
                } description: {
                    Text("Translations you copy, save, or pause on show up here. They stay on this Mac.")
                } actions: {
                    Button("Start Translating") {
                        openInTranslate(nil)
                    }
                }
            case .saved:
                ContentUnavailableView {
                    Label("No saved translations", systemImage: "star")
                } description: {
                    Text("Star a translation to keep it here. Saved translations are never cleared.")
                } actions: {
                    Button("Start Translating") {
                        openInTranslate(nil)
                    }
                }
            }
        }
    }
}

/// The star in each row. A toggle, so its state reads as state.
private struct SaveStar: View {
    var entry: TranslationHistory

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Toggle("Save", systemImage: entry.isSaved ? "star.fill" : "star", isOn: Binding(
            get: { entry.isSaved },
            set: { isSaved in
                entry.isSaved = isSaved
                HistoryStore(context: modelContext).save()
            }
        ))
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .foregroundStyle(entry.isSaved ? AnyShapeStyle(.yellow) : AnyShapeStyle(.secondary))
        .help(entry.isSaved ? "Remove from Saved" : "Save")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

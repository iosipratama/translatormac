//
//  HistoryContent.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI

/// The table of history entries with the selected one shown in full below.
struct HistoryContent: View {
    var scope: HistoryListView.Scope
    var searchText: String
    @Binding var selection: TranslationHistory.ID?
    var openInTranslate: (TranslationHistory?) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.undoManager) private var undoManager
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro
    @Environment(\.openSettings) private var openSettings
    @AppStorage(SettingsKey.keepHistory) private var keepsHistory = true
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
        switch scope {
        case .recent:
            let predicate: Predicate<TranslationHistory> = text.isEmpty
                ? #Predicate { _ in true }
                : #Predicate {
                    $0.sourceText.localizedStandardContains(text)
                        || $0.translatedText.localizedStandardContains(text)
                }
            _items = Query(
                filter: predicate,
                sort: [SortDescriptor(\TranslationHistory.createdAt, order: .reverse)],
                animation: .smooth
            )
        case .saved:
            let predicate: Predicate<TranslationHistory> = text.isEmpty
                ? #Predicate { $0.isSaved }
                : #Predicate {
                    $0.isSaved
                        && ($0.sourceText.localizedStandardContains(text)
                            || $0.translatedText.localizedStandardContains(text))
                }
            // Newest saved first; entries starred before savedAt existed sort
            // by when they were made.
            _items = Query(
                filter: predicate,
                sort: [
                    SortDescriptor(\TranslationHistory.savedAt, order: .reverse),
                    SortDescriptor(\TranslationHistory.createdAt, order: .reverse),
                ],
                animation: .smooth
            )
        }
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
                        HistoryDetailPane(entry: entry, scope: scope, speaker: speaker) {
                            openInTranslate(entry)
                        } onSetSaved: { isSaved in
                            setSaved([entry], isSaved)
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
                SaveStar(entry: entry) { isSaved in
                    setSaved([entry], isSaved)
                }
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

            TableColumn(scope == .saved ? "Saved" : "When") { entry in
                Text(HistoryDate.label(for: scope == .saved ? entry.savedDate : entry.createdAt))
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
            guard let entry = selectedEntry else { return }
            // In Saved the Delete key only unstars: the entry survives in
            // Recent, and the action can be undone.
            switch scope {
            case .recent: delete([entry])
            case .saved: setSaved([entry], false)
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
        }
        if !entries.isEmpty {
            switch scope {
            case .recent:
                let allSaved = entries.allSatisfy(\.isSaved)
                Button(allSaved ? "Remove from Saved" : "Save") {
                    setSaved(entries, !allSaved)
                }
                Divider()
                Button("Delete", role: .destructive) {
                    delete(entries)
                }
            case .saved:
                Button("Remove from Saved") {
                    setSaved(entries, false)
                }
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
        Clipboard.copy(text)
    }

    private func setSaved(_ entries: [TranslationHistory], _ isSaved: Bool) {
        // In Saved an unstarred row leaves the list, so hand the selection on
        // first, as a deletion would.
        if scope == .saved, !isSaved {
            moveSelectionPast(entries)
        }
        for entry in entries where entry.isSaved != isSaved {
            if isSaved, !purchases.canSaveNew {
                pro.present()
                return
            }
            store.setSaved(entry, isSaved, undoManager: undoManager)
        }
    }

    private func delete(_ entries: [TranslationHistory]) {
        moveSelectionPast(entries)
        store.delete(entries)
    }

    /// Moves the selection to the next row so the keyboard flow isn't lost
    /// when the selected rows are about to go.
    private func moveSelectionPast(_ entries: [TranslationHistory]) {
        let ids = Set(entries.map(\.id))
        guard let selection, ids.contains(selection) else { return }
        let remaining = items.filter { !ids.contains($0.id) }
        let index = items.firstIndex { $0.id == selection } ?? 0
        self.selection = remaining[safe: index]?.id ?? remaining.last?.id
    }

    // MARK: - Chrome

    private var statusBar: some View {
        HStack {
            if !searchText.isEmpty {
                Text("^[\(items.count) result](inflect: true)")
            } else if scope == .saved {
                Text("\(items.count) saved · never deleted automatically")
            } else {
                Text("^[\(items.count) translation](inflect: true) · kept on this Mac only")
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
            case .recent where !keepsHistory:
                // Saying translations will show up here would be untrue.
                ContentUnavailableView {
                    Label("History is off", systemImage: "clock")
                } description: {
                    Text("Turn on “Keep a history of translations” in Settings to see translations here.")
                } actions: {
                    Button("Open Settings…") {
                        SettingsNavigation.show(.general, using: openSettings)
                    }
                }
            case .recent:
                ContentUnavailableView {
                    Label("No translations yet", systemImage: "clock")
                } description: {
                    Text("Translations you make show up here. They stay on this Mac.")
                } actions: {
                    Button("Start Translating") {
                        openInTranslate(nil)
                    }
                }
            case .saved:
                ContentUnavailableView {
                    Label("No saved translations", systemImage: "star")
                } description: {
                    Text("Click the star on any translation to keep it here. Saved translations are never deleted automatically.")
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
    var onChange: (Bool) -> Void

    var body: some View {
        Toggle(entry.isSaved ? "Remove from Saved" : "Save", systemImage: entry.isSaved ? "star.fill" : "star", isOn: Binding(
            get: { entry.isSaved },
            set: { onChange($0) }
        ))
        .toggleStyle(.button)
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .foregroundStyle(entry.isSaved ? AnyShapeStyle(Color.accentForeground) : AnyShapeStyle(.secondary))
        .help(entry.isSaved ? "Remove from Saved" : "Save")
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

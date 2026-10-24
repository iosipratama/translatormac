//
//  LibraryScreen.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI

/// Saved and Recent translations. Tapping one opens it on Translate; swipes
/// and the long-press menu save, unsave, copy, read aloud and delete.
struct LibraryScreen: View {
    var model: TranslationModel
    /// The tab to open on; `nil` returns to the one used last.
    var initialTab: LibraryTab?
    var showTranslate: () -> Void
    var showSettings: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro
    @Environment(ReviewPrompter.self) private var reviews

    @SceneStorage("libraryTab") private var tab: LibraryTab = .saved
    @AppStorage(SettingsKey.keepHistory) private var keepsHistory = true

    @Query(sort: \TranslationHistory.createdAt, order: .reverse, animation: .smooth)
    private var everything: [TranslationHistory]

    @State private var query = ""
    @State private var toast: ToastMessage?
    @State private var isConfirmingClear = false
    @State private var savedCount = 0

    var body: some View {
        List {
            ForEach(rows) { entry in
                row(entry)
            }

            if !rows.isEmpty {
                footer
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .overlay {
            if rows.isEmpty {
                emptyState
            }
        }
        .safeAreaBar(edge: .top) {
            Picker("List", selection: $tab) {
                ForEach(LibraryTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tab.searchPrompt)
        .navigationTitle("Library")
        .toolbarTitleDisplayMode(.large)
        .toolbar {
            if tab == .recent {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("More", systemImage: "ellipsis") {
                        Button("Clear History…", systemImage: "trash", role: .destructive) {
                            isConfirmingClear = true
                        }
                        .disabled(!everything.contains { !$0.isSaved })
                    }
                    .tint(.textPrimary)
                }
            }
        }
        .confirmationDialog("Clear history?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) {
                model.historyWillClear()
                store.clearRecent()
            }
        } message: {
            Text("This removes every recent translation from this iPhone. Saved translations stay.")
        }
        .toast($toast, bottomPadding: 8)
        .sensoryFeedback(.success, trigger: savedCount)
        .onAppear {
            if let initialTab { tab = initialTab }
        }
    }

    // MARK: - Rows

    private func row(_ entry: TranslationHistory) -> some View {
        LibraryRow(entry: entry) {
            open(entry)
        } toggleSaved: {
            setSaved(entry, !entry.isSaved)
        }
        .swipeActions(edge: .trailing) {
            // Red pinned: the app's tint would otherwise color these too.
            switch tab {
            case .saved:
                Button("Unsave", systemImage: "star.slash", role: .destructive) {
                    setSaved(entry, false)
                }
                .tint(.red)
            case .recent:
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(entry)
                }
                .tint(.red)
            }
        }
        .swipeActions(edge: .leading) {
            if tab == .recent {
                Button(entry.isSaved ? "Unsave" : "Save", systemImage: entry.isSaved ? "star.slash" : "star.fill") {
                    setSaved(entry, !entry.isSaved)
                }
                .tint(Color.accent)
            }
        }
        .contextMenu {
            Button("Copy Translation", systemImage: "document.on.document") {
                Clipboard.copy(entry.translatedText)
            }
            Button("Copy Original", systemImage: "text.quote") {
                Clipboard.copy(entry.sourceText)
            }
            Button("Read Aloud", systemImage: "speaker.wave.2") {
                model.speaker.speak(entry.translatedText, in: LanguageCatalog.language(forIdentifier: entry.targetLanguageID))
            }
            Button(entry.isSaved ? "Unsave" : "Save", systemImage: entry.isSaved ? "star.slash" : "star") {
                setSaved(entry, !entry.isSaved)
            }
            if tab == .recent {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    delete(entry)
                }
            }
        }
        .listRowBackground(Color.canvas)
        .listRowSeparatorTint(.line)
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
    }

    @ViewBuilder
    private var footer: some View {
        footerText
            .font(.footnote)
            .foregroundStyle(.textMuted)
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }

    private var footerText: Text {
        if !query.isEmpty {
            return Text("^[\(rows.count) result](inflect: true)")
        }
        switch tab {
        case .saved:
            return Text("\(rows.count) saved · never deleted automatically")
        case .recent:
            return Text("^[\(rows.count) translation](inflect: true) · kept on this iPhone only")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else {
            switch tab {
            case .recent where !keepsHistory:
                // Saying translations will show up here would be untrue.
                ContentUnavailableView {
                    Label("History is off", systemImage: "clock")
                } description: {
                    Text("Turn on history in Settings to see your translations here.")
                } actions: {
                    startButton("Open Settings", action: showSettings)
                }
            case .recent:
                ContentUnavailableView {
                    Label("No translations yet", systemImage: "clock")
                } description: {
                    Text("Translations you finish, copy or save show up here. They stay on this iPhone.")
                } actions: {
                    startButton("Start Translating", action: showTranslate)
                }
            case .saved:
                ContentUnavailableView {
                    Label("No saved translations", systemImage: "star")
                } description: {
                    Text("Tap the star on any translation to keep it here. Saved items are never deleted automatically.")
                } actions: {
                    startButton("Start Translating", action: showTranslate)
                }
            }
        }
    }

    private func startButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.horizontal, 8)
        }
        .buttonStyle(.glassProminent)
        .controlSize(.large)
        .tint(.inverse)
        .foregroundStyle(.onInverse)
    }

    // MARK: - Lists

    private var store: HistoryStore {
        HistoryStore(context: modelContext)
    }

    private var rows: [TranslationHistory] {
        let base = tab == .saved ? saved : everything
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.translatedText.localizedStandardContains(query) || $0.sourceText.localizedStandardContains(query)
        }
    }

    /// Newest star first; entries starred before that was recorded sort by
    /// when they were made.
    private var saved: [TranslationHistory] {
        everything
            .filter(\.isSaved)
            .sorted { $0.savedDate > $1.savedDate }
    }

    // MARK: - Actions

    private func open(_ entry: TranslationHistory) {
        model.load(entry)
        showTranslate()
    }

    private func setSaved(_ entry: TranslationHistory, _ isSaved: Bool) {
        if isSaved {
            guard purchases.canSaveNew else {
                pro.present()
                return
            }
            store.setSaved(entry, true)
            savedCount += 1
            reviews.noteSaved(total: store.savedCount())
        } else {
            let savedAt = entry.savedAt
            store.setSaved(entry, false)
            toast = ToastMessage(
                text: "Removed from Saved",
                action: .init(title: "Undo") { store.restoreSaved(entry, savedAt: savedAt) },
                duration: .seconds(4)
            )
        }
    }

    private func delete(_ entry: TranslationHistory) {
        model.historyWillDelete([entry])
        store.delete([entry])
    }
}

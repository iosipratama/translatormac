//
//  HistoryListView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 29/12/25.
//

import SwiftData
import SwiftUI

/// Recent and Saved share one store and one screen; Saved is the starred
/// subset. This view owns the toolbar, search and the clear confirmation;
/// `HistoryContent` owns the query, since the search text shapes it.
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
    /// Switches to the translate screen, loading the entry when there is one.
    var openInTranslate: (TranslationHistory?) -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var searchText = ""
    @State private var selection: TranslationHistory.ID?
    @State private var showClearConfirm = false

    /// Only to know whether there is anything to clear.
    @Query(filter: #Predicate<TranslationHistory> { !$0.isSaved })
    private var unsaved: [TranslationHistory]

    var body: some View {
        HistoryContent(
            scope: scope,
            searchText: searchText,
            selection: $selection,
            openInTranslate: openInTranslate
        )
        .navigationTitle(scope.title)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
        .toolbar {
            if scope == .recent {
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear History…") {
                        showClearConfirm = true
                    }
                    .disabled(unsaved.isEmpty)
                    .help("Remove every translation that isn’t saved")
                }
            }
        }
        .alert("Clear all history?", isPresented: $showClearConfirm) {
            Button("Clear History", role: .destructive) {
                HistoryStore(context: modelContext).clearRecent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every translation in Recent. Saved translations are kept.")
        }
    }
}

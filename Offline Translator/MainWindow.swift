//
//  MainWindow.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// The app's window: a sidebar of screens beside the one that's selected.
struct MainWindow: View {
    @Environment(PurchaseStore.self) private var purchases

    @State private var model: TranslationModel
    @State private var selection: SidebarItem = .translate

    /// The model outlives the translate screen so switching to Recent and back
    /// keeps the text and result. `State` only reads this value the first time
    /// the window is created.
    init(modelContext: ModelContext, purchases: PurchaseStore) {
        _model = State(initialValue: TranslationModel(modelContext: modelContext, purchases: purchases))
    }

    var body: some View {
        NavigationSplitView {
            AppSidebar(selection: $selection)
        } detail: {
            switch selection {
            case .translate:
                TranslateView(model: model)
            case .recent:
                HistoryListView(scope: .recent)
            case .saved:
                HistoryListView(scope: .saved)
            }
        }
        .frame(minWidth: 800, minHeight: 520)
        // Attached here rather than to the translate screen so a translation or
        // download prompt that's underway survives a switch to another screen.
        .translationTask(model.configuration) { session in
            await model.translate(using: session)
        }
        .task {
            await model.loadSupportedLanguages()
        }
        .task(id: model.availabilityKey) {
            await model.refreshAvailability()
        }
        .onChange(of: purchases.canTranslate) { _, canTranslate in
            // Buying Pro while blocked should pick up where typing left off.
            if canTranslate { model.requestTranslation() }
        }
        .focusedSceneValue(\.sidebarSelection, $selection)
        .focusedSceneValue(\.translationModel, model)
    }
}

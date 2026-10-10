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
            Group {
                switch selection {
                case .translate:
                    TranslateView(model: model)
                case .recent:
                    HistoryListView(scope: .recent, openInTranslate: open)
                case .saved:
                    HistoryListView(scope: .saved, openInTranslate: open)
                }
            }
            // The size goes on the detail, not the split view: on macOS 26 a
            // frame on NavigationSplitView itself lays the content out at the
            // split view's own screen-tall measurement and centers it, pushing
            // the headers and footers out of view until the next layout.
            .frame(minWidth: 600, idealWidth: 800, minHeight: 520, idealHeight: 660)
        }
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

    /// Shows the translate screen, with a history entry loaded when given one.
    private func open(_ entry: TranslationHistory?) {
        if let entry {
            model.load(entry)
        }
        selection = .translate
    }
}

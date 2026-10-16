//
//  RootView.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// The iPhone app's tabs, and the translation engine they share.
struct RootView: View {
    @Environment(PurchaseStore.self) private var purchases

    @State private var model: TranslationModel
    @State private var selection: AppTab = .translate
    @AppStorage(SettingsKey.translationQuality) private var quality: TranslationQuality = .fast
    @AppStorage(SettingsKey.appearance) private var theme: AppTheme = .automatic

    /// The model outlives the tabs so switching away and back keeps the text
    /// and result. `State` only reads this value the first time.
    init(modelContext: ModelContext, purchases: PurchaseStore) {
        _model = State(initialValue: TranslationModel(modelContext: modelContext, purchases: purchases))
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(AppTab.allCases) { tab in
                Tab(tab.title, systemImage: tab.systemImage, value: tab) {
                    NavigationStack {
                        // Each screen is designed and built in turn; until
                        // then the tab says what it will hold.
                        ContentUnavailableView(tab.title, systemImage: tab.systemImage, description: Text("Coming soon"))
                            .navigationTitle(tab.title)
                    }
                }
            }
        }
        // Attached here rather than to the translate screen so a translation or
        // download prompt that's underway survives a switch to another tab.
        .translationTask(model.configuration) { session in
            await model.translate(using: session)
        }
        .task {
            await model.loadSupportedLanguages()
        }
        .task(id: model.availabilityKey) {
            await model.refreshAvailability()
        }
        .onChange(of: quality) {
            Task { await model.translationQualityDidChange() }
        }
        .onChange(of: purchases.canTranslate) { _, canTranslate in
            if canTranslate { model.requestTranslation() }
        }
        .preferredColorScheme(theme.colorScheme)
    }
}

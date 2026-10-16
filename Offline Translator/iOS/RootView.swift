//
//  RootView.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// The iPhone app: one navigation stack with Translate at its root, and the
/// translation engine every screen shares.
struct RootView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro

    @State private var model: TranslationModel
    @State private var path: [AppRoute] = []
    @AppStorage(SettingsKey.translationQuality) private var quality: TranslationQuality = .fast
    @AppStorage(SettingsKey.appearance) private var theme: AppTheme = .automatic

    /// The model outlives the pushed screens so going to Library and back
    /// keeps the text and result. `State` only reads this value the first time.
    init(modelContext: ModelContext, purchases: PurchaseStore) {
        _model = State(initialValue: TranslationModel(modelContext: modelContext, purchases: purchases))
    }

    var body: some View {
        NavigationStack(path: $path) {
            TranslateScreen(model: model) { path.append($0) }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .library:
                        placeholder("Library", systemImage: "bookmark")
                    case .settings:
                        placeholder("Settings", systemImage: "slider.horizontal.3")
                    }
                }
        }
        // Yellow text fails contrast on the light background, so tinted text
        // (links, Done, Cancel) uses the deepened accent there. Filled
        // buttons pin the true yellow themselves; see AccentStyles.swift.
        .tint(.accentForeground)
        // Attached here rather than to the translate screen so a translation or
        // download prompt that's underway survives a push to another screen.
        .translationTask(model.configuration) { session in
            await model.translate(using: session)
        }
        .task {
            await model.loadSupportedLanguages()
            await model.chooseStartingPair()
        }
        .task(id: model.availabilityKey) {
            await model.refreshAvailability()
        }
        .onChange(of: quality) {
            Task { await model.translationQualityDidChange() }
        }
        .onChange(of: purchases.canTranslate) { _, canTranslate in
            // Buying Pro while blocked should pick up where typing left off.
            if canTranslate { model.requestTranslation() }
        }
        .sheet(isPresented: Bindable(pro).isPresented) {
            ProPlaceholderSheet()
        }
        .preferredColorScheme(theme.colorScheme)
    }

    /// Stands in for a screen until it's designed and built.
    private func placeholder(_ title: LocalizedStringKey, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text("Coming soon"))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.canvas)
            .navigationTitle(title)
    }
}

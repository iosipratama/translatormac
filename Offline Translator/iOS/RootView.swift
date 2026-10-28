//
//  RootView.swift
//  TranslatorMac
//

import StoreKit
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
    @Environment(ReviewPrompter.self) private var reviews
    @Environment(\.requestReview) private var requestReview

    @State private var model: TranslationModel
    @State private var path: [AppRoute] = []
    /// Which languages are downloaded, for Settings and its Languages page.
    @State private var inventory = LanguageInventory()
    @State private var toast: ToastMessage?
    @State private var notice: FreeAccessNotice?
    /// Set when the notice's "See Pro Plans" closes it, so the Pro sheet
    /// opens once it's gone; only one sheet can show at a time.
    @State private var showsPlansAfterNotice = false
    /// Read so a change in Settings refreshes the view, and with it
    /// `TranslationQuality.effective`.
    @AppStorage(SettingsKey.translationQuality) private var quality: TranslationQuality = .fast
    @AppStorage(SettingsKey.appearance) private var theme: AppTheme = .automatic
    @AppStorage(OnboardingModel.didFinishKey) private var didFinishOnboarding = false

    /// The model outlives the pushed screens so going to Library and back
    /// keeps the text and result. `State` only reads this value the first time.
    init(modelContext: ModelContext, purchases: PurchaseStore, reviews: ReviewPrompter) {
        _model = State(initialValue: TranslationModel(modelContext: modelContext, purchases: purchases, reviews: reviews))
    }

    var body: some View {
        NavigationStack(path: $path) {
            TranslateScreen(model: model) { path.append($0) }
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .library(let tab):
                        LibraryScreen(model: model, initialTab: tab) {
                            path.removeAll()
                        } showSettings: {
                            path.append(.settings)
                        }
                    case .settings:
                        SettingsScreen(model: model, inventory: inventory)
                    case .languages:
                        LanguagesScreen(model: model, inventory: inventory)
                    #if DEBUG
                    case .debug:
                        DebugScreen {
                            // Back to Translate, then the flow covers it as
                            // on a first launch.
                            path.removeAll()
                            model.clearInput()
                            didFinishOnboarding = false
                        }
                    #endif
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
        .onChange(of: TranslationQuality.effective) {
            // Changes with the setting, and when Pro or the free days end.
            Task { await model.translationQualityDidChange() }
        }
        .onChange(of: model.upgradePrompts) {
            pro.present()
        }
        .onChange(of: reviews.requests) {
            requestReview()
        }
        .onChange(of: pro.isPresented) { _, isPresented in
            // No rating request in a session that showed the Pro sheet.
            if isPresented { reviews.noteInterruption() }
            // A notice that came due while the sheet was up waits for it.
            if !isPresented { showNoticeIfDue(purchases.dueFreeAccessNotice) }
        }
        .onChange(of: purchases.canTranslate) { _, canTranslate in
            // Buying Pro while blocked should pick up where typing left off.
            if canTranslate { model.requestTranslation() }
        }
        .fullScreenCover(isPresented: Binding { !didFinishOnboarding } set: { _ in }) {
            OnboardingFlow { source, target in
                adoptStartingPair(source: source, target: target)
                didFinishOnboarding = true
            }
        }
        .sheet(isPresented: Bindable(pro).isPresented) {
            PaywallSheet {
                toast = ToastMessage(text: "Pro is active", systemImage: "checkmark.seal.fill")
            }
        }
        .sheet(item: $notice) {
            if showsPlansAfterNotice {
                showsPlansAfterNotice = false
                pro.present()
            }
        } content: { notice in
            FreeAccessNoticeSheet(notice: notice) {
                showsPlansAfterNotice = true
                self.notice = nil
            }
        }
        // At launch, on the last free day, and when the day changes while
        // the app is open; never over onboarding or the Pro sheet.
        .onChange(of: purchases.dueFreeAccessNotice, initial: true) { _, due in
            showNoticeIfDue(due)
        }
        .onChange(of: didFinishOnboarding) {
            showNoticeIfDue(purchases.dueFreeAccessNotice)
        }
        .toast($toast, bottomPadding: 24)
        .preferredColorScheme(theme.colorScheme)
    }

    private func showNoticeIfDue(_ due: FreeAccessNotice?) {
        guard let due, didFinishOnboarding, notice == nil, !pro.isPresented else { return }
        purchases.markFreeAccessNoticeShown()
        notice = due
    }

    /// Opens Translate on the device's language and the first language
    /// onboarding downloaded.
    private func adoptStartingPair(source: Locale.Language?, target: Locale.Language?) {
        guard let target else { return }
        if let source, source != target {
            model.sourceLanguage = source
        }
        model.targetLanguage = target
    }
}

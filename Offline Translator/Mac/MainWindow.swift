//
//  MainWindow.swift
//  TranslatorMac
//

import StoreKit
import SwiftData
import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// The app's window: a sidebar of screens beside the one that's selected.
struct MainWindow: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro
    @Environment(ReviewPrompter.self) private var reviews
    @Environment(\.requestReview) private var requestReview

    @State private var model: TranslationModel
    @State private var selection: SidebarItem = .translate
    @State private var notice: FreeAccessNotice?
    /// Set when the notice's "See Pro Plans" closes it, so the Pro sheet
    /// opens once it's gone; only one sheet can show at a time.
    @State private var showsPlansAfterNotice = false
    /// Read so a change in Settings refreshes the view, and with it
    /// `TranslationQuality.effective`.
    @AppStorage(SettingsKey.translationQuality) private var quality: TranslationQuality = .fast

    /// The model outlives the translate screen so switching to Recent and back
    /// keeps the text and result. `State` only reads this value the first time
    /// the window is created.
    init(modelContext: ModelContext, purchases: PurchaseStore, reviews: ReviewPrompter) {
        _model = State(initialValue: TranslationModel(modelContext: modelContext, purchases: purchases, reviews: reviews))
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
            .frame(minWidth: 600, idealWidth: 800, minHeight: ScreenshotMode.isEnabled ? 400 : 520, idealHeight: 660)
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
        }
        .onChange(of: purchases.canTranslate) { _, canTranslate in
            // Buying Pro while blocked should pick up where typing left off.
            if canTranslate { model.requestTranslation() }
        }
        .focusedSceneValue(\.sidebarSelection, $selection)
        .focusedSceneValue(\.translationModel, model)
        .sheet(isPresented: Bindable(pro).isPresented) {
            ProView()
        }
        .sheet(item: $notice) {
            if showsPlansAfterNotice {
                showsPlansAfterNotice = false
                pro.present()
            }
        } content: { notice in
            FreeAccessNoticeView(notice: notice) {
                showsPlansAfterNotice = true
                self.notice = nil
            }
        }
        // At launch, on the last free day, and when the day changes while
        // the app is open.
        .onChange(of: purchases.dueFreeAccessNotice, initial: true) { _, due in
            showNoticeIfDue(due)
        }
        .onChange(of: pro.isPresented) { _, isPresented in
            if !isPresented { showNoticeIfDue(purchases.dueFreeAccessNotice) }
        }
    }

    /// The notice waits while the Pro sheet is up, and shows only once.
    private func showNoticeIfDue(_ due: FreeAccessNotice?) {
        guard let due, notice == nil, !pro.isPresented else { return }
        purchases.markFreeAccessNoticeShown()
        notice = due
    }

    /// Shows the translate screen, with a history entry loaded when given one.
    private func open(_ entry: TranslationHistory?) {
        if let entry {
            model.load(entry)
        }
        selection = .translate
    }
}

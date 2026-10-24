//
//  TranslateOfflineApp.swift
//  TranslatorMac
//
//  The iPhone app. It shares the models in Shared/ with the Mac app — the
//  translation engine, history, Pro and its daily allowance — and has its
//  own screens in this folder.
//

import SwiftData
import SwiftUI

@main
struct TranslateOfflineApp: App {
    @State private var purchases = PurchaseStore()
    @State private var pro = ProPresentation()
    @State private var reviews = ReviewPrompter()

    private let modelContainer: ModelContainer

    init() {
        SettingsKey.registerDefaults()
        do {
            modelContainer = try ScreenshotMode.sampleContainer() ?? ModelContainer(for: TranslationHistory.self)
        } catch {
            fatalError("Failed to open the translation history store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(modelContext: modelContainer.mainContext, purchases: purchases, reviews: reviews)
        }
        .modelContainer(modelContainer)
        .environment(purchases)
        .environment(pro)
        .environment(reviews)
    }
}

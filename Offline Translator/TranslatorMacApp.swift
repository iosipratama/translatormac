//
//  TranslatorMacApp.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import AppKit
import SwiftUI
import SwiftData

@main
struct TranslatorMacApp: App {

    @Environment(\.openWindow) private var openWindow

    @State private var purchases = PurchaseStore()

    /// One container shared by every scene. Scene modifiers do not cascade to
    /// sibling scenes, so applying `.modelContainer(for:)` per scene would build
    /// separate containers over the same store.
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: TranslationHistory.self)
        } catch {
            fatalError("Failed to open the translation history store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainWindow(modelContext: modelContainer.mainContext, purchases: purchases)
        }
        .modelContainer(modelContainer)
        .environment(purchases)
        .defaultSize(width: 1000, height: 660)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Translate Offline") {
                    openWindow(id: "about")
                }
                Button(purchases.hasPro ? "Translate Offline Pro" : "Upgrade to Pro…") {
                    openWindow(id: "pro")
                }
                Button("Rate Translate Offline") {
                    rateApp()
                }
            }

            SidebarCommands()
            NavigationCommands()
            TranslationCommands()
        }

        Window("About Translate Offline", id: "about") {
            AboutView()
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 300)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)

        Window("Translate Offline Pro", id: "pro") {
            ProView()
        }
        .environment(purchases)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .defaultLaunchBehavior(.suppressed)
    }

    private func rateApp() {
        let appID = "6757454429"
        let review = "id\(appID)?mt=12&action=write-review"
        guard let url = URL(string: "macappstore://itunes.apple.com/app/\(review)")
                ?? URL(string: "https://apps.apple.com/app/\(review)") else { return }
        NSWorkspace.shared.open(url)
    }
}

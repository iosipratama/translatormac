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

    /// One container shared by every scene. Scene modifiers do not cascade to
    /// sibling scenes, so applying `.modelContainer(for:)` per scene would build
    /// separate containers over the same store and the History window would not
    /// see newly saved translations until relaunch.
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: TranslationHistory.self)
        } catch {
            fatalError("Failed to open the translation history store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Translate Offline") {
                    openWindow(id: "about")
                }
                Button("Rate Translate Offline") {
                    rateApp()
                }
            }

            // History opens a window, so it belongs in the Window menu.
            CommandGroup(before: .windowList) {
                Button("History") {
                    openWindow(id: "history")
                }
                .keyboardShortcut("y", modifiers: [.command])

                Divider()
            }
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

        Window("History", id: "history") {
            HistoryView()
        }
        .modelContainer(modelContainer)
        .defaultSize(width: 520, height: 420)
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

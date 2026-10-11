//
//  TranslatorMacApp.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import SwiftUI
import SwiftData

@main
struct TranslatorMacApp: App {

    @Environment(\.openWindow) private var openWindow

    @State private var purchases = PurchaseStore()
    @State private var pro = ProPresentation()

    /// Read once at launch: it decides which window opens first. The flow
    /// itself updates the stored value when it finishes.
    private let didFinishOnboarding: Bool

    /// One container shared by every scene. Scene modifiers do not cascade to
    /// sibling scenes, so applying `.modelContainer(for:)` per scene would build
    /// separate containers over the same store.
    private let modelContainer: ModelContainer

    init() {
        SettingsKey.registerDefaults()
        didFinishOnboarding = OnboardingModel.didFinish
        do {
            modelContainer = try ModelContainer(for: TranslationHistory.self)
        } catch {
            fatalError("Failed to open the translation history store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow(modelContext: modelContainer.mainContext, purchases: purchases)
        }
        .modelContainer(modelContainer)
        .environment(purchases)
        .environment(pro)
        .defaultSize(width: 1000, height: 660)
        // On a first launch the welcome window opens instead; it opens this
        // one when it's done.
        .defaultLaunchBehavior(didFinishOnboarding ? .automatic : .suppressed)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Translate Offline") {
                    openWindow(id: "about")
                }
            }
            AppMenuCommands(purchases: purchases, pro: pro)

            SidebarCommands()
            NavigationCommands()
            TranslationCommands()
            HelpCommands()
        }

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
        .environment(purchases)
        .environment(pro)
        .windowResizability(.contentSize)

        Window("Welcome", id: "onboarding") {
            OnboardingWindow()
        }
        .environment(purchases)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(didFinishOnboarding ? .suppressed : .presented)

        Window("About Translate Offline", id: "about") {
            AboutView()
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 300)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

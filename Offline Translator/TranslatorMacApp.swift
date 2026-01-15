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
    
    @State private var showAbout = false
    @State private var showHistory = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        // Register SwiftDate in entry point
        .modelContainer(for: TranslationHistory.self)
        
        // Add about window
        Window("About Translate Offline", id: "about"){
            AboutView()
                .animation(.easeOut(duration: 1), value: UUID())
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 300)
        .defaultPosition(.center)
        
        Window("History", id: "history") {
            HistoryView()
                .modelContainer(for: TranslationHistory.self)
                .animation(.easeOut(duration: 1), value: UUID())
        }
        .windowResizability(.contentSize)
        
        .commands {
            // App menu items in desired order
            CommandGroup(replacing: .appInfo) {
                Button("History") {
                    openWindow(id: "history")
                }
                Button("About Translate Offline") {
                    openWindow(id: "about")
                }
                Button("Rate Translate Offline") {
                    // Replace with your real App Store Apple ID
                    let appID = "6757454429"
                    if let url = URL(string: "macappstore://itunes.apple.com/app/id\(appID)?mt=12&action=write-review") {
                        NSWorkspace.shared.open(url)
                    } else if let webURL = URL(string: "https://apps.apple.com/app/id\(appID)?mt=12&action=write-review") {
                        NSWorkspace.shared.open(webURL)
                    }
                }
            }
        }
    }
}


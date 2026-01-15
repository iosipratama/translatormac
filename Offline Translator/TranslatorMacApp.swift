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
            // Replace the system About with our custom About
            CommandGroup(replacing: .appInfo) {
                Button("About Translate Offline") {
                    openWindow(id: "about")
                }
            }
            // Then add History immediately after About
            CommandGroup(after: .appInfo) {
                Button("History") {
                    openWindow(id: "history")
                }
            }
        }
    }
}


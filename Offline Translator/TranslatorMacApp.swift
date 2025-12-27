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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        // Register SwiftDate in entry point
        .modelContainer(for: TranslationHistory.self)
        
        // Add about window
        Window("About Offline Translator", id: "about"){
            AboutView()
                .animation(.easeOut(duration: 1), value: UUID())
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 360, height: 300)
        .defaultPosition(.center)
        
        
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Offline Translator") {
                    openWindow(id: "about")
                }
            }
        }
        
        
        
        
    }
}

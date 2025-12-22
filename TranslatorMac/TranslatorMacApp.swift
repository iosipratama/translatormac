//
//  TranslatorMacApp.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import SwiftUI

@main
struct TranslatorMacApp: App {
    
    @Environment(\.openWindow) private var openWindow
    
    @State private var showAbout = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        
        Window("About Offline Translator", id: "about"){
            AboutView()
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

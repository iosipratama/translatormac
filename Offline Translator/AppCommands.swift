//
//  AppCommands.swift
//  TranslatorMac
//

import AppKit
import SwiftUI

/// App menu: Pro and rating, after the About item.
struct AppMenuCommands: Commands {
    var purchases: PurchaseStore
    var pro: ProPresentation

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            // Pro owners find their plan in Settings › Pro instead.
            if !purchases.hasPro {
                Button("Unlock Pro…") {
                    MainWindowAccess.bringForward()
                    pro.present()
                }
            }

            Button("Rate Translate Offline") {
                NSWorkspace.shared.open(AppLinks.appStoreReview)
            }
        }
    }
}

/// Help menu: the first-launch flow, for anyone who skipped it or wants to
/// download languages the easy way again.
struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Welcome to Translate Offline") {
                openWindow(id: "onboarding")
            }
        }
    }
}

/// View menu: jump between the sidebar's screens with ⌘1–⌘3.
struct NavigationCommands: Commands {
    @FocusedBinding(\.sidebarSelection) private var selection

    var body: some Commands {
        CommandGroup(before: .sidebar) {
            ForEach(SidebarItem.allCases) { item in
                Button(item.title) {
                    selection = item
                }
                .keyboardShortcut(item.keyEquivalent, modifiers: .command)
                .disabled(selection == nil)
            }
            Divider()
        }
    }
}

/// Everything the translate screen can do, so the toolbar is never the only
/// place a command lives and every shortcut is discoverable.
struct TranslationCommands: Commands {
    @FocusedValue(\.translationModel) private var model
    @Environment(\.openSettings) private var openSettings
    @FocusedValue(\.copyTranslation) private var copyTranslation

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Translation") {
                copyTranslation?()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(copyTranslation == nil)
        }

        CommandMenu("Translation") {
            Button("Translate Now") {
                model?.requestTranslation()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(model?.canTranslateNow != true)

            Button("Swap Languages") {
                model?.swapLanguages()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(model?.canSwapLanguages != true)

            Divider()

            Button(model?.speaker.isSpeaking == true ? "Stop Speaking" : "Speak Translation") {
                model?.toggleSpeech()
            }
            .keyboardShortcut("s", modifiers: [.command, .option])
            .disabled(model?.canSpeak != true && model?.speaker.isSpeaking != true)

            Button(model?.isCurrentSaved == true ? "Remove from Saved" : "Save Translation") {
                model?.toggleSaved()
            }
            .keyboardShortcut("d", modifiers: .command)
            .disabled(model?.currentResult == nil)

            Divider()

            Button("Clear Text") {
                model?.clearInput()
            }
            .disabled(model?.inputText.isEmpty != false)

            Divider()

            Button("Manage Languages…") {
                SettingsNavigation.show(.languages, using: openSettings)
            }
        }
    }
}

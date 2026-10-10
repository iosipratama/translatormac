//
//  AppCommands.swift
//  TranslatorMac
//

import SwiftUI

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

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Copy Translation") {
                model?.copyTranslation()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .disabled(model?.currentResult == nil)
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
                LanguageCatalog.openLanguageSettings()
            }
        }
    }
}

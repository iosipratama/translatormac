//
//  SettingsNavigation.swift
//  TranslatorMac
//

import SwiftUI

/// Opens Settings on a particular tab, from menus and buttons elsewhere.
enum SettingsNavigation {
    static func show(_ pane: SettingsView.Pane, using openSettings: OpenSettingsAction) {
        // The Settings window reads its tab from here, live, so this works
        // whether or not the window is already open.
        UserDefaults.standard.set(pane.rawValue, forKey: SettingsKey.settingsTab)
        openSettings()
    }
}

//
//  AppTheme.swift
//  TranslatorMac
//

import AppKit
import SwiftUI

/// Settings › General › Appearance: follow the Mac, or always light or dark.
enum AppTheme: String, CaseIterable, Identifiable {
    case automatic
    case light
    case dark

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Set on the application rather than per window, so every window,
    /// sheet, menu and alert follows at once — including ones opened later.
    func apply() {
        NSApplication.shared.appearance = switch self {
        case .automatic: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }

    static var stored: AppTheme {
        UserDefaults.standard.string(forKey: SettingsKey.appearance)
            .flatMap(AppTheme.init(rawValue:)) ?? .automatic
    }
}

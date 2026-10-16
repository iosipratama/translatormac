//
//  SettingsView.swift
//  TranslatorMac
//

import SwiftUI

/// The Settings window: the standard toolbar tabs, remembering the last one.
struct SettingsView: View {
    enum Pane: String {
        case general
        case languages
        case pro
    }

    @AppStorage(SettingsKey.settingsTab) private var pane: Pane = .general

    static let width: CGFloat = 600

    var body: some View {
        TabView(selection: $pane) {
            Tab("General", systemImage: "gearshape", value: Pane.general) {
                GeneralSettingsTab()
            }
            Tab("Languages", systemImage: "globe", value: Pane.languages) {
                LanguagesSettingsTab()
            }
            Tab("Pro", systemImage: "bolt.fill", value: Pane.pro) {
                ProSettingsTab()
            }
        }
        .frame(width: Self.width)
    }
}

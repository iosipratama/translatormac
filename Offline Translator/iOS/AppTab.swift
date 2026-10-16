//
//  AppTab.swift
//  TranslatorMac
//

import SwiftUI

/// The iPhone app's tabs, in order: the Mac sidebar's screens plus Settings.
enum AppTab: String, CaseIterable, Identifiable {
    case translate
    case recent
    case saved
    case settings

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .translate: "Translate"
        case .recent: "Recent"
        case .saved: "Saved"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .translate: "character.bubble"
        case .recent: "clock"
        case .saved: "star"
        case .settings: "gearshape"
        }
    }
}

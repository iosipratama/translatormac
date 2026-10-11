//
//  SidebarItem.swift
//  TranslatorMac
//

import SwiftUI

/// The screens listed in the sidebar, in order.
enum SidebarItem: String, CaseIterable, Identifiable {
    case translate
    case recent
    case saved

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .translate: "Translate"
        case .recent: "Recent"
        case .saved: "Saved"
        }
    }

    var systemImage: String {
        switch self {
        case .translate: "character.bubble"
        case .recent: "clock"
        case .saved: "star"
        }
    }

    /// ⌘1, ⌘2, ⌘3 in the View menu, matching the sidebar order.
    var keyEquivalent: KeyEquivalent {
        switch self {
        case .translate: "1"
        case .recent: "2"
        case .saved: "3"
        }
    }
}

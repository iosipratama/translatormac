//
//  LibraryTab.swift
//  TranslatorMac
//

import SwiftUI

/// The two lists in Library.
enum LibraryTab: String, CaseIterable, Identifiable {
    case saved
    case recent

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .saved: "Saved"
        case .recent: "Recent"
        }
    }

    var searchPrompt: Text {
        switch self {
        case .saved: Text("Search saved")
        case .recent: Text("Search recent")
        }
    }
}

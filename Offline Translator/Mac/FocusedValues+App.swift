//
//  FocusedValues+App.swift
//  TranslatorMac
//

import SwiftUI

/// What the frontmost window exposes to the menu bar. Commands read these so
/// each menu item acts on the window the person is looking at.
extension FocusedValues {
    @Entry var sidebarSelection: Binding<SidebarItem>?
    @Entry var translationModel: TranslationModel?
    /// Edit › Copy Translation, provided by whichever screen is showing, so
    /// it copies the selected history entry as readily as the live result.
    @Entry var copyTranslation: CopyTranslationAction?
}

/// A menu action compared by what it would copy, so the menu only
/// re-validates when the text changes rather than on every view update.
struct CopyTranslationAction: Equatable {
    var text: String
    var perform: () -> Void

    func callAsFunction() {
        perform()
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text
    }
}

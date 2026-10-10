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
}

//
//  ProPresentation.swift
//  TranslatorMac
//

import Foundation

/// Whether a window is showing the Pro sheet. One per window, handed down
/// through the environment so the sidebar card, the result pane and the
/// App menu all open the same sheet.
@Observable
final class ProPresentation {
    var isPresented = false

    func present() {
        isPresented = true
    }
}

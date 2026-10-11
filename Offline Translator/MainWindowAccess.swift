//
//  MainWindowAccess.swift
//  TranslatorMac
//

import AppKit

/// Finds the main window from places that don't have a window of their own,
/// such as the App menu and Settings, so the Pro sheet opens over it.
enum MainWindowAccess {
    /// Brings an existing main window forward. Returns `false` when there is
    /// none, in which case the caller opens one.
    @discardableResult
    static func bringForward() -> Bool {
        let existing = NSApp.windows.first {
            $0.isVisible && $0.identifier?.rawValue.hasPrefix("main") == true
        }
        guard let existing else { return false }
        existing.makeKeyAndOrderFront(nil)
        return true
    }
}

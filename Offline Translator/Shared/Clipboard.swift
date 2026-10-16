//
//  Clipboard.swift
//  TranslatorMac
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The system clipboard, the same call on the Mac and on iPhone.
enum Clipboard {
    static func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }
}

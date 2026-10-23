//
//  TextSessionTests.swift
//  TranslatorTests
//

import Testing
@testable import Translate_Offline

/// Which edits start a new text, and so count again once finished.
struct TextSessionTests {
    @Test(arguments: [
        ("", "Hello"),
        ("   ", "Hello"),
        ("Where is the station?", "How much is this?"),
        ("Good morning", "Thank you"),
        ("Thanks", "Tomorrow"),
        ("a", "b"),
    ])
    func newText(old: String, new: String) {
        #expect(TextSession.isNewText(from: old, to: new))
    }

    @Test(arguments: [
        ("Hello", "Hello world"),
        ("Hello world", "Hello"),
        ("world", "Hello world"),
        ("Where is the station", "Where is the train station"),
        ("cat", "bat"),
        ("Hello", "Hello  "),
        ("Hello", ""),
        ("Hel", "Hello"),
        ("H", "He"),
        ("hello", "Hello!"),
    ])
    func sameText(old: String, new: String) {
        #expect(!TextSession.isNewText(from: old, to: new))
    }
}

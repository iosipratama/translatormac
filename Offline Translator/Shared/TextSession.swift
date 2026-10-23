//
//  TextSession.swift
//  TranslatorMac
//

import Foundation

/// When an edit starts a new text, rather than changing the one on screen.
/// A new text gets its own entry in Recent and counts toward the free
/// plan's daily limit again once it's finished.
nonisolated enum TextSession {
    /// A new text starts when the text was empty, or when it was replaced in
    /// one go, as by pasting over all of it: neither its start nor its end
    /// survives. Typing, deleting or pasting anywhere inside the text keeps
    /// one of them, so it stays the same text. Case and the punctuation at
    /// either end are ignored, so two questions aren't the same text just
    /// because both end in "?".
    static func isNewText(from old: String, to new: String) -> Bool {
        let old = normalized(old)
        let new = normalized(new)
        guard !new.isEmpty else { return false }
        guard !old.isEmpty else { return true }

        let shared = max(
            old.commonPrefix(with: new).count,
            String(old.reversed()).commonPrefix(with: String(new.reversed())).count
        )
        // Two characters, so a coincidental first or last letter doesn't
        // make two texts the same; less when a text is shorter than that.
        return shared < min(2, old.count, new.count)
    }

    private static func normalized(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let core = trimmed.trimmingCharacters(in: .punctuationCharacters.union(.whitespacesAndNewlines))
        return (core.isEmpty ? trimmed : core).lowercased()
    }
}

//
//  TranslationResult.swift
//  TranslatorMac
//

import Foundation

/// A finished translation, tied to the exact text it came from.
///
/// Live translation means the input can change while a result is still on
/// screen. Carrying `sourceText` lets the screen tell a fresh result from a
/// stale one without a separate flag that could drift out of sync.
nonisolated struct TranslationResult: Equatable {
    /// The trimmed input that was translated.
    var sourceText: String
    var text: String
    /// A Latin-script reading of `text`; `nil` when the target already uses
    /// Latin script.
    var pronunciation: String?
    /// The language the framework detected when the source was set to
    /// Detect Language; `nil` when a source was chosen explicitly.
    var detectedSource: Locale.Language?
}

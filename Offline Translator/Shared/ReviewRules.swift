//
//  ReviewRules.swift
//  TranslatorMac
//

import Foundation

/// When to ask for a rating: after something went well, never right after
/// the person was stopped by the limit or shown the Pro sheet, and at most
/// once per version. The system adds its own limit of three times a year
/// and may show nothing at all.
nonisolated enum ReviewRules {
    /// The good moments worth asking after.
    enum Moment: Equatable {
        /// A translation was finished; `total` counts every one so far.
        case translationFinished(total: Int)
        /// A phrase was saved; `total` is how many are saved now.
        case phraseSaved(total: Int)
    }

    static let translationsBeforeAsking = 10
    static let savedBeforeAsking = 3

    /// Whether to ask now. From the 10th translation or 3rd saved phrase
    /// on, rather than only at exactly that one, so a moment missed because
    /// the session was spoiled comes round again in a later one.
    static func shouldAsk(
        after moment: Moment,
        sessionWasInterrupted: Bool,
        versionLastAsked: String?,
        currentVersion: String
    ) -> Bool {
        guard !sessionWasInterrupted, versionLastAsked != currentVersion else { return false }
        switch moment {
        case .translationFinished(let total): return total >= translationsBeforeAsking
        case .phraseSaved(let total): return total >= savedBeforeAsking
        }
    }
}

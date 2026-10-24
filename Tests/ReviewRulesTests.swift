//
//  ReviewRulesTests.swift
//  TranslatorTests
//

import Testing
@testable import Translate_Offline

/// When the app asks for a rating.
struct ReviewRulesTests {
    private func asks(
        _ moment: ReviewRules.Moment,
        interrupted: Bool = false,
        lastAsked: String? = nil
    ) -> Bool {
        ReviewRules.shouldAsk(after: moment, sessionWasInterrupted: interrupted, versionLastAsked: lastAsked, currentVersion: "1.3")
    }

    @Test func tenthTranslationAsks() {
        #expect(!asks(.translationFinished(total: 9)))
        #expect(asks(.translationFinished(total: 10)))
    }

    @Test func thirdSavedPhraseAsks() {
        #expect(!asks(.phraseSaved(total: 2)))
        #expect(asks(.phraseSaved(total: 3)))
    }

    @Test func neverAfterTheLimitOrTheProSheet() {
        #expect(!asks(.translationFinished(total: 10), interrupted: true))
        #expect(!asks(.phraseSaved(total: 3), interrupted: true))
    }

    /// A moment missed in a spoiled session comes round again later.
    @Test func missedMomentComesRoundAgain() {
        #expect(asks(.translationFinished(total: 14)))
    }

    @Test func onlyOncePerVersion() {
        #expect(!asks(.translationFinished(total: 10), lastAsked: "1.3"))
        #expect(asks(.translationFinished(total: 30), lastAsked: "1.2"))
    }
}

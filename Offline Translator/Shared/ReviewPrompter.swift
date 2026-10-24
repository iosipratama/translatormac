//
//  ReviewPrompter.swift
//  TranslatorMac
//

import Foundation

/// Decides when to ask for a rating, following `ReviewRules`, and tells the
/// window when to ask through `requests`. One for the app, so the translate
/// screen, Recent and Saved, and the Pro sheet all feed the same count.
@Observable
final class ReviewPrompter {
    private enum DefaultsKey {
        static let finishedTranslations = "reviewFinishedTranslations"
        static let versionLastAsked = "reviewVersionLastAsked"
    }

    /// Bumped when it's time to ask; the window calls `requestReview`.
    private(set) var requests = 0

    /// The person hit the daily limit or saw the Pro sheet since launch.
    private var sessionWasInterrupted = false

    func noteFinishedTranslation() {
        let defaults = UserDefaults.standard
        let total = defaults.integer(forKey: DefaultsKey.finishedTranslations) + 1
        defaults.set(total, forKey: DefaultsKey.finishedTranslations)
        consider(.translationFinished(total: total))
    }

    /// Call after a phrase is saved, with how many are saved now.
    func noteSaved(total: Int) {
        consider(.phraseSaved(total: total))
    }

    /// The daily limit stopped a translation, or the Pro sheet opened.
    func noteInterruption() {
        sessionWasInterrupted = true
    }

    #if DEBUG
    /// Debug builds only: ask right away, whatever the rules say.
    func requestNow() {
        requests += 1
    }

    /// Debug builds only: forget the count, the version asked and this
    /// session's interruptions, as on a new install.
    func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: DefaultsKey.finishedTranslations)
        defaults.removeObject(forKey: DefaultsKey.versionLastAsked)
        sessionWasInterrupted = false
    }

    /// Debug builds only: finished translations counted so far.
    var finishedTranslations: Int {
        UserDefaults.standard.integer(forKey: DefaultsKey.finishedTranslations)
    }
    #endif

    private func consider(_ moment: ReviewRules.Moment) {
        let defaults = UserDefaults.standard
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard ReviewRules.shouldAsk(
            after: moment,
            sessionWasInterrupted: sessionWasInterrupted,
            versionLastAsked: defaults.string(forKey: DefaultsKey.versionLastAsked),
            currentVersion: version
        ) else { return }
        defaults.set(version, forKey: DefaultsKey.versionLastAsked)
        requests += 1
    }
}

//
//  DebugScenario.swift
//  TranslatorMac
//

#if DEBUG
import Foundation

/// Debug builds only: one tap to put the app in a situation worth testing,
/// setting the plan, the day, today's count and the notice together, so a
/// scenario never depends on what was tapped before. Test purchases are
/// ignored except in the Pro scenarios.
enum DebugScenario: String, CaseIterable, Identifiable {
    case newUser
    case lastFreeDay
    case missedLastFreeDay
    case freePlan
    case oneLeft
    case limitReached
    case pro
    case earlierBuyer

    var id: Self { self }

    var title: String {
        switch self {
        case .newUser: "New User (Day 1)"
        case .lastFreeDay: "Last Free Day (Day 3)"
        case .missedLastFreeDay: "Free Days Just Ended (Day 4)"
        case .freePlan: "Free Plan, 5 Left"
        case .oneLeft: "Free Plan, 1 Left"
        case .limitReached: "Free Plan, Limit Reached"
        case .pro: "Pro"
        case .earlierBuyer: "Earlier Buyer"
        }
    }

    /// What to expect, shown under the scenario.
    var expectation: String {
        switch self {
        case .newUser: "Everything unlocked, no counter, no PRO tags."
        case .lastFreeDay: "The “Your free days end today” notice appears."
        case .missedLastFreeDay: "The “Your free days have ended” notice appears, then the free plan."
        case .freePlan: "PRO tags on pronunciation, Read Aloud, the star and Best quality."
        case .oneLeft: "One more new text translates; the next is blocked."
        case .limitReached: "A new text is blocked, and the upgrade screen opens on a pause."
        case .pro: "Everything unlocked, Pro shown as active."
        case .earlierBuyer: "Pro, shown as coming with the original purchase."
        }
    }

    func apply(to purchases: PurchaseStore, reviews: ReviewPrompter) {
        switch self {
        case .newUser:
            purchases.debugPlan = .notBought
            purchases.restartFreeAccess()
            purchases.setRemainingFreeTranslations(PlanLimits.freeTranslationsPerDay)
            reviews.reset()
        case .lastFreeDay:
            purchases.restartFreeAccess()
            purchases.setRemainingFreeTranslations(PlanLimits.freeTranslationsPerDay)
            purchases.replayFreeAccessNotice(ended: false)
        case .missedLastFreeDay:
            purchases.restartFreeAccess()
            purchases.setRemainingFreeTranslations(PlanLimits.freeTranslationsPerDay)
            purchases.replayFreeAccessNotice(ended: true)
        case .freePlan, .oneLeft, .limitReached:
            purchases.debugPlan = .notBought
            purchases.setDebugDay(PlanLimits.freeAccessDays + 1)
            // Already seen, so it doesn't interrupt the test.
            purchases.setFreeAccessNoticeShown(true)
            purchases.setRemainingFreeTranslations(remaining)
        case .pro:
            purchases.debugPlan = .forcePro
        case .earlierBuyer:
            purchases.debugPlan = .earlierBuyer
        }
    }

    private var remaining: Int {
        switch self {
        case .oneLeft: 1
        case .limitReached: 0
        default: PlanLimits.freeTranslationsPerDay
        }
    }
}
#endif

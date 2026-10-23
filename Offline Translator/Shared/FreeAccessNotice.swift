//
//  FreeAccessNotice.swift
//  TranslatorMac
//

import Foundation

/// The one-time note about the free days ending: what the free plan keeps,
/// and what Pro adds. Shown on the last free day, or, for someone who
/// didn't open the app that day, the first time after.
nonisolated enum FreeAccessNotice: Hashable, Identifiable {
    /// The last free day; everything stays unlocked until the given moment.
    case ending(until: Date)
    /// The free days are over.
    case ended

    var id: Self { self }

    /// The notice to show now, if any. Never for Pro, and only once.
    static func due(
        access: PlanAccess,
        period: FreeAccessPeriod,
        on date: Date,
        alreadyShown: Bool,
        calendar: Calendar = .current
    ) -> FreeAccessNotice? {
        guard !alreadyShown else { return nil }
        switch access {
        case .pro:
            return nil
        case .freeAccess(let end):
            return period.isLastDay(on: date, calendar: calendar) ? .ending(until: end) : nil
        case .free:
            return .ended
        }
    }
}

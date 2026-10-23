//
//  FreeAccessPeriod.swift
//  TranslatorMac
//

import Foundation

/// The first few days after the first launch, when everything is unlocked,
/// Pro included. Built into the app rather than an App Store free trial, so
/// nobody has to sign up for a subscription to try Pro.
///
/// A plain value with no storage of its own; `FirstLaunchRecord` keeps the
/// start date. The period runs in whole calendar days: it ends at local
/// midnight, as the daily free count resets.
nonisolated struct FreeAccessPeriod: Equatable {
    var start: Date
    var days: Int = PlanLimits.freeAccessDays

    /// The moment it's over: midnight at the start of the day after the last.
    func end(calendar: Calendar = .current) -> Date {
        let firstDay = calendar.startOfDay(for: start)
        return calendar.date(byAdding: .day, value: days, to: firstDay) ?? start
    }

    func isActive(on date: Date, calendar: Calendar = .current) -> Bool {
        date < end(calendar: calendar)
    }

    /// Which day of it `date` falls on, from 1; past the last day once it's
    /// over. A clock set before the start counts as day 1.
    func day(on date: Date, calendar: Calendar = .current) -> Int {
        let elapsed = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: start),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return max(1, elapsed + 1)
    }

    /// Whether `date` is the final day, when the app says it's ending.
    func isLastDay(on date: Date, calendar: Calendar = .current) -> Bool {
        day(on: date, calendar: calendar) == days
    }
}

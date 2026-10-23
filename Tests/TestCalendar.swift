//
//  TestCalendar.swift
//  TranslatorTests
//

import Foundation

/// A fixed calendar and time zone, so "midnight" means the same thing on
/// every machine that runs the tests.
nonisolated enum TestCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Jakarta")!
        return calendar
    }()

    /// 2026-10-<day> at the given local time.
    static func date(day: Int, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
    }
}

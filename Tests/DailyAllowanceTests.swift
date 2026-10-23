//
//  DailyAllowanceTests.swift
//  TranslatorTests
//

import Foundation
import Testing
@testable import Translate_Offline

/// The free plan's 5 translations a day, reset at local midnight.
struct DailyAllowanceTests {
    let calendar = TestCalendar.calendar
    let limit = PlanLimits.freeTranslationsPerDay

    @Test func limitIsFive() {
        #expect(limit == 5)
    }

    @Test func fifthTranslationIsAllowedAndSixthIsNot() {
        var allowance = DailyAllowance(day: TestCalendar.date(day: 14, hour: 8), used: 0)
        for hour in 8..<12 {
            allowance.record(on: TestCalendar.date(day: 14, hour: hour), calendar: calendar)
        }
        // Four used: the fifth can still go ahead.
        let now = TestCalendar.date(day: 14, hour: 13)
        #expect(allowance.remaining(limit: limit, on: now, calendar: calendar) == 1)

        allowance.record(on: now, calendar: calendar)
        // Five used: the sixth is blocked.
        #expect(allowance.used(on: now, calendar: calendar) == 5)
        #expect(allowance.remaining(limit: limit, on: now, calendar: calendar) == 0)
    }

    @Test func countResetsAtMidnight() {
        let allowance = DailyAllowance(day: TestCalendar.date(day: 14, hour: 23, minute: 50), used: 5)
        #expect(allowance.remaining(limit: limit, on: TestCalendar.date(day: 14, hour: 23, minute: 59), calendar: calendar) == 0)
        #expect(allowance.remaining(limit: limit, on: TestCalendar.date(day: 15, hour: 0), calendar: calendar) == 5)
    }

    @Test func firstTranslationAfterMidnightStartsAFreshCount() {
        var allowance = DailyAllowance(day: TestCalendar.date(day: 14, hour: 22), used: 5)
        let nextMorning = TestCalendar.date(day: 15, hour: 7)
        allowance.record(on: nextMorning, calendar: calendar)
        #expect(allowance.used(on: nextMorning, calendar: calendar) == 1)
        #expect(allowance.remaining(limit: limit, on: nextMorning, calendar: calendar) == 4)
    }
}

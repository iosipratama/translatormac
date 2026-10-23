//
//  FreeAccessTests.swift
//  TranslatorTests
//

import Foundation
import Testing
@testable import Translate_Offline

/// The free days after the first launch: three calendar days of everything,
/// ending at local midnight.
struct FreeAccessTests {
    let calendar = TestCalendar.calendar
    /// First launched late in the evening, so day 1 is short.
    let period = FreeAccessPeriod(start: TestCalendar.date(day: 10, hour: 23), days: 3)

    @Test func dayOneIsUnlocked() {
        let date = TestCalendar.date(day: 10, hour: 23, minute: 30)
        #expect(period.day(on: date, calendar: calendar) == 1)
        #expect(period.isActive(on: date, calendar: calendar))
        #expect(!period.isLastDay(on: date, calendar: calendar))
    }

    @Test func dayTwoIsUnlocked() {
        let date = TestCalendar.date(day: 11, hour: 9)
        #expect(period.day(on: date, calendar: calendar) == 2)
        #expect(period.isActive(on: date, calendar: calendar))
    }

    @Test func lastDayIsUnlockedUntilMidnight() {
        let lastMinute = TestCalendar.date(day: 12, hour: 23, minute: 59)
        #expect(period.day(on: lastMinute, calendar: calendar) == 3)
        #expect(period.isLastDay(on: lastMinute, calendar: calendar))
        #expect(period.isActive(on: lastMinute, calendar: calendar))
    }

    @Test func dayFourIsFree() {
        let midnight = TestCalendar.date(day: 13, hour: 0)
        #expect(period.end(calendar: calendar) == midnight)
        #expect(period.day(on: midnight, calendar: calendar) == 4)
        #expect(!period.isActive(on: midnight, calendar: calendar))
        #expect(!period.isActive(on: TestCalendar.date(day: 20), calendar: calendar))
    }

    @Test func clockBeforeTheStartCountsAsDayOne() {
        let earlier = TestCalendar.date(day: 8)
        #expect(period.day(on: earlier, calendar: calendar) == 1)
        #expect(period.isActive(on: earlier, calendar: calendar))
    }

    @Test(arguments: [(10, PlanAccess.freeAccess(until: TestCalendar.date(day: 13, hour: 0))),
                      (12, .freeAccess(until: TestCalendar.date(day: 13, hour: 0))),
                      (13, .free)])
    func accessWithoutPro(day: Int, expected: PlanAccess) {
        let access = PlanAccess.resolve(hasPro: false, freeAccess: period, on: TestCalendar.date(day: day), calendar: calendar)
        #expect(access == expected)
        #expect(access.unlocksPro == (expected != .free))
    }

    @Test(arguments: [10, 13, 40])
    func proIsProOnEveryDay(day: Int) {
        let access = PlanAccess.resolve(hasPro: true, freeAccess: period, on: TestCalendar.date(day: day), calendar: calendar)
        #expect(access == .pro)
    }
}

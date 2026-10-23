//
//  FreeAccessNoticeTests.swift
//  TranslatorTests
//

import Foundation
import Testing
@testable import Translate_Offline

/// The one-time note when the free days end.
struct FreeAccessNoticeTests {
    let calendar = TestCalendar.calendar
    let period = FreeAccessPeriod(start: TestCalendar.date(day: 10, hour: 9), days: 3)
    let end = TestCalendar.date(day: 13, hour: 0)

    private func notice(day: Int, hasPro: Bool = false, shown: Bool = false) -> FreeAccessNotice? {
        let date = TestCalendar.date(day: day)
        let access = PlanAccess.resolve(hasPro: hasPro, freeAccess: period, on: date, calendar: calendar)
        return FreeAccessNotice.due(access: access, period: period, on: date, alreadyShown: shown, calendar: calendar)
    }

    @Test func nothingOnTheFirstDays() {
        #expect(notice(day: 10) == nil)
        #expect(notice(day: 11) == nil)
    }

    @Test func endingOnTheLastDay() {
        #expect(notice(day: 12) == .ending(until: end))
    }

    @Test func endedForSomeoneWhoSkippedTheLastDay() {
        #expect(notice(day: 13) == .ended)
        #expect(notice(day: 30) == .ended)
    }

    @Test func onlyOnce() {
        #expect(notice(day: 12, shown: true) == nil)
        #expect(notice(day: 13, shown: true) == nil)
    }

    @Test func neverForPro() {
        #expect(notice(day: 12, hasPro: true) == nil)
        #expect(notice(day: 13, hasPro: true) == nil)
    }
}

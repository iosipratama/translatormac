//
//  EarlySupporterTests.swift
//  TranslatorTests
//

import StoreKit
import Testing
@testable import Translate_Offline

/// People who bought the app before it became free keep Pro.
struct EarlySupporterTests {
    @Test(arguments: ["1.0", "1.1", "1.1.3"])
    func paidVersionsGetPro(version: String) {
        #expect(PlanAccess.isEarlySupporter(originalAppVersion: version, environment: .production))
    }

    @Test(arguments: ["1.2", "1.2.1", "1.10", "2.0"])
    func freeVersionsDoNot(version: String) {
        #expect(!PlanAccess.isEarlySupporter(originalAppVersion: version, environment: .production))
    }

    /// Sandbox and Xcode report "1.0" for everyone; that mustn't unlock Pro.
    @Test func sandboxNeverCounts() {
        #expect(!PlanAccess.isEarlySupporter(originalAppVersion: "1.0", environment: .sandbox))
        #expect(!PlanAccess.isEarlySupporter(originalAppVersion: "1.0", environment: .xcode))
    }

    /// An earlier buyer is Pro whether or not the free days are over.
    @Test func earlierBuyerIsProAfterTheFreeDays() {
        let period = FreeAccessPeriod(start: TestCalendar.date(day: 1), days: 3)
        let isEarly = PlanAccess.isEarlySupporter(originalAppVersion: "1.1", environment: .production)
        let access = PlanAccess.resolve(hasPro: isEarly, freeAccess: period, on: TestCalendar.date(day: 20), calendar: TestCalendar.calendar)
        #expect(access == .pro)
    }
}

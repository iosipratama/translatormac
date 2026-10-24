//
//  MonthlyPriceTests.swift
//  TranslatorTests
//

import Foundation
import Testing
@testable import Translate_Offline

/// "About $0.83 a month" under the yearly price: the yearly price over 12,
/// in the person's own currency.
struct MonthlyPriceTests {
    private func monthly(_ yearly: String, _ code: String, _ locale: String) -> String {
        let format = Decimal.FormatStyle.Currency(code: code, locale: Locale(identifier: locale))
        return ProPlan.monthlyPrice(ofYearly: Decimal(string: yearly)!, format: format)
    }

    @Test func dollars() {
        // 9.99 / 12 = 0.8325
        #expect(monthly("9.99", "USD", "en_US") == "$0.83")
        // 14.99 / 12 = 1.249…
        #expect(monthly("14.99", "USD", "en_US") == "$1.25")
        #expect(monthly("12.00", "USD", "en_US") == "$1.00")
    }

    @Test func euros() {
        #expect(monthly("9.99", "EUR", "de_DE") == "0,83\u{00A0}€")
    }

    @Test func currencyWithoutCents() {
        // 1,500 / 12 = 125
        let yen = monthly("1500", "JPY", "ja_JP")
        #expect(yen.hasSuffix("125"))
        #expect(!yen.contains("."))
    }
}

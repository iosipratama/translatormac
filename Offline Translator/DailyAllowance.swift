//
//  DailyAllowance.swift
//  TranslatorMac
//

import Foundation

/// How many translations the free tier has used on a given day.
///
/// A plain value with no storage of its own, so the counting rules can't drift
/// from what `PurchaseStore` persists.
nonisolated struct DailyAllowance: Equatable {
    var day: Date
    var used: Int

    /// Translations used on the day containing `date`; a count from an
    /// earlier day no longer applies.
    func used(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(day, inSameDayAs: date) ? used : 0
    }

    func remaining(limit: Int, on date: Date, calendar: Calendar = .current) -> Int {
        max(0, limit - used(on: date, calendar: calendar))
    }

    /// Counts one translation, starting a fresh count when the day has changed.
    mutating func record(on date: Date, calendar: Calendar = .current) {
        used = used(on: date, calendar: calendar) + 1
        day = date
    }
}

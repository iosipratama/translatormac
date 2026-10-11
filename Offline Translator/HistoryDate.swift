//
//  HistoryDate.swift
//  TranslatorMac
//

import Foundation

/// Short "when" labels for history rows: recent moments relatively, older
/// ones as a date, so a column of them scans at a glance.
nonisolated enum HistoryDate {

    static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        // Today and yesterday read relatively, in the system's own wording
        // and grammar for every language: "5 min. ago", "yesterday".
        if calendar.isDateInToday(date) || calendar.isDateInYesterday(date) {
            var style = Date.RelativeFormatStyle(presentation: .named, unitsStyle: .abbreviated)
            style.calendar = calendar
            return date.formatted(style)
        }

        let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

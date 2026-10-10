//
//  HistoryDate.swift
//  TranslatorMac
//

import Foundation

/// Short "when" labels for history rows: recent moments relatively, older
/// ones as a date, so a column of them scans at a glance.
nonisolated enum HistoryDate {

    static func label(for date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let seconds = now.timeIntervalSince(date)

        if seconds < 60 {
            return String(localized: "Just now")
        }
        if seconds < 3600 {
            let minutes = Int(seconds / 60)
            return String(localized: "\(minutes) min ago")
        }
        if calendar.isDateInToday(date) {
            let hours = Int(seconds / 3600)
            return String(localized: "\(hours) hr ago")
        }
        if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        }

        let sameYear = calendar.isDate(date, equalTo: now, toGranularity: .year)
        return sameYear
            ? date.formatted(.dateTime.month(.abbreviated).day())
            : date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}

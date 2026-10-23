//
//  PlanAccess.swift
//  TranslatorMac
//

import Foundation
import StoreKit

/// What this person can use right now. Every Pro gate asks this, through
/// `PurchaseStore.access`, so the free days and earlier buyers are respected
/// everywhere at once.
nonisolated enum PlanAccess: Equatable {
    /// Bought a plan, or bought the app back when it was paid.
    case pro
    /// In the free days after the first launch: everything unlocked until
    /// the given moment.
    case freeAccess(until: Date)
    /// The free plan: a daily limit, and no Pro features.
    case free

    /// Pro features and unlimited translations are available.
    var unlocksPro: Bool {
        self != .free
    }

    /// - Parameter hasPro: Bought a plan, or is an earlier buyer.
    static func resolve(
        hasPro: Bool,
        freeAccess: FreeAccessPeriod,
        on date: Date,
        calendar: Calendar = .current
    ) -> PlanAccess {
        if hasPro { return .pro }
        if freeAccess.isActive(on: date, calendar: calendar) {
            return .freeAccess(until: freeAccess.end(calendar: calendar))
        }
        return .free
    }

    /// The first version given away for free. Versions before it were paid,
    /// so anyone whose original download predates it already bought the app
    /// and gets Pro without buying it again.
    static let firstFreeVersion = "1.2"

    /// Whether the app's original download makes this person an earlier
    /// buyer. On macOS `originalAppVersion` is the CFBundleShortVersionString
    /// first downloaded.
    static func isEarlySupporter(originalAppVersion: String, environment: AppStore.Environment) -> Bool {
        // Sandbox and Xcode always report an original version of "1.0",
        // which would make every tester an early supporter and hide the
        // free plan entirely.
        guard environment == .production else { return false }
        return originalAppVersion.compare(firstFreeVersion, options: .numeric) == .orderedAscending
    }
}

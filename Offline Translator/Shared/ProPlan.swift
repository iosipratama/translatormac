//
//  ProPlan.swift
//  TranslatorMac
//

import Foundation
import StoreKit

/// A way to pay for Pro. The App Store product behind each plan is fixed
/// here; which plans the sheet offers, and in what order, is decided by
/// `PurchaseStore.offeredPlans`, so trying a different mix is one edit.
enum ProPlan: String, CaseIterable, Identifiable, Sendable {
    case weekly
    case yearly
    case lifetime

    var id: Self { self }

    var productID: String {
        switch self {
        case .weekly: "iosipratama.TranslatorMac.pro.weekly"
        case .yearly: "iosipratama.TranslatorMac.pro.yearly"
        // The original one-time purchase keeps its identifier so existing
        // owners stay entitled.
        case .lifetime: "iosipratama.TranslatorMac.pro"
        }
    }

    init?(productID: String) {
        guard let plan = Self.allCases.first(where: { $0.productID == productID }) else { return nil }
        self = plan
    }

    var isSubscription: Bool {
        self != .lifetime
    }

    var title: LocalizedStringResource {
        switch self {
        case .weekly: "Weekly"
        case .yearly: "Yearly"
        case .lifetime: "Lifetime"
        }
    }

    /// A short tag on the card, for the plan worth drawing the eye to.
    var badge: LocalizedStringResource? {
        switch self {
        case .lifetime: "Best Value"
        case .weekly, .yearly: nil
        }
    }

    /// The line under the plan's name, which reads down the list as a
    /// choice: pay once, or subscribe.
    var tagline: LocalizedStringResource {
        switch self {
        case .weekly: "Or subscribe weekly"
        case .yearly: "Renews every year"
        case .lifetime: "Pay once"
        }
    }

    var callToAction: LocalizedStringResource {
        switch self {
        case .weekly: "Start Weekly Plan"
        case .yearly: "Start Yearly Plan"
        case .lifetime: "Buy Lifetime"
        }
    }

    /// The terms under the button, in plain words. For a subscription
    /// these are the auto-renewal terms App Review requires: the price, the
    /// period, that it renews, and how to cancel.
    func terms(for product: Product) -> String {
        switch self {
        case .weekly:
            String(localized: "\(product.displayPrice) a week. Renews automatically until you cancel, and is charged to your Apple Account. Cancel anytime in App Store settings, at least 24 hours before it renews.")
        case .yearly:
            String(localized: "\(product.displayPrice) a year. Renews automatically until you cancel, and is charged to your Apple Account. Cancel anytime in App Store settings, at least 24 hours before it renews.")
        case .lifetime:
            String(localized: "One payment of \(product.displayPrice). No subscription, no renewals.")
        }
    }

    /// "9.99 / year"; Lifetime's tagline already says it's paid once.
    func priceLine(for product: Product) -> String {
        switch self {
        case .weekly: String(localized: "\(product.displayPrice) / week")
        case .yearly: String(localized: "\(product.displayPrice) / year")
        case .lifetime: product.displayPrice
        }
    }

    /// The line under the price that puts it in perspective; `nil` when
    /// the price says it all.
    func priceNote(for product: Product) -> String? {
        switch self {
        case .weekly:
            return String(localized: "Billed every week")
        case .yearly:
            let monthly = (product.price / 12).formatted(product.priceFormatStyle)
            return String(localized: "About \(monthly) a month")
        case .lifetime:
            return nil
        }
    }
}

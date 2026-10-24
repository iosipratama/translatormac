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

    /// The line under the plan's name.
    var tagline: LocalizedStringResource {
        switch self {
        case .weekly: "Cancel anytime"
        case .yearly: "Cancel anytime"
        case .lifetime: "Pay once"
        }
    }

    var callToAction: LocalizedStringResource {
        switch self {
        case .weekly: "Start Weekly Plan"
        case .yearly: "Continue"
        case .lifetime: "Buy Lifetime"
        }
    }

    /// The terms under the button, in plain words. For a subscription,
    /// together with the price and period on the plan's row, these are the
    /// auto-renewal terms App Review asks for: what it costs, how often,
    /// and that it renews until cancelled.
    var terms: LocalizedStringResource {
        switch self {
        case .weekly: "Renews every week. Cancel anytime."
        case .yearly: "Renews every year. Cancel anytime."
        case .lifetime: "One payment. No subscription."
        }
    }

    /// A yearly price spread over 12 months, rounded to the currency's
    /// smallest unit, which is why the note says "About".
    nonisolated static func monthlyPrice(ofYearly price: Decimal, format: Decimal.FormatStyle.Currency) -> String {
        (price / 12).formatted(format)
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
            let monthly = Self.monthlyPrice(ofYearly: product.price, format: product.priceFormatStyle)
            return String(localized: "About \(monthly) a month")
        case .lifetime:
            return nil
        }
    }
}

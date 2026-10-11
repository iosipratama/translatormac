//
//  PurchaseStore.swift
//  TranslatorMac
//

import Foundation
import StoreKit
import SwiftUI
import os

/// Everything about Translate Offline Pro: the plans, whether this person has
/// one, and the free tier's daily allowance.
@Observable
final class PurchaseStore {

    /// The plans the Pro sheet offers, in display order. The first is
    /// selected by default.
    static let offeredPlans: [ProPlan] = [.yearly, .lifetime]

    /// Free translations per calendar day without Pro.
    static let dailyFreeLimit = PlanLimits.freeTranslationsPerDay

    /// The first version given away for free. Versions before it were paid, so
    /// anyone whose original download predates it already bought the app and
    /// gets Pro without buying it again.
    private static let firstFreeVersion = "1.2"

    private enum DefaultsKey {
        static let activePlan = "activeProPlan"
        /// Written by versions that only had the one-time purchase.
        static let legacyOwnsPro = "ownsPro"
        static let isEarlySupporter = "isEarlySupporter"
        static let allowanceDay = "freeAllowanceDay"
        static let allowanceUsed = "freeAllowanceUsed"
    }

    /// Empty until the App Store answers, or when it can't be reached.
    private(set) var products: [ProPlan: Product] = [:]
    private(set) var isLoadingProducts = false

    /// The plan this person is entitled through, if any.
    private(set) var activePlan: ProPlan? {
        didSet { UserDefaults.standard.set(activePlan?.rawValue, forKey: DefaultsKey.activePlan) }
    }

    /// When the current subscription ends unless it renews; `nil` for
    /// lifetime or no plan.
    private(set) var subscriptionExpiration: Date?

    /// Whether the subscription is set to renew; `false` once it's been
    /// cancelled, so the date reads as an end rather than a renewal.
    private(set) var subscriptionWillRenew = true

    /// A subscription is still running alongside a lifetime purchase, which
    /// Apple doesn't cancel on its own.
    private(set) var hasRedundantSubscription = false

    /// Bought the app back when it was paid.
    private(set) var isEarlySupporter: Bool {
        didSet { UserDefaults.standard.set(isEarlySupporter, forKey: DefaultsKey.isEarlySupporter) }
    }

    var ownsPro: Bool { activePlan != nil }

    var hasPro: Bool { ownsPro || isEarlySupporter }

    private(set) var isPurchasing = false

    /// The outcome of the last purchase or restore worth telling the person about.
    private(set) var statusMessage: String?

    private var allowance: DailyAllowance {
        didSet {
            let defaults = UserDefaults.standard
            defaults.set(allowance.day, forKey: DefaultsKey.allowanceDay)
            defaults.set(allowance.used, forKey: DefaultsKey.allowanceUsed)
        }
    }

    var remainingFreeTranslations: Int {
        allowance.remaining(limit: Self.dailyFreeLimit, on: .now)
    }

    var translationsUsedToday: Int {
        allowance.used(on: .now)
    }

    /// How many Recent entries to keep for this person.
    var historyLimit: Int {
        hasPro ? PlanLimits.proHistory : PlanLimits.freeHistory
    }

    /// How many entries can be starred; `nil` means no limit.
    var savedLimit: Int? {
        hasPro ? nil : PlanLimits.freeSaved
    }

    var canTranslate: Bool {
        hasPro || remainingFreeTranslations > 0
    }

    init() {
        // Start from the last known answer so an offline launch doesn't briefly
        // treat a Pro owner as a free user; StoreKit corrects it moments later.
        let defaults = UserDefaults.standard
        if let raw = defaults.string(forKey: DefaultsKey.activePlan), let plan = ProPlan(rawValue: raw) {
            activePlan = plan
        } else if defaults.bool(forKey: DefaultsKey.legacyOwnsPro) {
            activePlan = .lifetime
        } else {
            activePlan = nil
        }
        isEarlySupporter = defaults.bool(forKey: DefaultsKey.isEarlySupporter)
        allowance = DailyAllowance(
            day: defaults.object(forKey: DefaultsKey.allowanceDay) as? Date ?? .now,
            used: defaults.integer(forKey: DefaultsKey.allowanceUsed)
        )

        // Purchases can also arrive from outside the app — Ask to Buy approvals,
        // refunds, renewals, or a purchase made on another Mac.
        Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }

        Task {
            await refreshAccess()
            await loadProducts()
        }
    }

    // MARK: - Free tier

    /// Call after each successful translation.
    func recordTranslation() {
        guard !hasPro else { return }
        allowance.record(on: .now)
    }

    // MARK: - Store

    func product(for plan: ProPlan) -> Product? {
        products[plan]
    }

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let loaded = try await Product.products(for: Self.offeredPlans.map(\.productID))
            var byPlan: [ProPlan: Product] = [:]
            for product in loaded {
                if let plan = ProPlan(productID: product.id) {
                    byPlan[plan] = product
                }
            }
            products = byPlan
            for plan in Self.offeredPlans where byPlan[plan] == nil {
                Log.purchases.error("The App Store returned no product for \(plan.productID, privacy: .public)")
            }
            await refreshRenewal()
        } catch {
            Log.purchases.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Takes SwiftUI's `purchase` action so the confirmation sheet attaches to
    /// the window the person is using.
    func purchase(_ plan: ProPlan, using purchase: PurchaseAction) async {
        guard let product = products[plan], !isPurchasing else { return }
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await purchase(product) {
            case .success(let verification):
                await handle(verification)
            case .pending:
                statusMessage = String(localized: "Your purchase is waiting for approval. Pro unlocks as soon as it’s approved.")
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            Log.purchases.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = String(localized: "The purchase couldn’t be completed. \(error.localizedDescription)")
        }
    }

    /// Asks the App Store for the latest purchases, signing in if needed.
    func restorePurchases() async {
        statusMessage = nil
        do {
            try await AppStore.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            Log.purchases.error("Restore failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = String(localized: "Couldn’t restore purchases. Check your connection and try again.")
            return
        }

        await refreshAccess()
        statusMessage = hasPro
            ? String(localized: "Purchases restored")
            : String(localized: "No Pro purchase found for this Apple Account.")
    }

    // MARK: - Entitlements

    private func refreshAccess() async {
        await refreshOwnership()
        await refreshEarlySupporter()
    }

    /// Reads every current entitlement. Lifetime wins over a subscription,
    /// since it never ends.
    private func refreshOwnership() async {
        var plan: ProPlan?
        var expiration: Date?
        var subscriptionSeen = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  transaction.revocationDate == nil,
                  let found = ProPlan(productID: transaction.productID) else { continue }
            if found.isSubscription {
                subscriptionSeen = true
            }
            if found == .lifetime || plan == nil {
                plan = found
                expiration = found.isSubscription ? transaction.expirationDate : nil
            }
        }
        activePlan = plan
        subscriptionExpiration = expiration
        hasRedundantSubscription = plan == .lifetime && subscriptionSeen
        await refreshRenewal()
    }

    /// Whether the subscription will renew comes from its status, which needs
    /// the product; until products load the answer stays optimistic.
    private func refreshRenewal() async {
        guard let plan = activePlan, plan.isSubscription,
              let subscription = products[plan]?.subscription else {
            subscriptionWillRenew = true
            return
        }
        do {
            let statuses = try await subscription.status
            for status in statuses {
                if case .verified(let renewal) = status.renewalInfo {
                    subscriptionWillRenew = renewal.willAutoRenew
                    return
                }
            }
        } catch {
            Log.purchases.error("Failed to read subscription status: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func refreshEarlySupporter() async {
        do {
            guard case .verified(let app) = try await AppTransaction.shared else {
                Log.purchases.error("App transaction failed verification")
                return
            }
            // Sandbox and Xcode always report an original version of "1.0",
            // which would make every tester an early supporter and hide the
            // free tier entirely.
            guard app.environment == .production else {
                isEarlySupporter = false
                return
            }
            // On macOS this is the CFBundleShortVersionString first downloaded.
            isEarlySupporter = app.originalAppVersion
                .compare(Self.firstFreeVersion, options: .numeric) == .orderedAscending
        } catch {
            // Keep the cached answer; this can fail offline.
            Log.purchases.error("Failed to read app transaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(_ verification: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = verification else {
            Log.purchases.error("Transaction failed verification")
            statusMessage = String(localized: "The purchase couldn’t be verified. Try Restore Purchases.")
            return
        }

        if ProPlan(productID: transaction.productID) != nil {
            // Any change to a plan — purchase, renewal, refund — is simplest
            // to answer from the full set of entitlements.
            await refreshOwnership()
        }
        await transaction.finish()
    }
}

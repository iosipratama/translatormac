//
//  PurchaseStore.swift
//  TranslatorMac
//

import Foundation
import StoreKit
import SwiftUI
import os

/// Everything about Translate Offline Pro: the plans, whether this person has
/// one, the free days after the first launch, and the free plan's daily
/// allowance.
@Observable
final class PurchaseStore {

    /// The plans the Pro sheet offers, in display order. The first is
    /// selected by default: paying once comes first, subscribing second.
    static let offeredPlans: [ProPlan] = [.lifetime, .yearly]

    /// Free translations per calendar day without Pro.
    static let dailyFreeLimit = PlanLimits.freeTranslationsPerDay

    private enum DefaultsKey {
        static let activePlan = "activeProPlan"
        /// Written by versions that only had the one-time purchase.
        static let legacyOwnsPro = "ownsPro"
        static let isEarlySupporter = "isEarlySupporter"
        static let allowanceDay = "freeAllowanceDay"
        static let allowanceUsed = "freeAllowanceUsed"
        static let freeAccessNoticeShown = "freeAccessNoticeShown"
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

    /// When Lifetime was bought; `nil` for subscriptions or no plan.
    private(set) var lifetimePurchaseDate: Date?

    /// A subscription is still running alongside a lifetime purchase, which
    /// Apple doesn't cancel on its own.
    private(set) var hasRedundantSubscription = false

    /// Bought the app back when it was paid.
    private(set) var isEarlySupporter: Bool {
        didSet { UserDefaults.standard.set(isEarlySupporter, forKey: DefaultsKey.isEarlySupporter) }
    }

    var ownsPro: Bool { activePlan != nil }

    /// Has Pro for good: bought a plan, or bought the app when it was paid.
    /// The free days don't count; to decide whether something is unlocked,
    /// ask `access` instead.
    var hasPro: Bool {
        #if DEBUG
        switch debugPlan {
        case .forcePro: return true
        case .forceFree: return false
        case .automatic: break
        }
        #endif
        return ownsPro || isEarlySupporter || ScreenshotMode.isEnabled
    }

    /// The days of full access after the first launch on this device.
    private(set) var freeAccess: FreeAccessPeriod

    /// What this person can use right now: Pro, the free days, or the free
    /// plan.
    var access: PlanAccess {
        #if DEBUG
        if debugPlan == .forceFree { return .free }
        #endif
        return PlanAccess.resolve(hasPro: hasPro, freeAccess: freeAccess, on: now)
    }

    /// The free days' notice has been shown, ending or ended.
    private var freeAccessNoticeShown = UserDefaults.standard.bool(forKey: DefaultsKey.freeAccessNoticeShown) {
        didSet { UserDefaults.standard.set(freeAccessNoticeShown, forKey: DefaultsKey.freeAccessNoticeShown) }
    }

    /// The free days' notice, when it's time to show it.
    var dueFreeAccessNotice: FreeAccessNotice? {
        FreeAccessNotice.due(access: access, period: freeAccess, on: now, alreadyShown: freeAccessNoticeShown)
    }

    func markFreeAccessNoticeShown() {
        freeAccessNoticeShown = true
    }

    /// Bumped when the calendar day changes, so the free days and the daily
    /// count move on at midnight while the app is open.
    private var dayChanges = 0

    /// The current time, for every rule that depends on the date. Debug
    /// builds can move it forward to try later days.
    var now: Date {
        _ = dayChanges
        #if DEBUG
        return Calendar.current.date(byAdding: .day, value: debugDayOffset, to: .now) ?? .now
        #else
        return .now
        #endif
    }

    #if DEBUG
    /// Debug builds only: pretend to be on Pro or on the free plan,
    /// whatever StoreKit says. Release builds don't have this at all.
    enum DebugPlan: String, CaseIterable, Identifiable {
        case automatic
        case forcePro
        case forceFree

        var id: Self { self }

        var title: String {
            switch self {
            case .automatic: "From App Store"
            case .forcePro: "Force Pro"
            case .forceFree: "Force Free (no free days)"
            }
        }
    }

    var debugPlan: DebugPlan = UserDefaults.standard.string(forKey: "debugPlan")
        .flatMap(DebugPlan.init(rawValue:)) ?? .automatic {
        didSet { UserDefaults.standard.set(debugPlan.rawValue, forKey: "debugPlan") }
    }

    /// Debug builds only: pretend it's this many days later than it is.
    var debugDayOffset: Int = UserDefaults.standard.integer(forKey: "debugDayOffset") {
        didSet { UserDefaults.standard.set(debugDayOffset, forKey: "debugDayOffset") }
    }

    /// Debug builds only: start the free days again from today, as on a
    /// first launch.
    func restartFreeAccess() {
        let start = Date.now
        FirstLaunchRecord.reset(to: start)
        freeAccess = FreeAccessPeriod(start: start)
        debugDayOffset = 0
        freeAccessNoticeShown = false
    }

    /// Debug builds only: which day since the first launch the app thinks
    /// it is, from 1.
    var debugDay: Int {
        freeAccess.day(on: now)
    }

    /// Debug builds only: pretend it's this day since the first launch.
    func setDebugDay(_ day: Int) {
        debugDayOffset = day - freeAccess.day(on: .now)
    }

    /// Debug builds only: show the free days' notice again, as on the last
    /// free day, or as after it for someone who skipped that day. Moves to
    /// that day and goes by the App Store, since the notice never shows
    /// for Pro.
    func replayFreeAccessNotice(ended: Bool) {
        debugPlan = .automatic
        setDebugDay(ended ? freeAccess.days + 1 : freeAccess.days)
        freeAccessNoticeShown = false
    }

    /// Debug builds only: set how many free translations are left today.
    func setRemainingFreeTranslations(_ remaining: Int) {
        allowance = DailyAllowance(day: now, used: Self.dailyFreeLimit - remaining)
    }

    /// Debug builds only: back to what the App Store and the clock say.
    func resetDebugOverrides() {
        debugPlan = .automatic
        debugDayOffset = 0
        UserDefaults.standard.removeObject(forKey: SettingsKey.debugNoAppleIntelligence)
    }
    #endif

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
        allowance.remaining(limit: Self.dailyFreeLimit, on: now)
    }

    var translationsUsedToday: Int {
        allowance.used(on: now)
    }

    /// Starring new phrases is a Pro feature. Phrases saved earlier, as
    /// during the free days, stay readable and can still be removed.
    var canSaveNew: Bool {
        access.unlocksPro
    }

    /// Pronunciation and read-aloud are Pro features.
    var canUsePronunciation: Bool {
        access.unlocksPro
    }

    var canTranslate: Bool {
        access.unlocksPro || remainingFreeTranslations > 0
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
        freeAccess = FreeAccessPeriod(start: FirstLaunchRecord.date(recordingIfNeeded: .now))
        TranslationQuality.purchases = self

        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .NSCalendarDayChanged) {
                self?.dayChanges += 1
            }
        }

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

    /// Call once for each finished translation. Nothing is counted while
    /// everything is unlocked.
    func recordTranslation() {
        guard !access.unlocksPro else { return }
        allowance.record(on: now)
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
            // The detail is in the log; on screen, a plain next step.
            statusMessage = String(localized: "Couldn’t complete the purchase. Try again in a moment.")
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

    /// Reads purchases and the early-buyer check again. Restore does this
    /// after syncing with the App Store; tests call it directly.
    func refreshAccess() async {
        await refreshOwnership()
        await refreshEarlySupporter()
    }

    /// Reads every current entitlement. Lifetime wins over a subscription,
    /// since it never ends.
    private func refreshOwnership() async {
        var plan: ProPlan?
        var expiration: Date?
        var purchased: Date?
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
                purchased = found.isSubscription ? nil : transaction.purchaseDate
            }
        }
        activePlan = plan
        subscriptionExpiration = expiration
        lifetimePurchaseDate = purchased
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
            isEarlySupporter = PlanAccess.isEarlySupporter(
                originalAppVersion: app.originalAppVersion,
                environment: app.environment
            )
        } catch {
            // Keep the cached answer; this can fail offline.
            Log.purchases.error("Failed to read app transaction: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func handle(_ verification: VerificationResult<StoreKit.Transaction>) async {
        guard case .verified(let transaction) = verification else {
            Log.purchases.error("Transaction failed verification")
            statusMessage = String(localized: "Couldn’t verify the purchase. Use Restore Purchases to try again.")
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

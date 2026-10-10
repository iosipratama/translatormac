//
//  PurchaseStore.swift
//  TranslatorMac
//

import Foundation
import StoreKit
import SwiftUI
import os

/// Everything about Translate Offline Pro: the product, whether this person has
/// it, and the free tier's daily allowance.
@Observable
final class PurchaseStore {

    static let proProductID = "iosipratama.TranslatorMac.pro"

    /// Free translations per calendar day without Pro.
    static let dailyFreeLimit = 10

    /// The first version given away for free. Versions before it were paid, so
    /// anyone whose original download predates it already bought the app and
    /// gets Pro without buying it again.
    private static let firstFreeVersion = "1.2"

    private enum DefaultsKey {
        static let ownsPro = "ownsPro"
        static let isEarlySupporter = "isEarlySupporter"
        static let allowanceDay = "freeAllowanceDay"
        static let allowanceUsed = "freeAllowanceUsed"
    }

    /// `nil` until the App Store answers, or when it can't be reached.
    private(set) var product: Product?
    private(set) var isLoadingProduct = false

    /// Bought the Pro in-app purchase.
    private(set) var ownsPro: Bool {
        didSet { UserDefaults.standard.set(ownsPro, forKey: DefaultsKey.ownsPro) }
    }

    /// Bought the app back when it was paid.
    private(set) var isEarlySupporter: Bool {
        didSet { UserDefaults.standard.set(isEarlySupporter, forKey: DefaultsKey.isEarlySupporter) }
    }

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

    var canTranslate: Bool {
        hasPro || remainingFreeTranslations > 0
    }

    init() {
        // Start from the last known answer so an offline launch doesn't briefly
        // treat a Pro owner as a free user; StoreKit corrects it moments later.
        let defaults = UserDefaults.standard
        ownsPro = defaults.bool(forKey: DefaultsKey.ownsPro)
        isEarlySupporter = defaults.bool(forKey: DefaultsKey.isEarlySupporter)
        allowance = DailyAllowance(
            day: defaults.object(forKey: DefaultsKey.allowanceDay) as? Date ?? .now,
            used: defaults.integer(forKey: DefaultsKey.allowanceUsed)
        )

        // Purchases can also arrive from outside the app — Ask to Buy approvals,
        // refunds, or a purchase made on another Mac.
        Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }

        Task {
            await refreshAccess()
            await loadProduct()
        }
    }

    // MARK: - Free tier

    /// Call after each successful translation.
    func recordTranslation() {
        guard !hasPro else { return }
        allowance.record(on: .now)
    }

    // MARK: - Store

    func loadProduct() async {
        guard product == nil, !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }

        do {
            product = try await Product.products(for: [Self.proProductID]).first
            if product == nil {
                Log.purchases.error("The App Store returned no product for \(Self.proProductID, privacy: .public)")
            }
        } catch {
            Log.purchases.error("Failed to load products: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Takes SwiftUI's `purchase` action so the confirmation sheet attaches to
    /// the window the person is using.
    func purchase(using purchase: PurchaseAction) async {
        guard let product, !isPurchasing else { return }
        isPurchasing = true
        statusMessage = nil
        defer { isPurchasing = false }

        do {
            switch try await purchase(product) {
            case .success(let verification):
                await handle(verification)
            case .pending:
                statusMessage = "Your purchase is waiting for approval. Pro unlocks as soon as it’s approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            Log.purchases.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            statusMessage = "The purchase couldn’t be completed. \(error.localizedDescription)"
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
            statusMessage = "Purchases couldn’t be restored. Check your internet connection and try again."
            return
        }

        await refreshAccess()
        if !hasPro {
            statusMessage = "No Pro purchase was found for this Apple Account."
        }
    }

    // MARK: - Entitlements

    private func refreshAccess() async {
        await refreshOwnership()
        await refreshEarlySupporter()
    }

    private func refreshOwnership() async {
        var owns = false
        for await result in StoreKit.Transaction.currentEntitlements(for: Self.proProductID) {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                owns = true
            }
        }
        ownsPro = owns
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
            statusMessage = "The purchase couldn’t be verified. Try Restore Purchases."
            return
        }

        if transaction.productID == Self.proProductID {
            if transaction.revocationDate == nil {
                ownsPro = true
            } else {
                await refreshOwnership()
            }
        }
        await transaction.finish()
    }
}

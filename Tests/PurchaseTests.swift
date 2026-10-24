//
//  PurchaseTests.swift
//  TranslatorTests
//

import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Translate_Offline

/// Buying, restoring and losing Pro, against `Translate Offline.storekit`.
@Suite(.serialized)
struct PurchaseTests {
    /// Cached answers `PurchaseStore` starts from, cleared so each test
    /// starts from what StoreKit says. Put back afterwards: hosted tests
    /// share the app's settings.
    private static let cachedKeys = ["activeProPlan", "ownsPro", "isEarlySupporter", "debugPlan"]

    private func withSession(_ body: (SKTestSession, PurchaseStore) async throws -> Void) async throws {
        let defaults = UserDefaults.standard
        let saved = Self.cachedKeys.map { ($0, defaults.object(forKey: $0)) }
        defer {
            for (key, value) in saved { defaults.set(value, forKey: key) }
        }
        for key in Self.cachedKeys { defaults.removeObject(forKey: key) }

        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "Translate Offline", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        defer { session.clearTransactions() }

        let store = PurchaseStore()
        store.debugPlan = .automatic
        try await body(session, store)
    }

    /// StoreKit testing caches the current entitlements: a first purchase
    /// shows within a second, but a later change, such as an expiry, can
    /// take about 15. Read them again until the store reaches the expected
    /// state, for up to 20 seconds.
    private func refresh(_ store: PurchaseStore, until condition: () -> Bool) async throws {
        for _ in 0..<80 {
            await store.refreshAccess()
            if condition() { return }
            try await Task.sleep(for: .milliseconds(250))
        }
    }

    @Test func nothingBoughtIsNotPro() async throws {
        try await withSession { _, store in
            await store.refreshAccess()
            #expect(store.activePlan == nil)
            #expect(!store.hasPro)
            #expect(!store.isEarlySupporter)
        }
    }

    @Test func buyingLifetimeUnlocksPro() async throws {
        try await withSession { session, store in
            try await session.buyProduct(identifier: ProPlan.lifetime.productID)
            try await refresh(store) { store.activePlan != nil }
            #expect(store.activePlan == .lifetime)
            #expect(store.hasPro)
            #expect(store.access == .pro)
            #expect(store.subscriptionExpiration == nil)
        }
    }

    @Test func buyingYearlyUnlocksPro() async throws {
        try await withSession { session, store in
            try await session.buyProduct(identifier: ProPlan.yearly.productID)
            try await refresh(store) { store.activePlan != nil }
            #expect(store.activePlan == .yearly)
            #expect(store.hasPro)
            #expect(store.access == .pro)
            #expect(store.subscriptionExpiration != nil)
        }
    }

    /// A fresh install, or another Mac, finds the purchase again: restore
    /// reads the same entitlements once it has synced with the App Store.
    @Test func restoreFindsAnEarlierPurchase() async throws {
        try await withSession { session, store in
            try await session.buyProduct(identifier: ProPlan.lifetime.productID)

            UserDefaults.standard.removeObject(forKey: "activeProPlan")
            let reinstalled = PurchaseStore()
            reinstalled.debugPlan = .automatic
            #expect(reinstalled.activePlan == nil)

            try await refresh(reinstalled) { reinstalled.activePlan != nil }
            #expect(reinstalled.activePlan == .lifetime)
            #expect(reinstalled.hasPro)
        }
    }

    @Test func expiredYearlyIsNoLongerPro() async throws {
        try await withSession { session, store in
            try await session.buyProduct(identifier: ProPlan.yearly.productID)
            try await refresh(store) { store.activePlan != nil }
            #expect(store.hasPro)

            try session.expireSubscription(productIdentifier: ProPlan.yearly.productID)
            try await refresh(store) { store.activePlan == nil }
            #expect(store.activePlan == nil)
            #expect(!store.hasPro)
            // Back to the free days or the free plan, whichever applies.
            #expect(store.access != .pro)
        }
    }

    @Test func lifetimeWinsOverASubscription() async throws {
        try await withSession { session, store in
            try await session.buyProduct(identifier: ProPlan.yearly.productID)
            try await session.buyProduct(identifier: ProPlan.lifetime.productID)
            try await refresh(store) { store.activePlan == .lifetime }
            #expect(store.activePlan == .lifetime)
            #expect(store.hasRedundantSubscription)
        }
    }

    @Test func productsLoadWithLocalPrices() async throws {
        try await withSession { _, store in
            await store.loadProducts()
            let lifetime = try #require(store.product(for: .lifetime))
            let yearly = try #require(store.product(for: .yearly))
            #expect(!lifetime.displayPrice.isEmpty)
            #expect(yearly.subscription?.subscriptionPeriod.unit == .year)
            #expect(ProPlan.yearly.priceNote(for: yearly) != nil)
            #expect(ProPlan.lifetime.priceNote(for: lifetime) == nil)
        }
    }
}

private final class BundleToken {}

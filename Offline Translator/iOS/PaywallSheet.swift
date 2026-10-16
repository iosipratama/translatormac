//
//  PaywallSheet.swift
//  TranslatorMac
//

import StoreKit
import SwiftUI

/// Translate Offline Pro: what it adds, the two plans, and buying one.
///
/// Prices come from the App Store, never from here. Trial wording appears
/// only when the yearly plan has a free trial this person can still take.
struct PaywallSheet: View {
    /// Called once Pro is unlocked, after the sheet has closed.
    var unlocked: () -> Void = {}

    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var presentation
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss

    @State private var plan: ProPlan = .yearly
    @State private var trialDays: Int?
    @State private var isRestoring = false
    @State private var isManagingSubscription = false
    /// Bought Lifetime while a yearly plan is still renewing.
    @State private var needsToCancelYearly = false
    @State private var purchasedCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Translate without limits")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.textPrimary)
                    Text("Everything stays offline and private. Pick the plan that fits how you travel.")
                        .font(.body)
                        .foregroundStyle(.textMuted)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 14) {
                        benefit("Unlimited translations, every day")
                        benefit("Unlimited voice and camera")
                        benefit("Save as many phrases as you want")
                        benefit("Your newest \(PlanLimits.proHistory) translations on this iPhone")
                    }
                    .padding(.top, 24)
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaBar(edge: .bottom) {
                if needsToCancelYearly {
                    cancelYearlyNotice
                } else {
                    purchasePanel
                }
            }
            .background(.canvas)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore", action: restore)
                        .disabled(isRestoring || purchases.isPurchasing)
                }
            }
        }
        .tint(.accentForeground)
        .presentationDetents([.large])
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        .sensoryFeedback(.impact(weight: .light), trigger: purchasedCount)
        .task {
            plan = presentation.preferredPlan ?? .yearly
            await purchases.loadProducts()
            await loadTrial()
        }
    }

    private func benefit(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark")
                .font(.footnote.weight(.bold))
                .foregroundStyle(.accentForeground)
                .frame(width: 28, height: 28)
                .background(.accentTint, in: .circle)
                .accessibilityHidden(true)
            Text(text)
                .font(.body)
                .foregroundStyle(.textPrimary)
        }
    }

    // MARK: - Buying

    private var purchasePanel: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                PaywallPlanRow(
                    title: ProPlan.yearly.title,
                    detail: yearlyDetail,
                    price: purchases.product(for: .yearly)?.displayPrice,
                    badge: "Best Value",
                    isSelected: plan == .yearly
                ) { plan = .yearly }

                PaywallPlanRow(
                    title: ProPlan.lifetime.title,
                    detail: String(localized: "Pay once, keep Pro forever"),
                    price: purchases.product(for: .lifetime)?.displayPrice,
                    isSelected: plan == .lifetime
                ) { plan = .lifetime }
            }
            .padding(.top, 14)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Plans")

            if let message = purchases.statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.danger)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            } else if !purchases.isLoadingProducts, purchases.product(for: plan) == nil {
                Text("Couldn’t reach the App Store. Check your connection and try again.")
                    .font(.footnote)
                    .foregroundStyle(.danger)
                    .multilineTextAlignment(.center)
            }

            PrimaryCapsuleButton(title: callToAction, action: buy)
                .disabled(purchases.product(for: plan) == nil || purchases.isPurchasing || isRestoring)
                .overlay {
                    if purchases.isPurchasing || isRestoring {
                        ProgressView().tint(.onAccent)
                    }
                }

            Text(finePrint)
                .font(.caption)
                .foregroundStyle(.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)

            HStack(spacing: 20) {
                Link("Terms", destination: AppLinks.termsOfUse)
                Link("Privacy", destination: AppLinks.privacyPolicy)
            }
            .font(.footnote)
            .underline()
            .foregroundStyle(.textMuted)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
        .animation(.smooth, value: plan)
        .animation(.smooth, value: purchases.statusMessage)
        .onOpenURL(prefersInApp: true)
    }

    /// Shown after buying Lifetime on top of a yearly plan, which Apple
    /// doesn't cancel by itself.
    private var cancelYearlyNotice: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Label("You’re on Lifetime now", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                Text("Cancel your yearly plan in Manage Subscription so you aren’t charged again.")
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.surface, in: .rect(cornerRadius: 20))

            PrimaryCapsuleButton(title: "Manage Subscription") {
                isManagingSubscription = true
            }
            Button("Done") { close(unlocked: true) }
                .font(.headline)
                .padding(.vertical, 6)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
    }

    private var yearlyDetail: String {
        guard let product = purchases.product(for: .yearly) else { return String(localized: "Billed once a year") }
        let monthly = (product.price / 12).formatted(product.priceFormatStyle)
        if let trialDays {
            return String(localized: "\(monthly) a month · \(trialDays) days free")
        }
        return String(localized: "\(monthly) a month")
    }

    private var callToAction: LocalizedStringKey {
        let price = purchases.product(for: plan)?.displayPrice ?? ""
        switch plan {
        case .lifetime:
            return "Buy Lifetime · \(price)"
        case .yearly, .weekly:
            if let trialDays { return "Start \(trialDays)-Day Free Trial" }
            return "Subscribe · \(price)/year"
        }
    }

    private var finePrint: String {
        let price = purchases.product(for: plan)?.displayPrice ?? "…"
        switch plan {
        case .lifetime:
            return String(localized: "One payment of \(price). No subscription. Restores on all your Apple devices.")
        case .yearly, .weekly:
            let renewal = String(localized: "Renews automatically. Cancel anytime in Settings › Apple Account at least 24 hours before renewal.")
            return trialDays == nil
                ? String(localized: "\(price)/year. \(renewal)")
                : String(localized: "\(price)/year after the trial. \(renewal)")
        }
    }

    // MARK: - Actions

    /// The yearly plan's free trial, if it has one and this person hasn't
    /// used it.
    private func loadTrial() async {
        guard let subscription = purchases.product(for: .yearly)?.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await subscription.isEligibleForIntroOffer else {
            trialDays = nil
            return
        }
        let period = offer.period
        trialDays = switch period.unit {
        case .day: period.value
        case .week: period.value * 7
        case .month: period.value * 30
        case .year: period.value * 365
        @unknown default: nil
        }
    }

    private func buy() {
        let wasYearly = purchases.activePlan == .yearly
        let chosen = plan
        Task {
            await purchases.purchase(chosen, using: purchase)
            // Cancelled, pending or failed: stay, with any message above the button.
            guard purchases.activePlan == chosen else { return }
            purchasedCount += 1
            if chosen == .lifetime, wasYearly || purchases.hasRedundantSubscription {
                withAnimation(.smooth) { needsToCancelYearly = true }
            } else {
                close(unlocked: true)
            }
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            let hadPro = purchases.hasPro
            await purchases.restorePurchases()
            isRestoring = false
            if purchases.hasPro, !hadPro {
                close(unlocked: true)
            }
        }
    }

    private func close(unlocked didUnlock: Bool) {
        dismiss()
        if didUnlock { unlocked() }
    }
}

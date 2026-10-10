//
//  ProView.swift
//  TranslatorMac
//

import AppKit
import StoreKit
import SwiftUI

/// The Pro sheet: what Pro gives, the plans, and one button.
struct ProView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan = PurchaseStore.offeredPlans.first ?? .lifetime

    private let width: CGFloat = 540

    var body: some View {
        VStack(spacing: 0) {
            header

            benefits
                .padding(.top, 20)

            if purchases.hasPro {
                ownedState
                    .padding(.top, 24)
            } else {
                plans
                    .padding(.top, 22)
                callToAction
                    .padding(.top, 18)
            }

            if let message = purchases.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }

            footer
                .padding(.top, 18)
        }
        .padding(EdgeInsets(top: 28, leading: 32, bottom: 20, trailing: 32))
        .frame(width: width)
        .animation(.smooth, value: purchases.hasPro)
        .task {
            await purchases.loadProducts()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)
                .padding(.bottom, 10)

            Text("Unlock Pro")
                .font(.title2.weight(.bold))
            Text("Translate without limits.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 20, verticalSpacing: 12) {
            GridRow {
                benefit(
                    "Unlimited translations",
                    detail: "Free plan: \(PurchaseStore.dailyFreeLimit) a day"
                )
                benefit(
                    "Every language Apple offers",
                    detail: "Translated on this Mac, offline"
                )
            }
            GridRow {
                benefit(
                    "History and Saved",
                    detail: "Keep and star as many translations as you like"
                )
                benefit(
                    "All future updates",
                    detail: "New features included as they ship"
                )
            }
        }
    }

    private func benefit(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.tint)
                .frame(width: 15, height: 17)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.body)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    private var plans: some View {
        HStack(spacing: 12) {
            ForEach(PurchaseStore.offeredPlans) { plan in
                PlanCard(
                    plan: plan,
                    product: purchases.product(for: plan),
                    isSelected: plan == selectedPlan
                ) {
                    withAnimation(.snappy) { selectedPlan = plan }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Choose a plan")
    }

    @ViewBuilder
    private var callToAction: some View {
        VStack(spacing: 8) {
            if purchases.product(for: selectedPlan) != nil {
                Button {
                    Task { await purchases.purchase(selectedPlan, using: purchase) }
                } label: {
                    Text(purchases.isPurchasing ? "Purchasing…" : String(localized: selectedPlan.callToAction))
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchases.isPurchasing || !AppStore.canMakePayments)
                .keyboardShortcut(.defaultAction)

                if AppStore.canMakePayments {
                    Text(selectedPlan.terms)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Purchases are turned off on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if purchases.isLoadingProducts {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 32)
            } else {
                Text("The App Store can’t be reached right now.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    Task { await purchases.loadProducts() }
                }
            }
        }
    }

    // MARK: - Owned

    private var ownedState: some View {
        VStack(spacing: 8) {
            Label("Pro is unlocked", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Group {
                if purchases.isEarlySupporter && !purchases.ownsPro {
                    Text("Thanks for buying Translate Offline early. Pro comes with your original purchase.")
                } else if let expiration = purchases.subscriptionExpiration {
                    Text("Thank you for supporting Translate Offline. Your plan renews on \(expiration, format: .dateTime.day().month().year()).")
                } else {
                    Text("Thank you for supporting Translate Offline. Enjoy unlimited translations.")
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 14) {
            Button(purchases.hasPro ? "Done" : "Not Now") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if purchases.activePlan?.isSubscription == true {
                Link("Manage Subscription", destination: AppLinks.manageSubscriptions)
            }
            if !purchases.hasPro {
                Button("Restore Purchase") {
                    Task { await purchases.restorePurchases() }
                }
                .buttonStyle(.link)
                .disabled(purchases.isPurchasing)
            }
            Link("Terms of Use", destination: AppLinks.termsOfUse)
            Link("Privacy Policy", destination: AppLinks.privacyPolicy)
        }
        .font(.callout)
    }
}

/// One plan to pick: a radio with the price as the headline.
private struct PlanCard: View {
    var plan: ProPlan
    var product: Product?
    var isSelected: Bool
    var action: () -> Void

    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    radio
                    Text(plan.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 4)
                    if let badge = plan.badge {
                        Text(badge)
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(.tint, in: .capsule)
                    }
                }

                Group {
                    if let product {
                        Text(plan.priceLine(for: product))
                            .font(.system(size: 20, weight: .bold))
                        Text(plan.priceNote(for: product))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        // Keeps the card's height while prices load.
                        Text(verbatim: "0.00 / year")
                            .font(.system(size: 20, weight: .bold))
                        Text(verbatim: "About 0.00 a month")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, 24)
                .redacted(reason: product == nil ? .placeholder : [])
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .contentShape(.rect(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .accessibilityHint("Selects this plan")
    }

    private var radio: some View {
        ZStack {
            Circle()
                .fill(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary))
            Circle()
                .strokeBorder(.separator, lineWidth: isSelected ? 0 : 1)
            if isSelected {
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

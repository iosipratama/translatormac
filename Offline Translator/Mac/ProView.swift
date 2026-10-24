//
//  ProView.swift
//  TranslatorMac
//

import AppKit
import StoreKit
import SwiftUI

/// The Pro sheet: what Pro gives, the plans, and one button. Opens from the
/// daily limit, any "PRO" tag, the end of the free days, and the App menu.
struct ProView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var presentation
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan = PurchaseStore.offeredPlans.first ?? .lifetime
    @State private var isRestoring = false

    private let width: CGFloat = 480

    var body: some View {
        VStack(spacing: 0) {
            header

            benefits
                .padding(.top, 28)

            if purchases.hasPro {
                ownedState
                    .padding(.top, 28)
            } else {
                plans
                    .padding(.top, 28)
                callToAction
                    .padding(.top, 20)
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
                .padding(.top, 16)
        }
        .padding(EdgeInsets(top: 36, leading: 36, bottom: 24, trailing: 36))
        .frame(width: width)
        .overlay(alignment: .topLeading) {
            // Dismissal lives where the eye expects it on a sheet like this,
            // leaving the bottom to the one button that matters.
            Button(purchases.hasPro ? "Done" : "Not Now", systemImage: "xmark.circle.fill") {
                dismiss()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.system(size: 22))
            .foregroundStyle(.secondary)
            .keyboardShortcut(.cancelAction)
            .padding(16)
            .help(purchases.hasPro ? "Close" : "Not now")
        }
        .animation(.smooth, value: purchases.hasPro)
        .task {
            if let plan = presentation.preferredPlan, PurchaseStore.offeredPlans.contains(plan) {
                selectedPlan = plan
            }
            await purchases.loadProducts()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)
                .padding(.bottom, 8)

            Text("Upgrade to Pro")
                .font(.title.weight(.bold))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subtitle: LocalizedStringKey {
        if case .freeAccess(let end) = purchases.access {
            // The end is midnight, so name the last whole day instead.
            return "Everything is unlocked through \(end.addingTimeInterval(-1), format: .dateTime.weekday(.wide)). Keep it all with Pro."
        }
        return "Translate without limits."
    }

    // MARK: - Benefits

    /// Word for word the Pro list on the website, after "Everything in
    /// Free".
    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Everything in Free, plus:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.bottom, 2)
            ForEach(PlanFeatures.pro, id: \.key) { feature in
                benefit(feature)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private func benefit(_ title: LocalizedStringResource) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accentForeground)
                .frame(width: 14)
                .accessibilityHidden(true)

            Text(title)
                .font(.body.weight(.medium))
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Plans

    private var plans: some View {
        VStack(spacing: 10) {
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
                .accentProminentButton()
                .controlSize(.large)
                .disabled(purchases.isPurchasing || !AppStore.canMakePayments)
                .keyboardShortcut(.defaultAction)

                if AppStore.canMakePayments {
                    Text(selectedPlan.terms)
                        .font(.caption)
                        .padding(.top, 2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Purchases are turned off in Screen Time on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if purchases.isLoadingProducts {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 32)
            } else {
                Text("Couldn’t reach the App Store. Check your connection and try again.")
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
            Label("Pro is active", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Group {
                if purchases.hasRedundantSubscription {
                    Text("Your yearly plan is still active. To avoid another charge, cancel it in Manage Subscription.")
                } else if purchases.isEarlySupporter && !purchases.ownsPro {
                    Text("Thanks for buying Translate Offline early. Pro comes with your original purchase.")
                } else if let expiration = purchases.subscriptionExpiration {
                    // A cancelled plan ends rather than renews.
                    if purchases.subscriptionWillRenew {
                        Text("Thanks for supporting Translate Offline. Renews on \(expiration, format: .dateTime.day().month().year()).")
                    } else {
                        Text("Thanks for supporting Translate Offline. Ends on \(expiration, format: .dateTime.day().month().year()).")
                    }
                } else {
                    Text("Thanks for supporting Translate Offline.")
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
        HStack(spacing: 6) {
            if purchases.activePlan?.isSubscription == true || purchases.hasRedundantSubscription {
                footerLink("Manage Subscription…", destination: AppLinks.manageSubscriptions)
                footerSeparator
            }
            if !purchases.hasPro {
                Button(isRestoring ? "Restoring…" : "Restore Purchases") {
                    Task {
                        isRestoring = true
                        await purchases.restorePurchases()
                        isRestoring = false
                    }
                }
                .buttonStyle(.plain)
                .disabled(isRestoring || purchases.isPurchasing)
                footerSeparator
            }
            footerLink("Terms of Use", destination: AppLinks.termsOfUse)
            footerSeparator
            footerLink("Privacy Policy", destination: AppLinks.privacyPolicy)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
    }

    private func footerLink(_ title: LocalizedStringKey, destination: URL) -> some View {
        Button(title) {
            NSWorkspace.shared.open(destination)
        }
        .buttonStyle(.plain)
    }

    private var footerSeparator: some View {
        Text(verbatim: "·")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

/// One plan to pick: a row with a radio, the plan and its tagline, and the
/// price on the right, from the App Store in the person's own currency.
private struct PlanCard: View {
    var plan: ProPlan
    var product: Product?
    var isSelected: Bool
    var action: () -> Void

    private let cornerRadius: CGFloat = 10

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                radio

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                        if let badge = plan.badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .textCase(.uppercase)
                                .foregroundStyle(Color.onAccent)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accent, in: .capsule)
                        }
                    }
                    Text(plan.tagline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    if let product {
                        Text(plan.priceLine(for: product))
                            .font(.system(size: 16, weight: .bold))
                        if let note = plan.priceNote(for: product) {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        // Keeps the row's height while prices load.
                        Text(verbatim: "0.00 / year")
                            .font(.system(size: 16, weight: .bold))
                        Text(verbatim: "About 0.00 a month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .redacted(reason: product == nil ? .placeholder : [])
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        isSelected ? AnyShapeStyle(Color.accentForeground) : AnyShapeStyle(.separator),
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
                .fill(isSelected ? AnyShapeStyle(Color.accent) : AnyShapeStyle(.fill.secondary))
            Circle()
                .strokeBorder(.separator, lineWidth: isSelected ? 0 : 1)
            if isSelected {
                Circle()
                    .fill(Color.onAccent)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: 16, height: 16)
        .accessibilityHidden(true)
    }
}

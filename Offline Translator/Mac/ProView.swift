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
    @Environment(ProPresentation.self) private var presentation
    @Environment(\.purchase) private var purchase
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan = PurchaseStore.offeredPlans.first ?? .lifetime
    @State private var isRestoring = false

    private let width: CGFloat = 540

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

            Text("Unlock Pro")
                .font(.title.weight(.bold))
            Text("Translate without limits.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Benefits

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Only what Pro adds, each against the free plan's limit. Every
            // language is on the free plan too, so it isn't listed here.
            benefit("Unlimited translations", detail: "Free plan: \(PlanLimits.freeTranslationsPerDay) a day")
            benefit("Saved phrases", detail: "Pro only")
            benefit("Future Pro features", detail: "Included as they ship")
        }
        .frame(maxWidth: 400)
    }

    private func benefit(_ title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accentForeground)
                .frame(width: 14)
                .accessibilityHidden(true)

            Text("\(Text(title).fontWeight(.medium)) \(Text(verbatim: "—").foregroundStyle(.tertiary)) \(Text(detail).foregroundStyle(.secondary))")
                .font(.body)
                .lineLimit(1)
        }
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
                    Text("Your yearly plan is still active. Cancel it under Manage Subscription, since Apple doesn’t cancel it automatically.")
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
                            .foregroundStyle(Color.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accent, in: .capsule)
                    }
                }

                Group {
                    if let product {
                        Text(plan.priceLine(for: product))
                            .font(.system(size: 18, weight: .bold))
                        Text(plan.priceNote(for: product))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        // Keeps the card's height while prices load.
                        Text(verbatim: "0.00 / year")
                            .font(.system(size: 18, weight: .bold))
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

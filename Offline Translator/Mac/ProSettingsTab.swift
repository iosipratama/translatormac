//
//  ProSettingsTab.swift
//  TranslatorMac
//

import AppKit
import SwiftUI

/// Settings › Pro: the plan this Mac is on, and what it allows.
struct ProSettingsTab: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro

    @State private var isRestoring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if purchases.hasPro {
                planCard
                    .padding(.top, 20)
                subscriptionButtons
                    .padding(.top, 14)
            } else if purchases.access == .free {
                usageCard
                    .padding(.top, 20)
            }

            if let message = purchases.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 12)
            }

            footer
                .padding(.top, 28)

            #if DEBUG
            ProDebugControls()
                .padding(.top, 28)
            #endif
        }
        .padding(EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32))
        .animation(.smooth, value: purchases.hasPro)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(purchases.hasPro ? "Translate Offline Pro" : "Free plan")
                        .font(.headline)
                    if purchases.hasPro {
                        Text("Active")
                            .font(.caption2.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.onAccent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Color.accent, in: .capsule)
                    }
                }
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var subtitle: LocalizedStringKey {
        switch purchases.access {
        case .pro:
            "Thanks for supporting the app."
        case .freeAccess(let end):
            // The end is midnight, so name the last whole day instead.
            "Everything is unlocked through \(end.addingTimeInterval(-1), format: .dateTime.weekday(.wide).month().day()). Then the free plan gives you \(PlanLimits.freeTranslationsPerDay) translations a day."
        case .free:
            "Pro removes the daily limit and unlocks every feature."
        }
    }

    // MARK: - Free

    private var usageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            meter("Translations today", value: purchases.translationsUsedToday, max: PlanLimits.freeTranslationsPerDay)
            Text("Free translations reset at midnight.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator)
        }
    }

    private func meter(_ title: LocalizedStringKey, value: Int, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value) of \(max)")
                    .foregroundStyle(.secondary)
            }
            .font(.callout)
            ProgressView(value: Double(min(value, max)), total: Double(max))
                .progressViewStyle(.linear)
                .labelsHidden()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Pro

    private var planCard: some View {
        VStack(spacing: 0) {
            planRow("Plan", value: planName)
            if purchases.activePlan?.isSubscription == true, let date = purchases.subscriptionExpiration {
                Divider()
                planRow(
                    purchases.subscriptionWillRenew ? "Renews" : "Ends",
                    value: date.formatted(date: .long, time: .omitted)
                )
            }
            Divider()
            planRow("Includes", value: String(localized: "Every feature, without limits"))
        }
        .background(.background, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator)
        }
    }

    private var planName: String {
        if let plan = purchases.activePlan {
            return String(localized: plan.title)
        }
        // Early supporters never bought the Lifetime product; their Pro
        // comes from buying the app when it was paid, and the row says so.
        return String(localized: "Lifetime (original purchase)")
    }

    private func planRow(_ label: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
        .padding(.horizontal, 14)
        .frame(height: 36)
    }

    @ViewBuilder
    private var subscriptionButtons: some View {
        if purchases.activePlan?.isSubscription == true || purchases.hasRedundantSubscription {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Manage Subscription…") {
                        NSWorkspace.shared.open(AppLinks.manageSubscriptions)
                    }
                    if purchases.activePlan?.isSubscription == true {
                        Button("Switch to Lifetime…") {
                            MainWindowAccess.bringForward()
                            pro.present(plan: .lifetime)
                        }
                    }
                }
                if purchases.hasRedundantSubscription {
                    Text("Your yearly plan is still active. Cancel it under Manage Subscription, since Apple doesn’t cancel it automatically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if purchases.hasPro {
                Text("Bought on another Mac?")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                restoreButton
            } else {
                restoreButton
                Spacer()
                Button("Unlock Pro…") {
                    MainWindowAccess.bringForward()
                    pro.present()
                }
                .accentProminentButton()
                .controlSize(.large)
            }
        }
    }

    private var restoreButton: some View {
        Button(isRestoring ? "Restoring…" : "Restore Purchases") {
            Task {
                isRestoring = true
                await purchases.restorePurchases()
                isRestoring = false
            }
        }
        .disabled(isRestoring || purchases.isPurchasing)
    }
}

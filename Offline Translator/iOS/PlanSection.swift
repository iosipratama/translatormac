//
//  PlanSection.swift
//  TranslatorMac
//

import StoreKit
import SwiftData
import SwiftUI

/// The top of Settings: on the free plan, the Pro card and what's been used
/// today; with Pro, which plan it is and how to manage it.
struct PlanSection: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro

    @State private var isManagingSubscription = false

    var body: some View {
        if purchases.hasPro {
            Section {
                proCard
                if purchases.activePlan?.isSubscription == true || purchases.hasRedundantSubscription {
                    Button {
                        isManagingSubscription = true
                    } label: {
                        chevronRow("Manage Subscription")
                    }
                }
                if purchases.activePlan?.isSubscription == true {
                    Button {
                        pro.present(plan: .lifetime)
                    } label: {
                        chevronRow("Switch to Lifetime")
                    }
                }
            } footer: {
                if purchases.hasRedundantSubscription {
                    Text("Your yearly plan is still active. To avoid another charge, cancel it in Manage Subscription.")
                }
            }
            .listRowBackground(Color.surface)
            .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        } else {
            Section {
                unlockCard
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            if case .freeAccess(let end) = purchases.access {
                Section {
                    LabeledContent("Free days", value: String(localized: "Everything unlocked"))
                } footer: {
                    // The end is midnight, so name the last whole day instead.
                    Text("Everything is unlocked through \(end.addingTimeInterval(-1), format: .dateTime.weekday(.wide).month().day()). Then the free plan gives you \(PlanLimits.freeTranslationsPerDay) translations a day.")
                }
                .listRowBackground(Color.surface)
            } else {
                Section {
                    LabeledContent("Translations left today", value: "\(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay)")
                } footer: {
                    Text("Free translations reset at midnight.")
                }
                .listRowBackground(Color.surface)
            }
        }
    }

    // MARK: - Free

    private var unlockCard: some View {
        Button {
            pro.present()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "bolt.fill")
                    .font(.title3)
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.08), in: .rect(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Pro")
                        .font(.headline)
                    Text("Unlimited translations, history and saved")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.onAccent)
            .padding(16)
            .background(Color.accent, in: .rect(cornerRadius: 22))
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pro

    private var proCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.title3)
                .foregroundStyle(.onAccent)
                .frame(width: 48, height: 48)
                .background(Color.accent, in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("Translate Offline Pro")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    Text("Active")
                        .font(.caption2.weight(.bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.onAccent)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accent, in: .capsule)
                }
                Text(planLine)
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
            }
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }

    /// "Yearly · renews October 11, 2027", "Lifetime · purchased …".
    private var planLine: String {
        #if DEBUG
        if purchases.debugPlan == .forcePro, purchases.activePlan == nil {
            return "Pro, set in Settings › Debug"
        }
        #endif
        switch purchases.activePlan {
        case let plan? where plan.isSubscription:
            let title = String(localized: plan.title)
            guard let date = purchases.subscriptionExpiration?.formatted(date: .long, time: .omitted) else { return title }
            return purchases.subscriptionWillRenew
                ? String(localized: "\(title) · renews \(date)")
                : String(localized: "\(title) · ends \(date)")
        case .some:
            guard let date = purchases.lifetimePurchaseDate?.formatted(date: .long, time: .omitted) else {
                return String(localized: "Lifetime")
            }
            return String(localized: "Lifetime · purchased \(date)")
        case nil:
            // Early supporters' Pro comes from buying the app when it was paid.
            return String(localized: "Lifetime · original purchase")
        }
    }

    private func chevronRow(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.textFaint)
                .accessibilityHidden(true)
        }
        .contentShape(.rect)
    }
}

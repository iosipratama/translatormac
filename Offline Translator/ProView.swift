//
//  ProView.swift
//  TranslatorMac
//

import AppKit
import StoreKit
import SwiftUI

struct ProView: View {
    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.purchase) private var purchase

    var body: some View {
        VStack(spacing: 20) {
            header

            if purchases.hasPro {
                ownedState
            } else {
                benefits
                purchaseControls
            }

            if let message = purchases.statusMessage {
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(28)
        .frame(width: 360)
        .animation(.smooth, value: purchases.hasPro)
        .task {
            await purchases.loadProduct()
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            Text("Translate Offline Pro")
                .font(.title2)
                .fontWeight(.semibold)

            if !purchases.hasPro {
                Text("You get \(PurchaseStore.dailyFreeLimit) free translations a day. Pro removes the limit.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Unlimited translations every day", systemImage: "infinity")
            Label("One-time purchase, no subscription", systemImage: "checkmark.seal")
            Label("Supports an independent developer", systemImage: "heart")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var purchaseControls: some View {
        VStack(spacing: 10) {
            if let product = purchases.product {
                Button {
                    Task { await purchases.purchase(using: purchase) }
                } label: {
                    Group {
                        if purchases.isPurchasing {
                            Text("Purchasing…")
                        } else {
                            Text("Unlock Pro for \(product.displayPrice)")
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchases.isPurchasing || !AppStore.canMakePayments)
                .keyboardShortcut(.defaultAction)

                if !AppStore.canMakePayments {
                    Text("Purchases are turned off on this Mac.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if purchases.isLoadingProduct {
                ProgressView()
                    .controlSize(.small)
                    .frame(height: 28)
            } else {
                VStack(spacing: 6) {
                    Text("The App Store can’t be reached right now.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        Task { await purchases.loadProduct() }
                    }
                }
            }

            Button("Restore Purchases") {
                Task { await purchases.restorePurchases() }
            }
            .buttonStyle(.link)
            .font(.callout)
            .disabled(purchases.isPurchasing)
        }
    }

    private var ownedState: some View {
        VStack(spacing: 8) {
            Label("Pro is unlocked", systemImage: "checkmark.seal.fill")
                .font(.headline)
                .foregroundStyle(.green)

            Group {
                if purchases.isEarlySupporter && !purchases.ownsPro {
                    Text("Thanks for buying Translate Offline early. Pro comes with your original purchase.")
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
}

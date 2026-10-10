//
//  AppSidebar.swift
//  TranslatorMac
//

import StoreKit
import SwiftUI

struct AppSidebar: View {
    @Binding var selection: SidebarItem

    @Environment(PurchaseStore.self) private var purchases
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 280)
        .safeAreaInset(edge: .bottom) {
            if !purchases.hasPro {
                ProUnlockCard(price: purchases.product?.displayPrice) {
                    openWindow(id: "pro")
                }
                .padding(10)
            }
        }
        .animation(.smooth, value: purchases.hasPro)
    }
}

/// A quiet pointer to Pro at the foot of the sidebar. The App menu and the
/// result pane's limit message also lead there, so nothing depends on it.
private struct ProUnlockCard: View {
    var price: String?
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(.tint, in: .rect(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Unlock Pro")
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(.fill.tertiary, in: .rect(cornerRadius: 10))
            .contentShape(.rect(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unlock Pro")
        .accessibilityHint(Text(subtitle))
        .help("Unlimited translations with a one-time purchase")
    }

    private var subtitle: String {
        if let price { return "\(price), one-time purchase" }
        return "One-time purchase"
    }
}

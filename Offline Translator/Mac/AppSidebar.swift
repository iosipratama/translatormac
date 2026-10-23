//
//  AppSidebar.swift
//  TranslatorMac
//

import StoreKit
import SwiftUI

struct AppSidebar: View {
    @Binding var selection: SidebarItem

    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro

    var body: some View {
        List(selection: $selection) {
            ForEach(SidebarItem.allCases) { item in
                Label(item.title, systemImage: item.systemImage)
                    .tag(item)
            }
        }
        // Sidebar icons take the tint; the deeper variant keeps them legible
        // on the light sidebar.
        .tint(Color.accentForeground)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 280)
        .safeAreaInset(edge: .bottom) {
            if !purchases.hasPro {
                ProUnlockCard {
                    pro.present()
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
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.onAccent)
                    .frame(width: 28, height: 28)
                    .background(Color.accent, in: .rect(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("No daily limit")
                        .font(.subheadline.weight(.semibold))
                    Text("Upgrade to Pro")
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
        .accessibilityLabel("Upgrade to Pro")
        .accessibilityHint("No daily limit")
        .help("Show Pro plans")
    }
}

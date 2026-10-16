//
//  ProPlaceholderSheet.swift
//  TranslatorMac
//

import SwiftUI

/// Stands in for the Pro paywall, which is designed and built in its own step.
struct ProPlaceholderSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Translate Offline Pro", systemImage: "star.fill")
            } description: {
                Text("Unlimited translations and saved phrases. The full Pro screen is coming soon.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

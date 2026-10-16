//
//  PrimaryCapsuleButton.swift
//  TranslatorMac
//

import SwiftUI

/// The full-width yellow capsule for a screen's main action, as in
/// onboarding and the paywall.
struct PrimaryCapsuleButton: View {
    var title: LocalizedStringKey
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 54)
                .contentShape(.capsule)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .tint(isEnabled ? Color.accent : Color.raised)
        .foregroundStyle(isEnabled ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.textFaint))
    }
}

//
//  PrimaryCapsuleButton.swift
//  TranslatorMac
//

import SwiftUI

/// The full-width yellow capsule for a screen's main action, as in
/// onboarding and the paywall.
///
/// Drawn at an exact height: the system's prominent glass button style adds
/// padding of its own, which would make it taller than the design.
struct PrimaryCapsuleButton: View {
    var title: LocalizedStringKey
    var height: CGFloat = 57
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(isEnabled ? AnyShapeStyle(.onAccent) : AnyShapeStyle(.textFaint))
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .glassEffect(.regular.tint(isEnabled ? Color.accent : Color.raised).interactive(), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
    }
}

//
//  RoundIconButton.swift
//  TranslatorMac
//

import SwiftUI

/// A circular, icon-only Liquid Glass button. Prominent ones are filled with
/// the app's yellow, for the main action in a group. A locked one, for a Pro
/// feature on the free plan, wears the "PRO" badge; its action opens the
/// Pro sheet.
struct RoundIconButton: View {
    var title: LocalizedStringKey
    var systemImage: String
    var diameter: CGFloat = 48
    var isProminent = false
    /// The icon's color on a plain button, such as the yellow of a filled star.
    var iconColor: Color = .textPrimary
    var isLocked = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(.iconOnly)
                .font(.system(size: diameter * 0.36, weight: .semibold))
                .frame(width: diameter, height: diameter)
                .contentShape(.circle)
        }
        .buttonStyle(RoundIconButtonStyle(isProminent: isProminent, iconColor: iconColor))
        .overlay(alignment: .topTrailing) {
            if isLocked {
                ProBadge()
                    .offset(x: 8, y: -6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityHint(isLocked ? Text("Included with Pro") : Text(verbatim: ""))
    }
}

private struct RoundIconButtonStyle: ButtonStyle {
    var isProminent: Bool
    var iconColor: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(isProminent ? .onAccent : iconColor)
            .glassEffect(
                isProminent ? .regular.tint(Color.accent).interactive() : .regular.interactive(),
                in: .circle
            )
    }
}

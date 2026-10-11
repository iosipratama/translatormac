//
//  AccentStyles.swift
//  TranslatorMac
//
//  The app's yellow, applied the same way everywhere. Three colors in the
//  asset catalog carry it:
//  - AccentColor: the fill, for primary buttons, badges and the selected radio.
//  - OnAccent: labels and icons drawn on that fill, near-black so they read.
//  - AccentForeground: the yellow as text or a thin icon on the background,
//    deepened in light mode, where the fill color would be too faint.
//

import SwiftUI

extension View {
    /// The primary action: a yellow button with a dark label. The fill is
    /// pinned rather than left to the system accent, so the main button is
    /// the app's yellow even on a Mac with another accent chosen.
    func accentProminentButton() -> some View {
        buttonStyle(.borderedProminent)
            .tint(Color.accent)
            .foregroundStyle(Color.onAccent)
    }
}

/// Text that acts like a link, in the app's yellow instead of system blue.
struct AccentLinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.accentForeground)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .contentShape(.rect)
    }
}

extension ButtonStyle where Self == AccentLinkButtonStyle {
    static var accentLink: AccentLinkButtonStyle { AccentLinkButtonStyle() }
}

//
//  ProTag.swift
//  TranslatorMac
//

import SwiftUI

/// A locked feature on the free plan: the "PRO" badge standing in for it.
/// Tapping it opens the Pro sheet.
struct ProTag: View {
    /// What's locked, for VoiceOver.
    var feature: LocalizedStringKey

    @Environment(ProPresentation.self) private var pro

    var body: some View {
        Button {
            pro.present()
        } label: {
            ProBadge()
                .padding(4)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("\(Text(feature)), included with Pro"))
        .accessibilityHint("Shows Pro plans")
    }
}

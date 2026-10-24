//
//  ProTag.swift
//  TranslatorMac
//

import SwiftUI

/// A locked feature: the "PRO" badge, after the feature's icon when it has
/// one, standing in for the control. Clicking it opens the Pro sheet over
/// the main window, from anywhere, Settings included.
struct ProTag: View {
    /// What's locked, for VoiceOver and the tooltip.
    var feature: LocalizedStringKey
    var systemImage: String?

    @Environment(ProPresentation.self) private var pro

    var body: some View {
        if systemImage == nil {
            button.buttonStyle(.plain)
        } else {
            button
        }
    }

    private var button: some View {
        Button {
            MainWindowAccess.bringForward()
            pro.present()
        } label: {
            HStack(spacing: 5) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                ProBadge()
            }
            .contentShape(.rect)
        }
        .accessibilityLabel(Text("\(Text(feature)), included with Pro"))
        .accessibilityHint("Shows Pro plans")
        .help(Text("\(Text(feature)) is included with Pro"))
    }
}

//
//  ProBadge.swift
//  TranslatorMac
//

import SwiftUI

/// The small yellow "PRO" capsule. Every locked feature wears it, through
/// `ProTag`, so they all read the same way, on the Mac and the iPhone.
struct ProBadge: View {
    var body: some View {
        Text("Pro")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .foregroundStyle(Color.onAccent)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Color.accent, in: .capsule)
            .fixedSize()
    }
}

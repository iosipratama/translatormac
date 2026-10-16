//
//  SectionLabel.swift
//  TranslatorMac
//

import SwiftUI

/// The small uppercase label over a section: "ENGLISH", "RECENT",
/// "HOLD TO TALK".
struct SectionLabel: View {
    var title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.textMuted)
    }
}

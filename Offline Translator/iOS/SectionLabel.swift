//
//  SectionLabel.swift
//  TranslatorMac
//

import SwiftUI

/// The small uppercase label over a section: "ENGLISH", "RECENT",
/// "HOLD TO TALK".
struct SectionLabel: View {
    var text: Text

    init(_ title: LocalizedStringKey) {
        text = Text(title)
    }

    /// A language name or other text that's already localized.
    @_disfavoredOverload
    init(_ title: String) {
        text = Text(title)
    }

    /// For labels with a styled part, such as "JAPANESE · READING ALOUD".
    init(_ text: Text) {
        self.text = text
    }

    var body: some View {
        text
            .font(.caption.weight(.semibold))
            .textCase(.uppercase)
            .tracking(0.6)
            .foregroundStyle(.textMuted)
    }
}

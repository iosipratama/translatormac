//
//  PronunciationLine.swift
//  TranslatorMac
//

import SwiftUI

/// The reading under a translation in another script. A Pro feature: on the
/// free plan the line keeps its place with a "PRO" tag instead.
struct PronunciationLine: View {
    var pronunciation: String

    @Environment(PurchaseStore.self) private var purchases

    var body: some View {
        if purchases.canUsePronunciation {
            Text(pronunciation)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .accessibilityLabel("Pronunciation: \(pronunciation)")
        } else {
            HStack(spacing: 6) {
                Text("Pronunciation")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
                ProTag(feature: "Pronunciation")
            }
        }
    }
}

//
//  PaneChrome.swift
//  TranslatorMac
//

import SwiftUI

/// Shared geometry for the two panes, so they always line up.
enum PaneMetrics {
    static let inset: CGFloat = 20
    static let headerHeight: CGFloat = 32
    static let footerHeight: CGFloat = 44
}

/// A pane's title row, with room for a small control on the trailing side.
struct PaneHeader<Accessory: View>: View {
    var title: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            accessory
                .font(.subheadline)
        }
        .padding(.horizontal, PaneMetrics.inset)
        .frame(height: PaneMetrics.headerHeight)
    }
}

/// A pane's bottom row, separated from the content by a hairline.
struct PaneFooter<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .padding(.horizontal, PaneMetrics.inset)
        .frame(height: PaneMetrics.footerHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

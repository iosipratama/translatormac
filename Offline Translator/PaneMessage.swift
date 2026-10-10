//
//  PaneMessage.swift
//  TranslatorMac
//

import SwiftUI

/// A centered message for a pane with nothing else to show: the empty state,
/// a failure, or the free-tier limit. Quieter than `ContentUnavailableView`,
/// which is sized for a whole window.
struct PaneMessage<Action: View>: View {
    var systemImage: String
    var title: LocalizedStringKey
    var description: LocalizedStringKey
    @ViewBuilder var action: Action

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(description)
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            action
                .padding(.top, 6)
        }
        .frame(maxWidth: 300)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension PaneMessage where Action == EmptyView {
    init(systemImage: String, title: LocalizedStringKey, description: LocalizedStringKey) {
        self.init(systemImage: systemImage, title: title, description: description) {
            EmptyView()
        }
    }
}

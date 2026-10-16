//
//  PaywallPlanRow.swift
//  TranslatorMac
//

import SwiftUI

/// One plan in the paywall's radio group: title, a supporting line, and
/// the price, with an optional badge on the top edge.
struct PaywallPlanRow: View {
    var title: LocalizedStringResource
    var detail: String
    /// `nil` while the App Store hasn't answered.
    var price: String?
    var badge: LocalizedStringResource?
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.accent) : AnyShapeStyle(.lineStrong))
                    .contentTransition(.symbolEffect(.replace))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let price {
                    Text(price)
                        .font(.title3.bold())
                        .foregroundStyle(.textPrimary)
                } else {
                    ProgressView()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(isSelected ? AnyShapeStyle(.accentTintSubtle) : AnyShapeStyle(.surface), in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(isSelected ? AnyShapeStyle(.accentForeground) : AnyShapeStyle(.lineStrong), lineWidth: isSelected ? 2 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.heavy))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(.onAccent)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.accent, in: .capsule)
                        .offset(x: -16, y: -11)
                }
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .animation(.snappy, value: isSelected)
    }
}

//
//  FreeAccessNoticeView.swift
//  TranslatorMac
//

import AppKit
import SwiftUI

/// The one-time sheet when the free days end: a thank-you, what the free
/// plan keeps, what Pro adds, and a way to the plans that's easy to decline.
struct FreeAccessNoticeView: View {
    var notice: FreeAccessNotice
    /// Closes this sheet and opens the Pro sheet.
    var showPlans: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            Text(title)
                .font(.title2.weight(.bold))
                .padding(.top, 12)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            HStack(alignment: .top, spacing: 16) {
                column("Still free", features: PlanFeatures.free, systemImage: "checkmark", style: AnyShapeStyle(.secondary))
                column("Pro adds", features: PlanFeatures.pro, systemImage: "plus", style: AnyShapeStyle(Color.accentForeground))
            }
            .padding(.top, 24)

            HStack(spacing: 12) {
                Button("Continue with Free") {
                    dismiss()
                }
                .controlSize(.large)
                .keyboardShortcut(.cancelAction)

                Button("See Pro Plans") {
                    showPlans()
                }
                .accentProminentButton()
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
            .padding(.top, 24)
        }
        .padding(EdgeInsets(top: 32, leading: 32, bottom: 24, trailing: 32))
        .frame(width: 500)
    }

    private var title: LocalizedStringKey {
        switch notice {
        case .ending: "Your free days end today"
        case .ended: "Your free days have ended"
        }
    }

    private var message: LocalizedStringKey {
        switch notice {
        case .ending:
            "Thanks for trying everything in Translate Offline. Starting tomorrow, you’ll be on the free plan."
        case .ended:
            "Thanks for trying everything in Translate Offline. You’re now on the free plan, and Pro is there whenever you want more."
        }
    }

    private func column(
        _ heading: LocalizedStringKey,
        features: [LocalizedStringResource],
        systemImage: String,
        style: AnyShapeStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(heading)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.bottom, 2)
            ForEach(features, id: \.key) { feature in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(style)
                        .frame(width: 12)
                        .accessibilityHidden(true)
                    Text(feature)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
        .accessibilityElement(children: .contain)
    }
}

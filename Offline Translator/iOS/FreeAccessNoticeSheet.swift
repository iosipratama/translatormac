//
//  FreeAccessNoticeSheet.swift
//  TranslatorMac
//

import SwiftUI

/// The one-time sheet when the free days end, as on the Mac: a thank-you,
/// what the free plan keeps, what Pro adds, and an easy way to decline.
struct FreeAccessNoticeSheet: View {
    var notice: FreeAccessNotice
    /// Closes this sheet and opens the Pro sheet.
    var showPlans: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.textPrimary)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.textMuted)
                    .padding(.top, 8)

                column("Still free", features: PlanFeatures.free, systemImage: "checkmark", iconStyle: .textMuted)
                    .padding(.top, 24)
                column("Pro adds", features: PlanFeatures.pro, systemImage: "plus", iconStyle: .accentForeground)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 6) {
                PrimaryCapsuleButton(title: "See Pro Plans", action: showPlans)
                Button("Continue with Free") {
                    dismiss()
                }
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .background(.canvas)
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
        iconStyle: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(heading)
                .accessibilityAddTraits(.isHeader)
            ForEach(features, id: \.key) { feature in
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(iconStyle)
                        .frame(width: 16)
                        .accessibilityHidden(true)
                    Text(feature)
                        .font(.body)
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .contain)
    }
}

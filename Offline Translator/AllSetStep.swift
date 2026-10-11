//
//  AllSetStep.swift
//  TranslatorMac
//

import SwiftUI

/// Step three: how the downloads went, and into the app.
struct AllSetStep: View {
    var model: OnboardingModel
    var onFinish: () -> Void

    private let rowHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, .green)
                .accessibilityHidden(true)

            Text("You’re all set")
                .font(.title.weight(.bold))
                .padding(.top, 16)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            if !model.requested.isEmpty {
                statusList
                    .padding(.top, 22)
            }

            Spacer(minLength: 16)

            Button("Start Translating", action: onFinish)
                .accentProminentButton()
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(model.isDownloading)
        }
        .padding(EdgeInsets(top: 44, leading: 60, bottom: 12, trailing: 60))
    }

    private var subtitle: LocalizedStringKey {
        if model.isDownloading {
            return "Downloading… macOS shows the progress."
        }
        return model.requested.isEmpty
            ? "You can download languages any time from the language menu."
            : "These languages now work offline on this Mac."
    }

    private var statusList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(model.requested, id: \.self) { language in
                    HStack {
                        Text(model.name(for: language))
                        Spacer()
                        status(for: language)
                            .font(.subheadline)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight)
                    Divider()
                }
            }
        }
        .frame(maxHeight: rowHeight * 5)
        .background(.background, in: .rect(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator)
        }
        .clipShape(.rect(cornerRadius: 8))
    }

    @ViewBuilder
    private func status(for language: Locale.Language) -> some View {
        switch model.result(for: language) {
        case .ready:
            Label("Ready", systemImage: "checkmark")
                .foregroundStyle(.green)
        case .notDownloaded:
            HStack(spacing: 10) {
                Text("Not downloaded")
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    model.retry(language)
                }
                .controlSize(.small)
                .disabled(model.isDownloading)
            }
        case nil:
            ProgressView()
                .controlSize(.small)
        }
    }
}

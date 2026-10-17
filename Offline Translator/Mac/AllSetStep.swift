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
            statusIcon
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            Text(title)
                .font(.title.weight(.bold))
                .padding(.top, 16)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
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

    /// The heading follows what's actually happening, so it never says
    /// "all set" while a download is still running or after one failed.
    private enum Phase {
        case downloading
        case done
        case partlyDone
        case nothingChosen
    }

    private var phase: Phase {
        if model.requested.isEmpty { return .nothingChosen }
        // Still prompting, or accepted and downloading in the background.
        if model.isDownloading || !model.isFinished { return .downloading }
        return model.hasFailedDownloads ? .partlyDone : .done
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch phase {
        case .downloading:
            ProgressView()
                .controlSize(.large)
        case .partlyDone:
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, .orange)
        case .done, .nothingChosen:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.white, .green)
        }
    }

    private var title: LocalizedStringKey {
        switch phase {
        case .downloading: "Downloading languages…"
        case .partlyDone: "Almost done"
        case .done, .nothingChosen: "You’re all set"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch phase {
        case .downloading: "Progress appears in a macOS window."
        case .done: "These languages now work offline."
        case .partlyDone: "Some languages didn’t download. Try again, or add them later in Settings."
        case .nothingChosen: "You can download languages anytime in Settings."
        }
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

//
//  OnboardingChrome.swift
//  TranslatorMac
//
//  Pieces the onboarding steps share: the app's mark and language status
//  rows.
//

import SwiftUI

/// The app's icon, as on the Home Screen, following Light and Dark.
struct AppMark: View {
    var size: CGFloat = 96

    var body: some View {
        Image(.appMark)
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
            .accessibilityHidden(true)
    }
}

/// A row of language status: "✓ Ready", a spinner, "Waiting".
struct LanguageStatusRow: View {
    enum Status {
        case alreadyHere
        case ready
        case downloading
        case waiting
        case failed(retry: () -> Void)
    }

    var name: String
    var status: Status

    var body: some View {
        HStack {
            Text(name)
                .foregroundStyle(.textPrimary)
            Spacer()
            switch status {
            case .alreadyHere:
                checkLabel("On this iPhone")
            case .ready:
                checkLabel("Downloaded")
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            case .downloading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Downloading…")
                        .foregroundStyle(.textMuted)
                }
            case .waiting:
                Text("Waiting")
                    .foregroundStyle(.textFaint)
            case .failed(let retry):
                HStack(spacing: 6) {
                    Text("Not downloaded ·")
                        .foregroundStyle(.textMuted)
                    Button("Try Again", action: retry)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentForeground)
                        .buttonStyle(.plain)
                }
            }
        }
        .font(.body)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private func checkLabel(_ text: LocalizedStringKey) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .fontWeight(.semibold)
                .foregroundStyle(.green)
            Text(text)
                .foregroundStyle(.textMuted)
        }
    }
}

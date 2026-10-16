//
//  OnboardingChrome.swift
//  TranslatorMac
//
//  Pieces every onboarding step shares: the page dots, the app's mark,
//  and language status rows.
//

import SwiftUI

/// Three dots for the three steps, the current one stretched.
struct OnboardingDots: View {
    var current: Int
    var count = 3

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? AnyShapeStyle(Color.accent) : AnyShapeStyle(.lineStrong))
                    .frame(width: index == current ? 20 : 6, height: 6)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

/// The app's mark: "文A" on a yellow tile.
struct AppMark: View {
    var size: CGFloat = 88

    var body: some View {
        Text(verbatim: "文A")
            .font(.system(size: size * 0.36, weight: .heavy))
            .foregroundStyle(.onAccent)
            .frame(width: size, height: size)
            .background(Color.accent, in: .rect(cornerRadius: size * 0.27))
            .shadow(color: Color.accent.opacity(0.35), radius: 18, y: 8)
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
                checkLabel("Ready")
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

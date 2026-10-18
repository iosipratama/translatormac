//
//  OnboardingDownloads.swift
//  TranslatorMac
//

import SwiftUI

/// Step 3: the chosen languages downloading, then "You're all set", on one
/// screen that only says Ready once iOS confirms each download.
///
/// iOS shows its own download sheet for each language and closes it as soon
/// as the download starts, never reporting progress. So each row moves from
/// Waiting to Downloading to Ready by checking with iOS, and the person can
/// start translating at any point while the rest finish in the background.
struct OnboardingDownloads: View {
    var onboarding: OnboardingModel
    var finish: () -> Void

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                    .padding(.top, 56)

                if !rows.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element) { index, language in
                            if index > 0 {
                                Rectangle().fill(.line).frame(height: 1).padding(.leading, 16)
                            }
                            LanguageStatusRow(name: rowName(for: language), status: status(of: language))
                                .accessibilityLabel(rowAccessibilityName(for: language))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                    }
                    .background(.surface, in: .rect(cornerRadius: 20))
                    .padding(.top, 32)
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .safeAreaBar(edge: .bottom) {
            // Same place as on the other onboarding screens: measured from
            // the bottom of the screen, not the home indicator.
            PrimaryCapsuleButton(title: "Start Translating", height: 60, action: finish)
                .padding(.horizontal, 32)
                .padding(.bottom, 59)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(.canvas)
        .navigationBarBackButtonHidden()
        .animation(.smooth, value: phase)
        .animation(.smooth, value: readyCount)
        .sensoryFeedback(.success, trigger: phase) { _, phase in phase == .done }
        .onChange(of: scenePhase) { _, phase in
            // Downloads keep going while the app is away.
            if phase == .active {
                Task { await onboarding.inventory.refreshBackgroundDownloads() }
            }
        }
    }

    // MARK: - Header

    private enum Phase {
        case downloading
        case done
        case someFailed
    }

    private var phase: Phase {
        if !onboarding.isFinished { return .downloading }
        return onboarding.hasFailedDownloads ? .someFailed : .done
    }

    private var header: some View {
        VStack(spacing: 0) {
            Group {
                switch phase {
                case .done:
                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(.green, in: .circle)
                        .symbolEffect(.bounce, value: phase)
                case .downloading:
                    ProgressView()
                        .controlSize(.large)
                        .frame(width: 88, height: 88)
                        .background(.surface, in: .circle)
                case .someFailed:
                    Image(systemName: "arrow.down")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.textMuted)
                        .frame(width: 88, height: 88)
                        .background(.surface, in: .circle)
                }
            }
            .transition(.scale(scale: 0.8).combined(with: .opacity))
            .accessibilityHidden(true)

            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, 28)
                .contentTransition(.opacity)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .contentTransition(.opacity)
        }
    }

    private var title: LocalizedStringKey {
        switch phase {
        case .downloading: "Downloading your languages"
        case .done: rows.isEmpty ? "Ready when you are" : "You’re all set"
        case .someFailed: "Some languages didn’t download"
        }
    }

    private var subtitle: LocalizedStringKey {
        switch phase {
        case .downloading:
            "iOS asks you to confirm each pair. Languages you already have finish right away."
        case .done:
            rows.isEmpty
                ? "You can download languages anytime in Settings › Languages."
                : "These languages now work offline on this iPhone."
        case .someFailed:
            "Try again, or add them later in Settings › Languages."
        }
    }

    // MARK: - Rows

    /// The pairs asked for. With nothing asked for, the languages already
    /// here, so the screen still shows what works offline.
    private var rows: [Locale.Language] {
        onboarding.requested.isEmpty
            ? onboarding.choices.filter(\.isInstalled).map(\.language)
            : onboarding.requested
    }

    /// "English ↔ Japanese": iOS downloads pairs and its sheet lists both
    /// halves, so the row names both too.
    private func rowName(for language: Locale.Language) -> String {
        guard onboarding.requested.contains(language) else { return onboarding.name(for: language) }
        let partner = onboarding.name(for: onboarding.partner(for: language))
        return "\(partner) ↔ \(onboarding.name(for: language))"
    }

    private func rowAccessibilityName(for language: Locale.Language) -> Text {
        guard onboarding.requested.contains(language) else { return Text(onboarding.name(for: language)) }
        let partner = onboarding.name(for: onboarding.partner(for: language))
        return Text("\(partner) and \(onboarding.name(for: language))")
    }

    private var readyCount: Int {
        rows.count { onboarding.result(for: $0) == .ready || !onboarding.requested.contains($0) }
    }

    private func status(of language: Locale.Language) -> LanguageStatusRow.Status {
        guard onboarding.requested.contains(language) else { return .ready }
        switch onboarding.result(for: language) {
        case .ready:
            return .ready
        case .notDownloaded:
            return .failed { onboarding.retry(language) }
        case nil:
            return onboarding.inventory.isActivelyDownloading(language) ? .downloading : .waiting
        }
    }
}

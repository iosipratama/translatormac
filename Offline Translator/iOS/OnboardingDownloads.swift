//
//  OnboardingDownloads.swift
//  TranslatorMac
//

import SwiftUI

/// Step 3: the chosen languages downloading one after another, then
/// "You're all set".
///
/// The Translation framework shows its own download sheet for each language
/// and reports only when it's done, never how far along it is, so rows move
/// from Waiting to Downloading to Ready, and the bar counts languages.
struct OnboardingDownloads: View {
    var onboarding: OnboardingModel
    var finish: () -> Void

    /// Downloads ended with something missing, and the person moved on.
    @State private var acceptedFailures = false
    @State private var finishCount = 0

    var body: some View {
        Group {
            if isAllSet {
                allSet
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            } else {
                downloading
                    .transition(.opacity)
            }
        }
        .animation(.smooth, value: isAllSet)
        .background(.canvas)
        .navigationBarBackButtonHidden()
        .sensoryFeedback(.success, trigger: isAllSet) { _, isAllSet in isAllSet }
    }

    // MARK: - Downloading

    private var downloading: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text(isFinished ? "Some languages didn’t download" : "Downloading your languages")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.textPrimary)
                        .contentTransition(.opacity)
                    Text(isFinished
                         ? "Try them again now, or continue and add them later in Settings."
                         : "This takes about a minute on Wi-Fi. If you skip, downloads iOS has started keep going.")
                        .font(.body)
                        .foregroundStyle(.textMuted)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }

            Section {
                ForEach(alreadyHere, id: \.self) { language in
                    LanguageStatusRow(name: onboarding.name(for: language), status: .alreadyHere)
                }
                ForEach(onboarding.requested, id: \.self) { language in
                    LanguageStatusRow(name: onboarding.name(for: language), status: status(of: language))
                }
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .animation(.smooth, value: onboarding.results.count)
        .animation(.smooth, value: isFinished)
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 14) {
                if isFinished {
                    // Something didn't download; the title says so.
                    OnboardingButton(title: "Continue") { acceptedFailures = true }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Downloading \(min(done + 1, total)) of \(total)…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                            .contentTransition(.numericText())
                        ProgressView(value: Double(done), total: Double(max(total, 1)))
                            .tint(Color.accent)
                    }
                    .animation(.smooth, value: done)
                }
                OnboardingDots(current: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: finish)
            }
        }
    }

    private func status(of language: Locale.Language) -> LanguageStatusRow.Status {
        switch onboarding.result(for: language) {
        case .ready:
            return .ready
        case .notDownloaded:
            return .failed { onboarding.retry(language) }
        case nil:
            return onboarding.inventory.downloading == language ? .downloading : .waiting
        }
    }

    // MARK: - All set

    private var allSet: some View {
        ScrollView {
            VStack(spacing: 0) {
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 88, height: 88)
                    .background(.green, in: .circle)
                    .symbolEffect(.bounce, value: isAllSet)
                    .accessibilityHidden(true)
                    .padding(.top, 72)

                Text(readyLanguages.isEmpty ? "Ready when you are" : "You’re all set")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.textPrimary)
                    .padding(.top, 28)
                Text(readyLanguages.isEmpty
                     ? "You can download languages anytime in Settings › Languages."
                     : "These languages now work offline on this iPhone.")
                    .font(.body)
                    .foregroundStyle(.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                if !readyLanguages.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(readyLanguages.enumerated()), id: \.element) { index, language in
                            if index > 0 {
                                Rectangle().fill(.line).frame(height: 1).padding(.leading, 16)
                            }
                            LanguageStatusRow(name: onboarding.name(for: language), status: .ready)
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
        .safeAreaBar(edge: .bottom) {
            OnboardingButton(title: "Start Translating", action: finish)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
        }
    }

    // MARK: - Progress

    private var alreadyHere: [Locale.Language] {
        onboarding.choices.filter(\.isInstalled).map(\.language)
    }

    private var readyLanguages: [Locale.Language] {
        alreadyHere + onboarding.requested.filter { onboarding.result(for: $0) == .ready }
    }

    private var total: Int { onboarding.requested.count }
    private var done: Int { onboarding.results.count }

    /// Every requested language has an answer, one way or the other.
    private var isFinished: Bool {
        !onboarding.isDownloading && done >= total
    }

    private var isAllSet: Bool {
        isFinished && (!onboarding.hasFailedDownloads || acceptedFailures)
    }
}

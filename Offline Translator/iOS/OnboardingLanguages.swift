//
//  OnboardingLanguages.swift
//  TranslatorMac
//

import SwiftUI

/// Step 2: which languages to add. Languages already on this iPhone are
/// listed as ready; the rest can be ticked for download. Nothing is ticked at
/// first, so moving on without downloading is just Continue.
struct OnboardingLanguages: View {
    @Bindable var onboarding: OnboardingModel
    var network: NetworkMonitor
    var download: () -> Void
    var skip: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Add languages to translate")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.textPrimary)
                    Text("Each language downloads once and works offline. You can add more later.")
                        .font(.body)
                        .foregroundStyle(.textMuted)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 8, trailing: 4))
            }

            if !network.isOnline {
                Section {
                    offlineCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }

            if onboarding.isLoadingChoices {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.surface)
            } else {
                if !available.isEmpty {
                    Section {
                        ForEach(available) { choice in
                            availableRow(choice)
                        }
                    } header: {
                        sectionHeader("Available offline")
                    }
                    .listRowBackground(Color.surface)
                }

                if !downloadable.isEmpty {
                    Section {
                        ForEach(visibleDownloadable) { choice in
                            downloadRow(choice)
                        }
                        if !onboarding.showsAllLanguages, downloadable.count > OnboardingModel.shortListCount {
                            Button("Show All Languages") {
                                withAnimation(.smooth) { onboarding.showsAllLanguages = true }
                            }
                            .foregroundStyle(.accentForeground)
                        }
                    } header: {
                        sectionHeader("Download to use")
                    }
                    .listRowBackground(Color.surface)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .scrollEdgeEffectStyle(.soft, for: .bottom)
        .animation(.smooth, value: network.isOnline)
        .safeAreaBar(edge: .bottom) {
            // Same place as on the welcome screen: measured from the bottom
            // of the screen, not the home indicator.
            PrimaryCapsuleButton(title: buttonTitle, height: 60) {
                if onboarding.selectedCount == 0 {
                    continueWithout()
                } else {
                    download()
                }
            }
            .disabled(onboarding.selectedCount > 0 && !network.isOnline)
            .contentTransition(.numericText())
            .animation(.snappy, value: onboarding.selectedCount)
            .padding(.horizontal, 32)
            .padding(.bottom, 59)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: skip)
            }
        }
        .task {
            let isFirstLoad = onboarding.isLoadingChoices
            await onboarding.loadChoices()
            // The shared model ticks the device's languages; here the list
            // starts empty and the person picks.
            if isFirstLoad { onboarding.selection = [] }
        }
    }

    // MARK: - Lists

    private var available: [OnboardingModel.Choice] {
        onboarding.choices.filter(\.isInstalled)
    }

    /// The device's own languages come first, as the shared model orders them.
    private var downloadable: [OnboardingModel.Choice] {
        onboarding.choices.filter { !$0.isInstalled }
    }

    private var visibleDownloadable: [OnboardingModel.Choice] {
        onboarding.showsAllLanguages ? downloadable : Array(downloadable.prefix(OnboardingModel.shortListCount))
    }

    private var buttonTitle: LocalizedStringKey {
        let count = onboarding.selectedCount
        return count == 0 ? "Continue" : "^[Download \(count) Language](inflect: true)"
    }

    /// Nothing to download: go straight on, where the next step shows the
    /// languages already here as ready.
    private func continueWithout() {
        download()
    }

    // MARK: - Rows

    private func sectionHeader(_ title: LocalizedStringKey) -> some View {
        SectionLabel(title)
            .accessibilityAddTraits(.isHeader)
    }

    private func availableRow(_ choice: OnboardingModel.Choice) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "checkmark.circle")
                .font(.title2)
                .foregroundStyle(.textMuted)
                .accessibilityHidden(true)
            Text(choice.name)
                .foregroundStyle(.textPrimary)
            Spacer()
            Text("Ready")
                .font(.subheadline)
                .foregroundStyle(.textMuted)
        }
        .accessibilityElement(children: .combine)
    }

    private func downloadRow(_ choice: OnboardingModel.Choice) -> some View {
        let isChecked = onboarding.selection.contains(choice.id)
        return Button {
            withAnimation(.snappy) { onboarding.toggle(choice) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isChecked ? AnyShapeStyle(Color.accent) : AnyShapeStyle(.lineStrong))
                    .contentTransition(.symbolEffect(.replace))
                Text(choice.name)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text(choice.nativeName)
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .typesettingLanguage(choice.language)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isChecked)
    }

    private var offlineCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wifi.slash")
                .font(.headline)
                .foregroundStyle(.danger)
                .accessibilityHidden(true)
            Text("You’re offline. Connect to Wi-Fi or cellular to download, or tap Skip and add languages later.")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surface, in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.danger.opacity(0.35))
        }
    }
}

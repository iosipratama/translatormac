//
//  OnboardingLanguages.swift
//  TranslatorMac
//

import SwiftUI

/// Step 2: which languages to download now. The iPhone's own languages that
/// aren't here yet start ticked; ones already here can't be unticked.
struct OnboardingLanguages: View {
    @Bindable var onboarding: OnboardingModel
    var network: NetworkMonitor
    var download: () -> Void
    var skip: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Which languages do you need?")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.textPrimary)
                    Text("Each one downloads once and stays on this iPhone. You can add more later.")
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

            Section {
                if onboarding.isLoadingChoices {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(onboarding.visibleChoices) { choice in
                        row(choice)
                    }
                    if !onboarding.showsAllLanguages {
                        Button("Show all languages") {
                            withAnimation(.smooth) { onboarding.showsAllLanguages = true }
                        }
                        .foregroundStyle(.accentForeground)
                    }
                }
            }
            .listRowBackground(Color.surface)
        }
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .animation(.smooth, value: network.isOnline)
        .safeAreaBar(edge: .bottom) {
            VStack(spacing: 14) {
                Text("^[\(onboarding.selectedCount) selected](inflect: true) · needs internet once")
                    .font(.footnote)
                    .foregroundStyle(.textMuted)
                    .contentTransition(.numericText())
                OnboardingButton(title: downloadTitle, action: download)
                    .disabled(onboarding.selectedCount == 0 || !network.isOnline)
                OnboardingDots(current: 1)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .animation(.snappy, value: onboarding.selectedCount)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Skip", action: skip)
            }
        }
        .task {
            await onboarding.loadChoices()
        }
    }

    private var downloadTitle: LocalizedStringKey {
        onboarding.selectedCount == 1 ? "Download 1 Language" : "Download \(onboarding.selectedCount) Languages"
    }

    private func row(_ choice: OnboardingModel.Choice) -> some View {
        let isChecked = choice.isInstalled || onboarding.selection.contains(choice.id)
        return Button {
            withAnimation(.snappy) { onboarding.toggle(choice) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(checkStyle(choice, isChecked: isChecked))
                    .contentTransition(.symbolEffect(.replace))
                Text(choice.name)
                    .foregroundStyle(choice.isInstalled ? .textMuted : .textPrimary)
                Spacer()
                Group {
                    if choice.isInstalled {
                        Text("On this iPhone")
                    } else {
                        Text(choice.nativeName)
                            .typesettingLanguage(choice.language)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.textMuted)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(choice.isInstalled)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
        .accessibilityValue(choice.isInstalled ? Text("On this iPhone") : Text(""))
        .sensoryFeedback(.selection, trigger: isChecked)
    }

    private func checkStyle(_ choice: OnboardingModel.Choice, isChecked: Bool) -> AnyShapeStyle {
        if choice.isInstalled { return AnyShapeStyle(.lineStrong) }
        return isChecked ? AnyShapeStyle(Color.accent) : AnyShapeStyle(.lineStrong)
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

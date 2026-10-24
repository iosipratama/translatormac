//
//  LanguagesStep.swift
//  TranslatorMac
//

import SwiftUI

/// Step two: pick the languages to download.
struct LanguagesStep: View {
    @Bindable var model: OnboardingModel
    var network: NetworkMonitor
    var onSkip: () -> Void

    private let rowHeight: CGFloat = 36

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which languages do you need?")
                .font(.title2.weight(.bold))
            Text("Each one downloads once and stays on this Mac. You can add more later in Settings.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 6)

            languageList
                .padding(.top, 16)

            if !network.isOnline {
                Label("You’re offline. Connect to download, or skip for now.", systemImage: "wifi.slash")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)
            }

            Spacer(minLength: 12)

            footer
        }
        .padding(EdgeInsets(top: 44, leading: 40, bottom: 36, trailing: 40))
    }

    // MARK: - List

    @ViewBuilder
    private var languageList: some View {
        if model.isLoadingChoices {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .frame(height: rowHeight * 3)
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(model.visibleChoices) { choice in
                        row(for: choice)
                        Divider()
                    }
                    if !model.showsAllLanguages {
                        Button("Show All Languages") {
                            withAnimation(.smooth) { model.showsAllLanguages = true }
                        }
                        .buttonStyle(.accentLink)
                        .padding(.horizontal, 12)
                        .frame(height: rowHeight - 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            // Six rows and the link when collapsed; the full list takes the
            // room there is.
            .frame(maxHeight: model.showsAllLanguages ? .infinity : rowHeight * CGFloat(OnboardingModel.shortListCount) + rowHeight - 2)
            .background(.background, in: .rect(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(.separator)
            }
            .clipShape(.rect(cornerRadius: 8))
        }
    }

    private func row(for choice: OnboardingModel.Choice) -> some View {
        HStack(spacing: 8) {
            Toggle(choice.name, isOn: Binding(
                get: { choice.isInstalled || model.selection.contains(choice.id) },
                set: { _ in model.toggle(choice) }
            ))
            .toggleStyle(.checkbox)
            .disabled(choice.isInstalled)

            Spacer()

            Group {
                if choice.isInstalled {
                    Text("Already on this Mac")
                } else {
                    Text(choice.entry.spokenNativeName)
                }
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(height: rowHeight)
        .contentShape(.rect)
        .onTapGesture {
            if !choice.isInstalled { model.toggle(choice) }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text("^[\(model.selectedCount) selected](inflect: true) · needs internet once")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if !network.isOnline {
                Button("Skip for Now", action: onSkip)
            }
            Button("Back") {
                model.goBack()
            }
            Button("Download") {
                model.startDownloads()
            }
            .accentProminentButton()
            .keyboardShortcut(.defaultAction)
            .disabled(model.selectedCount == 0 || !network.isOnline)
        }
    }
}

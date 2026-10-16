//
//  LanguagesScreen.swift
//  TranslatorMac
//

import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Settings › Languages: which languages are on this iPhone, and downloads
/// for the rest. iOS owns the downloads, so there's nothing to delete here.
struct LanguagesScreen: View {
    var model: TranslationModel
    var inventory: LanguageInventory

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Text("Download a language once and it works offline everywhere in the app.")
                    .font(.body)
                    .foregroundStyle(.textMuted)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 4, trailing: 4))
            }

            if inventory.isLoading {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            } else if inventory.entries.isEmpty || (installed.isEmpty && downloadable.isEmpty) {
                ContentUnavailableView(
                    "No Languages Available",
                    systemImage: "globe",
                    description: Text("This device can’t translate right now.")
                )
                .listRowBackground(Color.clear)
            } else {
                if !installed.isEmpty {
                    Section("On this iPhone") {
                        ForEach(installed) { entry in
                            HStack {
                                names(entry)
                                Spacer()
                                Label("Ready", systemImage: "checkmark")
                                    .font(.subheadline)
                                    .foregroundStyle(.textMuted)
                                    .labelStyle(ReadyLabelStyle())
                            }
                        }
                    }
                }
                Section {
                    ForEach(downloadable) { entry in
                        Button {
                            inventory.download(entry.language)
                        } label: {
                            HStack {
                                names(entry)
                                Spacer()
                                if inventory.isDownloading(entry.language) {
                                    ProgressView()
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.title3)
                                        .foregroundStyle(.accentForeground)
                                }
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(inventory.isDownloading(entry.language))
                        .accessibilityHint("Downloads the language")
                    }
                } header: {
                    if !downloadable.isEmpty {
                        Text("Download to use")
                    }
                } footer: {
                    Text("iOS stores these languages for all apps. To remove one, go to the Settings app › Apps › Translate › Downloaded Languages.")
                }
            }
        }
        .listRowBackground(Color.surface)
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .navigationTitle("Languages")
        .toolbarTitleDisplayMode(.large)
        .animation(.smooth, value: installed.map(\.id))
        .translationTask(inventory.configuration) { session in
            await inventory.prepare(using: session)
        }
        .task {
            await inventory.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await inventory.refresh() }
            }
        }
        .onDisappear {
            // A language downloaded here may complete the pair on Translate.
            Task { await model.refreshAvailability() }
        }
    }

    private var installed: [LanguageInventory.Entry] {
        inventory.entries.filter(\.isInstalled)
    }

    private var downloadable: [LanguageInventory.Entry] {
        inventory.entries.filter { !$0.isInstalled }
    }

    private func names(_ entry: LanguageInventory.Entry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.name)
                .foregroundStyle(.textPrimary)
            if !entry.nativeName.isEmpty {
                Text(entry.spokenNativeName)
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .typesettingLanguage(entry.language)
            }
        }
    }
}

/// "✓ Ready", with the check in green.
private struct ReadyLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundStyle(.green)
                .fontWeight(.semibold)
            configuration.title
        }
    }
}

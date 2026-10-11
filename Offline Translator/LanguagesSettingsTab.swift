//
//  LanguagesSettingsTab.swift
//  TranslatorMac
//

import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Settings › Languages: what's on this Mac, and a button for what isn't.
struct LanguagesSettingsTab: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var inventory = LanguageInventory()

    /// Ready languages first, then the rest in catalog order.
    private var rows: [LanguageInventory.Entry] {
        inventory.entries.sorted { a, b in
            a.isInstalled && !b.isInstalled
        }
    }

    private var downloadedCount: Int {
        inventory.entries.count(where: \.isInstalled)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("All languages")
                    .font(.headline)
                Spacer()
                if !inventory.isLoading {
                    Text("\(downloadedCount) on this Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            table
                .frame(height: 300)

            HStack(alignment: .center, spacing: 16) {
                Text("Languages are shared with other apps on this Mac. To remove one, go to System Settings › General › Language & Region › Translation Languages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button("Open System Settings…") {
                    LanguageCatalog.openLanguageSettings()
                }
                .fixedSize()
            }
            .padding(.top, 6)
        }
        .padding(EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32))
        .translationTask(inventory.configuration) { session in
            await inventory.prepare(using: session)
        }
        .task {
            await inventory.refresh()
        }
        // Languages can be added or removed in System Settings meanwhile.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await inventory.refresh() }
            }
        }
    }

    @ViewBuilder
    private var table: some View {
        if inventory.isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Table(rows) {
                TableColumn("Language") { entry in
                    HStack(spacing: 6) {
                        Text(entry.name)
                        if !entry.nativeName.isEmpty {
                            Text(entry.spokenNativeName)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                TableColumn("Status") { entry in
                    if entry.isInstalled {
                        Label("Ready", systemImage: "checkmark")
                            .foregroundStyle(.green)
                    } else if inventory.isDownloading(entry.language) {
                        Text("Downloading…")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not downloaded")
                            .foregroundStyle(.secondary)
                    }
                }
                .width(150)

                TableColumn("") { entry in
                    if !entry.isInstalled {
                        if inventory.isDownloading(entry.language) {
                            ProgressView()
                                .controlSize(.small)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            Button("Download") {
                                inventory.download(entry.language)
                            }
                            .controlSize(.small)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
                .width(96)
            }
            .alternatingRowBackgrounds()
        }
    }
}

//
//  LanguageMenu.swift
//  TranslatorMac
//

import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// A toolbar pop-up listing the catalog, grouped by whether each language is
/// already on this Mac.
struct LanguageMenu: View {
    @Environment(\.openSettings) private var openSettings

    /// The menu's name for VoiceOver and its hidden picker label.
    var title: LocalizedStringKey
    /// The tooltip, which describes the menu rather than repeating its name.
    var help: LocalizedStringKey
    @Binding var selection: Locale.Language?
    var selectedName: String
    var languages: [TranslationLanguage]
    var statuses: [Locale.Language: LanguageAvailability.Status]
    var allowsDetection: Bool

    var body: some View {
        Menu {
            if allowsDetection {
                Picker(title, selection: $selection) {
                    Text("Detect Language").tag(Locale.Language?.none)
                }
                .pickerStyle(.inline)
                .labelsHidden()
                Divider()
            }

            if statuses.isEmpty {
                // Availability hasn't been checked yet: a flat list beats an
                // empty menu.
                picker(for: languages)
            } else {
                let installed = languages.filter { statuses[$0.language] == .installed }
                let downloadable = languages.filter { statuses[$0.language] == .supported }
                let unavailable = languages.filter { statuses[$0.language] == .unsupported }

                if !installed.isEmpty {
                    Section("On This Mac") {
                        picker(for: installed)
                    }
                }
                if !downloadable.isEmpty {
                    Section("Not Downloaded") {
                        picker(for: downloadable, systemImage: "arrow.down.circle")
                    }
                }
                if !unavailable.isEmpty {
                    Section("Not Available for This Pair") {
                        picker(for: unavailable)
                            .disabled(true)
                    }
                }
            }

            Divider()

            Button("Manage Languages…") {
                SettingsNavigation.show(.languages, using: openSettings)
            }
        } label: {
            Text(selectedName)
                .frame(minWidth: 88, alignment: .leading)
                // Room between the name and the pill's edges and chevron.
                .padding(.horizontal, 6)
        }
        .menuIndicator(.visible)
        .disabled(languages.isEmpty)
        .help(help)
        .accessibilityLabel(title)
    }

    private func picker(for entries: [TranslationLanguage], systemImage: String? = nil) -> some View {
        Picker(title, selection: $selection) {
            ForEach(entries) { entry in
                if let systemImage {
                    Label(entry.name, systemImage: systemImage)
                        .tag(Locale.Language?.some(entry.language))
                } else {
                    Text(entry.name)
                        .tag(Locale.Language?.some(entry.language))
                }
            }
        }
        .pickerStyle(.inline)
        .labelsHidden()
    }
}

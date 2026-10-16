//
//  LanguagePickerSheet.swift
//  TranslatorMac
//

import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Chooses either end of the pair. Languages already on the iPhone come
/// first; picking one that isn't closes the sheet and lets iOS offer its
/// download.
struct LanguagePickerSheet: View {
    var model: TranslationModel

    @Environment(\.dismiss) private var dismiss

    @State private var side: LanguageSide
    @State private var draftSource: Locale.Language?
    @State private var draftTarget: Locale.Language
    @State private var query = ""

    init(model: TranslationModel, side: LanguageSide) {
        self.model = model
        _side = State(initialValue: side)
        _draftSource = State(initialValue: model.sourceLanguage)
        _draftTarget = State(initialValue: model.targetLanguage)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Side", selection: $side) {
                        Text("From · \(name(of: draftSource))").tag(LanguageSide.source)
                        Text("To · \(model.name(for: draftTarget))").tag(LanguageSide.target)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if statuses.isEmpty {
                    Section {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    }
                } else if installed.isEmpty, downloadable.isEmpty {
                    Section {
                        if query.isEmpty {
                            ContentUnavailableView(
                                "No Languages Available",
                                systemImage: "globe",
                                description: Text("This device can’t translate right now.")
                            )
                        } else {
                            ContentUnavailableView.search(text: query)
                        }
                    }
                    .listRowBackground(Color.clear)
                } else {
                    if !installed.isEmpty {
                        Section("On this iPhone") {
                            ForEach(installed) { language in
                                installedRow(language)
                            }
                        }
                    }
                    Section {
                        ForEach(downloadable) { language in
                            downloadRow(language)
                        }
                    } header: {
                        if !downloadable.isEmpty {
                            Text("Download to use")
                        }
                    } footer: {
                        Text("Each language downloads once, then works offline.")
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search languages")
            .navigationTitle("Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(role: .confirm) {
                        apply()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Rows

    private func installedRow(_ language: TranslationLanguage) -> some View {
        Button {
            choose(language.language)
        } label: {
            HStack {
                names(language)
                Spacer()
                if language.language == current {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.accentForeground)
                        .accessibilityLabel("Selected")
                } else if language.language == other {
                    Text(side == .source ? "Translating to" : "Translating from")
                        .font(.subheadline)
                        .foregroundStyle(.textMuted)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(language.language == current ? .isSelected : [])
    }

    private func downloadRow(_ language: TranslationLanguage) -> some View {
        Button {
            choose(language.language)
            apply()
            dismiss()
        } label: {
            HStack {
                names(language)
                Spacer()
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(.accentForeground)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Downloads the language")
    }

    private func names(_ language: TranslationLanguage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(language.name)
                .foregroundStyle(.textPrimary)
            let native = LanguageInventory.nativeName(for: language)
            if !native.isEmpty {
                Text(native)
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .typesettingLanguage(language.language)
            }
        }
    }

    // MARK: - Choosing

    private var current: Locale.Language? {
        side == .source ? draftSource : draftTarget
    }

    private var other: Locale.Language? {
        side == .source ? draftTarget : draftSource
    }

    /// Picking the language on the other side swaps the pair.
    private func choose(_ language: Locale.Language) {
        switch side {
        case .source:
            if language == draftTarget, let source = draftSource {
                draftTarget = source
            }
            draftSource = language
        case .target:
            if language == draftSource {
                draftSource = draftTarget
            }
            draftTarget = language
        }
    }

    /// The model swaps the pair itself when a side takes the other's
    /// language, so setting the source first lands on the drafted pair.
    private func apply() {
        if let draftSource, draftSource != model.sourceLanguage {
            model.sourceLanguage = draftSource
        }
        if draftTarget != model.targetLanguage {
            model.targetLanguage = draftTarget
        }
    }

    // MARK: - Lists

    /// Whether each language is downloaded, paired with the current other side.
    private var statuses: [Locale.Language: LanguageAvailability.Status] {
        side == .source ? model.sourceStatuses : model.targetStatuses
    }

    private var matching: [TranslationLanguage] {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return model.supportedLanguages }
        return model.supportedLanguages.filter {
            $0.name.localizedStandardContains(query)
                || LanguageInventory.nativeName(for: $0).localizedStandardContains(query)
        }
    }

    private var installed: [TranslationLanguage] {
        matching.filter { statuses[$0.language] == .installed }
    }

    private var downloadable: [TranslationLanguage] {
        matching.filter { statuses[$0.language] == .supported }
    }

    private func name(of language: Locale.Language?) -> String {
        language.map(model.name(for:)) ?? String(localized: "Detect")
    }
}

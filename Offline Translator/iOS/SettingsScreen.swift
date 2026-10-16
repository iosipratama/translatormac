//
//  SettingsScreen.swift
//  TranslatorMac
//

import SwiftData
import SwiftUI

/// Settings: the plan, how translation behaves, the voice, languages,
/// history, and the fine print. Every change applies at once.
struct SettingsScreen: View {
    var model: TranslationModel
    var inventory: LanguageInventory

    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseStore.self) private var purchases

    @AppStorage(SettingsKey.liveTranslate) private var translatesAsYouType = true
    @AppStorage(SettingsKey.showPronunciation) private var showsPronunciation = true
    @AppStorage(SettingsKey.autoSpeakVoice) private var speaksAfterVoice = true
    @AppStorage(SettingsKey.speechRate) private var speechRate = 0.45
    @AppStorage(SettingsKey.keepHistory) private var keepsHistory = true
    @AppStorage(SettingsKey.translationQuality) private var quality: TranslationQuality = .fast

    @Query(filter: #Predicate<TranslationHistory> { !$0.isSaved })
    private var recent: [TranslationHistory]

    @State private var isConfirmingClear = false
    @State private var isRestoring = false
    @State private var sampleSpeaker = TranslationSpeaker()

    var body: some View {
        Form {
            PlanSection()

            Section {
                Group {
                    Toggle("Translate as you type", isOn: $translatesAsYouType)
                    Toggle("Show pronunciation", isOn: $showsPronunciation)
                    Toggle("Read results aloud after voice", isOn: $speaksAfterVoice)
                }
                .tint(.green)
                Picker("Quality", selection: shownQuality) {
                    ForEach(TranslationQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .disabled(!TranslationQuality.isBestAvailable)
            } header: {
                Text("Translation")
            } footer: {
                Text(qualityNote)
            }

            Section("Voice") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Speaking speed")
                    Slider(value: $speechRate, in: 0...1) {
                        Text("Speaking speed")
                    } minimumValueLabel: {
                        Text("Slow")
                    } maximumValueLabel: {
                        Text("Fast")
                    } onEditingChanged: { isEditing in
                        if !isEditing { playSample() }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .tint(Color.accent)
                }
                .padding(.vertical, 4)
            }

            Section("Languages") {
                NavigationLink(value: AppRoute.languages) {
                    LabeledContent("Languages") {
                        if !inventory.isLoading {
                            Text("\(inventory.entries.count(where: \.isInstalled)) downloaded")
                        }
                    }
                }
            }

            Section {
                Toggle("Keep history", isOn: $keepsHistory)
                    .tint(.green)
                Button("Clear History", role: .destructive) {
                    isConfirmingClear = true
                }
                .tint(.red)
                .disabled(recent.isEmpty)
            } header: {
                Text("History")
            } footer: {
                Text(historyNote)
            }

            Section {
                Button {
                    restore()
                } label: {
                    HStack {
                        Text("Restore Purchase")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        if isRestoring {
                            ProgressView()
                        }
                    }
                }
                .disabled(isRestoring)
                Link(destination: AppLinks.privacyPolicy) {
                    linkRow("Privacy Policy")
                }
                Link(destination: AppLinks.termsOfUse) {
                    linkRow("Terms of Use")
                }
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    if let message = purchases.statusMessage {
                        Text(message)
                    }
                    Text("Version \(Self.version) · Everything runs on this iPhone.")
                }
            }
        }
        .listRowBackground(Color.surface)
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .navigationTitle("Settings")
        .toolbarTitleDisplayMode(.large)
        .onOpenURL(prefersInApp: true)
        .confirmationDialog("Clear all history?", isPresented: $isConfirmingClear, titleVisibility: .visible) {
            Button("Clear History", role: .destructive) {
                model.historyWillClear()
                HistoryStore(context: modelContext).clearRecent()
            }
        } message: {
            Text("This removes every translation in Recent. Saved translations are kept.")
        }
        .onChange(of: quality) {
            Task { await inventory.reload() }
        }
        .task {
            await inventory.refresh()
        }
    }

    // MARK: - Notes

    /// Shows Fast while Best quality can't take effect, so the picker matches
    /// what translation actually uses; the stored choice is kept for later.
    private var shownQuality: Binding<TranslationQuality> {
        Binding {
            TranslationQuality.isBestAvailable ? quality : .fast
        } set: { quality = $0 }
    }

    private var qualityNote: String {
        if let reason = TranslationQuality.bestUnavailableReason {
            return String(localized: "Uses the languages downloaded to this iPhone. \(reason)")
        }
        switch quality {
        case .fast:
            return String(localized: "Uses the languages downloaded to this iPhone. Quick enough to translate as you type.")
        case .best:
            return String(localized: "Uses Apple Intelligence for more natural translations in every language, with nothing to download. Each one takes a moment longer. Still works offline.")
        }
    }

    private var historyNote: LocalizedStringKey {
        // With history off, describing what's kept would be untrue.
        guard keepsHistory else { return "New translations aren’t added to Recent. Saved items still work." }
        return purchases.hasPro
            ? "Keeps your newest \(PlanLimits.proHistory) translations on this iPhone. Saved items are never removed."
            : "Keeps your last \(PlanLimits.freeHistory) translations on this iPhone. Saved items are never removed."
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    // MARK: - Actions

    private func linkRow(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.textPrimary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.textFaint)
                .accessibilityHidden(true)
        }
    }

    private func restore() {
        isRestoring = true
        Task {
            await purchases.restorePurchases()
            isRestoring = false
        }
    }

    /// A line in the iPhone's own language, so the new speed can be heard.
    private func playSample() {
        sampleSpeaker.speak(
            String(localized: "This is how translations will sound."),
            in: Locale.current.language
        )
    }
}

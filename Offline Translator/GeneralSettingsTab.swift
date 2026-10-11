//
//  GeneralSettingsTab.swift
//  TranslatorMac
//

import AVFoundation
import SwiftData
import SwiftUI

/// Settings › General: how translation, speech and history behave.
struct GeneralSettingsTab: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PurchaseStore.self) private var purchases

    @AppStorage(SettingsKey.liveTranslate) private var translatesAsYouType = true
    @AppStorage(SettingsKey.showPronunciation) private var showsPronunciation = true
    @AppStorage(SettingsKey.speechRate) private var speechRate = 0.45
    @AppStorage(SettingsKey.keepHistory) private var keepsHistory = true
    @AppStorage(SettingsKey.appearance) private var theme: AppTheme = .automatic

    @State private var showClearConfirm = false
    @State private var sampleSpeaker = TranslationSpeaker()

    /// Only to know whether there is anything to clear.
    @Query(filter: #Predicate<TranslationHistory> { !$0.isSaved })
    private var unsaved: [TranslationHistory]

    var body: some View {
        Form {
            Picker("Appearance:", selection: $theme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            LabeledContent("Translation:") {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Translate as you type", isOn: $translatesAsYouType)
                        note("Otherwise, press ⌘⏎ to translate.")
                            .padding(.leading, 20)
                    }
                    Toggle("Show pronunciation", isOn: $showsPronunciation)
                }
            }

            LabeledContent("Speaking speed:") {
                Slider(value: $speechRate, in: 0...1) {
                    Text("Speaking speed")
                } minimumValueLabel: {
                    Text("Slow")
                } maximumValueLabel: {
                    Text("Fast")
                } onEditingChanged: { editing in
                    if !editing { playSample() }
                }
                .labelsHidden()
                .frame(width: 260)
            }

            LabeledContent("History:") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Keep a history of translations", isOn: $keepsHistory)
                    Button("Clear History…") {
                        showClearConfirm = true
                    }
                    .disabled(unsaved.isEmpty)
                    note(historyNote)
                }
            }
        }
        .formStyle(.columns)
        .onChange(of: theme) { _, theme in
            theme.apply()
        }
        .padding(EdgeInsets(top: 24, leading: 32, bottom: 24, trailing: 32))
        .alert("Clear all history?", isPresented: $showClearConfirm) {
            Button("Clear History", role: .destructive) {
                HistoryStore(context: modelContext).clearRecent()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every translation in Recent. Saved translations are kept.")
        }
    }

    private var historyNote: LocalizedStringKey {
        // With history off, describing what's kept would be untrue.
        guard keepsHistory else { return "New translations aren’t added to Recent." }
        return purchases.hasPro
            ? "Keeps your last \(PlanLimits.proHistory) translations on this Mac. Saved translations are never removed."
            : "Keeps your last \(PlanLimits.freeHistory) translations on this Mac. Saved translations are never removed."
    }

    private func note(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// A line in the Mac's own language, so the new speed can be heard.
    private func playSample() {
        sampleSpeaker.speak(
            String(localized: "This is how translations will sound."),
            in: Locale.current.language
        )
    }
}

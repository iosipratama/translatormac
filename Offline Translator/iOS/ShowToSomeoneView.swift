//
//  ShowToSomeoneView.swift
//  TranslatorMac
//

import SwiftUI
import UIKit

/// The translation, as big as it fits, to hold up to the person you're
/// talking to. Flip turns it to face someone across the table; the screen
/// stays awake and at full brightness while it's open.
struct ShowToSomeoneView: View {
    var model: TranslationModel

    @Environment(\.dismiss) private var dismiss
    @Environment(PurchaseStore.self) private var purchases
    @State private var isFlipped = false
    /// Its own Pro sheet: the app's can't show over this full-screen view.
    @State private var isShowingPro = false
    @State private var brightnessBefore: CGFloat?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let result = model.currentResult {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(model.name(for: model.targetLanguage))
                    Text(result.text)
                        .font(.system(size: 64, weight: .bold))
                        .minimumScaleFactor(0.3)
                        .foregroundStyle(.textPrimary)
                        .typesettingLanguage(model.targetLanguage)
                    // Held up to someone else, so a locked line isn't shown
                    // with a tag here; it just isn't shown.
                    if let pronunciation = result.pronunciation, showsPronunciation, purchases.canUsePronunciation {
                        Text(pronunciation)
                            .font(.title2)
                            .foregroundStyle(.textMuted)
                            .minimumScaleFactor(0.5)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .rotationEffect(isFlipped ? .degrees(180) : .zero)
                .animation(.smooth, value: isFlipped)
                .padding(.vertical, 24)

                VStack(alignment: .leading, spacing: 6) {
                    SectionLabel(Text("\(model.sourceTitle) · You said"))
                    Text(result.sourceText)
                        .font(.headline)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(3)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.surface, in: .rect(cornerRadius: 20))

                HStack(spacing: 16) {
                    RoundIconButton(
                        title: model.speaker.isSpeaking ? "Stop" : "Read Aloud",
                        systemImage: model.speaker.isSpeaking ? "stop.fill" : "speaker.wave.2.fill",
                        diameter: 64,
                        isProminent: true,
                        isLocked: !purchases.canUsePronunciation && !model.speaker.isSpeaking
                    ) {
                        if purchases.canUsePronunciation || model.speaker.isSpeaking {
                            model.toggleSpeech()
                        } else {
                            isShowingPro = true
                        }
                    }
                    .disabled(!model.canSpeak && purchases.canUsePronunciation)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Read Aloud")
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                        Text("Screen stays bright while this is open")
                            .font(.subheadline)
                            .foregroundStyle(.textMuted)
                    }
                    .accessibilityHidden(true)
                }
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
        .background(.canvas)
        .sheet(isPresented: $isShowingPro) {
            PaywallSheet()
        }
        .onAppear {
            model.noteShownToSomeone()
            UIApplication.shared.isIdleTimerDisabled = true
            if let screen {
                brightnessBefore = screen.brightness
                screen.brightness = 1
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            if let brightnessBefore, let screen {
                screen.brightness = brightnessBefore
            }
        }
    }

    private var header: some View {
        HStack {
            RoundIconButton(title: "Close", systemImage: "xmark") {
                dismiss()
            }
            Spacer()
            SectionLabel("Show to someone")
                .accessibilityAddTraits(.isHeader)
            Spacer()
            RoundIconButton(title: isFlipped ? "Turn back" : "Flip to face them", systemImage: "arrow.trianglehead.2.clockwise.rotate.90") {
                isFlipped.toggle()
            }
        }
        .padding(.top, 8)
    }

    @AppStorage(SettingsKey.showPronunciation) private var showsPronunciation = true

    private var screen: UIScreen? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.screen
    }
}

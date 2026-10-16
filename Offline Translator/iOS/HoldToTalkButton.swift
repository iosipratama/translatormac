//
//  HoldToTalkButton.swift
//  TranslatorMac
//

import SwiftUI

/// The big mic: press and hold to talk, let go to translate, slide away to
/// cancel. When voice can't be used it turns muted and taps explain why.
struct HoldToTalkButton: View {
    enum Mode {
        case ready
        /// No history yet: a soft halo hints at where to start.
        case readyWithHint
        /// Listening, with the current input level from 0 to 1.
        case listening(level: Float)
        /// Microphone or speech recognition was turned off.
        case off
        /// No on-device speech model for the language.
        case unavailable
    }

    var mode: Mode
    var press: () -> Void
    var release: () -> Void
    var cancel: () -> Void
    /// A tap while muted; explains what's wrong.
    var explain: () -> Void

    /// How far the finger can stray before the press cancels.
    private static let cancelDistance: CGFloat = 80

    @State private var isPressing = false
    @State private var didCancel = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 18) {
            circle
                .gesture(holdGesture, isEnabled: !isMuted)
                .onTapGesture { if isMuted { explain() } }
                .accessibilityElement()
                .accessibilityLabel(accessibilityLabel)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(isMuted ? "" : "Double-tap to start listening, and again to translate")
                .accessibilityAction {
                    // VoiceOver can't hold, so a double-tap starts and stops.
                    if isMuted { explain() } else if isListening { release() } else { press() }
                }

            SectionLabel(caption)
                .foregroundStyle(isListening ? AnyShapeStyle(.textPrimary) : AnyShapeStyle(.textMuted))
                .accessibilityHidden(true)
        }
    }

    // MARK: - Look

    /// The button keeps the same footprint while listening; the growth and
    /// the rings are drawn around it, so nothing else on screen moves.
    private var circle: some View {
        let scale: CGFloat = isListening ? 104.0 / 96.0 : 1
        let swell = reduceMotion ? 0 : CGFloat(listeningLevel) * 14

        return Image(systemName: isMuted ? "microphone.slash" : "microphone.fill")
            .font(.system(size: 34, weight: .semibold))
            .foregroundStyle(isMuted ? AnyShapeStyle(.textMuted) : AnyShapeStyle(.onAccent))
            .frame(width: 96, height: 96)
            .background {
                if isMuted {
                    Circle().fill(.raised)
                } else {
                    Circle().fill(Color.accent)
                }
            }
            .glassEffect(isMuted ? .regular : .regular.tint(Color.accent).interactive(), in: .circle)
            .scaleEffect(isPressing && !reduceMotion ? scale * 0.97 : scale)
            .background {
                if isListening {
                    Circle()
                        .fill(.accentTintSubtle)
                        .padding(-(34 + swell))
                    Circle()
                        .fill(.accentTint)
                        .padding(-(16 + swell / 2))
                } else if case .readyWithHint = mode {
                    Circle()
                        .fill(.accentTint)
                        .padding(-10)
                }
            }
            .contentShape(.circle)
            .animation(.snappy, value: isListening)
            .animation(reduceMotion ? nil : .smooth(duration: 0.15), value: listeningLevel)
    }

    private var caption: LocalizedStringKey {
        switch mode {
        case .listening: "Release to translate"
        case .off: "Mic off"
        case .ready, .readyWithHint, .unavailable: "Hold to talk"
        }
    }

    private var accessibilityLabel: Text {
        switch mode {
        case .listening: Text("Listening")
        case .off: Text("Microphone off")
        case .unavailable: Text("Voice unavailable offline")
        case .ready, .readyWithHint: Text("Hold to talk")
        }
    }

    private var isMuted: Bool {
        switch mode {
        case .off, .unavailable: true
        default: false
        }
    }

    private var isListening: Bool {
        if case .listening = mode { return true }
        return false
    }

    private var listeningLevel: Float {
        if case .listening(let level) = mode { return level }
        return 0
    }

    // MARK: - Gesture

    private var holdGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressing {
                    isPressing = true
                    didCancel = false
                    press()
                }
                let distance = hypot(value.translation.width, value.translation.height)
                if !didCancel, distance > Self.cancelDistance {
                    didCancel = true
                    cancel()
                }
            }
            .onEnded { _ in
                isPressing = false
                if !didCancel { release() }
                didCancel = false
            }
    }
}

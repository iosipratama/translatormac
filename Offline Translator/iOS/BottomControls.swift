//
//  BottomControls.swift
//  TranslatorMac
//

import SwiftUI

/// The three ways in, pinned to the bottom: type, hold to talk, and camera.
/// While listening, the other two step back.
struct BottomControls: View {
    var mic: HoldToTalkButton.Mode
    var type: () -> Void
    var camera: () -> Void
    var press: () -> Void
    var release: () -> Void
    var cancel: () -> Void
    var explainMic: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            RoundIconButton(title: "Type instead", systemImage: "keyboard", diameter: 56, action: type)
                .padding(.top, 20)
                .opacity(isListening ? 0.3 : 1)
                .disabled(isListening)

            Spacer(minLength: 0)

            HoldToTalkButton(mode: mic, press: press, release: release, cancel: cancel, explain: explainMic)

            Spacer(minLength: 0)

            RoundIconButton(title: "Translate with camera", systemImage: "camera", diameter: 56, action: camera)
                .padding(.top, 20)
                .opacity(isListening ? 0.3 : 1)
                .disabled(isListening)
        }
        .padding(.horizontal, 16)
        .animation(.smooth, value: isListening)
    }

    private var isListening: Bool {
        if case .listening = mic { return true }
        return false
    }
}

//
//  BottomControls.swift
//  TranslatorMac
//

import SwiftUI

/// The three ways in, pinned to the bottom: type, hold to talk, and camera.
struct BottomControls: View {
    /// A soft halo around the mic, the first-launch hint at where to start.
    var showsMicHint: Bool
    var type: () -> Void
    var talk: () -> Void
    var camera: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            RoundIconButton(title: "Type instead", systemImage: "keyboard", diameter: 56, action: type)
                .padding(.top, 20)

            Spacer()

            VStack(spacing: 10) {
                RoundIconButton(title: "Hold to talk", systemImage: "microphone.fill", diameter: 96, isProminent: true, action: talk)
                    .background {
                        if showsMicHint {
                            Circle()
                                .fill(.accentTint)
                                .padding(-10)
                        }
                    }
                SectionLabel("Hold to talk")
                    .accessibilityHidden(true)
            }

            Spacer()

            RoundIconButton(title: "Translate with camera", systemImage: "camera", diameter: 56, action: camera)
                .padding(.top, 20)
        }
        .padding(.horizontal, 16)
    }
}

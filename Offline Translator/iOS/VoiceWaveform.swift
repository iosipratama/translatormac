//
//  VoiceWaveform.swift
//  TranslatorMac
//

import SwiftUI

/// A row of bars following the microphone's level while listening.
struct VoiceWaveform: View {
    var levels: [Float]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.accent)
                    .frame(width: 3, height: height(for: index))
            }
        }
        .frame(height: 28, alignment: .center)
        .animation(reduceMotion ? nil : .smooth(duration: 0.12), value: levels)
        .accessibilityHidden(true)
    }

    /// With Reduce Motion, a still row instead of moving bars.
    private func height(for index: Int) -> CGFloat {
        let level = reduceMotion ? 0.3 : CGFloat(levels[index])
        return 4 + level * 24
    }
}

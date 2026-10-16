//
//  CameraOffView.swift
//  TranslatorMac
//

import PhotosUI
import SwiftUI

/// Shown when camera access was refused: a way to Settings, and photos as
/// an alternative, which need no permission.
struct CameraOffView: View {
    @Binding var photo: PhotosPickerItem?
    var close: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                RoundIconButton(title: "Close", systemImage: "xmark", action: close)
                Spacer()
            }

            Spacer()

            Image(systemName: "video.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.textMuted)
                .frame(width: 72, height: 72)
                .background(.surface, in: .circle)
                .accessibilityHidden(true)

            Text("Camera is off")
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
                .padding(.top, 20)

            Text("Turn on Camera for Translate Offline in Settings to translate signs and menus live. Or pick a photo you already took.")
                .font(.body)
                .foregroundStyle(.textMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 8)

            VStack(spacing: 12) {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                } label: {
                    Text("Open Settings")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .tint(.inverse)
                .foregroundStyle(.onInverse)

                PhotosPicker(selection: $photo, matching: .images) {
                    Text("Choose a Photo")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .foregroundStyle(.textPrimary)
                .buttonStyle(.glass)
                .controlSize(.large)
            }
            .padding(.top, 28)

            Spacer()
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .background(.canvas)
    }
}

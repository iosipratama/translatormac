//
//  WelcomeStep.swift
//  TranslatorMac
//

import AppKit
import SwiftUI

/// Step one: what the app is, in three lines.
struct WelcomeStep: View {
    var model: OnboardingModel

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text("Welcome to Translate Offline")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 18)
            Text("Translate text between languages on this Mac.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 18) {
                feature(
                    "character.bubble",
                    title: "Translations appear as you type",
                    detail: "Type or paste anything."
                )
                feature(
                    "wifi.slash",
                    title: "Works without internet",
                    detail: "Download a language once, then use it anywhere."
                )
                feature(
                    "lock",
                    title: "Stays on this Mac",
                    detail: "No account, and nothing is uploaded."
                )
            }
            .padding(.top, 32)
            .frame(maxWidth: 440)

            Spacer(minLength: 16)

            Button("Continue") {
                model.continueFromWelcome()
            }
            .accentProminentButton()
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        }
        .padding(EdgeInsets(top: 48, leading: 60, bottom: 36, trailing: 60))
    }

    private func feature(_ systemImage: String, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 22))
                .foregroundStyle(Color.accentForeground)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

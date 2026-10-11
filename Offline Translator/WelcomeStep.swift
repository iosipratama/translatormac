//
//  WelcomeStep.swift
//  TranslatorMac
//

import AppKit
import SwiftUI

/// Step one: what the app is, in three lines.
struct WelcomeStep: View {
    var model: OnboardingModel

    @Environment(PurchaseStore.self) private var purchases
    @State private var isRestoring = false
    @State private var restoreMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)
                .accessibilityHidden(true)

            Text("Welcome to Translate Offline")
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 18)
            Text("Offline translation on this Mac.")
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
                    "arrow.down.circle",
                    title: "Works without internet",
                    detail: "Download a language once, then use it anywhere."
                )
                feature(
                    "lock",
                    title: "Stays on this Mac",
                    detail: "Nothing you type is sent anywhere."
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

            restoreLink
                .padding(.top, 12)
        }
        .padding(EdgeInsets(top: 48, leading: 60, bottom: 12, trailing: 60))
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

    @ViewBuilder
    private var restoreLink: some View {
        if let restoreMessage {
            Text(restoreMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                Text("Already bought Pro?")
                    .foregroundStyle(.secondary)
                Button(isRestoring ? "Restoring…" : "Restore Purchases") {
                    Task { await restore() }
                }
                .buttonStyle(.accentLink)
                .disabled(isRestoring)
            }
            .font(.caption)
        }
    }

    private func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        await purchases.restorePurchases()
        restoreMessage = purchases.statusMessage
    }
}

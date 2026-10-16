//
//  AboutView.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 22/12/25.
//

import AppKit
import SwiftUI

/// The About window: the app, its version, and where to find out more. Laid
/// out like the Pro sheet's header and footer so it reads as the same app.
struct AboutView: View {

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return String(localized: "Version \(short) (\(build))")
    }

    private var copyright: String? {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
                .accessibilityHidden(true)

            Text("Translate Offline")
                .font(.title2.weight(.bold))
                .padding(.top, 12)
            Text(version)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
                .textSelection(.enabled)

            Text("Offline translation on this Mac.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            HStack(spacing: 6) {
                link("Website", destination: AppLinks.website)
                separator
                link("Privacy Policy", destination: AppLinks.privacyPolicy)
                separator
                link("Rate on the App Store", destination: AppLinks.appStoreReview)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 20)

            VStack(spacing: 2) {
                if let copyright {
                    Text(copyright)
                }
                Text("Made by Mekarya")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .padding(.top, 16)
        }
        // The top inset leaves room for the traffic lights of the title bar,
        // which is hidden but still there.
        .padding(EdgeInsets(top: 34, leading: 32, bottom: 26, trailing: 32))
        .frame(width: 320)
    }

    private func link(_ title: LocalizedStringKey, destination: URL) -> some View {
        Button(title) {
            NSWorkspace.shared.open(destination)
        }
        .buttonStyle(.plain)
    }

    private var separator: some View {
        Text(verbatim: "·")
            .foregroundStyle(.tertiary)
            .accessibilityHidden(true)
    }
}

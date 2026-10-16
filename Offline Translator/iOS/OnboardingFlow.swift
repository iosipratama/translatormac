//
//  OnboardingFlow.swift
//  TranslatorMac
//

import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// First launch: welcome, choose languages, download them. Shown once, over
/// Translate; no permissions and no paywall here.
struct OnboardingFlow: View {
    /// Called on Start Translating or Skip, with the device's language and
    /// the first language that downloaded, for the opening pair.
    var finish: (_ source: Locale.Language?, _ target: Locale.Language?) -> Void

    @State private var onboarding = OnboardingModel()
    @State private var network = NetworkMonitor()
    @State private var path: [Page] = []

    private enum Page: Hashable {
        case languages
        case downloads
    }

    var body: some View {
        NavigationStack(path: $path) {
            OnboardingWelcome {
                path.append(.languages)
            }
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .languages:
                    OnboardingLanguages(onboarding: onboarding, network: network) {
                        onboarding.startDownloads()
                        path.append(.downloads)
                    } skip: {
                        done()
                    }
                case .downloads:
                    OnboardingDownloads(onboarding: onboarding) {
                        done()
                    }
                }
            }
        }
        .tint(.accentForeground)
        .interactiveDismissDisabled()
        .translationTask(onboarding.inventory.configuration) { session in
            await onboarding.prepare(using: session)
        }
    }

    private func done() {
        onboarding.finish()
        finish(onboarding.inventory.deviceLanguage, onboarding.firstDownloaded)
    }
}

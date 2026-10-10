//
//  OnboardingWindow.swift
//  TranslatorMac
//

import AppKit
import SwiftUI
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// The first-launch flow: welcome, choose languages, all set.
struct OnboardingWindow: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow

    @State private var model = OnboardingModel()
    @State private var network = NetworkMonitor()
    @State private var didFinish = false

    static let size = CGSize(width: 600, height: 520)

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch model.step {
                case .welcome:
                    WelcomeStep(model: model)
                case .languages:
                    LanguagesStep(model: model, network: network, onSkip: finish)
                case .allSet:
                    AllSetStep(model: model, onFinish: finish)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.opacity.combined(with: .offset(x: 24)))
            .id(model.step)

            PageDots(count: OnboardingModel.Step.allCases.count, current: model.step.rawValue)
                .padding(.bottom, 18)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .animation(.smooth, value: model.step)
        .translationTask(model.configuration) { session in
            await model.prepare(using: session)
        }
        .task {
            await model.loadChoices()
        }
        // Closing the window early is a skip: the main window still opens
        // and languages can be downloaded later from its menus.
        .onDisappear {
            if !didFinish {
                finish()
            }
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        model.finish()
        showMainWindow()
        dismissWindow(id: "onboarding")
    }

    /// Opening the main window group always makes a new window, so when the
    /// flow was reopened from the Help menu the existing one comes forward
    /// instead.
    private func showMainWindow() {
        let existing = NSApp.windows.first {
            $0.isVisible && $0.identifier?.rawValue.hasPrefix("main") == true
        }
        if let existing {
            existing.makeKeyAndOrderFront(nil)
        } else {
            openWindow(id: "main")
        }
    }
}

/// Three dots, the current one in the accent color.
private struct PageDots: View {
    var count: Int
    var current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(index == current ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(current + 1) of \(count)")
    }
}

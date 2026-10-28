//
//  OnboardingWelcome.swift
//  TranslatorMac
//

import SwiftUI

/// Step 1: what the app is, in three lines. A centered header over a
/// left-aligned list, centered in the space above the button.
struct OnboardingWelcome: View {
    var next: () -> Void

    @State private var hasAppeared = false
    @State private var continueCount = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    // Centered in the space above the button; with large
                    // text it grows past it and scrolls.
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .safeAreaBar(edge: .bottom) {
            // Measured from the bottom of the screen, not the home
            // indicator, so it sits at the same place on every iPhone.
            PrimaryCapsuleButton(title: "Continue", height: 60) {
                continueCount += 1
                next()
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 59)
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(.canvas)
        .toolbar(.hidden, for: .navigationBar)
        .sensoryFeedback(.impact(weight: .light), trigger: continueCount)
        .onAppear {
            withAnimation(reduceMotion ? .none : .smooth(duration: 0.6)) { hasAppeared = true }
        }
    }

    private var content: some View {
            VStack(alignment: .leading, spacing: 64) {
                // Icon, title and subtitle, centered.
                VStack(spacing: 32) {
                    AppMark(size: 100)
                        .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.9)
                        .opacity(hasAppeared ? 1 : 0)

                    VStack(spacing: 12) {
                        Text("Welcome to Translate Offline")
                            .font(.largeTitle.bold())
                            .foregroundStyle(.textPrimary)
                        Text("Private translation on this iPhone.")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.textMuted)
                            .frame(maxWidth: 225)
                    }
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 28) {
                    feature(
                        "Use your camera",
                        "Translate signs, menus, and photos.",
                        icon: .cameraFrame,
                        index: 0
                    )
                    feature(
                        "Talk and listen",
                        "Speak, then hear the translation.",
                        icon: .waveformLines,
                        index: 1
                    )
                    feature(
                        "Works without internet",
                        "Download a language once, then use it anywhere.",
                        icon: .wifiOff,
                        index: 2
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
    }

    /// One reason to use the app; the three arrive one after another.
    private func feature(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, icon: ImageResource, index: Int) -> some View {
        HStack(alignment: .top, spacing: 17) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundStyle(.accentForeground)
                .frame(width: 44, height: 44)
                .background(.raised, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        .opacity(hasAppeared ? 1 : 0)
        .offset(y: hasAppeared || reduceMotion ? 0 : 12)
        .animation(reduceMotion ? nil : .smooth(duration: 0.5).delay(0.15 + Double(index) * 0.08), value: hasAppeared)
    }
}

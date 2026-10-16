//
//  OnboardingWelcome.swift
//  TranslatorMac
//

import SwiftUI

/// Step 1: what the app is, in three lines.
struct OnboardingWelcome: View {
    var next: () -> Void

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                AppMark()
                    .scaleEffect(hasAppeared || reduceMotion ? 1 : 0.85)
                    .opacity(hasAppeared ? 1 : 0)
                    .padding(.top, 48)

                Text("Welcome to Translate Offline")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 28)
                Text("Private, offline translation for your iPhone.")
                    .font(.body)
                    .foregroundStyle(.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                VStack(alignment: .leading, spacing: 26) {
                    feature(
                        "Type, talk, or use the camera",
                        "Translate a sentence, a conversation, or a menu in seconds.",
                        systemImage: "character.bubble.fill",
                        index: 0
                    )
                    feature(
                        "Works without internet",
                        "Download a language once, then use it anywhere: on a plane, abroad, offline.",
                        systemImage: "airplane",
                        index: 1
                    )
                    feature(
                        "Private by design",
                        "Everything runs on this iPhone. Nothing you type or say is sent anywhere.",
                        systemImage: "lock.fill",
                        index: 2
                    )
                }
                .padding(.top, 44)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaBar(edge: .bottom) {
            // Measured from the bottom of the screen, not the home
            // indicator, so it sits at the same place on every iPhone.
            PrimaryCapsuleButton(title: "Continue", action: next)
                .padding(.horizontal, 28)
                .padding(.bottom, 62)
                .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(.canvas)

        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            withAnimation(reduceMotion ? .none : .smooth(duration: 0.6)) { hasAppeared = true }
        }
    }

    /// One reason to use the app; the three arrive one after another.
    private func feature(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, systemImage: String, index: Int) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.accentForeground)
                .frame(width: 48, height: 48)
                .background(.surface, in: .rect(cornerRadius: 14))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
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

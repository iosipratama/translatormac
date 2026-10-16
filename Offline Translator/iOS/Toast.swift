//
//  Toast.swift
//  TranslatorMac
//

import SwiftUI

/// A brief confirmation — "Copied", "Saved" — with an optional action such
/// as View or Undo.
struct ToastMessage: Identifiable, Equatable {
    var id = UUID()
    var text: LocalizedStringResource
    var action: Action?

    struct Action {
        var title: LocalizedStringResource
        var perform: () -> Void
    }

    /// Each message is new, so showing the same text again restarts the timer.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

extension View {
    /// Shows the message at the bottom, `bottomPadding` above the edge so it
    /// clears the controls there, and hides it after a moment.
    func toast(_ message: Binding<ToastMessage?>, bottomPadding: CGFloat = 16) -> some View {
        modifier(ToastPresenter(message: message, bottomPadding: bottomPadding))
    }
}

private struct ToastPresenter: ViewModifier {
    @Binding var message: ToastMessage?
    var bottomPadding: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let visibleDuration: Duration = .seconds(2.5)

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    ToastView(message: message) {
                        self.message = nil
                    }
                    .padding(.bottom, bottomPadding)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .task(id: message.id) {
                        try? await Task.sleep(for: Self.visibleDuration)
                        guard !Task.isCancelled else { return }
                        self.message = nil
                    }
                }
            }
            .animation(.snappy, value: message)
            .onChange(of: message) { _, newValue in
                if let newValue {
                    AccessibilityNotification.Announcement(String(localized: newValue.text)).post()
                }
            }
    }
}

private struct ToastView: View {
    var message: ToastMessage
    var dismiss: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Text(message.text)
            if let action = message.action {
                Button {
                    action.perform()
                    dismiss()
                } label: {
                    Text(action.title)
                        .bold()
                        .underline()
                }
            }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.onInverse)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.inverse, in: .capsule)
        .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
    }
}

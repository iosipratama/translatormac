//
//  ProPresentation.swift
//  TranslatorMac
//

import Foundation

/// Whether the Pro sheet is showing. One for the app, handed down through
/// the environment so the sidebar card, the result pane, the App menu and
/// Settings all open the same sheet over the main window.
@Observable
final class ProPresentation {
    var isPresented = false

    /// The plan to start with the next time the sheet opens.
    var preferredPlan: ProPlan?

    func present(plan: ProPlan? = nil) {
        preferredPlan = plan
        isPresented = true
    }
}

//
//  PlanLimits.swift
//  TranslatorMac
//

import Foundation

/// What each plan allows. Every number the app shows or enforces about the
/// free tier comes from here, so the paywall, Settings and the store agree.
enum PlanLimits {
    /// Free translations per calendar day.
    static let freeTranslationsPerDay = 20
    /// Recent entries kept without Pro.
    static let freeHistory = 20
    /// Starred entries allowed without Pro.
    static let freeSaved = 10
    /// Recent entries kept with Pro.
    static let proHistory = 500
}

/// Keys for the settings people can change, with their defaults registered
/// at launch so every reader sees the same answer.
enum SettingsKey {
    static let liveTranslate = "liveTranslate"
    static let showPronunciation = "showPronunciation"
    static let speechRate = "speechRate"
    static let keepHistory = "keepHistory"
    static let settingsTab = "settingsTab"

    static let defaults: [String: Any] = [
        liveTranslate: true,
        showPronunciation: true,
        speechRate: 0.45,
        keepHistory: true,
    ]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaults)
    }
}

//
//  PlanLimits.swift
//  TranslatorMac
//

import Foundation

/// What each plan allows. Every number the app shows or enforces about the
/// free tier comes from here, so the paywall, Settings and the store agree.
/// Recent has no limit on any plan.
nonisolated enum PlanLimits {
    /// Calendar days of full access, Pro included, from the first launch.
    static let freeAccessDays = 3
    /// Free translations per calendar day, once the free days are over.
    static let freeTranslationsPerDay = 5
    /// Starred entries allowed without Pro.
    static let freeSaved = 10
}

/// Keys for the settings people can change, with their defaults registered
/// at launch so every reader sees the same answer.
enum SettingsKey {
    static let liveTranslate = "liveTranslate"
    static let showPronunciation = "showPronunciation"
    static let speechRate = "speechRate"
    static let keepHistory = "keepHistory"
    static let settingsTab = "settingsTab"
    static let appearance = "appearance"
    static let translationQuality = "translationQuality"
    /// iPhone: read a voice translation aloud as soon as it's ready.
    static let autoSpeakVoice = "autoSpeakVoice"
    /// Debug builds only: pretend Apple Intelligence isn't available.
    static let debugNoAppleIntelligence = "debugNoAppleIntelligence"

    static let defaults: [String: Any] = [
        liveTranslate: true,
        showPronunciation: true,
        speechRate: 0.45,
        keepHistory: true,
        appearance: AppTheme.automatic.rawValue,
        translationQuality: TranslationQuality.fast.rawValue,
        autoSpeakVoice: true,
    ]

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: defaults)
    }
}

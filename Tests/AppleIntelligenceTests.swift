//
//  AppleIntelligenceTests.swift
//  TranslatorTests
//

import Foundation
import Testing
@testable import Translate_Offline

/// Best quality is only offered where Apple Intelligence is available.
@Suite(.serialized)
struct AppleIntelligenceTests {
    @Test func unavailableMacFallsBackToFast() {
        let defaults = UserDefaults.standard
        let previousSimulation = defaults.object(forKey: SettingsKey.debugNoAppleIntelligence)
        let previousQuality = defaults.object(forKey: SettingsKey.translationQuality)
        defer {
            defaults.set(previousSimulation, forKey: SettingsKey.debugNoAppleIntelligence)
            defaults.set(previousQuality, forKey: SettingsKey.translationQuality)
        }

        defaults.set(true, forKey: SettingsKey.debugNoAppleIntelligence)
        defaults.set(TranslationQuality.best.rawValue, forKey: SettingsKey.translationQuality)

        #expect(!TranslationQuality.isBestAvailable)
        #expect(TranslationQuality.bestUnavailableReason != nil)
        #expect(TranslationQuality.effective == .fast)
    }
}

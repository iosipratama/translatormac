//
//  PlanFeatures.swift
//  TranslatorMac
//

import Foundation

/// What each plan includes, word for word as on the website, so the Pro
/// sheet and the free days' notice say the same thing.
enum PlanFeatures {
    /// The free plan.
    static var free: [LocalizedStringResource] {
        [
            "\(PlanLimits.freeTranslationsPerDay) translations a day",
            "Translate as you type",
            "All 19 languages, offline",
            "Recent translations",
            "Private, nothing uploaded",
        ]
    }

    /// What Pro adds to everything in Free. Best quality is only promised
    /// on a device that can run it.
    static var pro: [LocalizedStringResource] {
        var features: [LocalizedStringResource] = ["Unlimited translations"]
        if TranslationQuality.isBestAvailable {
            features.append("Best quality with Apple Intelligence")
        }
        features.append("Pronunciation and read-aloud")
        features.append("Saved phrases")
        return features
    }
}

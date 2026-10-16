//
//  TranslationQuality.swift
//  TranslatorMac
//

import Foundation
import FoundationModels
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Settings › General › Translation quality: which on-device models translate.
///
/// Both choices work without an internet connection.
/// - `fast` uses the per-language models downloaded in System Settings or
///   from the app: quick enough to translate as you type, and light on power.
/// - `best` uses the Apple Intelligence models, which are already on a Mac
///   with Apple Intelligence turned on: more natural translations and every
///   language without a download, but each one takes a moment longer.
enum TranslationQuality: String, CaseIterable, Identifiable {
    case fast
    case best

    var id: Self { self }

    var title: String {
        switch self {
        case .fast: String(localized: "Fast")
        case .best: String(localized: "Best quality")
        }
    }

    /// The choice in Settings, whether or not it can take effect.
    static var chosen: TranslationQuality {
        UserDefaults.standard.string(forKey: SettingsKey.translationQuality)
            .flatMap(TranslationQuality.init(rawValue:)) ?? .fast
    }

    /// What translation actually uses: Best quality only counts where Apple
    /// Intelligence can provide it.
    static var effective: TranslationQuality {
        chosen == .best && isBestAvailable ? .best : .fast
    }

    /// Best quality needs the Translation framework's strategies (macOS 26.4)
    /// and Apple Intelligence turned on and ready.
    static var isBestAvailable: Bool {
        guard #available(macOS 26.4, iOS 26.4, *) else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    /// Why Best quality can't be chosen, or `nil` when it can.
    static var bestUnavailableReason: String? {
        #if os(macOS)
        guard #available(macOS 26.4, *) else {
            return String(localized: "Best quality needs macOS 26.4 or later.")
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return String(localized: "Best quality needs a Mac that supports Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return String(localized: "Best quality needs Apple Intelligence, which you can turn on in System Settings.")
        case .unavailable(.modelNotReady):
            return String(localized: "Best quality will be available once Apple Intelligence finishes setting up.")
        case .unavailable:
            return String(localized: "Best quality isn’t available on this Mac right now.")
        }
        #else
        guard #available(iOS 26.4, *) else {
            return String(localized: "Best quality needs iOS 26.4 or later.")
        }
        switch SystemLanguageModel.default.availability {
        case .available:
            return nil
        case .unavailable(.deviceNotEligible):
            return String(localized: "Best quality needs an iPhone that supports Apple Intelligence.")
        case .unavailable(.appleIntelligenceNotEnabled):
            return String(localized: "Best quality needs Apple Intelligence, which you can turn on in Settings.")
        case .unavailable(.modelNotReady):
            return String(localized: "Best quality will be available once Apple Intelligence finishes setting up.")
        case .unavailable:
            return String(localized: "Best quality isn’t available on this iPhone right now.")
        }
        #endif
    }

    @available(macOS 26.4, iOS 26.4, *)
    var strategy: TranslationSession.Strategy {
        switch self {
        case .fast: .lowLatency
        case .best: .highFidelity
        }
    }
}

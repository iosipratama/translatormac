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
    /// Intelligence can provide it, and with Pro or during the free days.
    /// A choice made during the free days is kept for when Pro is bought.
    static var effective: TranslationQuality {
        chosen == .best && isBestAvailable && isUnlocked ? .best : .fast
    }

    /// The app's purchases, registered at launch, so translation can check
    /// whether Best quality is unlocked wherever it starts. Reading it in a
    /// view also updates that view when access changes.
    static weak var purchases: PurchaseStore?

    /// Best quality is a Pro feature.
    static var isUnlocked: Bool {
        purchases?.access.unlocksPro ?? false
    }

    /// Best quality needs the Translation framework's strategies (macOS 26.4)
    /// and Apple Intelligence turned on and ready.
    static var isBestAvailable: Bool {
        if simulatesNoAppleIntelligence { return false }
        guard #available(macOS 26.4, iOS 26.4, *) else { return false }
        return SystemLanguageModel.default.isAvailable
    }

    /// Debug builds only: behave as on a device without Apple Intelligence.
    static var simulatesNoAppleIntelligence: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: SettingsKey.debugNoAppleIntelligence)
        #else
        false
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

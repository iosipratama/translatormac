//
//  TranslationFailure.swift
//  TranslatorMac
//

import Foundation
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// An error from the Translation framework, as the person should see it:
/// what happened and what to do next, with no codes or framework terms.
nonisolated struct TranslationFailure: Equatable {
    var message: String
    /// The pair just isn't downloaded, so the screen can offer to fetch it.
    var offersDownload: Bool

    /// `nil` when there's nothing worth showing, such as a superseded request.
    static func from(_ error: any Error, from source: Locale.Language?, to target: Locale.Language) -> TranslationFailure? {
        let targetName = LanguageCatalog.fallbackName(for: target)
        let sourceName = source.map(LanguageCatalog.fallbackName(for:))
            ?? String(localized: "the detected language")

        switch error {
        case is CancellationError:
            return nil

        case TranslationError.notInstalled:
            let message = source.map {
                String(localized: "\(LanguageCatalog.fallbackName(for: $0)) → \(targetName) isn’t downloaded yet.")
            } ?? String(localized: "\(targetName) isn’t downloaded yet.")
            return TranslationFailure(message: message, offersDownload: true)

        case TranslationError.unsupportedLanguagePairing:
            return TranslationFailure(
                message: String(localized: "Translation between \(sourceName) and \(targetName) isn’t available. Choose another language."),
                offersDownload: false
            )

        case TranslationError.unsupportedSourceLanguage:
            return TranslationFailure(
                message: String(localized: "Translating from \(sourceName) isn’t available. Choose another language."),
                offersDownload: false
            )

        case TranslationError.unsupportedTargetLanguage:
            return TranslationFailure(
                message: String(localized: "Translating into \(targetName) isn’t available. Choose another language."),
                offersDownload: false
            )

        case TranslationError.unableToIdentifyLanguage:
            return TranslationFailure(
                message: String(localized: "Couldn’t tell which language this is. Choose the language you’re translating from."),
                offersDownload: false
            )

        case TranslationError.nothingToTranslate:
            return TranslationFailure(
                message: String(localized: "There’s nothing to translate."),
                offersDownload: false
            )

        default:
            // The framework's own description can be technical; the person
            // gets a plain next step instead, and the log keeps the detail.
            return TranslationFailure(
                message: String(localized: "Try again, or try shorter text."),
                offersDownload: false
            )
        }
    }
}

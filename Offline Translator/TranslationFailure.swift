//
//  TranslationFailure.swift
//  TranslatorMac
//

import Foundation
// See LanguageCatalog.swift: the Translation framework is not yet
// Sendable-audited.
@preconcurrency import Translation

/// Maps errors thrown by the Translation framework onto messages worth showing.
///
/// The previous implementation funnelled every failure into "this language pair
/// is not downloaded yet", which sent people to System Settings to install a
/// model that, for an unsupported pairing, does not exist.
nonisolated enum TranslationFailure {

    static func message(for error: any Error, from source: Locale.Language?, to target: Locale.Language) -> String {
        let sourceName = source.map(LanguageCatalog.displayName(for:)) ?? "the detected language"
        let targetName = LanguageCatalog.displayName(for: target)

        switch error {
        case is CancellationError:
            return ""

        case TranslationError.notInstalled:
            return """
            The \(sourceName) → \(targetName) model isn't downloaded yet.

            Open System Settings → Translation Languages to download it.
            """

        case TranslationError.unsupportedLanguagePairing:
            return "Translating \(sourceName) to \(targetName) isn't supported."

        case TranslationError.unsupportedSourceLanguage:
            return "\(sourceName.prefix(1).uppercased() + sourceName.dropFirst()) isn't supported as a source language."

        case TranslationError.unsupportedTargetLanguage:
            return "\(targetName) isn't supported as a target language."

        case TranslationError.unableToIdentifyLanguage:
            return "Couldn't detect the language of that text. Choose a source language instead of Automatic."

        case TranslationError.nothingToTranslate:
            return "There's nothing to translate."

        default:
            return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

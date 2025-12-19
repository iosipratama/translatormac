//
//  AppleTranslator.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

/// A helper type for performing on-device text translations using the macOS Translation framework.
/// This enum provides utilities to translate text between supported languages without needing network access.

import Foundation
// Translation is the macOS framework that can translate on device level
// Available on macOS 26+ and performs on-device translation.
import Translation

@available(macOS 26.0, *)
// This enum namespaces translation utilities and is only available on macOS 26 or later.
enum AppleTranslator {
    
    // Custom error type for translation failures.
    // Implements LocalizedError to provide friendly, user-readable descriptions of errors.
    enum TranslateError: LocalizedError {
        case unavailableOS            // Error for when the OS version is too old to support translation.
        case unsupportedLanguage(String) // Error when the given language is not supported.
        case missingLanguageModel(source: String, target: String) // Error when required language models are not installed.
        case emptyInput              // Error when the input text is empty.
        case underlying(Error)       // Wraps other underlying errors that may occur.

        // Maps each error case to a human-readable message.
        var errorDescription: String? {
            switch self {
            case .unavailableOS:
                return "Translation requires macOS 26 or later."
            case .unsupportedLanguage(let name):
                return "Unsupported Language: \(name)"
            case .missingLanguageModel(let source, let target):
                return "Required on-device language models are not installed for \(source) → \(target)."
            case .emptyInput:
                return "Input text is empty."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    // Cleans up user input by trimming whitespace and lowercasing to match language names consistently.
    private static func normalizeLanguageKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /*
     Maps friendly language names or aliases to BCP-47 language identifiers.
     Extend this switch statement to support more languages as needed.
     */
    private static func languageIdentifier(for name: String) throws -> String {
        let key = normalizeLanguageKey(name)
        switch key {
        case "english", "en", "en-us", "en-gb": return "en"
        case "indonesian", "bahasa indonesia", "id": return "id"
        case "japanese", "ja": return "ja"
        case "german", "de": return "de"
        case "arabic", "ar": return "ar"
        default:
            throw TranslateError.unsupportedLanguage(name)
        }
    }

    // Converts a friendly language name into a Locale.Language instance used by the Translation APIs.
    private static func language(_ name: String) throws -> Locale.Language {
        let id = try languageIdentifier(for: name)
        return .init(identifier: id)
    }
    
    /**
     Translates the given text from a source language to a target language using on-device translation.
     
     - Parameters:
       - text: The text to translate.
       - from: The source language (name or alias).
       - to: The target language (name or alias).
     
     - Throws: `TranslateError` if input is invalid, languages are unsupported, models are missing, or other failures occur.
     - Returns: The translated text as a String.
     */
    static func translate(text: String, from: String, to: String) async throws -> String {
        // Trim whitespace and check that input is not empty.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }

        // Attempt to resolve source and target language names to Locale.Language instances.
        // This is wrapped in do/catch because resolving may fail if language is unsupported.
        let sourceLang: Locale.Language
        let targetLang: Locale.Language
        do {
            sourceLang = try language(from)
            targetLang = try language(to)
        } catch {
            throw error
        }

        // Create a TranslationSession assuming required language models are installed.
        // This initializer does not throw.
        let session = TranslationSession(installedSource: sourceLang, target: targetLang)

        do {
            // Perform the async translation request.
            let response = try await session.translate(trimmed)
            let translated = response.targetText
            // Return the translated text if not empty.
            if !translated.isEmpty {
                return translated
            }
            // If translation result is empty, throw an error for better feedback.
            throw TranslateError.underlying(NSError(domain: "AppleTranslator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty translation result"]))
        } catch {
            // Wrap any underlying errors in our TranslateError for better UI messages.
            if let tError = error as? TranslateError { throw tError }
            throw TranslateError.underlying(error)
        }
    }
    
}


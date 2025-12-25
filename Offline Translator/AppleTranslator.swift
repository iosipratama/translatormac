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
import NaturalLanguage

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
        case lowConfidenceDetection
        case sameSourceAndTarget

        // Maps each error case to a human-readable message.
        var errorDescription: String? {
            switch self {
            case .unavailableOS:
                return "Translation requires macOS 26 or later."
            case .unsupportedLanguage(let name):
                return "Unsupported Language: \(name)"
            case .missingLanguageModel(let source, let target):
                return """
                This \(AppleTranslator.displayName(forLanguageID: source)) → \(AppleTranslator.displayName(forLanguageID: target)) translation not downloaded yet.
                
                Open System Settings → search Translation Languages → download the language you want to use.
                """
            case .emptyInput:
                return "Input text is empty."
            case .lowConfidenceDetection:
                return "Unable to confidently detect the source language."
            case .sameSourceAndTarget:
                return "Source and target languages are the same."
            case .underlying(let error):
                return error.localizedDescription
            }
        }
    }

    // Cleans up user input by trimming whitespace and lowercasing to match language names consistently.
    private static func normalizeLanguageKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
    
    // Returns true when the provided language string indicates auto-detection.
    private static func isAutoSelection(_ value: String?) -> Bool {
        guard let v = value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { return true }
        return v == "auto" || v == "automatic" || v == "detect" || v == "auto-detect"
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
        case "french", "fr", "fr-fr", "fr-ca": return "fr"
        default:
            throw TranslateError.unsupportedLanguage(name)
        }
    }

    // Converts a friendly language name into a Locale.Language instance used by the Translation APIs.
    private static func language(_ name: String) throws -> Locale.Language {
        let id = try languageIdentifier(for: name)
        return .init(identifier: id)
    }
    
    // Detect language and also return its BCP-47 identifier for error reporting.
    private static func detectLanguageWithID(from text: String) -> (Locale.Language, String)? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let (lang, confidence) = hypotheses.first, confidence >= 0.4 else {
            return nil
        }
        let id = lang.rawValue
        return (Locale.Language(identifier: id), id)
    }
    
    // MARK: - Helpers for language auto detection
    private static func detectLanguage(from text: String) -> Locale.Language? {
        return detectLanguageWithID(from: text)?.0
    }

    // Returns a user-friendly display name for a BCP-47 language identifier (fallbacks to the id itself).
    private static func displayName(forLanguageID id: String) -> String {
        if let name = Locale.current.localizedString(forLanguageCode: id) {
            // Capitalize the first letter for consistency (e.g., "english" -> "English")
            return name.prefix(1).uppercased() + name.dropFirst()
        }
        return id
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
    static func translate(text: String, from: String?, to: String) async throws -> String {
        // Trim whitespace and check that input is not empty.
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslateError.emptyInput }
        
        var sourceID: String = ""
        let targetID: String = try languageIdentifier(for: to)
        
        let targetLang = Locale.Language(identifier: targetID)
        let sourceLang: Locale.Language
        if isAutoSelection(from) {
            guard let (detected, detectedID) = detectLanguageWithID(from: trimmed) else {
                throw TranslateError.lowConfidenceDetection
            }
            sourceLang = detected
            sourceID = detectedID
        } else {
            let provided = try languageIdentifier(for: from!)
            sourceID = provided
            sourceLang = Locale.Language(identifier: provided)
        }
        
        if sourceLang == targetLang {
            throw TranslateError.sameSourceAndTarget
        }

        let session = TranslationSession(installedSource: sourceLang, target: targetLang)
        do {
            let response = try await session.translate(trimmed)
            let translated = response.targetText
            guard !translated.isEmpty else {
                throw TranslateError.underlying(NSError(domain: "AppleTranslator", code: 2, userInfo: [NSLocalizedDescriptionKey: "Empty translation result"]))
            }
            return translated
        } catch {
            if let tError = error as? TranslateError { throw tError }
            // If the underlying error suggests models aren’t present, surface a clearer message.
            // We can’t directly introspect model presence here, so provide a targeted error.
            throw TranslateError.missingLanguageModel(source: sourceID, target: targetID)
        }
    }
    
    
}


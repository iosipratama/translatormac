//
//  AppleTranslator.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import Foundation
import Translation
// Translation is the macOS framework that can translate on device level

@available(macOS 26.0, *)
enum AppleTranslator {
    
    static func translate(text: String, from: String, to: String) async throws -> String {
        
        let source = try language(from)
        let target = try language(to)
        
        
        let session = TranslationSession(installedSource: source, target: target)
        
        // Perform the translation. `translate(_:)` returns a single Response object.
        let response = try await session.translate(text)

        // Use the translated target text (non-optional); provide a minimal fallback if unexpected.
        let translated = response.targetText
        if !translated.isEmpty {
            return translated
        }
        // Fallback: stringify the response if target text is unexpectedly empty.
        return String(describing: response)
        
    }
    
    // maps the language
    private static func language(_ name: String) throws -> Locale.Language {
        switch name {
        case "English": return .init(identifier: "en")
        case "Indonesian": return .init(identifier: "id")
        case "Japanese": return .init(identifier: "ja")
        case "German": return .init(identifier: "de")
        case "Arabic": return .init(identifier: "ar")
            
        default:
            
            throw NSError(domain: "AppleTranslator", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Unsupported Language: \(name)"
            ])
            
        }
    }
    
}


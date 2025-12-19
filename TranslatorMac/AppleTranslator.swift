//
//  AppleTranslator.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import Foundation
import Translation
// Translation is the macOS framework that can transalte on device level

@available(macOS 26.0, *)
enum AppleTranslator {
    
    static func translate(text: String, from: String, to: String) async throws -> String {
        
        let source = try language(from)
        let target = try language(to)
        
        
        let session = TranslationSession(installedSource: source, target:target)
        
        let response = try await session.translate(text)
        
        var result = ""
            for segment in response {
                result += segment.text
            }

            return result
        
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


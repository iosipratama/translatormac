//
//  SwiftTranslation.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 27/12/25.
//

import Foundation
import SwiftData

@Model
final class TranslationHistory {
    var sourceText: String
    var translatedText: String
    var sourceLanguage: String
    var targetLanguage: String
    var createdAt: Date
    
    init(
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        createdAt: Date
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdAt = createdAt
    }
}

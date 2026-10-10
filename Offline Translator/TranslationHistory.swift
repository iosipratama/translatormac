//
//  TranslationHistory.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 27/12/25.
//

import Foundation
import SwiftData

/// One translation the person made. Every record appears in Recent; starring
/// it also shows it in Saved.
@Model
final class TranslationHistory {
    // Every query sorts on createdAt, so index it.
    #Index<TranslationHistory>([\.createdAt])

    var sourceText: String
    var translatedText: String
    var sourceLanguage: String
    var targetLanguage: String
    var createdAt: Date

    /// Starred by the person. Defaults so records from earlier versions
    /// migrate without a schema step.
    var isSaved: Bool = false

    /// When it was starred; Saved sorts and labels by this. `nil` when not
    /// saved, or for entries saved before this was recorded.
    var savedAt: Date?

    init(
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        createdAt: Date = .now
    ) {
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.createdAt = createdAt
    }

    /// The date to show in Saved; entries starred before `savedAt` existed
    /// fall back to when they were made.
    var savedDate: Date { savedAt ?? createdAt }

    /// The stored languages as identifiers, whatever version wrote them.
    var sourceLanguageID: String { LanguageCatalog.normalizedIdentifier(sourceLanguage) }
    var targetLanguageID: String { LanguageCatalog.normalizedIdentifier(targetLanguage) }
}

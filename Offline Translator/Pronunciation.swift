//
//  Pronunciation.swift
//  TranslatorMac
//

import Foundation

/// Latin-script readings for translations into other scripts, so someone who
/// can't read Japanese or Thai can still say the translation out loud.
///
/// Everything here is CoreFoundation and runs on this Mac; nothing is sent
/// anywhere.
nonisolated enum Pronunciation {

    /// A reading of `text` in Latin letters, or `nil` when the language already
    /// uses Latin script or no transcription could be produced.
    static func latinTranscription(of text: String, in language: Locale.Language) -> String? {
        guard usesNonLatinScript(language) else { return nil }

        let locale = Locale(identifier: LanguageCatalog.identifier(for: language))
        let transcription = tokenizedTranscription(of: text, locale: locale) ?? transformed(text)

        guard let transcription else { return nil }
        let cleaned = tidy(transcription)
        guard !cleaned.isEmpty, cleaned != text else { return nil }
        return cleaned
    }

    /// Whether a language is normally written in something other than Latin
    /// script. The maximal identifier fills in the likely script, so "ja"
    /// resolves to Japanese script even though the catalog entry carries none.
    static func usesNonLatinScript(_ language: Locale.Language) -> Bool {
        let maximal = Locale.Language(identifier: language.maximalIdentifier)
        guard let script = maximal.script?.identifier else { return false }
        return script != "Latn"
    }

    // MARK: - Strategies

    /// Word-by-word transcription from the system tokenizer. This is the only
    /// route that reads Japanese kanji correctly: a plain transliteration
    /// treats every Han character as Mandarin and produces pinyin for Japanese.
    private static func tokenizedTranscription(of text: String, locale: Locale) -> String? {
        let cfText = text as CFString
        let length = CFStringGetLength(cfText)
        guard length > 0 else { return nil }

        let tokenizer = CFStringTokenizerCreate(
            kCFAllocatorDefault,
            cfText,
            CFRange(location: 0, length: length),
            kCFStringTokenizerUnitWordBoundary | kCFStringTokenizerAttributeLatinTranscription,
            locale as CFLocale
        )

        var output = ""
        var previousWasWord = false
        var transcribedAnything = false

        var tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        while tokenType != [] {
            let range = CFStringTokenizerGetCurrentTokenRange(tokenizer)
            let original = (CFStringCreateWithSubstring(nil, cfText, range) as String?) ?? ""

            let attribute = CFStringTokenizerCopyCurrentTokenAttribute(
                tokenizer,
                kCFStringTokenizerAttributeLatinTranscription
            )

            // Punctuation comes back as its own "reading"; only a reading with
            // letters in it counts as a word.
            if let latin = attribute as? String, latin.contains(where: { $0.isLetter || $0.isNumber }) {
                // Scripts like Japanese have no spaces between words, so put
                // one back between consecutive readings.
                if previousWasWord { output += " " }
                output += latin
                previousWasWord = true
                transcribedAnything = true
            } else {
                let isWord = original.contains { $0.isLetter || $0.isNumber }
                if isWord && previousWasWord { output += " " }
                output += original
                previousWasWord = isWord
            }

            tokenType = CFStringTokenizerAdvanceToNextToken(tokenizer)
        }

        return transcribedAnything ? output : nil
    }

    /// Whole-string transliteration. Good for alphabets such as Cyrillic,
    /// Greek, Arabic, Hebrew and Thai, where the tokenizer offers no reading.
    private static func transformed(_ text: String) -> String? {
        let mutable = NSMutableString(string: text)
        guard CFStringTransform(mutable, nil, kCFStringTransformToLatin, false) else { return nil }
        return mutable as String
    }

    // MARK: - Presentation

    /// Full-width punctuation that survives transcription, mapped to the Latin
    /// equivalent so the reading looks like a sentence rather than a mix.
    private static let punctuation: [Character: String] = [
        "。": ".", "｡": ".", "．": ".", "、": ",", "､": ",", "，": ",", "！": "!", "？": "?",
        "：": ":", "；": ";", "「": "“", "」": "”", "『": "“", "』": "”",
        "（": "(", "）": ")", "・": " ", "　": " ",
    ]

    private static func tidy(_ transcription: String) -> String {
        var result = ""
        result.reserveCapacity(transcription.count)
        for character in transcription {
            result += punctuation[character] ?? String(character)
        }

        // A space after sentence punctuation, and never more than one in a row.
        result = result.replacing(/([.,!?;:])(?=\S)/) { "\($0.output.1) " }
        result = result.replacing(/\s+/, with: " ")
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        return result.prefix(1).uppercased() + result.dropFirst()
    }
}

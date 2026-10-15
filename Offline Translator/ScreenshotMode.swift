//
//  ScreenshotMode.swift
//  TranslatorMac
//

import Foundation
import SwiftData

/// A Debug-only setup for App Store screenshots: launch with
/// `-screenshotMode YES` to unlock Pro, let the window shrink to 1000×587,
/// and fill Recent and Saved with a sample trip kept in memory, so the real
/// history is never touched. Release builds ignore the flag entirely.
///
/// `Scripts/screenshots/capture.sh` drives the whole capture.
enum ScreenshotMode {
    static var isEnabled: Bool {
        #if DEBUG
        UserDefaults.standard.bool(forKey: "screenshotMode")
        #else
        false
        #endif
    }

    /// An in-memory history filled with the sample trip, or `nil` when
    /// screenshot mode is off.
    @MainActor
    static func sampleContainer() throws -> ModelContainer? {
        #if DEBUG
        guard isEnabled else { return nil }
        let container = try ModelContainer(
            for: TranslationHistory.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        for sample in sampleTrip {
            let entry = TranslationHistory(
                sourceText: sample.text,
                translatedText: sample.translation,
                sourceLanguage: sample.source,
                targetLanguage: sample.target,
                createdAt: .now.addingTimeInterval(-sample.hoursAgo * 3600)
            )
            if sample.isSaved {
                entry.isSaved = true
                entry.savedAt = entry.createdAt
            }
            container.mainContext.insert(entry)
        }
        return container
        #else
        return nil
        #endif
    }

    #if DEBUG
    private struct Sample {
        var source: String
        var target: String
        var text: String
        var translation: String
        /// Relative to launch, so "12 min ago" and "yesterday" stay true.
        var hoursAgo: Double
        var isSaved = false
    }

    /// A week of travel, newest first: Kyoto today, Berlin and Paris before
    /// it. Translations come from Apple's on-device models, so they match
    /// what the app itself would show.
    private static let sampleTrip: [Sample] = [
        Sample(source: "en", target: "ja",
               text: "Could I leave my luggage at the front desk after checkout? My train to Osaka leaves at 4 p.m.",
               translation: "チェックアウト後、フロントに荷物を預けてもよろしいでしょうか？ 私の大阪行きの電車は午後4時に出発します。",
               hoursAgo: 0.2),
        Sample(source: "ja", target: "en",
               text: "朝食会場は2階のレストランです。営業時間は6時30分から10時までとなっております。",
               translation: "The breakfast venue is the restaurant on the second floor. Business hours are from 6:30 to 10:00.",
               hoursAgo: 1.4),
        Sample(source: "ja", target: "en",
               text: "診察のご予約は明日午前10時で承りました。保険証とお薬手帳をお持ちください。",
               translation: "Your appointment for the medical examination is accepted at 10 a.m. tomorrow. Please bring your insurance card and medication notebook.",
               hoursAgo: 11),
        Sample(source: "en", target: "ja",
               text: "Is there a pharmacy near here that's open late?",
               translation: "この近くに遅くまで営業している薬局はありますか？",
               hoursAgo: 20, isSaved: true),
        Sample(source: "en", target: "ja",
               text: "I'm allergic to shellfish. Does this dish contain any shrimp or crab?",
               translation: "私は甲殻類にアレルギーがあります。 この料理にはエビやカニが含まれていますか？",
               hoursAgo: 26, isSaved: true),
        Sample(source: "en", target: "ja",
               text: "Hi, I'm in room 1204 and the Wi-Fi hasn't worked since last night, so could someone please take a look before my video call tomorrow morning?",
               translation: "こんにちは、1204号室におりますが、昨晩からWi‐Fiが機能しておらず、明日の朝のビデオ通話の前にご確認いただけませんでしょうか？",
               hoursAgo: 49),
        Sample(source: "en", target: "ja",
               text: "Please take me to Kyoto Station, Hachijo exit.",
               translation: "京都駅の八条出口まで連れて行ってください。",
               hoursAgo: 51, isSaved: true),
        Sample(source: "ja", target: "en",
               text: "強風の影響により、電車に30分程度の遅れが出ております。",
               translation: "Due to strong winds, the train is delayed by about 30 minutes.",
               hoursAgo: 53),
        Sample(source: "de", target: "en",
               text: "Die Schlüsselbox befindet sich links neben der Haustür, der Code lautet 4721. Beim Auschecken werfen Sie den Schlüssel bitte einfach in den Briefkasten.",
               translation: "The key box is to the left of the front door, the code is 4721. When checking out, please simply throw the key in the mailbox.",
               hoursAgo: 98),
        Sample(source: "en", target: "de",
               text: "Is this ticket valid on the S-Bahn to the airport, or do I need to buy a separate one?",
               translation: "Ist dieses Ticket mit der S-Bahn zum Flughafen gültig oder muss ich ein separates kaufen?",
               hoursAgo: 100, isSaved: true),
        Sample(source: "de", target: "en",
               text: "Bitte trennen Sie den Müll: Papier in die blaue Tonne, Verpackungen in die gelbe Tonne.",
               translation: "Please separate the garbage: paper in the blue bin, packaging in the yellow bin.",
               hoursAgo: 122),
        Sample(source: "fr", target: "en",
               text: "En raison d'une grève, le trafic sera fortement perturbé sur la ligne RER B ce jeudi.",
               translation: "Due to a strike, traffic will be severely disrupted on the RER B line this Thursday.",
               hoursAgo: 146),
        Sample(source: "en", target: "fr",
               text: "Could we have a table for two on the terrace at around 8 tonight?",
               translation: "Pourrions-nous avoir une table pour deux sur la terrasse vers 20 heures ce soir ?",
               hoursAgo: 150, isSaved: true),
    ]
    #endif
}

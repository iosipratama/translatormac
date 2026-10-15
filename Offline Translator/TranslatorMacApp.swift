//
//  TranslatorMacApp.swift
//  TranslatorMac
//
//  Created by Iosi Pratama on 19/12/25.
//

import SwiftUI
import SwiftData

@main
struct TranslatorMacApp: App {

    @Environment(\.openWindow) private var openWindow

    @State private var purchases = PurchaseStore()
    @State private var pro = ProPresentation()

    /// Read once at launch: it decides which window opens first. The flow
    /// itself updates the stored value when it finishes.
    private let didFinishOnboarding: Bool

    /// One container shared by every scene. Scene modifiers do not cascade to
    /// sibling scenes, so applying `.modelContainer(for:)` per scene would build
    /// separate containers over the same store.
    private let modelContainer: ModelContainer

    init() {
        SettingsKey.registerDefaults()
        AppTheme.stored.apply()
        didFinishOnboarding = OnboardingModel.didFinish
        do {
            modelContainer = try ModelContainer(for: TranslationHistory.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            let seed: [(String, String, String, String, Double, Bool)] = [
                ("en", "ja", "Could I leave my luggage at the front desk after checkout? My train to Osaka leaves at 4 p.m.", "チェックアウト後、フロントに荷物を預けてもよろしいでしょうか？ 私の大阪行きの電車は午後4時に出発します。", 0.2, false),
                ("ja", "en", "朝食会場は2階のレストランです。営業時間は6時30分から10時までとなっております。", "The breakfast venue is the restaurant on the second floor. Business hours are from 6:30 to 10:00.", 1.4, false),
                ("ja", "en", "診察のご予約は明日午前10時で承りました。保険証とお薬手帳をお持ちください。", "Your appointment for the medical examination is accepted at 10 a.m. tomorrow. Please bring your insurance card and medication notebook.", 11, false),
                ("en", "ja", "Is there a pharmacy near here that's open late?", "この近くに遅くまで営業している薬局はありますか？", 20, true),
                ("en", "ja", "I'm allergic to shellfish. Does this dish contain any shrimp or crab?", "私は甲殻類にアレルギーがあります。 この料理にはエビやカニが含まれていますか？", 26, true),
                ("en", "ja", "Hi, I'm in room 1204 and the Wi-Fi hasn't worked since last night, so could someone please take a look before my video call tomorrow morning?", "こんにちは、1204号室におりますが、昨晩からWi‐Fiが機能しておらず、明日の朝のビデオ通話の前にご確認いただけませんでしょうか？", 49, false),
                ("en", "ja", "Please take me to Kyoto Station, Hachijo exit.", "京都駅の八条出口まで連れて行ってください。", 51, true),
                ("ja", "en", "強風の影響により、電車に30分程度の遅れが出ております。", "Due to strong winds, the train is delayed by about 30 minutes.", 53, false),
                ("ja", "en", "チェックインは15時以降となります。玄関の暗証番号は当日の朝にお送りします。", "Check-in is after 15:00. The PIN number of the entrance will be sent to you on the morning of the day.", 74, false),
                ("en", "id", "I'm arriving in Bali on Saturday evening. Could you arrange a driver to pick me up at the airport?", "Saya akan tiba di Bali pada Sabtu malam. Bisakah Anda mengatur sopir untuk menjemput saya di bandara?", 76, false),
                ("en", "ja", "Thank you for a wonderful stay. We'd love to come back next spring.", "素晴らしい滞在をありがとうございました。 来春、ぜひまた伺いたいです。", 98, false),
            ]
            for (source, target, text, translation, hoursAgo, saved) in seed {
                let entry = TranslationHistory(sourceText: text, translatedText: translation, sourceLanguage: source, targetLanguage: target, createdAt: .now.addingTimeInterval(-hoursAgo * 3600))
                entry.isSaved = saved
                if saved { entry.savedAt = entry.createdAt }
                modelContainer.mainContext.insert(entry)
            }
        } catch {
            fatalError("Failed to open the translation history store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            MainWindow(modelContext: modelContainer.mainContext, purchases: purchases)
        }
        .modelContainer(modelContainer)
        .environment(purchases)
        .environment(pro)
        .defaultSize(width: 1000, height: 660)
        // On a first launch the welcome window opens instead; it opens this
        // one when it's done.
        .defaultLaunchBehavior(didFinishOnboarding ? .automatic : .suppressed)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Translate Offline") {
                    openWindow(id: "about")
                }
            }
            AppMenuCommands(purchases: purchases, pro: pro)

            SidebarCommands()
            NavigationCommands()
            TranslationCommands()
            HelpCommands()
        }

        Settings {
            SettingsView()
        }
        .modelContainer(modelContainer)
        .environment(purchases)
        .environment(pro)
        .windowResizability(.contentSize)

        Window("Welcome", id: "onboarding") {
            OnboardingWindow()
        }
        .environment(purchases)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(didFinishOnboarding ? .suppressed : .presented)

        Window("About Translate Offline", id: "about") {
            AboutView()
        }
        .modelContainer(modelContainer)
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
    }
}

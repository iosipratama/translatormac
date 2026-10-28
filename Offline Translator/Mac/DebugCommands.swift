//
//  DebugCommands.swift
//  TranslatorMac
//

#if DEBUG
import SwiftUI

/// A Debug menu in the menu bar, in debug builds only, for trying every
/// plan, day and screen of the Free and Pro model without waiting days or
/// buying anything. Release builds don't have it at all.
struct DebugCommands: Commands {
    var purchases: PurchaseStore
    var pro: ProPresentation
    var reviews: ReviewPrompter

    @Environment(\.openWindow) private var openWindow
    @AppStorage(SettingsKey.debugNoAppleIntelligence) private var simulatesNoAppleIntelligence = false

    /// Days worth jumping to: the free days, the first day after, and later.
    private let days = [1, 2, 3, 4, 5, 10]

    var body: some Commands {
        CommandMenu("Debug") {
            Text(status)

            Divider()

            Menu("Scenario") {
                ForEach(DebugScenario.allCases) { scenario in
                    Button(scenario.title) {
                        showMainWindow()
                        scenario.apply(to: purchases, reviews: reviews)
                    }
                }
            }

            Divider()

            Picker("Plan", selection: Binding(get: { purchases.debugPlan }, set: { purchases.debugPlan = $0 })) {
                ForEach(PurchaseStore.DebugPlan.allCases) { plan in
                    Text(plan.title).tag(plan)
                }
            }

            Picker("Pretend Today Is", selection: Binding(get: { purchases.debugDay }, set: { purchases.setDebugDay($0) })) {
                ForEach(days, id: \.self) { day in
                    Text(dayTitle(day)).tag(day)
                }
            }

            Button("Restart Free Days From Today") {
                purchases.restartFreeAccess()
            }

            Divider()

            Button("Show Upgrade Screen") {
                showMainWindow()
                pro.present()
            }
            .keyboardShortcut("u", modifiers: [.command, .option, .control])

            Button("Show “Free Days End Today” Notice") {
                showMainWindow()
                purchases.replayFreeAccessNotice(ended: false)
            }

            Button("Show “Free Days Have Ended” Notice") {
                showMainWindow()
                purchases.replayFreeAccessNotice(ended: true)
            }

            Button("Replay Onboarding") {
                openWindow(id: "onboarding")
            }

            Divider()

            Menu("Free Translations Today") {
                Button("Use Them All Up") {
                    purchases.setRemainingFreeTranslations(0)
                }
                Button("Leave One") {
                    purchases.setRemainingFreeTranslations(1)
                }
                Button("Reset to \(PlanLimits.freeTranslationsPerDay)") {
                    purchases.setRemainingFreeTranslations(PlanLimits.freeTranslationsPerDay)
                }
            }

            Toggle("Simulate No Apple Intelligence", isOn: $simulatesNoAppleIntelligence)

            Divider()

            Button("Request a Rating Now") {
                showMainWindow()
                reviews.requestNow()
            }

            Button("Reset Rating Prompt") {
                reviews.reset()
            }

            Divider()

            Button("Reset Debug Settings") {
                purchases.resetDebugOverrides()
            }
        }
    }

    /// What the app thinks right now, at the top of the menu.
    private var status: String {
        let access = switch purchases.access {
        case .pro: "Pro"
        case .freeAccess: "Free days"
        case .free: "Free, \(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay) left"
        }
        return "\(access) · Day \(purchases.debugDay) · \(reviews.finishedTranslations) finished"
    }

    private func dayTitle(_ day: Int) -> String {
        switch day {
        case 1: "Day 1 (first launch)"
        case PlanLimits.freeAccessDays: "Day \(day) (last free day)"
        case PlanLimits.freeAccessDays + 1: "Day \(day) (free plan starts)"
        default: "Day \(day)"
        }
    }

    /// The upgrade screen, the notice and the rating request all show over
    /// the main window.
    private func showMainWindow() {
        if !MainWindowAccess.bringForward() {
            openWindow(id: "main")
        }
    }
}
#endif

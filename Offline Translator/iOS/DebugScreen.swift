//
//  DebugScreen.swift
//  TranslatorMac
//

#if DEBUG
import SwiftUI

/// Settings › Debug, in debug builds only: tools for trying the app as a
/// different kind of user.
struct DebugScreen: View {
    var replayOnboarding: () -> Void

    @Environment(PurchaseStore.self) private var purchases
    @Environment(ProPresentation.self) private var pro
    @Environment(ReviewPrompter.self) private var reviews
    @AppStorage(SettingsKey.debugNoAppleIntelligence) private var simulatesNoAppleIntelligence = false

    /// Days worth jumping to: the free days, the first day after, and later.
    private let days = [1, 2, 3, 4, 5, 10]

    var body: some View {
        @Bindable var purchases = purchases

        Form {
            Section {
                Picker("Plan", selection: $purchases.debugPlan) {
                    ForEach(PurchaseStore.DebugPlan.allCases) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Plan")
            } footer: {
                Text("Overrides what the App Store says, everywhere in the app. Now: \(status).")
            }

            Section {
                Picker("Pretend today is", selection: Binding(get: { purchases.debugDay }, set: { purchases.setDebugDay($0) })) {
                    ForEach(days, id: \.self) { day in
                        Text(dayTitle(day)).tag(day)
                    }
                }
                Button("Restart Free Days From Today") {
                    purchases.restartFreeAccess()
                }
            } header: {
                Text("Free days")
            }

            Section {
                Button("Show Upgrade Screen") {
                    pro.present()
                }
                Button("Show “Free Days End Today” Notice") {
                    purchases.replayFreeAccessNotice(ended: false)
                }
                Button("Show “Free Days Have Ended” Notice") {
                    purchases.replayFreeAccessNotice(ended: true)
                }
            } header: {
                Text("Screens")
            } footer: {
                Text("The notices go by the App Store plan, since they never show for Pro.")
            }

            Section {
                Button("Use Up Today’s Free Translations") {
                    purchases.setRemainingFreeTranslations(0)
                }
                Button("Leave One Free Translation") {
                    purchases.setRemainingFreeTranslations(1)
                }
                Button("Reset to \(PlanLimits.freeTranslationsPerDay)") {
                    purchases.setRemainingFreeTranslations(PlanLimits.freeTranslationsPerDay)
                }
            } header: {
                Text("Free translations today")
            }

            Section {
                Toggle("Simulate No Apple Intelligence", isOn: $simulatesNoAppleIntelligence)
                    .tint(.green)
                Button("Request a Rating Now") {
                    reviews.requestNow()
                }
                Button("Reset Rating Prompt") {
                    reviews.reset()
                }
                Button("Reset Debug Settings", role: .destructive) {
                    purchases.resetDebugOverrides()
                }
            } header: {
                Text("Other")
            } footer: {
                Text("\(reviews.finishedTranslations) finished translations counted for the rating prompt.")
            }

            Section {
                Button("Replay Onboarding", action: replayOnboarding)
            } footer: {
                Text("Opens the first-launch flow again, as a new user would see it.")
            }
        }
        .listRowBackground(Color.surface)
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .navigationTitle("Debug")
        .toolbarTitleDisplayMode(.inline)
    }

    private var status: String {
        let access = switch purchases.access {
        case .pro: "Pro"
        case .freeAccess: "Free days"
        case .free: "Free, \(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay) left"
        }
        return "\(access), day \(purchases.debugDay)"
    }

    private func dayTitle(_ day: Int) -> String {
        switch day {
        case 1: "Day 1 (first launch)"
        case PlanLimits.freeAccessDays: "Day \(day) (last free day)"
        case PlanLimits.freeAccessDays + 1: "Day \(day) (free plan starts)"
        default: "Day \(day)"
        }
    }
}
#endif

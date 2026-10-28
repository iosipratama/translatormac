//
//  DebugScreen.swift
//  TranslatorMac
//

#if DEBUG
import SwiftUI

/// Settings › Debug, in debug builds only: one-tap scenarios for every
/// kind of user, what the app thinks right now, and the individual
/// switches behind them.
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
            Section("Right now") {
                LabeledContent("Access", value: accessDescription)
                LabeledContent("Day", value: dayDescription)
                LabeledContent("Free translations left", value: "\(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay)")
                LabeledContent("Free days notice", value: purchases.debugNoticeShown ? "Seen" : "Not seen yet")
                LabeledContent("Best quality", value: TranslationQuality.isBestAvailable ? "Available" : "Not on this device")
                LabeledContent("Finished translations", value: "\(reviews.finishedTranslations)")
            }

            Section {
                ForEach(DebugScenario.allCases) { scenario in
                    Button {
                        scenario.apply(to: purchases, reviews: reviews)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(scenario.title)
                                .foregroundStyle(.textPrimary)
                            Text(scenario.expectation)
                                .font(.footnote)
                                .foregroundStyle(.textMuted)
                        }
                    }
                }
            } header: {
                Text("Scenarios")
            } footer: {
                Text("Each sets the plan, the day, today’s count and the notice together. Then go back and try the app.")
            }

            Section {
                Picker("Plan", selection: $purchases.debugPlan) {
                    ForEach(PurchaseStore.DebugPlan.allCases) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                Picker("Pretend today is", selection: Binding(get: { purchases.debugDay }, set: { purchases.setDebugDay($0) })) {
                    ForEach(days, id: \.self) { day in
                        Text(dayTitle(day)).tag(day)
                    }
                }
                Button("Restart Free Days From Today") {
                    purchases.restartFreeAccess()
                }
            } header: {
                Text("Plan and day")
            } footer: {
                Text("“From App Store” counts test purchases made with the StoreKit file. “Not Bought” ignores them.")
            }

            Section("Free translations today") {
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

            Section("Screens") {
                Button("Show Upgrade Screen") {
                    pro.present()
                }
                Button("Show “Free Days End Today” Notice") {
                    purchases.replayFreeAccessNotice(ended: false)
                }
                Button("Show “Free Days Have Ended” Notice") {
                    purchases.replayFreeAccessNotice(ended: true)
                }
                Button("Replay Onboarding", action: replayOnboarding)
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
            } header: {
                Text("Other")
            } footer: {
                Text("Without Apple Intelligence, the Quality setting and the Best quality line on the upgrade screen disappear.")
            }

            Section {
                Button("Reset Debug Settings", role: .destructive) {
                    purchases.resetDebugOverrides()
                }
            } footer: {
                Text("Back to what the App Store and the clock say.")
            }
        }
        .listRowBackground(Color.surface)
        .scrollContentBackground(.hidden)
        .background(.canvas)
        .navigationTitle("Debug")
        .toolbarTitleDisplayMode(.inline)
    }

    private var accessDescription: String {
        switch purchases.access {
        case .pro: purchases.isEarlySupporter && !purchases.ownsPro ? "Pro (earlier buyer)" : "Pro"
        case .freeAccess: "Free days"
        case .free: "Free plan"
        }
    }

    private var dayDescription: String {
        let day = purchases.debugDay
        let end = purchases.freeAccess.end().addingTimeInterval(-1)
        return "\(day) · free days through \(end.formatted(.dateTime.weekday().month().day()))"
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

//
//  ProDebugControls.swift
//  TranslatorMac
//

#if DEBUG
import SwiftUI

/// Settings › Pro, debug builds only: try each plan, later days and a Mac
/// without Apple Intelligence without waiting or changing Macs. The Debug
/// menu has these and more.
struct ProDebugControls: View {
    @Environment(PurchaseStore.self) private var purchases
    @AppStorage(SettingsKey.debugNoAppleIntelligence) private var simulatesNoAppleIntelligence = false

    var body: some View {
        @Bindable var purchases = purchases

        GroupBox("Debug") {
            Form {
                Picker("Plan:", selection: $purchases.debugPlan) {
                    ForEach(PurchaseStore.DebugPlan.allCases) { plan in
                        Text(plan.title).tag(plan)
                    }
                }
                .fixedSize()

                LabeledContent("Today is:") {
                    Stepper(value: $purchases.debugDayOffset, in: -30...30) {
                        Text("Day \(dayNumber) · \(purchases.now, format: .dateTime.day().month())")
                            .monospacedDigit()
                    }
                }

                LabeledContent("Access:") {
                    Text(accessDescription)
                }

                LabeledContent("Free days:") {
                    Button("Start Again From Today") {
                        purchases.restartFreeAccess()
                    }
                }

                Toggle("Simulate no Apple Intelligence", isOn: $simulatesNoAppleIntelligence)
            }
            .formStyle(.columns)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.callout)
    }

    /// Which day since the first launch the app thinks it is, from 1.
    private var dayNumber: Int {
        purchases.freeAccess.day(on: purchases.now)
    }

    private var accessDescription: String {
        switch purchases.access {
        case .pro:
            "Pro"
        case .freeAccess(let end):
            "Free days, until \(end.formatted(date: .abbreviated, time: .shortened))"
        case .free:
            "Free, \(purchases.remainingFreeTranslations) of \(PlanLimits.freeTranslationsPerDay) left today"
        }
    }
}
#endif

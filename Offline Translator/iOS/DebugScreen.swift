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
                Text("Overrides what the App Store says, everywhere in the app. Currently \(purchases.hasPro ? "Pro" : "Free").")
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
}
#endif

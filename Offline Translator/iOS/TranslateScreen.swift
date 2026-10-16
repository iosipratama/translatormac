//
//  TranslateScreen.swift
//  TranslatorMac
//

import SwiftUI

/// The root screen: type, speak or point the camera, and read the
/// translation. Library and Settings push from its toolbar.
struct TranslateScreen: View {
    var model: TranslationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Translate")
                .font(.title.bold())
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.canvas)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink(value: AppRoute.library) {
                    Label("Library", systemImage: "bookmark")
                }
                NavigationLink(value: AppRoute.settings) {
                    Label("Settings", systemImage: "slider.horizontal.3")
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

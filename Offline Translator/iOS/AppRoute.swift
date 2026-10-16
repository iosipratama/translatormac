//
//  AppRoute.swift
//  TranslatorMac
//

import Foundation

/// The screens pushed onto the iPhone app's one navigation stack, above
/// Translate at its root.
enum AppRoute: Hashable {
    /// Library on a given tab, or on the one used last when `nil`.
    case library(LibraryTab?)
    case settings
}

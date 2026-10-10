//
//  AppLinks.swift
//  TranslatorMac
//

import Foundation

/// Where the app sends people outside itself.
enum AppLinks {
    static let website = URL(string: "https://www.mekarya.studio")!
    /// Apple's standard licence, which the App Store applies when an app
    /// provides none of its own.
    static let termsOfUse = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicy = URL(string: "https://www.mekarya.studio/privacy")!
    static let manageSubscriptions = URL(string: "https://apps.apple.com/account/subscriptions")!
}

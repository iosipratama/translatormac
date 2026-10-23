//
//  FirstLaunchRecord.swift
//  TranslatorMac
//

import Foundation
import Security
import os

/// When this app was first opened on this device, which starts the free
/// days.
///
/// Kept in the Keychain so deleting and reinstalling the app doesn't start
/// them again, and never synced: it stays on this device and goes nowhere
/// else. A copy in UserDefaults covers a Keychain that can't be written,
/// and the earlier of the two wins.
enum FirstLaunchRecord {
    private static let service = "iosipratama.TranslatorMac.firstLaunch"
    private static let account = "firstLaunch"
    private static let defaultsKey = "firstLaunchDate"

    /// The recorded date, recording `now` if there's none yet.
    static func date(recordingIfNeeded now: Date = .now) -> Date {
        let stored = [readKeychain(), UserDefaults.standard.object(forKey: defaultsKey) as? Date]
            .compactMap { $0 }
            .min()
        let date = stored ?? now
        write(date)
        return date
    }

    #if DEBUG
    /// Debug builds only: start the free days again from `date`.
    static func reset(to date: Date) {
        deleteKeychain()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        write(date)
    }
    #endif

    // MARK: - Storage

    private static func write(_ date: Date) {
        UserDefaults.standard.set(date, forKey: defaultsKey)
        guard readKeychain() != date else { return }

        let data = Data(String(date.timeIntervalSince1970).utf8)
        let update = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData: data] as CFDictionary)
        guard update == errSecItemNotFound else {
            logFailure(update, "update")
            return
        }
        var item = baseQuery
        item[kSecValueData] = data
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        logFailure(SecItemAdd(item as CFDictionary, nil), "add")
    }

    private static func readKeychain() -> Date? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let seconds = TimeInterval(String(decoding: data, as: UTF8.self)) else {
            if status != errSecItemNotFound { logFailure(status, "read") }
            return nil
        }
        return Date(timeIntervalSince1970: seconds)
    }

    #if DEBUG
    private static func deleteKeychain() {
        SecItemDelete(baseQuery as CFDictionary)
    }
    #endif

    private static var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrSynchronizable: false,
            kSecUseDataProtectionKeychain: true,
        ]
    }

    private static func logFailure(_ status: OSStatus, _ operation: StaticString) {
        guard status != errSecSuccess else { return }
        Log.purchases.error("Keychain \(operation, privacy: .public) of the first launch failed: \(status)")
    }
}

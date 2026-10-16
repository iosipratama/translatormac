//
//  NetworkMonitor.swift
//  TranslatorMac
//

import Foundation
import Network

/// Whether this Mac can reach the internet right now. Only the first-launch
/// flow needs it, to explain why a download can't start.
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isOnline = path.status == .satisfied
            Task { @MainActor in self?.isOnline = isOnline }
        }
        monitor.start(queue: DispatchQueue(label: "network-monitor"))
    }

    deinit {
        monitor.cancel()
    }
}

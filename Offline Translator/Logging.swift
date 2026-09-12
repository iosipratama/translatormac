//
//  Logging.swift
//  TranslatorMac
//

import os

/// Shared loggers. Using `Logger` rather than `print` keeps diagnostics out of
/// stdout in release builds while remaining inspectable in Console.
enum Log {
    static let translation = Logger(subsystem: "iosipratama.TranslatorMac", category: "translation")
    static let history = Logger(subsystem: "iosipratama.TranslatorMac", category: "history")
}

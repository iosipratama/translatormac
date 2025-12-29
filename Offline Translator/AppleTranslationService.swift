import Foundation

// Plain service to isolate translation work and error mapping
struct AppleTranslationService {
    enum ServiceError: Error, LocalizedError {
        case unsupportedOS
        case underlying(Error)

        var errorDescription: String? {
            switch self {
            case .unsupportedOS:
                return "Translation requires macOS 26 or newer."
            case .underlying(let error):
                return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    // Keeps business logic out of SwiftUI views
    func translate(_ text: String, from: String, to: String) async throws -> String {
        guard #available(macOS 26.0, *) else {
            throw ServiceError.unsupportedOS
        }
        do {
            // Delegate to AppleTranslator; service keeps the view clean and testable
            return try await AppleTranslator.translate(text: text, from: from, to: to)
        } catch {
            throw ServiceError.underlying(error)
        }
    }
}

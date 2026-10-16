//
//  CameraText.swift
//  TranslatorMac
//

import UIKit
import Vision

/// One line of text found in a photo, where it sits, and its translation.
struct CameraLine: Identifiable, Hashable, Sendable {
    var id: Int
    var text: String
    /// In the photo's own pixels, origin at the top left.
    var center: CGPoint
    var width: CGFloat
    var height: CGFloat
    /// The line's tilt, in radians, so its label can follow it.
    var angle: CGFloat
    var translation: String?
}

/// Finds the lines of text in a photo with Vision, on this iPhone.
nonisolated enum CameraTextReader {

    /// Whether Vision can read text in this language at all.
    static func canRead(_ language: Locale.Language) -> Bool {
        guard let code = language.languageCode?.identifier else { return false }
        return RecognizeTextRequest().supportedRecognitionLanguages.contains {
            $0.languageCode?.identifier == code
                && (language.script == nil || $0.script == nil || $0.script == language.script)
        }
    }

    /// Every line of text in `image`, top to bottom.
    static func lines(in image: CGImage, language: Locale.Language) async throws -> [CameraLine] {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = [language]

        let size = CGSize(width: image.width, height: image.height)
        let observations = try await request.perform(on: image)

        let lines = observations.compactMap { observation -> CameraLine? in
            guard let text = observation.topCandidates(1).first?.string
                .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
            let topLeft = observation.topLeft.toImageCoordinates(size, origin: .upperLeft)
            let topRight = observation.topRight.toImageCoordinates(size, origin: .upperLeft)
            let bottomLeft = observation.bottomLeft.toImageCoordinates(size, origin: .upperLeft)
            let bottomRight = observation.bottomRight.toImageCoordinates(size, origin: .upperLeft)
            return CameraLine(
                id: 0,
                text: text,
                center: CGPoint(
                    x: (topLeft.x + topRight.x + bottomLeft.x + bottomRight.x) / 4,
                    y: (topLeft.y + topRight.y + bottomLeft.y + bottomRight.y) / 4
                ),
                width: hypot(topRight.x - topLeft.x, topRight.y - topLeft.y),
                height: hypot(bottomLeft.x - topLeft.x, bottomLeft.y - topLeft.y),
                angle: atan2(topRight.y - topLeft.y, topRight.x - topLeft.x)
            )
        }
        return lines
            .sorted { $0.center.y < $1.center.y }
            .enumerated()
            .map { index, line in
                var line = line
                line.id = index
                return line
            }
    }
}

extension UIImage {
    /// The image redrawn upright, so pixel coordinates match what's on screen.
    func uprightCGImage() -> CGImage? {
        if imageOrientation == .up, let cgImage { return cgImage }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: pixelSize))
        }.cgImage
    }
}

//
//  CameraViewfinder.swift
//  TranslatorMac
//

import AVFoundation
import SwiftUI
import VisionKit

/// The live picture: VisionKit's scanner, highlighting text in `language`,
/// or a plain preview where live scanning isn't supported.
struct CameraViewfinder: View {
    var feed: CameraFeed
    var language: Locale.Language

    var body: some View {
        if CameraFeed.scansLive {
            LiveTextScanner(feed: feed, language: language)
                // The recognized languages are fixed when the scanner is
                // made, so a new language needs a new scanner.
                .id(LanguageCatalog.identifier(for: language))
        } else {
            PlainCameraPreview(session: feed.plainSession)
        }
    }
}

/// VisionKit's `DataScannerViewController`, with its own text highlights.
private struct LiveTextScanner: UIViewControllerRepresentable {
    var feed: CameraFeed
    var language: Locale.Language

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text(languages: [LanguageCatalog.identifier(for: language)])],
            qualityLevel: .accurate,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        feed.scanner = scanner
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        feed.scanner = scanner
        if !scanner.isScanning {
            try? scanner.startScanning()
        }
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(feed: feed)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let feed: CameraFeed

        init(feed: CameraFeed) {
            self.feed = feed
        }

        func dataScanner(_ scanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            feed.visibleTextCount = allItems.count
        }

        func dataScanner(_ scanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            feed.visibleTextCount = allItems.count
        }
    }
}

/// A plain camera preview filling its space.
private struct PlainCameraPreview: UIViewRepresentable {
    var session: PlainCameraSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session.session
        view.previewLayer.videoGravity = .resizeAspectFill
        session.start()
        return view
    }

    // The camera screen stops the session when it closes, off the main
    // thread as AVFoundation asks.
    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

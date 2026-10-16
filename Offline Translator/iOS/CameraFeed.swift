//
//  CameraFeed.swift
//  TranslatorMac
//

import AVFoundation
import UIKit
import VisionKit

/// The live camera behind the viewfinder, and the one way to take a photo
/// from it.
///
/// Where Live Text scanning is supported, VisionKit's scanner runs the feed
/// and highlights text as it's found. Elsewhere — older iPhones, and the
/// simulator — a plain capture session stands in, so the camera still works;
/// it just can't point out text before the shutter.
@Observable
final class CameraFeed {

    enum Access {
        case notAsked
        case granted
        case denied
    }

    /// Whether this device runs VisionKit's live text scanner.
    static var scansLive: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private(set) var access: Access = CameraFeed.currentAccess

    /// How many pieces of text the scanner sees right now; always 0 without
    /// live scanning.
    var visibleTextCount = 0

    private(set) var isTorchOn = false

    /// Set by whichever view is showing the feed.
    weak var scanner: DataScannerViewController?
    let plainSession = PlainCameraSession()

    private static var currentAccess: Access {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    func requestAccess() async {
        if access == .notAsked {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        access = Self.currentAccess
    }

    func refreshAccess() {
        access = Self.currentAccess
    }

    // MARK: - Capture

    /// A photo from the live feed, upright.
    func capturePhoto() async throws -> UIImage {
        if let scanner {
            return try await scanner.capturePhoto()
        }
        return try await plainSession.capturePhoto()
    }

    // MARK: - Torch

    var hasTorch: Bool {
        AVCaptureDevice.default(for: .video)?.hasTorch ?? false
    }

    func toggleTorch() {
        setTorch(!isTorchOn)
    }

    func setTorch(_ isOn: Bool) {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = isOn ? .on : .off
            device.unlockForConfiguration()
            isTorchOn = isOn
        } catch {
            isTorchOn = false
        }
    }
}

/// A plain back-camera session with photo capture, for devices without live
/// text scanning.
///
/// The session runs on its own queue, as AVFoundation asks; everything it
/// touches is confined to that queue or set up before it starts.
nonisolated final class PlainCameraSession: NSObject, @unchecked Sendable, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "camera.session")
    private var isConfigured = false
    private var pending: CheckedContinuation<UIImage, any Error>?

    func start() {
        queue.async { [self] in
            if !isConfigured { configure() }
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [self] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() {
        isConfigured = true
        session.beginConfiguration()
        session.sessionPreset = .photo
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            ?? AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        session.commitConfiguration()
    }

    func capturePhoto() async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                guard session.isRunning, pending == nil else {
                    continuation.resume(throwing: CameraError.unavailable)
                    return
                }
                pending = continuation
                output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        let data = photo.fileDataRepresentation()
        queue.async { [self] in
            let continuation = pending
            pending = nil
            if let data, let image = UIImage(data: data) {
                continuation?.resume(returning: image)
            } else {
                continuation?.resume(throwing: error ?? CameraError.unavailable)
            }
        }
    }
}

enum CameraError: Error {
    case unavailable
}

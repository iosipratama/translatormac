// Captures every on-screen window of one app — the main window plus any open
// menu — as a single PNG on a transparent background, keeping the window's
// rounded corners and leaving out shadows.
//
// usage: WindowShot <pid> <out.png>
import AppKit
import ScreenCaptureKit

let pid = pid_t(CommandLine.arguments[1])!
let out = URL(fileURLWithPath: CommandLine.arguments[2])

let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
let windows = content.windows.filter {
    $0.owningApplication?.processID == pid && $0.isOnScreen && $0.frame.width > 20
}
guard !windows.isEmpty,
      let display = content.displays.first(where: { d in windows.contains { d.frame.intersects($0.frame) } })
else { fatalError("No windows on screen for process \(pid)") }

let bounds = windows.map(\.frame).reduce(CGRect.null) { $0.union($1) }
let filter = SCContentFilter(display: display, including: windows)
let config = SCStreamConfiguration()
let scale = CGFloat(filter.pointPixelScale)
config.sourceRect = bounds.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
config.width = Int(bounds.width * scale)
config.height = Int(bounds.height * scale)
config.backgroundColor = .clear
config.showsCursor = false
config.ignoreShadowsDisplay = true

let image: CGImage = try await withCheckedThrowingContinuation { continuation in
    SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) { image, error in
        if let image { continuation.resume(returning: image) } else { continuation.resume(throwing: error!) }
    }
}
try NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: out)
print("\(out.lastPathComponent): \(image.width)×\(image.height)")

import ScreenCaptureKit
import CoreGraphics
import AppKit

@MainActor
final class CaptureEngine {
    /// Capture the entire main display
    func captureFullscreen() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first else {
            throw KaptError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.width = display.width * 2  // Retina
        config.height = display.height * 2
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }

    /// Capture a specific window
    func captureWindow(_ window: SCWindow) async throws -> CGImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.showsCursor = false
        config.scalesToFit = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }

    /// Capture a region of the main display
    func captureRegion(_ rect: CGRect) async throws -> CGImage {
        let fullImage = try await captureFullscreen()

        let scale = CGFloat(fullImage.width) / (NSScreen.main?.frame.width ?? 1)
        let imageRect = CGRect(
            x: rect.origin.x * scale,
            y: rect.origin.y * scale,
            width: rect.width * scale,
            height: rect.height * scale
        )

        guard let cropped = fullImage.cropping(to: imageRect) else {
            throw KaptError.captureFailed
        }
        return cropped
    }

    /// List available windows for window picker
    func availableWindows() async throws -> [SCWindow] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        return content.windows.filter { window in
            window.frame.width > 100 && window.frame.height > 100
            && window.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier
        }
    }
}

import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Which display(s) to capture
enum DisplayTarget: String, CaseIterable {
    case activeScreen = "active"     // Screen with the focused window / mouse
    case primaryScreen = "primary"   // NSScreen.main (menu bar screen)
    case secondaryScreen = "secondary" // First non-primary screen
    case allScreens = "all"          // Stitch all screens together

    var label: String {
        switch self {
        case .activeScreen: "Active Screen"
        case .primaryScreen: "Primary Screen"
        case .secondaryScreen: "Secondary Screen"
        case .allScreens: "All Screens"
        }
    }
}

@MainActor
final class CaptureEngine {

    /// Resolve which NSScreen(s) to use based on the target preference
    func resolveScreen(for target: DisplayTarget) -> NSScreen {
        switch target {
        case .activeScreen:
            // Screen containing the mouse cursor
            let mouseLocation = NSEvent.mouseLocation
            return NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
                ?? NSScreen.main ?? NSScreen.screens[0]
        case .primaryScreen:
            return NSScreen.main ?? NSScreen.screens[0]
        case .secondaryScreen:
            let primary = NSScreen.main
            return NSScreen.screens.first(where: { $0 != primary }) ?? NSScreen.screens[0]
        case .allScreens:
            return NSScreen.main ?? NSScreen.screens[0] // union handled separately
        }
    }

    /// Capture fullscreen for a specific display target
    func captureFullscreen(target: DisplayTarget = .activeScreen) async throws -> CGImage {
        if target == .allScreens {
            return try await captureAllScreens()
        }

        let screen = resolveScreen(for: target)
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Match SCDisplay to NSScreen by frame origin
        guard let display = content.displays.first(where: { display in
            abs(CGFloat(display.width) - screen.frame.width) < 2 &&
            abs(CGFloat(display.height) - screen.frame.height) < 2
        }) ?? content.displays.first else {
            throw KaptError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        let backingScale = screen.backingScaleFactor
        config.width = Int(screen.frame.width * backingScale)
        config.height = Int(screen.frame.height * backingScale)
        config.showsCursor = false

        return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Capture all screens and stitch into one image
    private func captureAllScreens() async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard !content.displays.isEmpty else {
            throw KaptError.noDisplayFound
        }

        // Capture each display
        var images: [(CGImage, CGRect)] = []
        for display in content.displays {
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = display.width * 2
            config.height = display.height * 2
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
            let frame = CGRect(x: display.frame.origin.x, y: display.frame.origin.y,
                               width: CGFloat(display.width), height: CGFloat(display.height))
            images.append((image, frame))
        }

        if images.count == 1 { return images[0].0 }

        // Compute bounding rect of all displays
        let union = images.reduce(CGRect.null) { $0.union($1.1) }
        let scale: CGFloat = 2 // Retina
        let totalWidth = Int(union.width * scale)
        let totalHeight = Int(union.height * scale)

        guard let ctx = CGContext(
            data: nil, width: totalWidth, height: totalHeight,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw KaptError.captureFailed }

        // Draw each image at its offset (flip Y since CGContext origin is bottom-left)
        for (image, frame) in images {
            let x = (frame.origin.x - union.origin.x) * scale
            let y = (union.maxY - frame.maxY) * scale
            let w = frame.width * scale
            let h = frame.height * scale
            ctx.draw(image, in: CGRect(x: x, y: y, width: w, height: h))
        }

        guard let result = ctx.makeImage() else { throw KaptError.captureFailed }
        return result
    }

    /// Capture a region on the given screen
    func captureRegion(_ rect: CGRect, on screen: NSScreen) async throws -> CGImage {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let display = content.displays.first(where: { display in
            abs(CGFloat(display.width) - screen.frame.width) < 2 &&
            abs(CGFloat(display.height) - screen.frame.height) < 2
        }) ?? content.displays.first else {
            throw KaptError.noDisplayFound
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        // Use the actual backing pixel size for accurate capture
        let backingScale = screen.backingScaleFactor
        config.width = Int(screen.frame.width * backingScale)
        config.height = Int(screen.frame.height * backingScale)
        config.showsCursor = false

        let fullImage = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        // Scale from logical points to actual captured pixels
        let scaleX = CGFloat(fullImage.width) / screen.frame.width
        let scaleY = CGFloat(fullImage.height) / screen.frame.height
        let imageRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )

        snapLog("captureRegion: screen=\(screen.frame), backing=\(backingScale), fullImage=\(fullImage.width)x\(fullImage.height), rect=\(rect), imageRect=\(imageRect)")

        guard let cropped = fullImage.cropping(to: imageRect) else {
            throw KaptError.captureFailed
        }
        return cropped
    }
}

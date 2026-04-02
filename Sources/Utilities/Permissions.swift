import ScreenCaptureKit
import AppKit

enum Permissions {
    /// Check if screen recording permission is granted
    static func hasScreenRecordingPermission() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    /// Request screen recording permission (opens System Settings if needed)
    static func requestScreenRecordingPermission() {
        if !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    /// Verify by attempting to fetch shareable content
    static func verifyAccess() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }

    /// Check if Accessibility permission is granted (needed for auto-scroll)
    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission (opens System Settings)
    @MainActor
    static func requestAccessibilityPermission() {
        let prompt = "kAXTrustedCheckOptionPrompt"
        let key = prompt as CFString
        let options = [key: kCFBooleanTrue!] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

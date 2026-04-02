import AppKit
import UniformTypeIdentifiers

extension CGImage {
    /// Convert to NSImage
    var nsImage: NSImage {
        NSImage(cgImage: self, size: NSSize(width: width, height: height))
    }

    /// Export as PNG data
    var pngData: Data? {
        let rep = NSBitmapImageRep(cgImage: self)
        return rep.representation(using: .png, properties: [:])
    }

    /// Save as PNG to a file URL
    func savePNG(to url: URL) throws {
        guard let data = pngData else {
            throw SnapXError.exportFailed
        }
        try data.write(to: url)
    }

    /// Copy to system pasteboard
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }
}

enum SnapXError: LocalizedError {
    case capturePermissionDenied
    case captureFailed
    case exportFailed
    case noDisplayFound

    var errorDescription: String? {
        switch self {
        case .capturePermissionDenied: "Screen recording permission is required."
        case .captureFailed: "Failed to capture screen."
        case .exportFailed: "Failed to export image."
        case .noDisplayFound: "No display found."
        }
    }
}

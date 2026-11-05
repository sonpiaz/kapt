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
            throw KaptError.exportFailed
        }
        try data.write(to: url)
    }

    /// File name for a capture taken at `date`, e.g. "Kapt 2026-11-05 at 1.07.42 PM.png"
    static func captureFilename(at date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        return "Kapt \(formatter.string(from: date)).png"
    }

    /// Save as a new PNG in `directory`, creating the directory if it is missing.
    /// Never overwrites: a second capture in the same second gets " (2)", " (3)", …
    func savePNG(into directory: URL, at date: Date = Date()) throws -> URL {
        guard let data = pngData else {
            throw KaptError.exportFailed
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = CGImage.captureFilename(at: date)
        let stem = (filename as NSString).deletingPathExtension
        var url = directory.appendingPathComponent(filename)
        var copy = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = directory.appendingPathComponent("\(stem) (\(copy)).png")
            copy += 1
        }
        try data.write(to: url, options: .withoutOverwriting)
        return url
    }

    /// Copy to system pasteboard
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(pngData, forType: .png)
    }
}

enum KaptError: LocalizedError {
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

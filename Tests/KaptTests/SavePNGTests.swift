import CoreGraphics
import Foundation
import Testing
@testable import Kapt

@Suite struct SavePNGTests {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("KaptTests-\(UUID().uuidString)", isDirectory: true)

    func makeImage() throws -> CGImage {
        let context = try #require(CGContext(
            data: nil, width: 4, height: 4, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 4, height: 4))
        return try #require(context.makeImage())
    }

    @Test func createsMissingFolder() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("Pictures/Screenshots", isDirectory: true)
        #expect(!FileManager.default.fileExists(atPath: folder.path))

        let url = try makeImage().savePNG(into: folder)

        #expect(url.deletingLastPathComponent().standardizedFileURL == folder.standardizedFileURL)
        let data = try Data(contentsOf: url)
        #expect(data.starts(with: [0x89, 0x50, 0x4E, 0x47]))  // PNG signature
    }

    @Test func sameSecondCapturesDoNotOverwrite() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let image = try makeImage()
        let date = Date()

        let first = try image.savePNG(into: root, at: date)
        let second = try image.savePNG(into: root, at: date)
        let third = try image.savePNG(into: root, at: date)

        #expect(Set([first, second, third]).count == 3)
        #expect(second.lastPathComponent.hasSuffix(" (2).png"))
        #expect(third.lastPathComponent.hasSuffix(" (3).png"))
        let files = try FileManager.default.contentsOfDirectory(atPath: root.path)
        #expect(files.count == 3)
    }

    @Test func unwritableFolderThrows() throws {
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: root.path)
            try? FileManager.default.removeItem(at: root)
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: root.path)
        let image = try makeImage()

        #expect(throws: (any Error).self) { try image.savePNG(into: root) }
        #expect(throws: (any Error).self) { try image.savePNG(into: root.appendingPathComponent("sub")) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).isEmpty)
    }
}

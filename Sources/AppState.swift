import SwiftUI
import ScreenCaptureKit
import AppKit
func snapLog(_ msg: String) {
    let line = "[\(Date())] \(msg)\n"
    let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop/kapt-debug.log")
    if let handle = try? FileHandle(forWritingTo: url) {
        handle.seekToEndOfFile()
        handle.write(line.data(using: .utf8)!)
        handle.closeFile()
    } else {
        try? line.data(using: .utf8)?.write(to: url)
    }
}

enum CaptureMode {
    case fullscreen
    case region
}

@MainActor
@Observable
final class AppState {
    var capturedImage: CGImage?
    var isCapturing = false
    var lastSaveURL: URL?
    var statusMessage: String?
    var isAnnotationEditorOpen = false

    let captureEngine = CaptureEngine()
    private var thumbnailPanel = ThumbnailPanel()
    private var regionSelectionWindow: RegionSelectionWindow?

    // MARK: - Capture Actions

    func startCapture(mode: CaptureMode) {
        snapLog("startCapture called with mode: \(mode)")
        guard !isCapturing else {
            snapLog("Already capturing, ignoring")
            return
        }
        thumbnailPanel.dismiss()

        // Activate app so region overlay can become key
        NSApp.activate(ignoringOtherApps: true)

        Task {
            isCapturing = true
            defer {
                isCapturing = false
                snapLog("isCapturing reset to false")
            }

            do {
                snapLog("Starting \(mode) capture...")
                switch mode {
                case .fullscreen:
                    capturedImage = try await captureEngine.captureFullscreen()
                case .region:
                    capturedImage = try await captureRegion()
                }

                if let image = capturedImage {
                    snapLog("Capture success: \(image.width)x\(image.height)")
                    let savedURL = saveToDesktop(image)
                    image.copyToClipboard()
                    snapLog("Saved and copied to clipboard")
                    showThumbnail(for: image, fileURL: savedURL)
                } else {
                    snapLog("Capture returned nil image")
                }
            } catch is CancellationError {
                snapLog("Capture cancelled")
                statusMessage = "Capture cancelled"
            } catch {
                snapLog("Capture error: \(error)")
                statusMessage = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Region Capture

    private func captureRegion() async throws -> CGImage {
        snapLog("captureRegion: creating selection window")
        defer { cleanupRegionWindow() }
        let rect: CGRect = try await withCheckedThrowingContinuation { continuation in
            let window = RegionSelectionWindow { rect in
                snapLog("captureRegion: selection done, rect=\(rect)")
                continuation.resume(returning: rect)
            } onCancel: {
                snapLog("captureRegion: cancelled")
                continuation.resume(throwing: CancellationError())
            }
            regionSelectionWindow = window
            window.beginSelection()
            snapLog("captureRegion: window.beginSelection() called")
        }
        snapLog("captureRegion: capturing rect")
        let image = try await captureEngine.captureRegion(rect)
        snapLog("captureRegion: crop success \(image.width)x\(image.height)")
        return image
    }

    private func cleanupRegionWindow() {
        regionSelectionWindow?.orderOut(nil)
        regionSelectionWindow = nil
    }

    // MARK: - Thumbnail Preview (bottom-right)

    func showThumbnail(for image: CGImage, fileURL: URL? = nil) {
        thumbnailPanel.show(image: image, fileURL: fileURL) { [weak self] in
            self?.openAnnotationEditor(for: image)
        }
    }

    // MARK: - Annotation Editor

    private var annotationPanel: NSPanel?

    func openAnnotationEditor(for image: CGImage) {
        snapLog("openAnnotationEditor called, image: \(image.width)x\(image.height)")
        isAnnotationEditorOpen = true
        let state = AnnotationState(baseImage: image)
        let editorView = AnnotationEditorView(state: state) { [weak self] finalImage in
            self?.isAnnotationEditorOpen = false
            self?.annotationPanel?.close()
            self?.annotationPanel = nil
            if let finalImage {
                self?.capturedImage = finalImage
                self?.saveToDesktop(finalImage)
                finalImage.copyToClipboard()
                self?.showThumbnail(for: finalImage)
            }
        }

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Kapt — Annotate"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none
        panel.contentView = NSHostingView(rootView: editorView)

        let size = NSSize(
            width: min(CGFloat(image.width) / 2 + 60, 1200),
            height: min(CGFloat(image.height) / 2 + 120, 800)
        )
        panel.setContentSize(size)
        panel.center()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        annotationPanel = panel
        snapLog("openAnnotationEditor: panel shown")
    }

    // MARK: - OCR

    func performOCR(on image: CGImage) {
        Task {
            let text = await OCREngine.recognizeText(in: image)
            let resultView = OCRResultView(text: text)
            let panel = FloatingPanel(contentView: resultView)
            panel.show(
                near: NSEvent.mouseLocation,
                size: NSSize(width: 400, height: 300)
            )
        }
    }

    // MARK: - Save

    @discardableResult
    func saveToDesktop(_ image: CGImage) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
        let filename = "Kapt \(formatter.string(from: Date())).png"
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(filename)

        do {
            try image.savePNG(to: desktopURL)
            lastSaveURL = desktopURL
            statusMessage = "Saved to Desktop"
            return desktopURL
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
            return nil
        }
    }
}

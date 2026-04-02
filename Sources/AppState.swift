import SwiftUI
import ScreenCaptureKit
import AppKit

enum CaptureMode {
    case fullscreen
    case region
    case window
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
    private var quickAccessPanel: FloatingPanel<QuickAccessView>?

    // MARK: - Capture Actions

    func startCapture(mode: CaptureMode) {
        guard !isCapturing else { return }
        dismissQuickAccess()

        Task {
            isCapturing = true
            defer { isCapturing = false }

            do {
                switch mode {
                case .fullscreen:
                    capturedImage = try await captureEngine.captureFullscreen()
                case .region:
                    capturedImage = try await captureRegion()
                case .window:
                    capturedImage = try await captureWindow()
                }

                if let image = capturedImage {
                    showQuickAccess(for: image)
                }
            } catch {
                statusMessage = "Capture failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Region Capture (Phase 3)

    private func captureRegion() async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            let selectionWindow = RegionSelectionWindow { [weak self] rect in
                guard let self else {
                    continuation.resume(throwing: SnapXError.captureFailed)
                    return
                }
                Task {
                    do {
                        let image = try await self.captureEngine.captureRegion(rect)
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                continuation.resume(throwing: CancellationError())
            }
            selectionWindow.beginSelection()
        }
    }

    // MARK: - Window Capture (Phase 3)

    private func captureWindow() async throws -> CGImage {
        let windows = try await captureEngine.availableWindows()
        guard !windows.isEmpty else { throw SnapXError.captureFailed }

        return try await withCheckedThrowingContinuation { continuation in
            let picker = WindowPickerPanel(windows: windows) { [weak self] window in
                guard let self else {
                    continuation.resume(throwing: SnapXError.captureFailed)
                    return
                }
                Task {
                    do {
                        let image = try await self.captureEngine.captureWindow(window)
                        continuation.resume(returning: image)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            } onCancel: {
                continuation.resume(throwing: CancellationError())
            }
            picker.show()
        }
    }

    // MARK: - Quick Access Overlay

    func showQuickAccess(for image: CGImage) {
        dismissQuickAccess()

        let view = QuickAccessView(
            image: image,
            onCopy: { [weak self] in
                image.copyToClipboard()
                self?.statusMessage = "Copied!"
                self?.dismissQuickAccess()
            },
            onSave: { [weak self] in
                self?.saveToDesktop(image)
                self?.dismissQuickAccess()
            },
            onAnnotate: { [weak self] in
                self?.dismissQuickAccess()
                self?.openAnnotationEditor(for: image)
            },
            onOCR: { [weak self] in
                self?.dismissQuickAccess()
                self?.performOCR(on: image)
            },
            onDismiss: { [weak self] in
                self?.dismissQuickAccess()
            }
        )

        let panel = FloatingPanel(contentView: view)
        let mouseLocation = NSEvent.mouseLocation
        panel.show(near: mouseLocation, size: NSSize(width: 300, height: 220))
        quickAccessPanel = panel
    }

    func dismissQuickAccess() {
        quickAccessPanel?.close()
        quickAccessPanel = nil
    }

    // MARK: - Annotation Editor (Phase 4)

    func openAnnotationEditor(for image: CGImage) {
        isAnnotationEditorOpen = true
        let state = AnnotationState(baseImage: image)
        let editorView = AnnotationEditorView(state: state) { [weak self] finalImage in
            self?.isAnnotationEditorOpen = false
            if let finalImage {
                self?.capturedImage = finalImage
                self?.showQuickAccess(for: finalImage)
            }
        }
        let panel = FloatingPanel(contentView: editorView)
        let size = NSSize(
            width: min(CGFloat(image.width) / 2 + 60, 1200),
            height: min(CGFloat(image.height) / 2 + 120, 800)
        )
        panel.show(near: NSPoint(x: NSScreen.main!.frame.midX, y: NSScreen.main!.frame.midY), size: size)
        panel.center()
    }

    // MARK: - OCR (Phase 6)

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

    func saveToDesktop(_ image: CGImage) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "SnapX_\(formatter.string(from: Date())).png"
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop")
            .appendingPathComponent(filename)

        do {
            try image.savePNG(to: desktopURL)
            lastSaveURL = desktopURL
            statusMessage = "Saved to Desktop"
        } catch {
            statusMessage = "Save failed: \(error.localizedDescription)"
        }
    }
}

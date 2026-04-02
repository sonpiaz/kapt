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
    case scrolling
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
    private var scrollingController: ScrollingCaptureController?
    private var scrollingHUD: ScrollingCaptureHUD?

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            "autoCopy": true,
            "saveLocation": "Desktop",
            "displayTarget": "active",
            "scrollSpeed": 3,
            "scrollMaxHeight": 20000,
        ])
    }

    /// Which display to capture (read from UserDefaults)
    var displayTarget: DisplayTarget {
        let raw = UserDefaults.standard.string(forKey: "displayTarget") ?? "active"
        return DisplayTarget(rawValue: raw) ?? .activeScreen
    }

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
                    capturedImage = try await captureEngine.captureFullscreen(target: displayTarget)
                case .region:
                    capturedImage = try await captureRegion()
                case .scrolling:
                    capturedImage = try await captureScrolling()
                }

                if let image = capturedImage {
                    snapLog("Capture success: \(image.width)x\(image.height)")
                    let savedURL = saveToDesktop(image)
                    let autoCopy = UserDefaults.standard.bool(forKey: "autoCopy")
                    if autoCopy { image.copyToClipboard() }
                    snapLog("Saved\(autoCopy ? " and copied to clipboard" : "")")
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
        let targetScreen = captureEngine.resolveScreen(for: displayTarget)
        defer { cleanupRegionWindow() }
        let rect: CGRect = try await withCheckedThrowingContinuation { continuation in
            let window = RegionSelectionWindow(screen: targetScreen) { rect in
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
        let image = try await captureEngine.captureRegion(rect, on: targetScreen)
        snapLog("captureRegion: crop success \(image.width)x\(image.height)")
        return image
    }

    private func cleanupRegionWindow() {
        regionSelectionWindow?.orderOut(nil)
        regionSelectionWindow = nil
    }

    // MARK: - Scrolling Capture

    private func captureScrolling() async throws -> CGImage {
        snapLog("captureScrolling: starting region selection")
        let targetScreen = captureEngine.resolveScreen(for: displayTarget)
        defer { cleanupRegionWindow() }

        // Step 1: Select region (reuse existing selection UI)
        let rect: CGRect = try await withCheckedThrowingContinuation { continuation in
            let window = RegionSelectionWindow(screen: targetScreen) { rect in
                snapLog("captureScrolling: selection done, rect=\(rect)")
                continuation.resume(returning: rect)
            } onCancel: {
                snapLog("captureScrolling: cancelled")
                continuation.resume(throwing: CancellationError())
            }
            regionSelectionWindow = window
            window.beginSelection()
        }

        snapLog("captureScrolling: region selected, showing HUD")

        // Step 2: Setup controller and HUD
        let controller = ScrollingCaptureController(rect: rect, screen: targetScreen)
        scrollingController = controller

        let hud = ScrollingCaptureHUD()
        scrollingHUD = hud

        let hasAccessibility = Permissions.hasAccessibilityPermission()
        if !hasAccessibility {
            snapLog("captureScrolling: no accessibility permission, manual mode only")
        }

        // Step 3: Wait for user interaction via HUD
        let image: CGImage = try await withCheckedThrowingContinuation { continuation in
            var isAutoScrolling = false

            controller.onFrameCaptured = { [weak hud] count in
                hud?.updateFrameCount(count)
            }

            controller.onAutoScrollStopped = { [weak hud] in
                isAutoScrolling = false
                hud?.updateAutoScrolling(false)
            }

            hud.onAutoScroll = { [weak controller, weak hud] in
                guard let controller else { return }
                if isAutoScrolling {
                    controller.stop()
                    isAutoScrolling = false
                    hud?.updateAutoScrolling(false)
                    // Switch to manual mode so user can still scroll
                    controller.startManualCapture()
                } else {
                    controller.stop()
                    isAutoScrolling = true
                    hud?.updateAutoScrolling(true)
                    controller.startAutoScroll()
                }
            }

            hud.onDone = { [weak controller, weak hud] in
                guard let controller else { return }
                if let result = controller.finish() {
                    hud?.dismiss()
                    continuation.resume(returning: result)
                } else {
                    hud?.dismiss()
                    continuation.resume(throwing: KaptError.captureFailed)
                }
            }

            hud.onCancel = { [weak controller, weak hud] in
                controller?.stop()
                hud?.dismiss()
                continuation.resume(throwing: CancellationError())
            }

            hud.show(near: rect, on: targetScreen, hasAccessibility: hasAccessibility)

            // Start in manual mode by default (captures on user scroll)
            controller.startManualCapture()
        }

        scrollingController = nil
        scrollingHUD = nil

        snapLog("captureScrolling: stitched result \(image.width)x\(image.height)")
        return image
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
        let folder = UserDefaults.standard.string(forKey: "saveLocation") ?? "Desktop"
        let desktopURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(folder)
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

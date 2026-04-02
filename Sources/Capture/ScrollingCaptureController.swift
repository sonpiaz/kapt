import ScreenCaptureKit
import CoreGraphics
import AppKit

enum ScrollMode {
    case auto
    case manual
}

extension Int {
    func nonZeroOr(_ fallback: Int) -> Int {
        self != 0 ? self : fallback
    }
}

/// Orchestrates a scrolling capture session: captures frames while content scrolls
@MainActor
final class ScrollingCaptureController {
    var capturedFrames: [CGImage] = []
    var isCapturing = false
    var frameCount: Int { capturedFrames.count }

    private let selectedRect: CGRect
    private let screen: NSScreen
    private let captureEngine = CaptureEngine()
    private var captureTask: Task<Void, Never>?
    private var scrollMonitor: Any?
    private var scrollTimer: DispatchSourceTimer?
    private var lastScrollTime: Date = .distantPast
    private var identicalFrameCount = 0

    // Callbacks
    var onFrameCaptured: ((Int) -> Void)?
    var onAutoScrollStopped: (() -> Void)?

    private var maxTotalHeight: Int {
        UserDefaults.standard.integer(forKey: "scrollMaxHeight").nonZeroOr(20_000)
    }
    private let captureInterval: TimeInterval = 0.12 // ~8fps

    init(rect: CGRect, screen: NSScreen) {
        self.selectedRect = rect
        self.screen = screen
    }

    // Cleanup is handled by stop() which is called before dealloc

    // MARK: - Auto Scroll Mode

    func startAutoScroll(speed: Int? = nil) {
        let speed = speed ?? UserDefaults.standard.integer(forKey: "scrollSpeed").nonZeroOr(3)
        guard !isCapturing else { return }
        isCapturing = true
        identicalFrameCount = 0

        // Start continuous capture + scroll injection
        captureTask = Task { [weak self] in
            guard let self else { return }

            // Small delay before starting to let UI settle
            try? await Task.sleep(for: .milliseconds(300))

            while !Task.isCancelled && self.isCapturing {
                // Capture frame
                await self.captureFrame()

                // Check if content stopped scrolling (identical frames)
                if self.identicalFrameCount >= 3 {
                    snapLog("ScrollingCapture: auto-stopped — content reached end")
                    self.isCapturing = false
                    self.onAutoScrollStopped?()
                    break
                }

                // Check max height
                if self.estimatedTotalHeight() > self.maxTotalHeight {
                    snapLog("ScrollingCapture: auto-stopped — max height reached")
                    self.isCapturing = false
                    self.onAutoScrollStopped?()
                    break
                }

                // Inject scroll event
                self.injectScroll(delta: -speed)

                try? await Task.sleep(for: .milliseconds(Int(self.captureInterval * 1000)))
            }
        }
    }

    // MARK: - Manual Mode

    func startManualCapture() {
        guard !isCapturing else { return }
        isCapturing = true
        identicalFrameCount = 0

        // Capture initial frame
        Task { await captureFrame() }

        // Monitor scroll events globally
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.isCapturing else { return }
            guard abs(event.scrollingDeltaY) > 0.5 else { return }

            let now = Date()
            // Throttle: capture at most every 100ms
            if now.timeIntervalSince(self.lastScrollTime) > 0.1 {
                self.lastScrollTime = now
                Task { @MainActor in
                    await self.captureFrame()
                }
            }
        }
    }

    // MARK: - Stop & Finish

    func stop() {
        isCapturing = false
        captureTask?.cancel()
        captureTask = nil
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
    }

    func finish() -> CGImage? {
        stop()
        snapLog("ScrollingCapture: stitching \(capturedFrames.count) frames")
        return FrameStitcher.stitch(frames: capturedFrames)
    }

    // MARK: - Frame Capture

    private func captureFrame() async {
        do {
            let image = try await captureEngine.captureRegion(selectedRect, on: screen)

            // Check if identical to previous frame
            if let last = capturedFrames.last, framesAreIdentical(last, image) {
                identicalFrameCount += 1
                return
            }
            identicalFrameCount = 0

            capturedFrames.append(image)
            onFrameCaptured?(capturedFrames.count)
            snapLog("ScrollingCapture: frame \(capturedFrames.count) captured (\(image.width)x\(image.height))")
        } catch {
            snapLog("ScrollingCapture: frame capture failed: \(error)")
        }
    }

    // MARK: - Scroll Injection

    private func injectScroll(delta: Int) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(delta),
            wheel2: 0,
            wheel3: 0
        ) else { return }
        event.post(tap: .cgSessionEventTap)
    }

    // MARK: - Helpers

    private func estimatedTotalHeight() -> Int {
        capturedFrames.reduce(0) { $0 + $1.height }
    }

    /// Quick check if two frames are nearly identical (compare a few sample rows)
    private func framesAreIdentical(_ a: CGImage, _ b: CGImage) -> Bool {
        guard a.width == b.width, a.height == b.height else { return false }

        // Sample 3 rows: top quarter, middle, bottom quarter
        let sampleRows = [a.height / 4, a.height / 2, a.height * 3 / 4]
        let stripH = 2

        for row in sampleRows {
            let rect = CGRect(x: 0, y: row, width: a.width, height: stripH)
            guard let stripA = a.cropping(to: rect),
                  let stripB = b.cropping(to: rect),
                  let dataA = stripPixelData(stripA),
                  let dataB = stripPixelData(stripB) else { return false }

            var diff = 0
            for i in stride(from: 0, to: min(dataA.count, dataB.count), by: 8) {
                diff += abs(Int(dataA[i]) - Int(dataB[i]))
            }
            if diff > dataA.count / 40 { return false } // >2.5% diff = not identical
        }
        return true
    }

    private func stripPixelData(_ image: CGImage) -> [UInt8]? {
        let w = image.width
        let h = image.height
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: h * bytesPerRow)
        guard let ctx = CGContext(
            data: &data, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ThumbnailPreviewView: View {
    let image: CGImage
    let isPaused: Bool
    let countdownFraction: CGFloat
    @State private var isHovering = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 0) {
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 200, maxHeight: 130)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
                )

            // Countdown bar — driven by timer, pauses on hover/drag
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: geo.size.width * countdownFraction, height: 2)
                    .animation(.linear(duration: 0.1), value: countdownFraction)
            }
            .frame(height: 2)
            .padding(.top, 6)
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.75)
        )
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 120)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: appeared)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }
}

// MARK: - Draggable hosting view

final class DraggableThumbnailView: NSView, NSDraggingSource, NSPasteboardItemDataProvider {
    nonisolated(unsafe) var image: CGImage?
    var fileURL: URL?
    var onClick: (() -> Void)?
    var onHoverChanged: ((Bool) -> Void)?
    var onDragCompleted: (() -> Void)?
    private var hostingView: NSView?
    private var mouseDownPoint: NSPoint?
    private var isDragging = false

    func setup(image: CGImage, fileURL: URL?, isPaused: @escaping () -> Bool, countdownFraction: @escaping () -> CGFloat, onClick: @escaping () -> Void) {
        self.image = image
        self.fileURL = fileURL
        self.onClick = onClick

        // We'll use a wrapper that reads from closures so ThumbnailPanel can drive the state
        let swiftUIView = ThumbnailPreviewHostView(image: image, isPausedProvider: isPaused, countdownProvider: countdownFraction)
        let hosting = NSHostingView(rootView: swiftUIView)
        hosting.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: topAnchor),
            hosting.bottomAnchor.constraint(equalTo: bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        hostingView = hosting
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // Route all mouse events to this view, not the NSHostingView child
    override func hitTest(_ point: NSPoint) -> NSView? {
        return frame.contains(point) ? self : nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in trackingAreas {
            removeTrackingArea(area)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChanged?(false)
    }

    override func mouseDown(with event: NSEvent) {
        // Ensure this window is key immediately so drag works on first click
        window?.makeKey()
        mouseDownPoint = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = mouseDownPoint else { return }
        let current = event.locationInWindow
        let dx = current.x - startPoint.x
        let dy = current.y - startPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        // Start drag after 3pt threshold (reduced for snappier feel)
        if !isDragging && distance > 3 {
            isDragging = true
            startDraggingSession(with: event)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !isDragging {
            snapLog("Thumbnail clicked — opening annotation editor")
            onClick?()
        }
        mouseDownPoint = nil
        isDragging = false
    }

    override func rightMouseDown(with event: NSEvent) {
        let menu = NSMenu()

        let copyItem = NSMenuItem(title: "Copy", action: #selector(copyImage), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        if fileURL != nil {
            let revealItem = NSMenuItem(title: "Show in Finder", action: #selector(showInFinder), keyEquivalent: "")
            revealItem.target = self
            menu.addItem(revealItem)
        }

        menu.addItem(NSMenuItem.separator())

        let annotateItem = NSMenuItem(title: "Annotate", action: #selector(annotateImage), keyEquivalent: "")
        annotateItem.target = self
        menu.addItem(annotateItem)

        menu.addItem(NSMenuItem.separator())

        if fileURL != nil {
            let deleteItem = NSMenuItem(title: "Delete", action: #selector(deleteImage), keyEquivalent: "")
            deleteItem.target = self
            menu.addItem(deleteItem)
        }

        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    @objc private func copyImage() {
        image?.copyToClipboard()
    }

    @objc private func showInFinder() {
        guard let fileURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    @objc private func annotateImage() {
        snapLog("Thumbnail right-click — Annotate")
        onClick?()
    }

    @objc private func deleteImage() {
        guard let fileURL else { return }
        try? FileManager.default.trashItem(at: fileURL, resultingItemURL: nil)
        // Dismiss thumbnail after delete
        window?.orderOut(nil)
    }

    private func startDraggingSession(with event: NSEvent) {
        guard let image else { return }

        // Use the saved file on Desktop, or create temp if needed
        let dragURL: URL
        if let fileURL, FileManager.default.fileExists(atPath: fileURL.path) {
            dragURL = fileURL
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd 'at' h.mm.ss a"
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("Kapt \(formatter.string(from: Date())).png")
            guard let pngData = image.pngData else { return }
            do { try pngData.write(to: tempURL) } catch { return }
            dragURL = tempURL
        }

        let dragItem = NSDraggingItem(pasteboardWriter: dragURL as NSURL)
        let thumbSize = NSSize(width: 120, height: 80)
        let nsImage = image.nsImage
        nsImage.size = thumbSize
        dragItem.setDraggingFrame(bounds, contents: nsImage)

        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    // MARK: - NSDraggingSource

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : .copy
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        // Dismiss thumbnail after successful drag-drop
        if operation != [] {
            snapLog("Drag completed with operation \(operation.rawValue) — dismissing thumbnail")
            onDragCompleted?()
        }
    }

    // MARK: - NSPasteboardItemDataProvider

    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        if type == .png, let data = image?.pngData {
            item.setData(data, forType: .png)
        }
    }
}

// MARK: - Panel

final class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    // Accept mouse events without requiring the panel to be key first
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown {
            makeKey()
        }
        super.sendEvent(event)
    }
}

// MARK: - SwiftUI host that bridges closure-based state to ThumbnailPreviewView

struct ThumbnailPreviewHostView: View {
    let image: CGImage
    let isPausedProvider: () -> Bool
    let countdownProvider: () -> CGFloat

    @State private var isPaused = false
    @State private var countdown: CGFloat = 1.0

    private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()

    var body: some View {
        ThumbnailPreviewView(image: image, isPaused: isPaused, countdownFraction: countdown)
            .onReceive(timer) { _ in
                isPaused = isPausedProvider()
                countdown = countdownProvider()
            }
    }
}

@MainActor
final class ThumbnailPanel {
    private var panel: ClickablePanel?
    private var timerTask: Task<Void, Never>?

    // State for hover-pause & countdown sync
    private var isHovered = false
    private var isDragging = false
    private var remainingSeconds: CGFloat = 5.0
    private let totalSeconds: CGFloat = 5.0

    private var isPaused: Bool { isHovered || isDragging }

    func show(image: CGImage, fileURL: URL? = nil, onClick: @escaping () -> Void) {
        dismiss()

        // Reset countdown state
        remainingSeconds = totalSeconds
        isHovered = false
        isDragging = false

        let panel = ClickablePanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none

        let draggableView = DraggableThumbnailView()
        draggableView.setup(
            image: image,
            fileURL: fileURL,
            isPaused: { [weak self] in self?.isPaused ?? false },
            countdownFraction: { [weak self] in
                guard let self else { return 0 }
                return max(0, self.remainingSeconds / self.totalSeconds)
            },
            onClick: { [weak self] in
                let action = onClick
                self?.dismiss()
                action()
            }
        )

        // Hook hover events to pause/resume timer
        draggableView.onHoverChanged = { [weak self] hovering in
            self?.isHovered = hovering
        }

        // Hook drag-completed to dismiss immediately
        draggableView.onDragCompleted = { [weak self] in
            self?.dismiss()
        }

        panel.contentView = draggableView

        let panelSize = NSSize(width: 240, height: 170)
        panel.setContentSize(panelSize)

        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let origin = NSPoint(
                x: screenFrame.maxX - panelSize.width - 16,
                y: screenFrame.minY + 16
            )
            panel.setFrameOrigin(origin)
        }

        panel.orderFrontRegardless()
        self.panel = panel

        // Start a tick-based timer that respects pause
        timerTask = Task { [weak self] in
            let tickInterval: CGFloat = 0.1
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard let self, !Task.isCancelled else { return }

                if !self.isPaused {
                    self.remainingSeconds -= tickInterval
                }

                if self.remainingSeconds <= 0 {
                    self.animateDismiss()
                    return
                }
            }
        }
    }

    func dismiss() {
        timerTask?.cancel()
        timerTask = nil
        panel?.orderOut(nil)
        panel = nil
    }

    private func animateDismiss() {
        guard let panel else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.dismiss()
            }
        })
    }
}

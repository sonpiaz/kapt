import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ThumbnailPreviewView: View {
    let image: CGImage
    @State private var isHovering = false
    @State private var appeared = false
    @State private var countdown: CGFloat = 1.0

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

            // Countdown bar
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.6))
                    .frame(width: geo.size.width * countdown, height: 2)
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
            withAnimation(.linear(duration: 5.0)) {
                countdown = 0
            }
        }
    }
}

// MARK: - Draggable hosting view

final class DraggableThumbnailView: NSView, NSDraggingSource, NSPasteboardItemDataProvider {
    nonisolated(unsafe) var image: CGImage?
    var fileURL: URL?
    var onClick: (() -> Void)?
    private var hostingView: NSView?
    private var mouseDownPoint: NSPoint?
    private var isDragging = false

    func setup(image: CGImage, fileURL: URL?, onClick: @escaping () -> Void) {
        self.image = image
        self.fileURL = fileURL
        self.onClick = onClick

        let swiftUIView = ThumbnailPreviewView(image: image)
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

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let startPoint = mouseDownPoint else { return }
        let current = event.locationInWindow
        let dx = current.x - startPoint.x
        let dy = current.y - startPoint.y
        let distance = sqrt(dx * dx + dy * dy)

        // Start drag after 4pt threshold
        if !isDragging && distance > 4 {
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
        // no-op: drag uses the saved file on Desktop
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
}

@MainActor
final class ThumbnailPanel {
    private var panel: ClickablePanel?
    private var autoDismissTask: Task<Void, Never>?

    func show(image: CGImage, fileURL: URL? = nil, onClick: @escaping () -> Void) {
        dismiss()

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
        draggableView.setup(image: image, fileURL: fileURL) { [weak self] in
            let action = onClick
            self?.dismiss()
            action()
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

        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                self.animateDismiss()
            }
        }
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
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

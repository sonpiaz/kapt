import AppKit
import SwiftUI

final class FloatingPanel<Content: View>: NSPanel {
    init(contentView: Content) {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isFloatingPanel = true
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.canJoinAllSpaces)

        // Exclude this panel from screen captures
        sharingType = .none

        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        contentView_panel = hostingView
    }

    private var contentView_panel: NSView? {
        didSet {
            if let view = contentView_panel {
                contentView = view
            }
        }
    }

    override var canBecomeKey: Bool { true }

    /// Show the panel near a screen point
    func show(near point: CGPoint, size: NSSize) {
        setContentSize(size)

        // Position: slightly below and to the right of the point
        let origin = NSPoint(
            x: point.x - size.width / 2,
            y: point.y - size.height - 20
        )
        setFrameOrigin(origin)

        // Ensure panel stays on screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            var frame = self.frame
            if frame.maxX > screenFrame.maxX { frame.origin.x = screenFrame.maxX - frame.width }
            if frame.minX < screenFrame.minX { frame.origin.x = screenFrame.minX }
            if frame.minY < screenFrame.minY { frame.origin.y = screenFrame.minY }
            setFrame(frame, display: true)
        }

        orderFrontRegardless()
    }
}

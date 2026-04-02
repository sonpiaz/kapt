import SwiftUI
import AppKit

struct ThumbnailPreviewView: View {
    let image: CGImage
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
                        .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                )
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
        .scaleEffect(isHovering ? 1.03 : 1.0)
        .offset(x: appeared ? 0 : 240)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appeared)
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

// NSPanel subclass that accepts first mouse click without requiring activation
final class ClickablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var acceptsFirstResponder: Bool { true }
}

final class ClickableHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

@MainActor
final class ThumbnailPanel {
    private var panel: ClickablePanel?
    private var autoDismissTask: Task<Void, Never>?
    private var clickAction: (() -> Void)?

    func show(image: CGImage, onClick: @escaping () -> Void) {
        dismiss()
        clickAction = onClick

        let view = ThumbnailPreviewView(image: image)

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

        let hostingView = ClickableHostingView(rootView: view)
        panel.contentView = hostingView

        // Add click gesture to the hosting view
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        hostingView.addGestureRecognizer(clickGesture)

        let panelSize = NSSize(width: 240, height: 170)
        panel.setContentSize(panelSize)

        // Position at bottom-right of main screen
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

        // Auto-dismiss after 5 seconds
        autoDismissTask = Task {
            try? await Task.sleep(for: .seconds(5))
            if !Task.isCancelled {
                self.animateDismiss()
            }
        }
    }

    @objc private func handleClick() {
        snapLog("Thumbnail clicked — opening annotation editor")
        let action = clickAction
        dismiss()
        action?()
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        panel?.orderOut(nil)
        panel = nil
        clickAction = nil
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

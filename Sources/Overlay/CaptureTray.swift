import SwiftUI
import AppKit

/// Parked captures ("Minimize — edit later"): compact chips stacked up the
/// bottom-right edge, above the thumbnail slot. A chip lives until it is
/// clicked (opens the annotation editor), dragged out, deleted, or dismissed.
@MainActor
final class CaptureTray {
    private var chips: [ClickablePanel] = []
    private let maxChips = 6
    private let chipSize = NSSize(width: 76, height: 56)
    /// Keep clear of the live thumbnail (240x170 at 16pt inset) so a fresh
    /// capture's preview never covers the parked chips.
    private let stackBaseOffset: CGFloat = 16 + 170 + 12

    func park(image: CGImage, fileURL: URL?, onEdit: @escaping (CGImage) -> Void) {
        if chips.count >= maxChips, let oldest = chips.first { remove(oldest) }

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
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none

        let view = DraggableThumbnailView()
        view.setup(
            image: image,
            fileURL: fileURL,
            rootView: AnyView(CaptureChipView(image: image)),
            onClick: { [weak self, weak panel] in
                snapLog("Tray chip clicked — opening annotation editor")
                if let panel { self?.remove(panel) }
                onEdit(image)
            }
        )
        view.onRemove = { [weak self, weak panel] in
            if let panel { self?.remove(panel) }
        }
        view.onDragCompleted = { [weak self, weak panel] in
            if let panel { self?.remove(panel) }
        }

        panel.contentView = view
        panel.setContentSize(chipSize)
        chips.append(panel)
        layout()
        panel.orderFrontRegardless()
        snapLog("Tray: parked capture (\(chips.count) chip(s))")
    }

    private func remove(_ panel: ClickablePanel) {
        panel.orderOut(nil)
        chips.removeAll { $0 === panel }
        layout()
    }

    private func layout() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            for (index, panel) in chips.enumerated() {
                let origin = NSPoint(
                    x: frame.maxX - chipSize.width - 16,
                    y: frame.minY + stackBaseOffset + CGFloat(index) * (chipSize.height + 8)
                )
                panel.animator().setFrameOrigin(origin)
            }
        }
    }
}

/// A parked capture: mini preview on material, hover lift. All mouse handling
/// (click / drag-out / context menu) lives in the hosting DraggableThumbnailView.
struct CaptureChipView: View {
    let image: CGImage
    @State private var isHovering = false

    var body: some View {
        Image(decorative: image, scale: 1.0)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 64, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
            .padding(6)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.75)
            )
            .scaleEffect(isHovering ? 1.06 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .onHover { isHovering = $0 }
    }
}

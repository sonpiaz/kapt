import SwiftUI
import AppKit

struct AnnotationBottomBar: View {
    @Bindable var state: AnnotationState
    @State private var isPinned = true

    var body: some View {
        HStack(spacing: 0) {
            // Left: Pin toggle
            Button {
                isPinned.toggle()
                if let window = NSApp.keyWindow {
                    window.level = isPinned ? .floating : .normal
                }
            } label: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(isPinned ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin from top" : "Pin on top")

            // Zoom controls
            HStack(spacing: 2) {
                Button { state.zoomOut() } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(state.zoomScale <= AnnotationState.zoomMin)

                Button { state.resetZoom() } label: {
                    Text("\(Int(state.zoomScale * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(minWidth: 40)
                }
                .buttonStyle(.plain)
                .help("Reset zoom")

                Button { state.zoomIn() } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .disabled(state.zoomScale >= AnnotationState.zoomMax)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 5).fill(.quaternary))

            Spacer()

            // Center: Drag-me pill
            DragMePill(state: state)

            Spacer()

            // Right: Copy + Share
            Button { copyToClipboard() } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")

            Button { shareImage() } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Share")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    private func copyToClipboard() {
        if let image = state.flatten() {
            image.copyToClipboard()
        }
    }

    private func shareImage() {
        guard let image = state.flatten(), let data = image.pngData else { return }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("Kapt-share.png")
        try? data.write(to: tempURL)

        guard let button = NSApp.keyWindow?.contentView else { return }
        let picker = NSSharingServicePicker(items: [tempURL])
        picker.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

// MARK: - Drag Me Pill (NSDraggingSource)

struct DragMePill: NSViewRepresentable {
    let state: AnnotationState

    func makeNSView(context: Context) -> DragMePillNSView {
        let view = DragMePillNSView()
        view.state = state
        return view
    }

    func updateNSView(_ nsView: DragMePillNSView, context: Context) {
        nsView.state = state
    }
}

@MainActor
final class DragMePillNSView: NSView, NSDraggingSource {
    var state: AnnotationState?
    private var mouseDownPoint: NSPoint?
    private var isDragging = false

    override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 120, height: 28))
        wantsLayer = true

        let pill = NSHostingView(rootView:
            HStack(spacing: 4) {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Drag me")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Capsule().fill(.quaternary))
        )
        pill.frame = bounds
        pill.autoresizingMask = [.width, .height]
        addSubview(pill)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 120, height: 28)
    }

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

        if !isDragging && distance > 3 {
            isDragging = true
            startDraggingSession(with: event)
        }
    }

    private func startDraggingSession(with event: NSEvent) {
        guard let state, let image = state.flatten() else { return }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kapt-drag-\(UUID().uuidString).png")
        guard let data = image.pngData else { return }
        try? data.write(to: tempURL)

        let dragItem = NSDraggingItem(pasteboardWriter: tempURL as NSURL)
        let thumbSize = NSSize(width: 60, height: 60)
        dragItem.setDraggingFrame(
            NSRect(origin: .zero, size: thumbSize),
            contents: NSImage(cgImage: image, size: thumbSize)
        )

        beginDraggingSession(with: [dragItem], event: event, source: self)
    }

    nonisolated func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}

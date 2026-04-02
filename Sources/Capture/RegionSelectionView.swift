import SwiftUI

struct RegionSelectionView: View {
    let screenFrame: CGRect
    let onSelect: (CGRect) -> Void
    let onCancel: () -> Void

    @State private var dragStart: CGPoint?
    @State private var dragCurrent: CGPoint?
    @State private var mousePosition: CGPoint = .zero

    private var selectionRect: CGRect? {
        guard let start = dragStart, let current = dragCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    var body: some View {
        ZStack {
            // Dark overlay
            Color.black.opacity(0.3)
                .allowsHitTesting(true)

            // Cut out the selected region
            if let rect = selectionRect {
                // Clear the selection area
                Rectangle()
                    .fill(.clear)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)

                // Selection border
                Rectangle()
                    .strokeBorder(Color.white, lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Dimensions label
                Text("\(Int(rect.width)) × \(Int(rect.height))")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .position(x: rect.midX, y: rect.maxY + 20)
            }

            // Crosshair lines
            if dragStart == nil {
                CrosshairView(position: mousePosition)
            }

            // Instructions
            if dragStart == nil {
                VStack {
                    Text("Click and drag to select region • ESC to cancel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Spacer()
                }
                .padding(.top, 60)
            }
        }
        .compositingGroup()
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = value.startLocation
                    }
                    dragCurrent = value.location
                }
                .onEnded { value in
                    if let rect = selectionRect, rect.width > 5, rect.height > 5 {
                        // Convert from view coordinates to screen coordinates
                        let screenRect = CGRect(
                            x: rect.origin.x,
                            y: rect.origin.y,
                            width: rect.width,
                            height: rect.height
                        )
                        onSelect(screenRect)
                    } else {
                        onCancel()
                    }
                    dragStart = nil
                    dragCurrent = nil
                }
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                mousePosition = location
            case .ended:
                break
            }
        }
        .onKeyPress(.escape) {
            onCancel()
            return .handled
        }
    }
}

struct CrosshairView: View {
    let position: CGPoint

    var body: some View {
        Canvas { context, size in
            // Vertical line
            let vPath = Path { p in
                p.move(to: CGPoint(x: position.x, y: 0))
                p.addLine(to: CGPoint(x: position.x, y: size.height))
            }
            context.stroke(vPath, with: .color(.white.opacity(0.5)), lineWidth: 0.5)

            // Horizontal line
            let hPath = Path { p in
                p.move(to: CGPoint(x: 0, y: position.y))
                p.addLine(to: CGPoint(x: size.width, y: position.y))
            }
            context.stroke(hPath, with: .color(.white.opacity(0.5)), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }
}

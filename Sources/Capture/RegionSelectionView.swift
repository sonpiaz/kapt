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
            // Desaturated dark overlay
            Color.black.opacity(0.4)
                .allowsHitTesting(true)

            // Cut out the selected region
            if let rect = selectionRect {
                Rectangle()
                    .fill(.clear)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .blendMode(.destinationOut)

                // Selection border — double stroke for visibility on any background
                Rectangle()
                    .strokeBorder(Color.white.opacity(0.9), lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .shadow(color: .black.opacity(0.5), radius: 2)

                // Dimensions label — flips above when near bottom edge
                dimensionLabel(for: rect)
            }

            // Crosshair
            if dragStart == nil {
                CrosshairView(position: mousePosition)
            }

            // Instructions
            if dragStart == nil {
                VStack {
                    HStack(spacing: 6) {
                        Image(systemName: "viewfinder")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Drag to select")
                            .font(.system(size: 13, weight: .medium))
                        Text("·")
                            .foregroundStyle(.white.opacity(0.5))
                        Text("ESC to cancel")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .background(Color.black.opacity(0.3))
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

    @ViewBuilder
    private func dimensionLabel(for rect: CGRect) -> some View {
        let labelY = rect.maxY + 30 > screenFrame.height
            ? rect.minY - 30
            : rect.maxY + 24
        Text("\(Int(rect.width)) × \(Int(rect.height))")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .background(Color.black.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .position(x: rect.midX, y: labelY)
    }
}

struct CrosshairView: View {
    let position: CGPoint

    var body: some View {
        Canvas { context, size in
            // Full-screen guide lines (subtle)
            let vFull = Path { p in
                p.move(to: CGPoint(x: position.x, y: 0))
                p.addLine(to: CGPoint(x: position.x, y: size.height))
            }
            let hFull = Path { p in
                p.move(to: CGPoint(x: 0, y: position.y))
                p.addLine(to: CGPoint(x: size.width, y: position.y))
            }
            context.stroke(vFull, with: .color(.white.opacity(0.25)), lineWidth: 0.5)
            context.stroke(hFull, with: .color(.white.opacity(0.25)), lineWidth: 0.5)

            // Bright crosshair near cursor (+/- 30pt)
            let arm: CGFloat = 30
            let vLocal = Path { p in
                p.move(to: CGPoint(x: position.x, y: position.y - arm))
                p.addLine(to: CGPoint(x: position.x, y: position.y + arm))
            }
            let hLocal = Path { p in
                p.move(to: CGPoint(x: position.x - arm, y: position.y))
                p.addLine(to: CGPoint(x: position.x + arm, y: position.y))
            }
            context.stroke(vLocal, with: .color(.white.opacity(0.9)), lineWidth: 1.5)
            context.stroke(hLocal, with: .color(.white.opacity(0.9)), lineWidth: 1.5)

            // Center dot
            let dotSize: CGFloat = 4
            let dotRect = CGRect(
                x: position.x - dotSize / 2,
                y: position.y - dotSize / 2,
                width: dotSize, height: dotSize
            )
            context.fill(Path(ellipseIn: dotRect), with: .color(.white))
        }
        .allowsHitTesting(false)
    }
}

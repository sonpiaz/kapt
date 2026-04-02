import SwiftUI

struct ArrowShape: AnnotationShape {
    let id = ShapeID()
    var start: CGPoint
    var end: CGPoint
    var strokeColor: Color
    var strokeWidth: CGFloat

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let path = arrowPath()
        context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)
        // Arrowhead
        let headPath = arrowheadPath()
        context.fill(headPath, with: .color(strokeColor))
    }

    func render(in context: CGContext, imageSize: CGSize) {
        let nsColor = NSColor(strokeColor)
        context.setStrokeColor(nsColor.cgColor)
        context.setFillColor(nsColor.cgColor)
        context.setLineWidth(strokeWidth)

        // Line
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()

        // Arrowhead
        let headPath = arrowheadCGPath()
        context.addPath(headPath)
        context.fillPath()
    }

    private func arrowPath() -> Path {
        Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
    }

    private func arrowheadPath() -> Path {
        Path { p in
            let points = arrowheadPoints()
            guard points.count == 3 else { return }
            p.move(to: points[0])
            p.addLine(to: points[1])
            p.addLine(to: points[2])
            p.closeSubpath()
        }
    }

    private func arrowheadCGPath() -> CGPath {
        let path = CGMutablePath()
        let points = arrowheadPoints()
        guard points.count == 3 else { return path }
        path.move(to: points[0])
        path.addLine(to: points[1])
        path.addLine(to: points[2])
        path.closeSubpath()
        return path
    }

    private func arrowheadPoints() -> [CGPoint] {
        let headLength: CGFloat = max(strokeWidth * 4, 12)
        let headWidth: CGFloat = headLength * 0.6
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = sqrt(dx * dx + dy * dy)
        guard length > 0 else { return [] }

        let unitX = dx / length
        let unitY = dy / length

        let baseX = end.x - unitX * headLength
        let baseY = end.y - unitY * headLength

        return [
            end,
            CGPoint(x: baseX + unitY * headWidth / 2, y: baseY - unitX * headWidth / 2),
            CGPoint(x: baseX - unitY * headWidth / 2, y: baseY + unitX * headWidth / 2),
        ]
    }
}

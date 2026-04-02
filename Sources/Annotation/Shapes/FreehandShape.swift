import SwiftUI

struct FreehandShape: AnnotationShape {
    let id = ShapeID()
    var points: [CGPoint]
    var strokeColor: Color
    var strokeWidth: CGFloat

    func draw(in context: inout GraphicsContext, size: CGSize) {
        guard points.count >= 2 else { return }
        let path = Path { p in
            p.move(to: points[0])
            for point in points.dropFirst() {
                p.addLine(to: point)
            }
        }
        context.stroke(path, with: .color(strokeColor), style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round))
    }

    func render(in context: CGContext, imageSize: CGSize) {
        guard points.count >= 2 else { return }
        context.setStrokeColor(NSColor(strokeColor).cgColor)
        context.setLineWidth(strokeWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.move(to: points[0])
        for point in points.dropFirst() {
            context.addLine(to: point)
        }
        context.strokePath()
    }
}

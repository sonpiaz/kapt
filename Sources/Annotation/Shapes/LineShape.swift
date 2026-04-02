import SwiftUI

struct LineShape: AnnotationShape {
    let id = ShapeID()
    var start: CGPoint
    var end: CGPoint
    var strokeColor: Color
    var strokeWidth: CGFloat

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let path = Path { p in
            p.move(to: start)
            p.addLine(to: end)
        }
        context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)
    }

    func render(in context: CGContext, imageSize: CGSize) {
        context.setStrokeColor(NSColor(strokeColor).cgColor)
        context.setLineWidth(strokeWidth)
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }
}

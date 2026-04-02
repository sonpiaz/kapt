import SwiftUI

struct RectShape: AnnotationShape {
    let id = ShapeID()
    var origin: CGPoint
    var size: CGSize
    var strokeColor: Color
    var strokeWidth: CGFloat

    var rect: CGRect {
        CGRect(origin: origin, size: size).standardized
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let path = Path(rect)
        context.stroke(path, with: .color(strokeColor), lineWidth: strokeWidth)
    }

    func render(in context: CGContext, imageSize: CGSize) {
        context.setStrokeColor(NSColor(strokeColor).cgColor)
        context.setLineWidth(strokeWidth)
        context.stroke(rect)
    }
}

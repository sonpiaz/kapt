import SwiftUI

struct ImageShape: AnnotationShape {
    let id = ShapeID()
    let cgImage: CGImage
    var origin: CGPoint
    var size: CGSize
    var strokeColor: Color = .clear
    var strokeWidth: CGFloat = 0

    var rect: CGRect { CGRect(origin: origin, size: size) }
    var boundingRect: CGRect { rect }
    var aspectRatio: CGFloat { CGFloat(cgImage.width) / CGFloat(cgImage.height) }

    func hitTest(point: CGPoint) -> Bool {
        rect.insetBy(dx: -4, dy: -4).contains(point)
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let image = Image(decorative: cgImage, scale: 1.0)
        context.draw(image, in: rect)
    }

    func render(in context: CGContext, imageSize: CGSize) {
        // Context is already flipped + scaled by flatten().
        // CGContext.draw() expects bottom-left origin, but we're in a flipped context,
        // so we need to locally un-flip for the image.
        context.saveGState()
        context.translateBy(x: origin.x, y: origin.y + size.height)
        context.scaleBy(x: 1, y: -1)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        context.restoreGState()
    }
}

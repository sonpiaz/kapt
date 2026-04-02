import SwiftUI

struct TextShape: AnnotationShape {
    let id = ShapeID()
    var position: CGPoint
    var text: String
    var fontSize: CGFloat
    var strokeColor: Color
    var strokeWidth: CGFloat // not used for text, but protocol conformance

    var boundingRect: CGRect {
        let font = NSFont.systemFont(ofSize: fontSize, weight: .medium)
        let size = (text as NSString).size(withAttributes: [.font: font])
        return CGRect(origin: position, size: size)
    }

    func hitTest(point: CGPoint) -> Bool {
        boundingRect.insetBy(dx: -8, dy: -8).contains(point)
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let resolved = context.resolve(
            Text(text)
                .font(.system(size: fontSize, weight: .medium))
                .foregroundStyle(strokeColor)
        )
        context.draw(resolved, at: position, anchor: .topLeading)
    }

    func render(in context: CGContext, imageSize: CGSize) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor(strokeColor),
        ]
        let nsString = text as NSString
        context.saveGState()
        context.textMatrix = .identity
        let textSize = nsString.size(withAttributes: attributes)
        nsString.draw(at: NSPoint(x: position.x, y: position.y - textSize.height), withAttributes: attributes)
        context.restoreGState()
    }
}

import SwiftUI

struct CounterShape: AnnotationShape {
    let id = ShapeID()
    var position: CGPoint
    var number: Int
    var strokeColor: Color
    var strokeWidth: CGFloat // unused

    private let circleRadius: CGFloat = 14

    func draw(in context: inout GraphicsContext, size: CGSize) {
        // Filled circle
        let circleRect = CGRect(
            x: position.x - circleRadius,
            y: position.y - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        let circlePath = Path(ellipseIn: circleRect)
        context.fill(circlePath, with: .color(strokeColor))

        // Number text
        let resolved = context.resolve(
            Text("\(number)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        )
        context.draw(resolved, at: position, anchor: .center)
    }

    func render(in context: CGContext, imageSize: CGSize) {
        let nsColor = NSColor(strokeColor)

        // Filled circle
        context.setFillColor(nsColor.cgColor)
        let circleRect = CGRect(
            x: position.x - circleRadius,
            y: position.y - circleRadius,
            width: circleRadius * 2,
            height: circleRadius * 2
        )
        context.fillEllipse(in: circleRect)

        // Number
        let text = "\(number)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.white,
        ]
        let textSize = text.size(withAttributes: attributes)
        text.draw(
            at: NSPoint(
                x: position.x - textSize.width / 2,
                y: position.y - textSize.height / 2
            ),
            withAttributes: attributes
        )
    }
}

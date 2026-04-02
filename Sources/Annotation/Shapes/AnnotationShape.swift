import SwiftUI

/// Unique identifier for each shape
typealias ShapeID = UUID

/// Base protocol for all annotation shapes
protocol AnnotationShape: Identifiable, Sendable {
    var id: ShapeID { get }
    var strokeColor: Color { get set }
    var strokeWidth: CGFloat { get set }

    /// Draw in SwiftUI Canvas context
    func draw(in context: inout GraphicsContext, size: CGSize)

    /// Render into a CGContext for final export
    func render(in context: CGContext, imageSize: CGSize)

    /// Hit test — does the point land on this shape?
    func hitTest(point: CGPoint) -> Bool
}

extension AnnotationShape {
    func hitTest(point: CGPoint) -> Bool { false }
}

/// All tool types
enum AnnotationToolType: String, CaseIterable, Identifiable {
    case select
    case arrow
    case rectangle
    case ellipse
    case line
    case freehand
    case text
    case blur
    case pixelate
    case counter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .select: "Select"
        case .arrow: "Arrow"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        case .line: "Line"
        case .freehand: "Freehand"
        case .text: "Text"
        case .blur: "Blur"
        case .pixelate: "Pixelate"
        case .counter: "Counter"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .arrow: "arrow.up.right"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        case .line: "line.diagonal"
        case .freehand: "pencil.and.scribble"
        case .text: "textformat"
        case .blur: "drop.halffull"
        case .pixelate: "square.grid.3x3.fill"
        case .counter: "number.circle"
        }
    }
}

import SwiftUI
import AppKit

@MainActor
@Observable
final class AnnotationState {
    let baseImage: CGImage
    var shapes: [any AnnotationShape] = []
    var undoStack: [[any AnnotationShape]] = []
    var redoStack: [[any AnnotationShape]] = []

    var activeTool: AnnotationToolType = .arrow
    var strokeColor: Color = .red
    var strokeWidth: CGFloat = 3
    var fontSize: CGFloat = 18
    var counterValue: Int = 1

    // Current shape being drawn (not yet committed)
    var currentShape: (any AnnotationShape)?

    // Selection state
    var selectedShapeID: ShapeID?

    // Text editing state
    var isEditingText = false
    var editingTextPosition: CGPoint = .zero
    var editingText: String = ""
    var editingShapeID: ShapeID?  // nil = new text, non-nil = editing existing

    init(baseImage: CGImage) {
        self.baseImage = baseImage
    }

    // MARK: - Shape Management

    func commitShape(_ shape: any AnnotationShape) {
        undoStack.append(shapes)
        redoStack.removeAll()
        shapes.append(shape)
        currentShape = nil
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(shapes)
        shapes = previous
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(shapes)
        shapes = next
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Selection

    func shapeAt(_ point: CGPoint) -> (any AnnotationShape)? {
        // Search in reverse so topmost shape is found first
        shapes.last(where: { $0.hitTest(point: point) })
    }

    var selectedShape: (any AnnotationShape)? {
        guard let id = selectedShapeID else { return nil }
        return shapes.first(where: { $0.id == id })
    }

    func updateShape(_ id: ShapeID, with newShape: any AnnotationShape) {
        undoStack.append(shapes)
        redoStack.removeAll()
        if let index = shapes.firstIndex(where: { $0.id == id }) {
            shapes[index] = newShape
        }
    }

    func deleteSelectedShape() {
        guard let id = selectedShapeID else { return }
        undoStack.append(shapes)
        redoStack.removeAll()
        shapes.removeAll(where: { $0.id == id })
        selectedShapeID = nil
    }

    // MARK: - Flatten (export)

    func flatten() -> CGImage? {
        let width = baseImage.width
        let height = baseImage.height
        let colorSpace = baseImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw base image
        context.draw(baseImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Apply blur/pixelate regions first (they modify the base image)
        var workingImage = baseImage
        for shape in shapes {
            if let blurRegion = shape as? BlurRegion {
                // Scale rect to image coordinates
                let scaleX = CGFloat(width) / canvasSize.width
                let scaleY = CGFloat(height) / canvasSize.height
                var scaledRegion = blurRegion
                scaledRegion.origin = CGPoint(x: blurRegion.origin.x * scaleX, y: blurRegion.origin.y * scaleY)
                scaledRegion.size = CGSize(width: blurRegion.size.width * scaleX, height: blurRegion.size.height * scaleY)
                if let blurred = scaledRegion.apply(to: workingImage) {
                    workingImage = blurred
                }
            }
        }

        // Redraw with blur applied
        context.draw(workingImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Flip context for correct text rendering
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Scale factor from canvas to image
        let scaleX = CGFloat(width) / canvasSize.width
        let scaleY = CGFloat(height) / canvasSize.height
        context.scaleBy(x: scaleX, y: scaleY)

        // Render non-blur shapes
        for shape in shapes {
            if shape is BlurRegion { continue }
            shape.render(in: context, imageSize: CGSize(width: width, height: height))
        }

        context.restoreGState()

        return context.makeImage()
    }

    /// Canvas display size (set by the AnnotationCanvas)
    var canvasSize: CGSize = CGSize(width: 800, height: 600)
}

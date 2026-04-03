import SwiftUI
import AppKit

enum ResizeHandle {
    case topLeft, topRight, bottomLeft, bottomRight
}

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

    // Zoom state
    var zoomScale: CGFloat = 1.0
    var zoomOffset: CGPoint = .zero // pan offset when zoomed
    static let zoomMin: CGFloat = 0.25
    static let zoomMax: CGFloat = 5.0
    static let zoomStep: CGFloat = 0.25

    func zoomIn() {
        zoomScale = min(zoomScale + Self.zoomStep, Self.zoomMax)
    }

    func zoomOut() {
        zoomScale = max(zoomScale - Self.zoomStep, Self.zoomMin)
    }

    func resetZoom() {
        zoomScale = 1.0
        zoomOffset = .zero
    }

    // Drag state — captured on drag start for smooth move/resize
    var dragInitialPosition: CGPoint?
    var dragInitialFontSize: CGFloat?
    var dragInitialSize: CGSize?
    var resizeHandle: ResizeHandle?
    var isDragging = false

    // Text editing state
    var isEditingText = false
    var editingTextPosition: CGPoint = .zero
    var editingText: String = ""
    var editingShapeID: ShapeID?  // nil = new text, non-nil = editing existing

    // Canvas expansion — how much extra space was added beyond the base image
    // All existing shapes use coordinates relative to canvas origin (0,0 = top-left of base image).
    // When canvas expands left/top, existing coords shift.
    var canvasExpansionRight: CGFloat = 0
    var canvasExpansionBottom: CGFloat = 0
    var canvasExpansionLeft: CGFloat = 0
    var canvasExpansionTop: CGFloat = 0

    /// Total canvas size including expansions (in display coordinates)
    var totalCanvasSize: CGSize {
        CGSize(
            width: canvasSize.width + canvasExpansionLeft + canvasExpansionRight,
            height: canvasSize.height + canvasExpansionTop + canvasExpansionBottom
        )
    }

    /// Whether the canvas has been expanded beyond the base image
    var isCanvasExpanded: Bool {
        canvasExpansionRight > 0 || canvasExpansionBottom > 0 ||
        canvasExpansionLeft > 0 || canvasExpansionTop > 0
    }

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

    /// Update shape in-place without pushing undo (for live drag frames)
    func liveUpdateShape(_ id: ShapeID, with newShape: any AnnotationShape) {
        if let index = shapes.firstIndex(where: { $0.id == id }) {
            shapes[index] = newShape
        }
    }

    /// Push undo snapshot for the current shapes (call before drag starts)
    func pushUndoSnapshot() {
        undoStack.append(shapes)
        redoStack.removeAll()
    }

    func deleteSelectedShape() {
        guard let id = selectedShapeID else { return }
        undoStack.append(shapes)
        redoStack.removeAll()
        shapes.removeAll(where: { $0.id == id })
        selectedShapeID = nil
    }

    // MARK: - Image Drop

    enum DropEdge {
        case right, left, top, bottom, none
    }

    /// Detect which edge zone the drop point is in
    func detectDropEdge(_ point: CGPoint) -> DropEdge {
        let totalSize = totalCanvasSize
        let edgeThreshold: CGFloat = totalSize.width * 0.15 // 15% from edge

        if point.x > totalSize.width - edgeThreshold { return .right }
        if point.x < edgeThreshold { return .left }
        if point.y > totalSize.height - edgeThreshold { return .bottom }
        if point.y < edgeThreshold { return .top }
        return .none
    }

    /// Add a dropped image — auto-layout if near edge, freeform otherwise
    func addDroppedImage(_ cgImage: CGImage, at dropPoint: CGPoint) {
        let edge = detectDropEdge(dropPoint)

        if edge != .none {
            addImageAtEdge(cgImage, edge: edge)
        } else {
            addImageFreeform(cgImage, at: dropPoint)
        }
    }

    /// Place image alongside the canvas at the given edge, expanding the canvas
    func addImageAtEdge(_ cgImage: CGImage, edge: DropEdge) {
        let totalSize = totalCanvasSize
        let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let gap: CGFloat = 4

        let displaySize: CGSize
        let origin: CGPoint

        switch edge {
        case .right:
            // Match height, place to the right
            let h = totalSize.height
            let w = h * imageAspect
            displaySize = CGSize(width: w, height: h)
            origin = CGPoint(x: totalSize.width + gap, y: 0)
            canvasExpansionRight += w + gap
        case .left:
            let h = totalSize.height
            let w = h * imageAspect
            displaySize = CGSize(width: w, height: h)
            // Shift all existing shapes right
            shiftAllShapes(dx: w + gap, dy: 0)
            origin = CGPoint(x: 0, y: 0)
            canvasExpansionLeft += w + gap
        case .bottom:
            // Match width, place below
            let w = totalSize.width
            let h = w / imageAspect
            displaySize = CGSize(width: w, height: h)
            origin = CGPoint(x: 0, y: totalSize.height + gap)
            canvasExpansionBottom += h + gap
        case .top:
            let w = totalSize.width
            let h = w / imageAspect
            displaySize = CGSize(width: w, height: h)
            shiftAllShapes(dx: 0, dy: h + gap)
            origin = CGPoint(x: 0, y: 0)
            canvasExpansionTop += h + gap
        case .none:
            addImageFreeform(cgImage, at: CGPoint(x: totalSize.width / 2, y: totalSize.height / 2))
            return
        }

        let imageShape = ImageShape(cgImage: cgImage, origin: origin, size: displaySize)
        commitShape(imageShape)
        selectedShapeID = imageShape.id
        activeTool = .select
    }

    /// Place image freely at drop point within canvas bounds
    private func addImageFreeform(_ cgImage: CGImage, at dropPoint: CGPoint) {
        let totalSize = totalCanvasSize
        let maxDimension = min(totalSize.width, totalSize.height) * 0.5
        let imageAspect = CGFloat(cgImage.width) / CGFloat(cgImage.height)
        let displaySize: CGSize
        if imageAspect > 1 {
            let w = min(CGFloat(cgImage.width) / 2, maxDimension)
            displaySize = CGSize(width: w, height: w / imageAspect)
        } else {
            let h = min(CGFloat(cgImage.height) / 2, maxDimension)
            displaySize = CGSize(width: h * imageAspect, height: h)
        }
        let origin = CGPoint(
            x: max(0, min(dropPoint.x - displaySize.width / 2, totalSize.width - displaySize.width)),
            y: max(0, min(dropPoint.y - displaySize.height / 2, totalSize.height - displaySize.height))
        )
        let imageShape = ImageShape(cgImage: cgImage, origin: origin, size: displaySize)
        commitShape(imageShape)
        selectedShapeID = imageShape.id
        activeTool = .select
    }

    /// Shift all existing shapes by dx/dy (when expanding left or top)
    private func shiftAllShapes(dx: CGFloat, dy: CGFloat) {
        for i in shapes.indices {
            if var img = shapes[i] as? ImageShape {
                img.origin.x += dx
                img.origin.y += dy
                shapes[i] = img
            } else if var txt = shapes[i] as? TextShape {
                txt.position.x += dx
                txt.position.y += dy
                shapes[i] = txt
            }
            // Other shapes (arrow, rect, etc.) have various position properties
            // but they're annotations on the base image, so they should shift too
        }
    }

    // MARK: - Flatten (export)

    func flatten() -> CGImage? {
        let colorSpace = baseImage.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!

        if isCanvasExpanded {
            return flattenExpanded(colorSpace: colorSpace)
        }

        let width = baseImage.width
        let height = baseImage.height

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

        context.draw(workingImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Flip context for correct text rendering
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        let scaleX = CGFloat(width) / canvasSize.width
        let scaleY = CGFloat(height) / canvasSize.height
        context.scaleBy(x: scaleX, y: scaleY)

        // Render image layers first (above base, below annotations)
        for shape in shapes where shape is ImageShape {
            shape.render(in: context, imageSize: CGSize(width: width, height: height))
        }

        // Render annotation shapes on top
        for shape in shapes {
            if shape is BlurRegion || shape is ImageShape { continue }
            shape.render(in: context, imageSize: CGSize(width: width, height: height))
        }

        context.restoreGState()
        return context.makeImage()
    }

    /// Flatten with expanded canvas — creates a new image larger than the base
    private func flattenExpanded(colorSpace: CGColorSpace) -> CGImage? {
        let totalDisplay = totalCanvasSize
        // Use the base image's pixel density to determine export resolution
        let pixelScale = CGFloat(baseImage.width) / canvasSize.width
        let exportWidth = Int(totalDisplay.width * pixelScale)
        let exportHeight = Int(totalDisplay.height * pixelScale)

        guard let context = CGContext(
            data: nil,
            width: exportWidth,
            height: exportHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Fill with white background
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: exportWidth, height: exportHeight))

        // Draw base image at its offset position (accounting for left/top expansion)
        let baseOffsetX = canvasExpansionLeft * pixelScale
        let baseOffsetY = canvasExpansionBottom * pixelScale // CGContext is bottom-left origin
        let baseWidth = CGFloat(baseImage.width)
        let baseHeight = CGFloat(baseImage.height)
        context.draw(baseImage, in: CGRect(x: baseOffsetX, y: baseOffsetY, width: baseWidth, height: baseHeight))

        // Flip context and scale for shape rendering
        context.saveGState()
        context.translateBy(x: 0, y: CGFloat(exportHeight))
        context.scaleBy(x: 1, y: -1)
        context.scaleBy(x: pixelScale, y: pixelScale)

        // Render image layers
        for shape in shapes where shape is ImageShape {
            shape.render(in: context, imageSize: CGSize(width: exportWidth, height: exportHeight))
        }

        // Render annotation shapes
        for shape in shapes {
            if shape is BlurRegion || shape is ImageShape { continue }
            shape.render(in: context, imageSize: CGSize(width: exportWidth, height: exportHeight))
        }

        context.restoreGState()
        return context.makeImage()
    }

    /// Canvas display size (set by the AnnotationCanvas)
    var canvasSize: CGSize = CGSize(width: 800, height: 600)
}

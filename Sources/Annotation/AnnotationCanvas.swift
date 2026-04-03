import SwiftUI
import UniformTypeIdentifiers

struct AnnotationCanvas: View {
    @Bindable var state: AnnotationState
    @FocusState private var isTextFieldFocused: Bool
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { geometry in
            let baseImageSize = fitSize(for: state.baseImage, in: geometry.size)
            let totalLogical = state.totalCanvasSize
            let displaySize = state.isCanvasExpanded
                ? fitExpandedSize(baseSize: baseImageSize, state: state, in: geometry.size)
                : baseImageSize
            // Scale from logical (totalCanvasSize) to display
            let renderScale = displaySize.width / totalLogical.width

            ZStack {
                // Canvas renders everything: background, base image, shapes
                Canvas { context, size in
                    // Apply scale so all shape coordinates (in logical space) map to display
                    var ctx = context
                    ctx.scaleBy(x: renderScale, y: renderScale)

                    if state.isCanvasExpanded {
                        // White background
                        ctx.fill(Path(CGRect(origin: .zero, size: totalLogical)),
                                    with: .color(.white))
                        // Base image at offset
                        ctx.draw(
                            Image(decorative: state.baseImage, scale: 1.0),
                            in: CGRect(
                                x: state.canvasExpansionLeft,
                                y: state.canvasExpansionTop,
                                width: state.canvasSize.width,
                                height: state.canvasSize.height
                            )
                        )
                    } else {
                        ctx.draw(
                            Image(decorative: state.baseImage, scale: 1.0),
                            in: CGRect(origin: .zero, size: totalLogical)
                        )
                    }

                    // Draw all shapes (coordinates are in logical space)
                    for shape in state.shapes {
                        var mCtx = ctx
                        shape.draw(in: &mCtx, size: totalLogical)
                    }
                    if let current = state.currentShape {
                        var mCtx = ctx
                        current.draw(in: &mCtx, size: totalLogical)
                    }
                    if let selected = state.selectedShape {
                        drawSelectionIndicator(for: selected, in: &ctx)
                    }
                }
                .frame(width: displaySize.width, height: displaySize.height)
                .contentShape(Rectangle())
                .gesture(canvasGesture(canvasSize: displaySize, renderScale: renderScale))
                .onTapGesture(count: 2) { location in
                    // Convert display coords to logical coords
                    let logical = CGPoint(x: location.x / renderScale, y: location.y / renderScale)
                    handleDoubleTap(at: logical)
                }
                .onTapGesture { location in
                    let logical = CGPoint(x: location.x / renderScale, y: location.y / renderScale)
                    handleTap(at: logical, canvasSize: totalLogical)
                }

                if state.isEditingText {
                    textEditingOverlay(canvasSize: displaySize)
                }
            }
            .overlay {
                if isDropTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .background(Color.accentColor.opacity(0.05))
                        .frame(width: displaySize.width, height: displaySize.height)
                        .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.image, .fileURL], isTargeted: $isDropTargeted) { providers, location in
                let canvasOrigin = CGPoint(
                    x: (geometry.size.width - displaySize.width) / 2,
                    y: (geometry.size.height - displaySize.height) / 2
                )
                // Convert display drop point to logical coords
                let canvasPoint = CGPoint(
                    x: (location.x - canvasOrigin.x) / renderScale,
                    y: (location.y - canvasOrigin.y) / renderScale
                )
                handleImageDrop(providers: providers, at: canvasPoint)
                return true
            }
            .frame(width: displaySize.width, height: displaySize.height)
            .scaleEffect(state.zoomScale)
            .offset(x: state.zoomOffset.x, y: state.zoomOffset.y)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
            .clipped()
            .background {
                ScrollWheelZoomView(state: state)
            }
            .onAppear {
                state.canvasSize = baseImageSize
            }
            .onChange(of: geometry.size) {
                state.canvasSize = fitSize(for: state.baseImage, in: geometry.size)
            }
            .onKeyPress(.delete) {
                if state.selectedShapeID != nil {
                    state.deleteSelectedShape()
                    return .handled
                }
                return .ignored
            }
        }
    }

    // MARK: - Selection Indicator

    private func drawSelectionIndicator(for shape: any AnnotationShape, in context: inout GraphicsContext) {
        if let textShape = shape as? TextShape {
            let rect = textShape.boundingRect.insetBy(dx: -6, dy: -6)
            let path = Path(roundedRect: rect, cornerRadius: 4)
            context.stroke(path, with: .color(.accentColor.opacity(0.8)),
                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        } else if let imageShape = shape as? ImageShape {
            let rect = imageShape.rect
            let path = Path(rect)
            context.stroke(path, with: .color(.accentColor.opacity(0.8)),
                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            // 4 corner handles
            for corner in [
                CGPoint(x: rect.minX, y: rect.minY),
                CGPoint(x: rect.maxX, y: rect.minY),
                CGPoint(x: rect.minX, y: rect.maxY),
                CGPoint(x: rect.maxX, y: rect.maxY),
            ] {
                drawHandle(at: corner, in: &context)
            }
        }
    }

    private func drawHandle(at point: CGPoint, in context: inout GraphicsContext) {
        let handleSize: CGFloat = 10
        let handleRect = CGRect(
            x: point.x - handleSize / 2,
            y: point.y - handleSize / 2,
            width: handleSize, height: handleSize
        )
        let handlePath = Path(ellipseIn: handleRect)
        context.stroke(handlePath, with: .color(.white), lineWidth: 2)
        context.fill(handlePath, with: .color(.accentColor))
    }

    // MARK: - Gestures

    private func canvasGesture(canvasSize: CGSize, renderScale: CGFloat = 1.0) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                // Convert display coordinates to logical coordinates
                let start = CGPoint(x: value.startLocation.x / renderScale, y: value.startLocation.y / renderScale)
                let current = CGPoint(x: value.location.x / renderScale, y: value.location.y / renderScale)

                switch state.activeTool {
                case .select:
                    handleSelectDrag(start: start, current: current)
                case .arrow:
                    state.currentShape = ArrowShape(
                        start: start, end: current,
                        strokeColor: state.strokeColor, strokeWidth: state.strokeWidth
                    )
                case .rectangle:
                    state.currentShape = RectShape(
                        origin: start,
                        size: CGSize(width: current.x - start.x, height: current.y - start.y),
                        strokeColor: state.strokeColor, strokeWidth: state.strokeWidth
                    )
                case .ellipse:
                    state.currentShape = EllipseShape(
                        origin: start,
                        size: CGSize(width: current.x - start.x, height: current.y - start.y),
                        strokeColor: state.strokeColor, strokeWidth: state.strokeWidth
                    )
                case .line:
                    state.currentShape = LineShape(
                        start: start, end: current,
                        strokeColor: state.strokeColor, strokeWidth: state.strokeWidth
                    )
                case .freehand:
                    if var freehand = state.currentShape as? FreehandShape {
                        freehand.points.append(current)
                        state.currentShape = freehand
                    } else {
                        state.currentShape = FreehandShape(
                            points: [start, current],
                            strokeColor: state.strokeColor, strokeWidth: state.strokeWidth
                        )
                    }
                case .blur:
                    state.currentShape = BlurRegion(
                        origin: start,
                        size: CGSize(width: current.x - start.x, height: current.y - start.y),
                        strokeColor: state.strokeColor, strokeWidth: state.strokeWidth,
                        isPixelate: false
                    )
                case .pixelate:
                    state.currentShape = BlurRegion(
                        origin: start,
                        size: CGSize(width: current.x - start.x, height: current.y - start.y),
                        strokeColor: state.strokeColor, strokeWidth: state.strokeWidth,
                        isPixelate: true
                    )
                case .text, .counter:
                    break
                }
            }
            .onEnded { value in
                switch state.activeTool {
                case .select:
                    endSelectDrag()
                default:
                    if let shape = state.currentShape {
                        state.commitShape(shape)
                    }
                }
            }
    }

    // MARK: - Select Tool Drag (move or resize)

    private func handleSelectDrag(start: CGPoint, current: CGPoint) {
        guard let id = state.selectedShapeID else { return }

        // TextShape move only (font size changed via toolbar, not drag)
        if var textShape = state.shapes.first(where: { $0.id == id }) as? TextShape {
            if !state.isDragging {
                guard textShape.boundingRect.insetBy(dx: -8, dy: -8).contains(start) else { return }
                state.isDragging = true
                state.dragInitialPosition = textShape.position
                state.pushUndoSnapshot()
            }
            guard let initialPos = state.dragInitialPosition else { return }
            textShape.position = CGPoint(
                x: initialPos.x + (current.x - start.x),
                y: initialPos.y + (current.y - start.y)
            )
            state.liveUpdateShape(id, with: textShape)
            return
        }

        // ImageShape move/resize
        if var imageShape = state.shapes.first(where: { $0.id == id }) as? ImageShape {
            if !state.isDragging {
                state.isDragging = true
                state.dragInitialPosition = imageShape.origin
                state.dragInitialSize = imageShape.size
                state.pushUndoSnapshot()
                state.resizeHandle = detectResizeHandle(for: imageShape, at: start)
            }

            if let handle = state.resizeHandle {
                guard let initialSize = state.dragInitialSize,
                      let initialOrigin = state.dragInitialPosition else { return }
                let dx = current.x - start.x

                // Calculate new width based on which handle and drag direction
                let newWidth: CGFloat
                switch handle {
                case .bottomRight, .topRight:
                    newWidth = max(40, initialSize.width + dx)
                case .bottomLeft, .topLeft:
                    newWidth = max(40, initialSize.width - dx)
                }
                let newHeight = newWidth / imageShape.aspectRatio

                switch handle {
                case .bottomRight:
                    imageShape.size = CGSize(width: newWidth, height: newHeight)
                case .bottomLeft:
                    imageShape.origin.x = initialOrigin.x + initialSize.width - newWidth
                    imageShape.size = CGSize(width: newWidth, height: newHeight)
                case .topRight:
                    imageShape.origin.y = initialOrigin.y + initialSize.height - newHeight
                    imageShape.size = CGSize(width: newWidth, height: newHeight)
                case .topLeft:
                    imageShape.origin = CGPoint(
                        x: initialOrigin.x + initialSize.width - newWidth,
                        y: initialOrigin.y + initialSize.height - newHeight
                    )
                    imageShape.size = CGSize(width: newWidth, height: newHeight)
                }
            } else if imageShape.rect.insetBy(dx: -8, dy: -8).contains(start) {
                guard let initialPos = state.dragInitialPosition else { return }
                imageShape.origin = CGPoint(
                    x: initialPos.x + (current.x - start.x),
                    y: initialPos.y + (current.y - start.y)
                )
            }
            state.liveUpdateShape(id, with: imageShape)
        }
    }

    private func endSelectDrag() {
        state.isDragging = false
        state.dragInitialPosition = nil
        state.dragInitialFontSize = nil
        state.dragInitialSize = nil
        state.resizeHandle = nil
    }

    private func detectResizeHandle(for shape: ImageShape, at point: CGPoint) -> ResizeHandle? {
        let rect = shape.rect
        let handleSize: CGFloat = 12
        let corners: [(CGPoint, ResizeHandle)] = [
            (CGPoint(x: rect.maxX, y: rect.maxY), .bottomRight),
            (CGPoint(x: rect.minX, y: rect.maxY), .bottomLeft),
            (CGPoint(x: rect.maxX, y: rect.minY), .topRight),
            (CGPoint(x: rect.minX, y: rect.minY), .topLeft),
        ]
        for (corner, handle) in corners {
            let hitRect = CGRect(
                x: corner.x - handleSize, y: corner.y - handleSize,
                width: handleSize * 2, height: handleSize * 2
            )
            if hitRect.contains(point) { return handle }
        }
        return nil
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, canvasSize: CGSize) {
        switch state.activeTool {
        case .select:
            // Select shape under cursor
            if let shape = state.shapeAt(location) {
                state.selectedShapeID = shape.id
            } else {
                state.selectedShapeID = nil
            }
        case .text:
            startTextEditing(at: location, existingShape: nil)
        case .counter:
            let counter = CounterShape(
                position: location,
                number: state.counterValue,
                strokeColor: state.strokeColor,
                strokeWidth: state.strokeWidth
            )
            state.commitShape(counter)
            state.counterValue += 1
        default:
            break
        }
    }

    private func handleDoubleTap(at location: CGPoint) {
        // Double-click on text shape = re-edit it
        if let shape = state.shapeAt(location), let textShape = shape as? TextShape {
            startTextEditing(at: textShape.position, existingShape: textShape)
        }
    }

    private func startTextEditing(at position: CGPoint, existingShape: TextShape?) {
        state.editingTextPosition = position
        state.editingText = existingShape?.text ?? ""
        state.editingShapeID = existingShape?.id
        if let existing = existingShape {
            state.fontSize = existing.fontSize
            state.strokeColor = existing.strokeColor
        }
        state.isEditingText = true
    }

    // MARK: - Text Editing Overlay

    @ViewBuilder
    private func textEditingOverlay(canvasSize: CGSize) -> some View {
        // Scrim to focus attention on text input
        Color.black.opacity(0.15)
            .contentShape(Rectangle())
            .onTapGesture {
                commitTextIfNeeded()
            }
            .overlay {
                VStack(spacing: 0) {
                    TextField("Type text...", text: $state.editingText)
                        .textFieldStyle(.plain)
                        .font(.system(size: state.fontSize, weight: .medium))
                        .foregroundStyle(state.strokeColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .frame(width: 260)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.accentColor.opacity(0.5), lineWidth: 1)
                        )
                        .focused($isTextFieldFocused)
                        .onAppear { isTextFieldFocused = true }
                        .onSubmit {
                            commitTextIfNeeded()
                        }
                        .onKeyPress(.escape) {
                            state.isEditingText = false
                            return .handled
                        }
                    // Hint
                    Text("Return to commit · ESC to cancel")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .position(
                    x: min(max(state.editingTextPosition.x, 140), canvasSize.width - 140),
                    y: state.editingTextPosition.y
                )
            }
    }

    private func commitTextIfNeeded() {
        if !state.editingText.isEmpty {
            if let existingID = state.editingShapeID,
               var existing = state.shapes.first(where: { $0.id == existingID }) as? TextShape {
                // Update existing text shape in place (keeps same ID)
                existing.text = state.editingText
                existing.fontSize = state.fontSize
                existing.strokeColor = state.strokeColor
                state.updateShape(existingID, with: existing)
            } else {
                // New text shape
                let textShape = TextShape(
                    position: state.editingTextPosition,
                    text: state.editingText,
                    fontSize: state.fontSize,
                    strokeColor: state.strokeColor,
                    strokeWidth: state.strokeWidth
                )
                state.commitShape(textShape)
            }
        } else if let existingID = state.editingShapeID {
            // Empty text = delete shape
            state.selectedShapeID = existingID
            state.deleteSelectedShape()
        }
        state.isEditingText = false
        state.editingShapeID = nil
    }

    // MARK: - Helpers

    // MARK: - Image Drop

    private func handleImageDrop(providers: [NSItemProvider], at location: CGPoint) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { image, _ in
                    guard let nsImage = image as? NSImage,
                          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    else { return }
                    Task { @MainActor in
                        state.addDroppedImage(cgImage, at: location)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    guard let data = data as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil),
                          let nsImage = NSImage(contentsOf: url),
                          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
                    else { return }
                    Task { @MainActor in
                        state.addDroppedImage(cgImage, at: location)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func fitSize(for image: CGImage, in containerSize: CGSize) -> CGSize {
        let imageAspect = CGFloat(image.width) / CGFloat(image.height)
        let containerAspect = containerSize.width / containerSize.height

        if imageAspect > containerAspect {
            let width = containerSize.width
            return CGSize(width: width, height: width / imageAspect)
        } else {
            let height = containerSize.height
            return CGSize(width: height * imageAspect, height: height)
        }
    }

    /// Fit the expanded canvas (totalCanvasSize) into the container
    private func fitExpandedSize(baseSize: CGSize, state: AnnotationState, in containerSize: CGSize) -> CGSize {
        let total = state.totalCanvasSize
        let aspect = total.width / total.height
        let containerAspect = containerSize.width / containerSize.height

        if aspect > containerAspect {
            let width = containerSize.width
            return CGSize(width: width, height: width / aspect)
        } else {
            let height = containerSize.height
            return CGSize(width: height * aspect, height: height)
        }
    }
}

// MARK: - Scroll Wheel Zoom (NSView overlay that captures ⌘+scroll for zoom)

struct ScrollWheelZoomView: NSViewRepresentable {
    let state: AnnotationState

    func makeNSView(context: Context) -> ScrollWheelNSView {
        let view = ScrollWheelNSView()
        view.state = state
        return view
    }

    func updateNSView(_ nsView: ScrollWheelNSView, context: Context) {
        nsView.state = state
    }
}

@MainActor
final class ScrollWheelNSView: NSView {
    var state: AnnotationState?
    private var scrollMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil && scrollMonitor == nil {
            scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, let state = self.state else { return event }
                // Only handle when our window is key
                guard event.window === self.window else { return event }

                let delta = event.scrollingDeltaY
                guard abs(delta) > 0.5 else { return event }

                // Pinch-to-zoom (magnify) or ⌘+scroll
                if event.modifierFlags.contains(.command) {
                    let factor: CGFloat = delta > 0 ? 1.05 : 0.95
                    state.zoomScale = max(AnnotationState.zoomMin,
                                          min(state.zoomScale * factor, AnnotationState.zoomMax))
                    return nil // consume event
                }
                return event
            }
        }
    }

    override func removeFromSuperview() {
        if let monitor = scrollMonitor {
            NSEvent.removeMonitor(monitor)
            scrollMonitor = nil
        }
        super.removeFromSuperview()
    }
}

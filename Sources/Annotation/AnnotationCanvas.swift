import SwiftUI

struct AnnotationCanvas: View {
    @Bindable var state: AnnotationState
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            let imageSize = fitSize(for: state.baseImage, in: geometry.size)

            ZStack {
                // Base image
                Image(decorative: state.baseImage, scale: 1.0)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: imageSize.width, height: imageSize.height)

                // Canvas overlay for shapes
                Canvas { context, size in
                    for shape in state.shapes {
                        var mutableContext = context
                        shape.draw(in: &mutableContext, size: size)
                    }
                    if let current = state.currentShape {
                        var mutableContext = context
                        current.draw(in: &mutableContext, size: size)
                    }
                    // Draw selection indicator
                    if let selected = state.selectedShape {
                        drawSelectionIndicator(for: selected, in: &context)
                    }
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .gesture(canvasGesture(canvasSize: imageSize))
                .onTapGesture(count: 2) { location in
                    handleDoubleTap(at: location)
                }
                .onTapGesture { location in
                    handleTap(at: location, canvasSize: imageSize)
                }

                // Text editing overlay
                if state.isEditingText {
                    textEditingOverlay(canvasSize: imageSize)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .onAppear {
                state.canvasSize = imageSize
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
            // Dashed selection border
            let path = Path(roundedRect: rect, cornerRadius: 4)
            context.stroke(path, with: .color(.accentColor.opacity(0.8)),
                          style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))

            // Resize handle — accent circle with white stroke + shadow
            let handleSize: CGFloat = 10
            let handleRect = CGRect(
                x: rect.maxX - handleSize / 2,
                y: rect.maxY - handleSize / 2,
                width: handleSize, height: handleSize
            )
            let handlePath = Path(ellipseIn: handleRect)
            // White outline
            context.stroke(handlePath, with: .color(.white), lineWidth: 2)
            // Accent fill
            context.fill(handlePath, with: .color(.accentColor))
        }
    }

    // MARK: - Gestures

    private func canvasGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = value.startLocation
                let current = value.location

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
        guard let id = state.selectedShapeID,
              var textShape = state.shapes.first(where: { $0.id == id }) as? TextShape else { return }

        let rect = textShape.boundingRect
        let handleRect = CGRect(x: rect.maxX - 8, y: rect.maxY - 8, width: 16, height: 16)

        if handleRect.contains(start) {
            // Resize: change fontSize based on vertical drag distance
            let dy = current.y - start.y
            let newSize = max(10, textShape.fontSize + dy * 0.3)
            textShape.fontSize = newSize
        } else if rect.insetBy(dx: -8, dy: -8).contains(start) {
            // Move
            let dx = current.x - start.x
            let dy = current.y - start.y
            textShape.position = CGPoint(
                x: textShape.position.x + dx,
                y: textShape.position.y + dy
            )
        }

        // Live update (don't push undo on every drag frame)
        if let index = state.shapes.firstIndex(where: { $0.id == id }) {
            state.shapes[index] = textShape
        }
    }

    private func endSelectDrag() {
        // Drag ended — undo state was not pushed during drag.
        // We could push here, but for simplicity we skip.
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
}

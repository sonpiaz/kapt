import SwiftUI

struct AnnotationCanvas: View {
    @Bindable var state: AnnotationState

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
                    // Draw committed shapes
                    for shape in state.shapes {
                        var mutableContext = context
                        shape.draw(in: &mutableContext, size: size)
                    }
                    // Draw current shape being drawn
                    if let current = state.currentShape {
                        var mutableContext = context
                        current.draw(in: &mutableContext, size: size)
                    }
                }
                .frame(width: imageSize.width, height: imageSize.height)
                .gesture(drawGesture(canvasSize: imageSize))
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
        }
    }

    // MARK: - Drawing Gesture

    private func drawGesture(canvasSize: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                let start = value.startLocation
                let current = value.location

                switch state.activeTool {
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
                    break // Handled by tap
                }
            }
            .onEnded { _ in
                if let shape = state.currentShape {
                    state.commitShape(shape)
                }
            }
    }

    // MARK: - Tap Handling

    private func handleTap(at location: CGPoint, canvasSize: CGSize) {
        switch state.activeTool {
        case .text:
            state.editingTextPosition = location
            state.editingText = ""
            state.isEditingText = true
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

    // MARK: - Text Editing Overlay

    @ViewBuilder
    private func textEditingOverlay(canvasSize: CGSize) -> some View {
        VStack {
            TextField("Type text...", text: $state.editingText)
                .textFieldStyle(.plain)
                .font(.system(size: state.fontSize, weight: .medium))
                .foregroundStyle(state.strokeColor)
                .padding(4)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .frame(width: 200)
                .onSubmit {
                    if !state.editingText.isEmpty {
                        let textShape = TextShape(
                            position: state.editingTextPosition,
                            text: state.editingText,
                            fontSize: state.fontSize,
                            strokeColor: state.strokeColor,
                            strokeWidth: state.strokeWidth
                        )
                        state.commitShape(textShape)
                    }
                    state.isEditingText = false
                }
                .onKeyPress(.escape) {
                    state.isEditingText = false
                    return .handled
                }
        }
        .position(x: state.editingTextPosition.x + 100, y: state.editingTextPosition.y)
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

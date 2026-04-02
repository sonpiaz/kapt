import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct BlurRegion: AnnotationShape {
    let id = ShapeID()
    var origin: CGPoint
    var size: CGSize
    var strokeColor: Color // unused but protocol conformance
    var strokeWidth: CGFloat // blur radius
    var isPixelate: Bool = false

    var rect: CGRect {
        CGRect(origin: origin, size: size).standardized
    }

    func draw(in context: inout GraphicsContext, size: CGSize) {
        // In Canvas, we draw a semi-transparent indicator
        let path = Path(rect)
        context.stroke(path, with: .color(.white.opacity(0.5)), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        context.fill(path, with: .color(.gray.opacity(0.3)))

        // Label
        let label = isPixelate ? "Pixelate" : "Blur"
        let resolved = context.resolve(
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white)
        )
        context.draw(resolved, at: CGPoint(x: rect.midX, y: rect.midY), anchor: .center)
    }

    func render(in context: CGContext, imageSize: CGSize) {
        // Blur/pixelate is applied during flatten — see AnnotationState.flatten()
    }

    /// Apply blur/pixelate effect on a CGImage for the specified region
    func apply(to image: CGImage) -> CGImage? {
        let ciImage = CIImage(cgImage: image)
        let ciContext = CIContext(options: [.useSoftwareRenderer: false])

        // Convert rect to CIImage coordinates (origin at bottom-left)
        let imageHeight = CGFloat(image.height)
        let ciRect = CGRect(
            x: rect.origin.x,
            y: imageHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        let cropped = ciImage.cropped(to: ciRect)

        let filtered: CIImage
        if isPixelate {
            let pixelate = CIFilter.pixellate()
            pixelate.inputImage = cropped
            pixelate.scale = Float(max(strokeWidth * 2, 8))
            pixelate.center = CGPoint(x: ciRect.midX, y: ciRect.midY)
            filtered = pixelate.outputImage ?? cropped
        } else {
            let blur = CIFilter.gaussianBlur()
            blur.inputImage = cropped
            blur.radius = Float(max(strokeWidth * 3, 10))
            filtered = blur.outputImage?.cropped(to: ciRect) ?? cropped
        }

        // Composite filtered region back onto original
        let composited = filtered.composited(over: ciImage)

        guard let result = ciContext.createCGImage(composited, from: ciImage.extent) else {
            return nil
        }
        return result
    }
}

import CoreGraphics
import AppKit

/// Stitches multiple overlapping screenshot frames into one tall image
enum FrameStitcher {

    /// Stitch an array of frames (captured top-to-bottom) into a single tall image
    static func stitch(frames: [CGImage]) -> CGImage? {
        guard !frames.isEmpty else { return nil }
        if frames.count == 1 { return frames[0] }

        // Step 1: Detect sticky header/footer heights
        let stickyTop = detectStickyRows(frames: frames, from: .top)
        let stickyBottom = detectStickyRows(frames: frames, from: .bottom)

        // Step 2: Find overlap between consecutive frames
        var cropOffsets: [Int] = [0] // first frame: no crop
        for i in 1..<frames.count {
            let overlap = findOverlap(
                previous: frames[i - 1],
                current: frames[i],
                stickyTop: stickyTop,
                stickyBottom: stickyBottom
            )
            cropOffsets.append(overlap)
        }

        // Step 3: Calculate total height
        let width = frames[0].width
        var totalHeight = 0
        for (i, frame) in frames.enumerated() {
            let cropTop = cropOffsets[i]
            // For frames after the first, also crop sticky regions that duplicate
            let effectiveHeight = frame.height - cropTop
            totalHeight += effectiveHeight
        }

        // Step 4: Composite into one CGContext
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: totalHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw from top to bottom (CGContext origin is bottom-left, so we flip)
        var yOffset = totalHeight
        for (i, frame) in frames.enumerated() {
            let cropTop = cropOffsets[i]
            let drawHeight = frame.height - cropTop

            // Crop the top overlap from this frame
            let cropped: CGImage
            if cropTop > 0 {
                let cropRect = CGRect(x: 0, y: cropTop, width: frame.width, height: drawHeight)
                guard let c = frame.cropping(to: cropRect) else { continue }
                cropped = c
            } else {
                cropped = frame
            }

            yOffset -= drawHeight
            ctx.draw(cropped, in: CGRect(x: 0, y: yOffset, width: width, height: drawHeight))
        }

        return ctx.makeImage()
    }

    // MARK: - Overlap Detection

    /// Find how many pixels of the top of `current` overlap with the bottom of `previous`
    private static func findOverlap(
        previous: CGImage,
        current: CGImage,
        stickyTop: Int,
        stickyBottom: Int
    ) -> Int {
        let stripHeight = min(80, previous.height / 4)
        let searchRange = min(current.height * 3 / 4, previous.height)

        // Extract bottom strip of previous frame (excluding sticky footer)
        let stripY = previous.height - stripHeight - stickyBottom
        guard stripY > 0,
              let strip = previous.cropping(to: CGRect(
                  x: 0, y: stripY,
                  width: previous.width, height: stripHeight
              )),
              let stripData = pixelData(for: strip)
        else { return stickyTop } // fallback: just crop sticky header

        // Slide the strip down the current frame to find best match
        var bestOffset = stickyTop
        var bestScore = Int.max

        // Sample every 2px for speed, then refine
        let coarseStep = 2
        var candidateOffsets: [Int] = []

        for offset in stride(from: stickyTop, to: searchRange - stripHeight, by: coarseStep) {
            guard let region = current.cropping(to: CGRect(
                x: 0, y: offset,
                width: current.width, height: stripHeight
            )),
                  let regionData = pixelData(for: region)
            else { continue }

            let score = comparePixels(stripData, regionData, sampleStep: 4)
            if score < bestScore {
                bestScore = score
                bestOffset = offset
                candidateOffsets = [offset]
            } else if score == bestScore {
                candidateOffsets.append(offset)
            }
        }

        // Refine around best coarse match
        if coarseStep > 1 {
            let refineStart = max(stickyTop, bestOffset - coarseStep)
            let refineEnd = min(searchRange - stripHeight, bestOffset + coarseStep)
            for offset in refineStart...refineEnd {
                guard let region = current.cropping(to: CGRect(
                    x: 0, y: offset,
                    width: current.width, height: stripHeight
                )),
                      let regionData = pixelData(for: region)
                else { continue }

                let score = comparePixels(stripData, regionData, sampleStep: 1)
                if score < bestScore {
                    bestScore = score
                    bestOffset = offset
                }
            }
        }

        // If best score is too high, frames don't overlap meaningfully
        let threshold = stripData.count / 4 // ~25% average diff per byte
        if bestScore > threshold {
            return stickyTop // no good overlap found, just crop sticky header
        }

        // The overlap is: everything from top of current frame to bestOffset + stripHeight
        return bestOffset + stripHeight
    }

    // MARK: - Sticky Element Detection

    enum Edge { case top, bottom }

    /// Detect rows that are identical across all frames (sticky headers/footers)
    private static func detectStickyRows(frames: [CGImage], from edge: Edge) -> Int {
        guard frames.count >= 3 else { return 0 }

        let maxCheck = min(200, frames[0].height / 4) // check up to 200px
        let sampleFrames = [frames[0], frames[frames.count / 2], frames.last!]

        for rowCount in stride(from: maxCheck, through: 1, by: -1) {
            let y: Int
            switch edge {
            case .top: y = 0
            case .bottom: y = frames[0].height - rowCount
            }

            let rect = CGRect(x: 0, y: y, width: frames[0].width, height: rowCount)
            guard let ref = sampleFrames[0].cropping(to: rect),
                  let refData = pixelData(for: ref) else { continue }

            var allMatch = true
            for frame in sampleFrames.dropFirst() {
                guard let strip = frame.cropping(to: rect),
                      let stripData = pixelData(for: strip) else {
                    allMatch = false
                    break
                }
                let diff = comparePixels(refData, stripData, sampleStep: 2)
                if diff > refData.count / 20 { // 5% tolerance
                    allMatch = false
                    break
                }
            }

            if allMatch {
                return rowCount
            }
        }
        return 0
    }

    // MARK: - Pixel Comparison Helpers

    private static func pixelData(for image: CGImage) -> [UInt8]? {
        let w = image.width
        let h = image.height
        let bytesPerRow = w * 4
        var data = [UInt8](repeating: 0, count: h * bytesPerRow)
        guard let ctx = CGContext(
            data: &data,
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return data
    }

    /// Sum of absolute differences between two pixel arrays, sampling every `sampleStep` bytes
    private static func comparePixels(_ a: [UInt8], _ b: [UInt8], sampleStep: Int) -> Int {
        let count = min(a.count, b.count)
        var sum = 0
        var i = 0
        while i < count {
            sum += abs(Int(a[i]) - Int(b[i]))
            i += sampleStep
        }
        return sum
    }
}

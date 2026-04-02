import SwiftUI
import AppKit

struct QuickAccessView: View {
    let image: CGImage
    let onCopy: () -> Void
    let onSave: () -> Void
    let onAnnotate: () -> Void
    let onOCR: () -> Void
    let onDismiss: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail preview
            Image(decorative: image, scale: 1.0)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 280, maxHeight: 160)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(8)
                .onDrag {
                    let provider = NSItemProvider()
                    if let data = image.pngData {
                        provider.registerDataRepresentation(forTypeIdentifier: "public.png", visibility: .all) { completion in
                            completion(data, nil)
                            return nil
                        }
                    }
                    return provider
                }

            Divider()

            // Action buttons
            HStack(spacing: 2) {
                quickButton("Copy", systemImage: "doc.on.doc") { onCopy() }
                quickButton("Save", systemImage: "square.and.arrow.down") { onSave() }
                quickButton("Annotate", systemImage: "pencil.tip.crop.circle") { onAnnotate() }
                quickButton("OCR", systemImage: "text.viewfinder") { onOCR() }
                Spacer()
                quickButton("", systemImage: "xmark") { onDismiss() }
                    .frame(width: 30)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
        }
        .frame(width: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        )
    }

    private func quickButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.001)) // hit area
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

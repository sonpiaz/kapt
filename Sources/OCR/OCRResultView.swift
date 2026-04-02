import SwiftUI
import AppKit

struct OCRResultView: View {
    let text: String
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recognized Text")
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy All", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
            }
            .padding(12)

            Divider()

            if text.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No text recognized")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    Text(text)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
            }
        }
        .frame(width: 400, height: 300)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

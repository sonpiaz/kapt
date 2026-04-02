import SwiftUI
import AppKit

struct OCRResultView: View {
    let text: String
    @State private var copied = false

    private var wordCount: Int {
        text.split(separator: " ").count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Recognized Text")
                    .font(.headline)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    withAnimation(.easeInOut(duration: 0.2)) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            copied = false
                        }
                    }
                } label: {
                    Label(copied ? "Copied!" : "Copy All",
                          systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                        .font(.system(size: 12))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.bordered)
                .tint(copied ? .green : nil)
            }
            .padding(12)

            Divider().padding(.horizontal, 12)

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
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }

                Divider().padding(.horizontal, 12)

                // Footer with stats
                HStack {
                    Text("\(wordCount) words · \(text.count) chars")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        }
        .frame(width: 440, height: 340)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

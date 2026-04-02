import SwiftUI

struct AnnotationEditorView: View {
    @Bindable var state: AnnotationState
    let onDone: (CGImage?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top toolbar
            AnnotationToolbar(state: state)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)

            Divider()

            // Canvas
            AnnotationCanvas(state: state)
                .padding(4)

            Divider()

            // Bottom bar — Cancel / Done
            HStack {
                Spacer()
                Button("Cancel") {
                    onDone(nil)
                }
                .keyboardShortcut(.cancelAction)

                Button("Done") {
                    let result = state.flatten()
                    onDone(result)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

import SwiftUI

struct AnnotationEditorView: View {
    @Bindable var state: AnnotationState
    let onDone: (CGImage?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                AnnotationToolbar(state: state)

                Spacer()

                HStack(spacing: 8) {
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
                .padding(.trailing, 8)
            }
            .padding(8)
            .background(.ultraThinMaterial)

            // Canvas
            AnnotationCanvas(state: state)
                .padding(8)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

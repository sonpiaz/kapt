import SwiftUI

struct AnnotationEditorView: View {
    @Bindable var state: AnnotationState
    let onDone: (CGImage?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Unified title-bar toolbar
            AnnotationToolbar(
                state: state,
                onSaveAs: { saveAs() },
                onDone: { done() }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(.ultraThinMaterial)

            Divider()

            // Canvas
            AnnotationCanvas(state: state)
                .padding(4)

            Divider()

            // Bottom action bar
            AnnotationBottomBar(state: state)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(.ultraThinMaterial)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        // Hidden Escape handler (window close = cancel)
        .background {
            Button("") { onDone(nil) }
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
        }
    }

    private func done() {
        let result = state.flatten()
        onDone(result)
    }

    private func saveAs() {
        guard let image = state.flatten() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Kapt Annotated.png"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? image.savePNG(to: url)
        }
    }
}

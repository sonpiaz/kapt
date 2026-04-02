import SwiftUI

struct AnnotationToolbar: View {
    @Bindable var state: AnnotationState

    var body: some View {
        HStack(spacing: 4) {
            // Tool buttons
            ForEach(AnnotationToolType.allCases) { tool in
                toolButton(tool)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Color picker
            ColorPicker("", selection: $state.strokeColor)
                .labelsHidden()
                .frame(width: 24, height: 24)

            // Stroke width
            Menu {
                ForEach([1, 2, 3, 5, 8], id: \.self) { width in
                    Button("\(width)px") {
                        state.strokeWidth = CGFloat(width)
                    }
                }
            } label: {
                Image(systemName: "lineweight")
                    .font(.system(size: 12))
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)

            // Font size (for text tool)
            if state.activeTool == .text {
                Menu {
                    ForEach([12, 14, 18, 24, 32, 48], id: \.self) { size in
                        Button("\(size)pt") {
                            state.fontSize = CGFloat(size)
                        }
                    }
                } label: {
                    Image(systemName: "textformat.size")
                        .font(.system(size: 12))
                        .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            // Undo/Redo
            Button { state.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 12))
            }
            .disabled(!state.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button { state.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 12))
            }
            .disabled(!state.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func toolButton(_ tool: AnnotationToolType) -> some View {
        Button {
            state.activeTool = tool
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(state.activeTool == tool ? Color.accentColor.opacity(0.3) : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
        .help(tool.label)
    }
}

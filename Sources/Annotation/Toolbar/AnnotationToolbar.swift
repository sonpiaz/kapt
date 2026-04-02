import SwiftUI

struct AnnotationToolbar: View {
    @Bindable var state: AnnotationState

    var body: some View {
        HStack(spacing: 3) {
            ForEach(AnnotationToolType.allCases) { tool in
                toolButton(tool)
            }

            toolDivider

            ColorPicker("", selection: $state.strokeColor)
                .labelsHidden()
                .frame(width: 28, height: 28)

            // Stroke width with current value badge
            Menu {
                ForEach([1, 2, 3, 5, 8], id: \.self) { width in
                    Button {
                        state.strokeWidth = CGFloat(width)
                    } label: {
                        HStack {
                            Text("\(width)px")
                            if state.strokeWidth == CGFloat(width) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                VStack(spacing: 1) {
                    Image(systemName: "lineweight")
                        .font(.system(size: 11))
                    Text("\(Int(state.strokeWidth))")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .frame(width: 28)

            // Font size (text tool only)
            if state.activeTool == .text {
                Menu {
                    ForEach([12, 14, 18, 24, 32, 48], id: \.self) { size in
                        Button {
                            state.fontSize = CGFloat(size)
                        } label: {
                            HStack {
                                Text("\(size)pt")
                                if state.fontSize == CGFloat(size) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "textformat.size")
                            .font(.system(size: 11))
                        Text("\(Int(state.fontSize))")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 28, height: 28)
                }
                .menuStyle(.borderlessButton)
                .frame(width: 28)
            }

            toolDivider

            Button { state.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!state.canUndo)
            .keyboardShortcut("z", modifiers: .command)

            Button { state.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!state.canRedo)
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var toolDivider: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 4)
    }

    private func toolButton(_ tool: AnnotationToolType) -> some View {
        let isActive = state.activeTool == tool
        return Button {
            state.activeTool = tool
        } label: {
            Image(systemName: tool.systemImage)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? .white : .primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color.accentColor : Color.clear)
                        .shadow(color: isActive ? Color.accentColor.opacity(0.4) : .clear, radius: 3)
                )
        }
        .buttonStyle(.plain)
        .help(tool.label)
    }
}

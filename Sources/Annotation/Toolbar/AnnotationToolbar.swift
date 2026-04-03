import SwiftUI
import UniformTypeIdentifiers

struct AnnotationToolbar: View {
    @Bindable var state: AnnotationState
    let onSaveAs: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            // Traffic light avoidance zone
            Spacer().frame(width: 70)

            // Group 1: Drawing tools
            ForEach(AnnotationToolType.allCases) { tool in
                toolButton(tool)
            }

            toolDivider

            // Group 2: Style controls
            ColorPicker("", selection: $state.strokeColor)
                .labelsHidden()
                .frame(width: 24, height: 24)

            // Inline stroke width
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
                Text("\(Int(state.strokeWidth))px")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
            }
            .menuStyle(.borderlessButton)
            .frame(width: 36)

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
                    Text("\(Int(state.fontSize))pt")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(RoundedRectangle(cornerRadius: 4).fill(.quaternary))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 36)
            }

            toolDivider

            // Group 3: Undo/Redo
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

            toolDivider

            // Add Image
            Button { addImageFromFile() } label: {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 13))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help("Add Image")

            // Push actions to the right
            Spacer()

            // Group 4: Actions
            Button("Save as\u{2026}", action: onSaveAs)
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)

            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var toolDivider: some View {
        Divider()
            .frame(height: 18)
            .padding(.horizontal, 4)
    }

    private func addImageFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK,
                  let url = panel.url,
                  let nsImage = NSImage(contentsOf: url),
                  let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil)
            else { return }
            state.addImageAtEdge(cgImage, edge: .right)
        }
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

import SwiftUI
import ScreenCaptureKit
import AppKit

struct WindowPickerView: View {
    let windows: [SCWindow]
    let onSelect: (SCWindow) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text("Select a Window")
                .font(.headline)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(windows, id: \.windowID) { window in
                        Button {
                            onSelect(window)
                        } label: {
                            HStack {
                                if let appName = window.owningApplication?.applicationName {
                                    Text(appName)
                                        .fontWeight(.medium)
                                }
                                if let title = window.title, !title.isEmpty {
                                    Text("— \(title)")
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(Int(window.frame.width))×\(Int(window.frame.height))")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 400)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
        .frame(width: 420)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

@MainActor
final class WindowPickerPanel {
    private var panel: FloatingPanel<WindowPickerView>?

    init(windows: [SCWindow], onSelect: @escaping (SCWindow) -> Void, onCancel: @escaping () -> Void) {
        let view = WindowPickerView(
            windows: windows,
            onSelect: { [weak self] window in
                self?.panel?.close()
                onSelect(window)
            },
            onCancel: { [weak self] in
                self?.panel?.close()
                onCancel()
            }
        )
        panel = FloatingPanel(contentView: view)
    }

    func show() {
        panel?.show(
            near: NSPoint(x: NSScreen.main!.frame.midX, y: NSScreen.main!.frame.midY),
            size: NSSize(width: 420, height: 450)
        )
        panel?.center()
    }
}

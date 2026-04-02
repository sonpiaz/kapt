import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Capture Fullscreen") {
            snapLog("Button: Capture Fullscreen clicked")
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appState.startCapture(mode: .fullscreen)
            }
        }

        Button("Capture Region") {
            snapLog("Button: Capture Region clicked")
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                appState.startCapture(mode: .region)
            }
        }

        Divider()

        if let message = appState.statusMessage {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
        }

        Button("Preferences...") {
            openWindow(id: "preferences")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit SnapX") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

import SwiftUI
import KeyboardShortcuts

struct MenuBarView: View {
    let appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Button("Capture Fullscreen") {
                appState.startCapture(mode: .fullscreen)
            }
            .keyboardShortcut("1", modifiers: [.command, .shift])

            Button("Capture Region") {
                appState.startCapture(mode: .region)
            }
            .keyboardShortcut("2", modifiers: [.command, .shift])

            Button("Capture Window") {
                appState.startCapture(mode: .window)
            }
            .keyboardShortcut("3", modifiers: [.command, .shift])

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

            if !Permissions.hasScreenRecordingPermission() {
                Button("Grant Screen Recording Permission...") {
                    Permissions.requestScreenRecordingPermission()
                }
                Divider()
            }

            Button("Quit SnapX") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}

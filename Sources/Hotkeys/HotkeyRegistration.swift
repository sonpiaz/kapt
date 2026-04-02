import KeyboardShortcuts
import Foundation

@MainActor
enum HotkeyRegistration {
    static func register(appState: AppState) {
        print("Registering hotkeys...")

        KeyboardShortcuts.onKeyUp(for: .captureFullscreen) { [weak appState] in
            print("Hotkey: captureFullscreen triggered")
            appState?.startCapture(mode: .fullscreen)
        }
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak appState] in
            print("Hotkey: captureRegion triggered")
            appState?.startCapture(mode: .region)
        }
        print("Hotkeys registered successfully")
    }
}

import KeyboardShortcuts
import Foundation

@MainActor
enum HotkeyRegistration {
    static func register(appState: AppState) {
        print("Registering hotkeys...")

        KeyboardShortcuts.onKeyUp(for: .captureFullscreen) { [weak appState] in
            snapLog("Hotkey: captureFullscreen triggered")
            appState?.startCapture(mode: .fullscreen)
        }
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak appState] in
            snapLog("Hotkey: captureRegion triggered")
            appState?.startCapture(mode: .region)
        }
        KeyboardShortcuts.onKeyUp(for: .captureScrolling) { [weak appState] in
            snapLog("Hotkey: captureScrolling triggered")
            appState?.startCapture(mode: .scrolling)
        }
        print("Hotkeys registered successfully")
    }
}

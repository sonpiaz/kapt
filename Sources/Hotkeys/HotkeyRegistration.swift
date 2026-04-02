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
        KeyboardShortcuts.onKeyUp(for: .captureScrolling) { [weak appState] in
            print("Hotkey: captureScrolling triggered")
            appState?.startCapture(mode: .scrolling)
        }
        print("Hotkeys registered successfully")
    }
}

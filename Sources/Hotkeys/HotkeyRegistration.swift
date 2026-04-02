import KeyboardShortcuts

@MainActor
enum HotkeyRegistration {
    static func register(appState: AppState) {
        KeyboardShortcuts.onKeyUp(for: .captureFullscreen) { [weak appState] in
            appState?.startCapture(mode: .fullscreen)
        }
        KeyboardShortcuts.onKeyUp(for: .captureRegion) { [weak appState] in
            appState?.startCapture(mode: .region)
        }
        KeyboardShortcuts.onKeyUp(for: .captureWindow) { [weak appState] in
            appState?.startCapture(mode: .window)
        }
    }
}

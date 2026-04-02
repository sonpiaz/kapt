import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Cmd+Ctrl+Shift combos — won't conflict with macOS or Chrome
    static let captureFullscreen = Self("captureFullscreen", default: .init(.three, modifiers: [.command, .control]))
    static let captureRegion = Self("captureRegion", default: .init(.four, modifiers: [.command, .control]))
}

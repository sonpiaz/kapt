import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let captureFullscreen = Self("captureFullscreen", default: .init(.one, modifiers: [.command, .shift]))
    static let captureRegion = Self("captureRegion", default: .init(.two, modifiers: [.command, .shift]))
    static let captureWindow = Self("captureWindow", default: .init(.three, modifiers: [.command, .shift]))
}

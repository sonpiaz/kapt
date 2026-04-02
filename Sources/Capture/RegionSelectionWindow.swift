import AppKit
import SwiftUI

final class RegionSelectionWindow: NSWindow {
    private let onSelect: (CGRect) -> Void
    private let onCancel: () -> Void

    init(onSelect: @escaping (CGRect) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel

        let screen = NSScreen.main ?? NSScreen.screens[0]
        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        level = .screenSaver
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        acceptsMouseMovedEvents = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Exclude from screen capture
        sharingType = .none

        let selectionView = RegionSelectionView(
            screenFrame: screen.frame,
            onSelect: { [weak self] rect in
                self?.close()
                onSelect(rect)
            },
            onCancel: { [weak self] in
                self?.close()
                onCancel()
            }
        )

        contentView = NSHostingView(rootView: selectionView)
    }

    func beginSelection() {
        makeKeyAndOrderFront(nil)
        NSCursor.crosshair.push()
    }

    override func close() {
        NSCursor.pop()
        super.close()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

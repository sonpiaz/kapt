import SwiftUI
import AppKit

/// Floating HUD that controls a scrolling capture session
struct ScrollingCaptureHUDView: View {
    @Binding var frameCount: Int
    @Binding var isAutoScrolling: Bool
    let hasAccessibility: Bool
    let onAutoScroll: () -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Frame counter
            HStack(spacing: 4) {
                Image(systemName: "camera.metering.matrix")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("\(frameCount)")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .frame(minWidth: 44)

            Divider()
                .frame(height: 18)

            if hasAccessibility {
                Button(action: onAutoScroll) {
                    HStack(spacing: 4) {
                        Image(systemName: isAutoScrolling ? "pause.fill" : "arrow.down.doc")
                            .font(.system(size: 11))
                        Text(isAutoScrolling ? "Pause" : "Auto Scroll")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(isAutoScrolling ? Color.orange.opacity(0.2) : Color.accentColor.opacity(0.15))
                    )
                }
                .buttonStyle(.plain)
            }

            Button(action: onDone) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Done")
                        .font(.system(size: 12, weight: .medium))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.accentColor.opacity(0.2))
                )
            }
            .buttonStyle(.plain)

            Button(action: onCancel) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(5)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 0.75)
        )
        .shadow(color: .black.opacity(0.2), radius: 8, y: 2)
    }
}

// MARK: - HUD Panel

@MainActor
final class ScrollingCaptureHUD {
    private var panel: NSPanel?
    private var frameCount = 0
    private var isAutoScrolling = false

    var onAutoScroll: (() -> Void)?
    var onDone: (() -> Void)?
    var onCancel: (() -> Void)?

    func show(near rect: CGRect, on screen: NSScreen, hasAccessibility: Bool) {
        dismiss()

        // Bindable state via class wrapper
        let state = HUDState()
        state.hasAccessibility = hasAccessibility

        let view = ScrollingCaptureHUDContent(
            state: state,
            onAutoScroll: { [weak self] in self?.onAutoScroll?() },
            onDone: { [weak self] in self?.onDone?() },
            onCancel: { [weak self] in self?.onCancel?() }
        )

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .screenSaver
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.sharingType = .none // exclude from capture

        let hosting = NSHostingView(rootView: view)
        panel.contentView = hosting

        let panelSize = NSSize(width: 340, height: 44)
        panel.setContentSize(panelSize)

        // Position above the selected region
        let screenFrame = screen.frame
        let x = rect.midX - panelSize.width / 2
        // In screen coords (origin bottom-left), rect.origin.y is from bottom
        // Place HUD above the selection rect
        let y = screenFrame.height - rect.origin.y + 16
        panel.setFrameOrigin(NSPoint(
            x: max(screenFrame.minX + 8, min(x, screenFrame.maxX - panelSize.width - 8)),
            y: max(screenFrame.minY + 8, min(y, screenFrame.maxY - panelSize.height - 8))
        ))

        panel.orderFrontRegardless()
        self.panel = panel

        // Store state reference for updates
        _hudState = state
    }

    private var _hudState: HUDState?

    func updateFrameCount(_ count: Int) {
        _hudState?.frameCount = count
    }

    func updateAutoScrolling(_ scrolling: Bool) {
        _hudState?.isAutoScrolling = scrolling
    }

    func dismiss() {
        panel?.orderOut(nil)
        panel = nil
        _hudState = nil
    }
}

// MARK: - Observable state wrapper

@Observable
private class HUDState {
    var frameCount = 0
    var isAutoScrolling = false
    var hasAccessibility = false
}

private struct ScrollingCaptureHUDContent: View {
    @Bindable var state: HUDState
    let onAutoScroll: () -> Void
    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollingCaptureHUDView(
            frameCount: $state.frameCount,
            isAutoScrolling: $state.isAutoScrolling,
            hasAccessibility: state.hasAccessibility,
            onAutoScroll: onAutoScroll,
            onDone: onDone,
            onCancel: onCancel
        )
    }
}

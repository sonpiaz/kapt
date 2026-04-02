import SwiftUI
import AppKit

@main
struct SnapXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            PreferencesView()
        }
    }
}

// MARK: - Popover Menu View (SwiftUI buttons — no ObjC target/action needed)

struct PopoverMenuView: View {
    let appState: AppState
    let dismissAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            menuButton("Capture Fullscreen") {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.startCapture(mode: .fullscreen)
                }
            }
            menuButton("Capture Region") {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.startCapture(mode: .region)
                }
            }

            Divider()

            if let message = appState.statusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                Divider()
            }

            menuButton("Preferences...") {
                dismissAction()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    AppDelegate.showPreferences()
                }
            }

            Divider()

            menuButton("Quit SnapX") {
                NSApp.terminate(nil)
            }
        }
        .padding(6)
        .frame(width: 200)
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 5)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(PopoverButtonStyle())
    }
}

// MARK: - Menu-style button for popover

struct MenuItemButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(MenuItemButtonStyle())
    }
}

struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.clear)
            .foregroundColor(configuration.isPressed ? .white : .primary)
            .cornerRadius(4)
    }
}

struct PopoverButtonStyle: ButtonStyle {
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(configuration.isPressed ? Color.accentColor : isHovering ? Color.accentColor.opacity(0.3) : Color.clear)
            )
            .foregroundColor(configuration.isPressed ? .white : .primary)
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

// MARK: - App Delegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Must set activation policy in code — Info.plist is NOT loaded
        // when running as a bare CLI binary (not .app bundle).
        // .accessory = can show windows + receive keyboard, no Dock icon.
        NSApp.setActivationPolicy(.accessory)

        snapLog("App launched")
        let hasPerm = Permissions.hasScreenRecordingPermission()
        snapLog("Screen recording permission: \(hasPerm)")
        if !hasPerm {
            Permissions.requestScreenRecordingPermission()
        }
        setupStatusItem()
        HotkeyRegistration.register(appState: appState)
        snapLog("Setup complete")
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SnapX")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 200, height: 260)
        popover.contentViewController = NSHostingController(
            rootView: PopoverMenuView(
                appState: appState,
                dismissAction: { [weak self] in
                    self?.popover.performClose(nil)
                }
            )
        )

        snapLog("Popover setup complete")
    }

    @objc private func togglePopover(_ sender: Any?) {
        snapLog("togglePopover called")
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Preferences Window

    private static var preferencesWindow: NSWindow?

    static func showPreferences() {
        if let existing = preferencesWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "SnapX Preferences"
        window.contentView = NSHostingView(rootView: PreferencesView())
        window.center()
        window.isReleasedWhenClosed = false

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        preferencesWindow = window
    }
}

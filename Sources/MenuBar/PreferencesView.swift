import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct PreferencesView: View {
    @AppStorage("saveLocation") private var saveLocation = "Desktop"
    @AppStorage("imageFormat") private var imageFormat = "png"
    @AppStorage("autoCopy") private var autoCopy = true
    @AppStorage("captureSound") private var captureSound = true
    @AppStorage("displayTarget") private var displayTarget = "active"
    @AppStorage("scrollSpeed") private var scrollSpeed = 3
    @AppStorage("scrollMaxHeight") private var scrollMaxHeight = 20000

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            scrollingTab
                .tabItem { Label("Scrolling", systemImage: "arrow.down.doc") }
            hotkeysTab
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .frame(width: 420, height: 380)
        .padding()
    }

    private var generalTab: some View {
        Form {
            Section("Capture") {
                Picker("Save format", selection: $imageFormat) {
                    Text("PNG").tag("png")
                    Text("JPEG").tag("jpeg")
                }
                Toggle("Auto-copy to clipboard", isOn: $autoCopy)
                Toggle("Capture sound", isOn: $captureSound)
            }

            Section("Display") {
                Picker("Capture screen", selection: $displayTarget) {
                    ForEach(DisplayTarget.allCases, id: \.rawValue) { target in
                        Text(target.label).tag(target.rawValue)
                    }
                }
                Text("Active = screen with mouse cursor. Useful for multi-monitor setups.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Save Location") {
                Picker("Default location", selection: $saveLocation) {
                    Text("Desktop").tag("Desktop")
                    Text("Downloads").tag("Downloads")
                    Text("Documents").tag("Documents")
                }
            }

            Section("System") {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            // Revert the toggle on failure
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
    }

    private var scrollingTab: some View {
        Form {
            Section("Auto Scroll") {
                HStack {
                    Text("Scroll speed")
                    Spacer()
                    Picker("", selection: $scrollSpeed) {
                        Text("Slow").tag(2)
                        Text("Normal").tag(3)
                        Text("Fast").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
                Text("How fast to scroll when using Auto Scroll mode.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Limits") {
                Picker("Max capture height", selection: $scrollMaxHeight) {
                    Text("10,000 px").tag(10000)
                    Text("20,000 px").tag(20000)
                    Text("40,000 px").tag(40000)
                    Text("Unlimited").tag(100000)
                }
                Text("Auto-stops scrolling capture when the stitched image reaches this height.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("Accessibility") {
                HStack {
                    if Permissions.hasAccessibilityPermission() {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Accessibility access granted")
                    } else {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Required for Auto Scroll")
                        Spacer()
                        Button("Grant Access") {
                            Permissions.requestAccessibilityPermission()
                        }
                    }
                }
                Text("Auto Scroll injects scroll events into the target app, which requires Accessibility permission. Manual scrolling works without it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .formStyle(.grouped)
    }

    private var hotkeysTab: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Capture Fullscreen:", name: .captureFullscreen)
                KeyboardShortcuts.Recorder("Capture Region:", name: .captureRegion)
                KeyboardShortcuts.Recorder("Scrolling Capture:", name: .captureScrolling)
            }
        }
        .formStyle(.grouped)
    }
}

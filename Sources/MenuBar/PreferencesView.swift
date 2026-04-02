import SwiftUI
import KeyboardShortcuts
import ServiceManagement

struct PreferencesView: View {
    @AppStorage("saveLocation") private var saveLocation = "Desktop"
    @AppStorage("imageFormat") private var imageFormat = "png"
    @AppStorage("autoCopy") private var autoCopy = true
    @AppStorage("showQuickAccess") private var showQuickAccess = true
    @AppStorage("captureSound") private var captureSound = true

    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gear") }
            hotkeysTab
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
        }
        .frame(width: 420, height: 320)
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
                Toggle("Show Quick Access overlay", isOn: $showQuickAccess)
                Toggle("Capture sound", isOn: $captureSound)
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

    private var hotkeysTab: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Capture Fullscreen:", name: .captureFullscreen)
                KeyboardShortcuts.Recorder("Capture Region:", name: .captureRegion)
            }
        }
        .formStyle(.grouped)
    }
}

import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @AppStorage("saveLocation") private var saveLocation = "Desktop"
    @AppStorage("imageFormat") private var imageFormat = "png"
    @AppStorage("autoCopy") private var autoCopy = true
    @AppStorage("showQuickAccess") private var showQuickAccess = true
    @AppStorage("captureSound") private var captureSound = true

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
        }
        .formStyle(.grouped)
    }

    private var hotkeysTab: some View {
        Form {
            Section("Keyboard Shortcuts") {
                KeyboardShortcuts.Recorder("Capture Fullscreen:", name: .captureFullscreen)
                KeyboardShortcuts.Recorder("Capture Region:", name: .captureRegion)
                KeyboardShortcuts.Recorder("Capture Window:", name: .captureWindow)
            }
        }
        .formStyle(.grouped)
    }
}

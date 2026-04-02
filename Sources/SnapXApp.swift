import SwiftUI

@main
struct SnapXApp: App {
    @State private var appState = AppState()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("SnapX", systemImage: "camera.viewfinder") {
            MenuBarView(appState: appState)
                .onAppear {
                    appDelegate.appState = appState
                    HotkeyRegistration.register(appState: appState)
                }
        }

        Window("SnapX Preferences", id: "preferences") {
            PreferencesView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var appState: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if !Permissions.hasScreenRecordingPermission() {
            Permissions.requestScreenRecordingPermission()
        }
    }
}

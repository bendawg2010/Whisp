import SwiftUI

@main
struct WhispApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store, updater: appDelegate.updater)
        }
    }
}


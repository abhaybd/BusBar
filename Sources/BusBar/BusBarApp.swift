import SwiftUI

/// Owns the long-lived model objects so both the SwiftUI scenes and the AppDelegate share them.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    let config: AppConfig
    let location: LocationManager
    let store: ArrivalStore
    let loginItem: LoginItem

    private init() {
        let config = AppConfig()
        let location = LocationManager()
        self.config = config
        self.location = location
        self.store = ArrivalStore(config: config, location: location)
        self.loginItem = LoginItem()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon, no app switcher entry — even when launched directly.
        NSApp.setActivationPolicy(.accessory)
        AppEnvironment.shared.store.start()
    }
}

struct BusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let env = AppEnvironment.shared

    var body: some Scene {
        MenuBarExtra {
            DropdownView()
                .environmentObject(env.store)
                .environmentObject(env.config)
                .environmentObject(env.location)
        } label: {
            MenuLabel(store: env.store)
        }
        .menuBarExtraStyle(.window)

        Window("BusBar Settings", id: "settings") {
            SettingsView()
                .environmentObject(env.store)
                .environmentObject(env.config)
                .environmentObject(env.location)
                .environmentObject(env.loginItem)
        }
        .windowResizability(.contentSize)
    }
}

/// Small observing wrapper so the menu bar title re-renders whenever the store updates.
/// A monochrome bus glyph (template SF Symbol, tints with the menu bar) sits left of the text.
private struct MenuLabel: View {
    @ObservedObject var store: ArrivalStore
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "bus.fill")
            Text(store.menuText)
        }
    }
}

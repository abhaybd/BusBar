import SwiftUI
import AppKit
import Combine

/// Owns the long-lived model objects so both the SwiftUI scenes and the AppDelegate share them.
@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()
    let config: AppConfig
    let location: LocationManager
    let store: ArrivalStore
    let loginItem: LoginItem

    private var settingsWindow: NSWindow?

    private init() {
        let config = AppConfig()
        let location = LocationManager()
        self.config = config
        self.location = location
        self.store = ArrivalStore(config: config, location: location)
        self.loginItem = LoginItem()
    }

    /// Show (creating once, then reusing) the settings window. Owned here rather than via
    /// NSApp.delegate, because SwiftUI's delegate adaptor wraps our AppDelegate.
    func showSettings() {
        if settingsWindow == nil {
            let host = NSHostingController(rootView:
                SettingsView()
                    .environmentObject(store)
                    .environmentObject(config)
                    .environmentObject(location)
                    .environmentObject(loginItem)
            )
            // Fixed size: do NOT use .preferredContentSize here, or the window resizes as tab
            // content grows (e.g. nearby-stop results) and shoves the tab strip under the title bar.
            let window = NSWindow(contentViewController: host)
            window.title = "BusBar Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: 480, height: 560))
            window.center()
            settingsWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

struct BusBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    private let env = AppEnvironment.shared

    var body: some Scene {
        // The menu bar item and the settings window are both managed by AppDelegate (AppKit),
        // which is reliable for an accessory/LSUIElement app. This placeholder scene just
        // satisfies SwiftUI's requirement that an App have at least one Scene; it never shows.
        Settings { EmptyView() }
    }
}

/// Opens the settings window from AppKit contexts (dropdown button, etc.).
@MainActor
func openBusBarSettings() {
    AppEnvironment.shared.showSettings()
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar-only: no Dock icon, no app switcher entry — even when launched directly.
        NSApp.setActivationPolicy(.accessory)

        let env = AppEnvironment.shared
        env.store.start()

        // Status item.
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        // Popover hosting the SwiftUI dropdown.
        popover.behavior = .transient
        let host = NSHostingController(rootView:
            DropdownView()
                .environmentObject(env.store)
                .environmentObject(env.config)
                .environmentObject(env.location)
                .environmentObject(env.loginItem)
        )
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host

        // Keep the button title in sync with the store.
        env.store.$menuText
            .receive(on: RunLoop.main)
            .sink { [weak self] text in self?.updateTitle(text) }
            .store(in: &cancellables)
        updateTitle(env.store.menuText)
    }

    private func updateTitle(_ text: String) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = MenuBarTitle.make(text: text)
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

/// Builds the menu bar button's attributed title: a monochrome bus glyph, a tunable gap, then
/// the text. Unlike a SwiftUI MenuBarExtra label, these values actually take effect.
enum MenuBarTitle {
    /// SF Symbol point size for the bus glyph.
    static let symbolPointSize: CGFloat = 13
    /// Extra horizontal space (points) between the bus and the text, on top of a normal space.
    static let gap: CGFloat = 3
    /// Vertical nudge for the glyph (points). Positive = up, negative = down.
    static let verticalOffset: CGFloat = 0

    static func make(text: String) -> NSAttributedString {
        let font = NSFont.menuBarFont(ofSize: 0)
        let result = NSMutableAttributedString()

        if let glyph = busGlyph() {
            let attachment = NSTextAttachment()
            attachment.image = glyph
            let h = glyph.size.height
            let w = glyph.size.width
            // Center the glyph on the text cap height, then apply the manual nudge.
            let y = (font.capHeight - h) / 2 + verticalOffset
            attachment.bounds = CGRect(x: 0, y: y, width: w, height: h)
            result.append(NSAttributedString(attachment: attachment))
            // A space carrying extra kern gives a tunable gap before the text.
            result.append(NSAttributedString(string: " ", attributes: [.font: font, .kern: gap]))
        }

        result.append(NSAttributedString(string: text, attributes: [.font: font]))
        return result
    }

    private static func busGlyph() -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
        guard let img = NSImage(systemSymbolName: "bus.fill", accessibilityDescription: "bus")?
            .withSymbolConfiguration(config) else { return nil }
        img.isTemplate = true // tint with the menu bar (monochrome)
        return img
    }
}

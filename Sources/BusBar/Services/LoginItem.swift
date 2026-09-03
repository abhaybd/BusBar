import Foundation
import ServiceManagement

/// Wraps the macOS 13+ `SMAppService` login-item API so BusBar can start at login.
/// Registers the currently-running `.app` bundle; move the app and re-toggle if the path changes.
@MainActor
final class LoginItem: ObservableObject {
    @Published private(set) var isEnabled: Bool
    @Published var lastError: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }
}

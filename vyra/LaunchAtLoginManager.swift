import Foundation
import ServiceManagement

@MainActor
enum LaunchAtLoginManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort; UI will reflect stored setting, while system may reject.
        }
    }
}


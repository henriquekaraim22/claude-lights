import ServiceManagement

/// Wraps SMAppService (macOS 13+) for the "Open at login" toggle. Real
/// registration with the OS, not a UI stub — matches the native "Open at
/// Login" convention from macOS's own Login Items settings.
enum LoginItemManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Best-effort: if registration fails (e.g. running unsigned via
            // `swift run` instead of a packaged .app), the toggle just won't
            // stick. Nothing sound- or state-critical depends on this.
        }
    }
}

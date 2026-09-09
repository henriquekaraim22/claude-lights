import SwiftUI
import AppKit

@main
struct ClaudeLightsApp: App {
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var soundSettings = SoundSettings()

    var body: some Scene {
        MenuBarExtra {
            SessionsMenuView(
                sessionStore: sessionStore,
                soundSettings: soundSettings
            )
        } label: {
            MenuBarIconView(status: sessionStore.aggregated)
                .task {
                    // NSApp isn't safely available in App.init() — NSApplication.shared
                    // doesn't exist yet at that point in SwiftUI's startup sequence,
                    // and calling it there crashes with "Unexpectedly found nil while
                    // implicitly unwrapping an Optional value" (hit this for real on
                    // 2026-09-09). By the time a view's .task runs, it's safe.
                    // The packaged .app's Info.plist LSUIElement is the primary
                    // mechanism for hiding the Dock icon; this is just a defensive
                    // fallback for unpackaged `swift run` during development.
                    NSApp.setActivationPolicy(.accessory)
                    sessionStore.start()
                }
        }
        .menuBarExtraStyle(.window)
    }
}

import Foundation
import Combine

/// Polls ~/.claude/claude-status/sessions/*.json (written by hooks/state.py)
/// and keeps an aggregated status for the menu bar icon.
///
/// Polling, not FSEvents (RNF2 of docs/PRD.md allows either; polling at
/// >= 500ms is explicitly fine and much simpler to get right). 500ms keeps
/// us comfortably under the "< 1s after event" criterion for Fase 2.
final class SessionStore: ObservableObject {
    static let statusDir = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/claude-status")
    static let sessionsDir = statusDir.appendingPathComponent("sessions")

    /// RF6: a session with no update in this long is treated as dead —
    /// SessionEnd doesn't always arrive (e.g. the app window was closed).
    private let staleAfter: TimeInterval = 30 * 60

    /// docs/PRD.md 6.1: `done` shows for this long, then decays to `idle`.
    /// This was documented back in the original discovery but never actually
    /// wired up when Fase 2 was built — the session file just says "done"
    /// forever until the next real event. Caught live on 2026-09-09 when the
    /// user noticed it never went away. Applied here, once, so both the bar
    /// and the menu's session list agree on when a session has settled.
    private let doneDisplayDuration: TimeInterval = 8

    @Published private(set) var sessions: [SessionInfo] = []
    @Published private(set) var aggregated: AggregatedStatus = .empty
    /// Whether hooks/state.py is actually installed at ~/.claude/claude-status/
    /// — false right after a fresh download until HookInstaller.install() runs.
    @Published private(set) var hooksInstalled: Bool = HookInstaller.isInstalled

    private var pollTimer: Timer?
    private var hasStarted = false
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Idempotent — safe to call from `.task` / `.onAppear`, which may fire
    /// more than once while the menu bar item is (re)created.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        poll()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        pollTimer?.invalidate()
    }

    /// Called right after HookInstaller.install() finishes, so the menu
    /// reflects "installed" immediately instead of waiting for the next
    /// 0.5s poll tick.
    func recheckHooksInstalled() {
        hooksInstalled = HookInstaller.isInstalled
    }

    private func poll() {
        hooksInstalled = HookInstaller.isInstalled
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: Self.sessionsDir, includingPropertiesForKeys: nil
        ) else {
            sessions = []
            aggregated = .empty
            return
        }

        let now = Date()
        var live: [SessionInfo] = []
        let decoder = JSONDecoder()

        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  var info = try? decoder.decode(SessionInfo.self, from: data) else { continue }
            guard let updated = isoFormatter.date(from: info.updatedAt) else { continue }
            let age = now.timeIntervalSince(updated)
            if age > staleAfter { continue }
            if info.state == .done, age > doneDisplayDuration {
                info.state = .idle
            }
            live.append(info)
        }

        sessions = live.sorted { $0.state.priority > $1.state.priority }
        aggregated = Self.aggregate(live)
    }

    /// Just the single highest-priority state across every live session —
    /// no rotation, no session name (2026-09-09: the bar only ever shows
    /// the state; which project it belongs to is a menu-open question).
    static func aggregate(_ sessions: [SessionInfo]) -> AggregatedStatus {
        guard let topPriority = sessions.map({ $0.state.priority }).max(),
              let topState = sessions.first(where: { $0.state.priority == topPriority })?.state
        else { return .empty }
        return AggregatedStatus(state: topState)
    }

    func relativeTime(for isoString: String) -> String {
        guard let date = isoFormatter.date(from: isoString) else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(max(seconds, 0))s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60) h ago"
    }
}

import SwiftUI

enum SessionState: String, Codable {
    case idle
    case working
    case waitingQuestion = "waiting_question"
    case waitingPermission = "waiting_permission"
    case done
    case error

    /// Priority for aggregation across sessions: higher wins. Matches
    /// docs/PRD.md RF2: error > waiting_* > working > done > idle.
    var priority: Int {
        switch self {
        case .error: return 4
        case .waitingQuestion, .waitingPermission: return 3
        case .working: return 2
        case .done: return 1
        case .idle: return 0
        }
    }

    /// Sparkle color per state (colors confirmed directly by the user
    /// 2026-09-09 — error is Claude's own proposal, not confirmed).
    var color: Color {
        switch self {
        case .idle: return Color.white.opacity(0.3)
        case .working, .done: return .white
        case .waitingQuestion, .waitingPermission: return Color(red: 0.94, green: 0.76, blue: 0.24)
        case .error: return Color(red: 0.89, green: 0.33, blue: 0.31)
        }
    }

    /// Menu bar label. `idle` has no label at all. `working` was literally
    /// "···" at first (the user's initial choice), changed back to the word
    /// on 2026-09-09.
    var label: String? {
        switch self {
        case .idle: return nil
        case .working: return "Working…"
        case .waitingQuestion: return "Waiting for reply"
        case .waitingPermission: return "Waiting for permission"
        case .done: return "Done"
        case .error: return "Error"
        }
    }
}

struct SessionInfo: Codable, Identifiable {
    var id: String { sessionID }
    let sessionID: String
    let cwd: String
    let transcriptPath: String?
    var state: SessionState  // var: SessionStore decays done -> idle after 8s in place
    let detail: String
    let turnStartedAt: String?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case cwd
        case transcriptPath = "transcript_path"
        case state
        case detail
        case turnStartedAt = "turn_started_at"
        case updatedAt = "updated_at"
    }

    /// Last path component of `cwd` — the project folder name, used as a
    /// human-readable session label in the menu and in multi-session rotation.
    var projectName: String {
        (cwd as NSString).lastPathComponent
    }
}

/// The aggregated status shown on the menu bar icon itself, computed across
/// every live session (see SessionStore.aggregate()).
///
/// Simplified 2026-09-09 at the user's request: no more rotation between
/// tied sessions, and no session/project name in the bar at all — just the
/// single highest-priority state's label. Which project is in which state
/// only shows once the user actually opens the menu.
struct AggregatedStatus {
    let state: SessionState

    static let empty = AggregatedStatus(state: .idle)

    var label: String? { state.label }
}

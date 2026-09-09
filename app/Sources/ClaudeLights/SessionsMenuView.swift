import SwiftUI
import AppKit

/// The panel that opens on click. Structure borrowed from the Granola menu
/// bar dropdown the user showed as a reference (grouped content, divider,
/// quiet meta line, divider, quit) — see docs/PRD.md 6.2. Custom SwiftUI
/// content via `.menuBarExtraStyle(.window)`, not a native NSMenu, so it can
/// match the mockup (rounded rows, no leading icons).
///
/// Trimmed 2026-09-09 at the user's request: usage/cost summary, "Mute for
/// 1 hour", and "Open event log" all removed — "não acho que é necessário".
/// The underlying code (UsageStore, UsageCalculator, Pricing, MuteManager)
/// was deleted outright rather than left unused.
struct SessionsMenuView: View {
    @ObservedObject var sessionStore: SessionStore
    @ObservedObject var soundSettings: SoundSettings
    @State private var loginItemEnabled = LoginItemManager.isEnabled

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionLabel("Sessions")

            if sessionStore.sessions.isEmpty {
                Row {
                    Text("No active sessions")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            } else {
                ForEach(sessionStore.sessions) { session in
                    Row {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(session.projectName)
                                .font(.system(size: 13, weight: .medium))
                            Text(sessionSubtitle(session))
                                .font(.system(size: 11))
                                .foregroundColor(subtitleColor(session))
                        }
                    }
                }
            }

            divider()

            sectionLabel("Settings")

            SwitchRow(
                title: "Open at login",
                subtitle: nil,
                isOn: Binding(
                    get: { loginItemEnabled },
                    set: { newValue in
                        loginItemEnabled = newValue
                        LoginItemManager.setEnabled(newValue)
                    }
                )
            )

            SwitchRow(
                title: "Force max volume",
                subtitle: "Briefly overrides your Mac's own volume right before every alert, then restores it. This also affects any other audio playing at that instant, like a call or music.",
                isOn: Binding(
                    get: { soundSettings.isEnabled },
                    set: { soundSettings.setEnabled($0) }
                )
            )

            if soundSettings.isEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Force volume to")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(soundSettings.levelPercent))%")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { soundSettings.levelPercent },
                            set: { soundSettings.setLevelPercent($0) }
                        ),
                        in: SoundSettings.levelRange, step: 5
                    )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }

            divider()

            sectionLabel("Claude Lights v0.1")

            Row(action: { NSApp.terminate(nil) }) {
                Text("Quit")
                    .font(.system(size: 13))
            }
        }
        .padding(8)
        .frame(width: 320)
        .background(Color(red: 0.157, green: 0.157, blue: 0.169).opacity(0.92))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func sessionSubtitle(_ session: SessionInfo) -> String {
        let time = sessionStore.relativeTime(for: session.updatedAt)
        guard let label = session.state.label else { return time }
        if session.state == .working, !session.detail.isEmpty, session.detail != "prompt sent" {
            return "Working · \(session.detail) · \(time)"
        }
        return "\(label) · \(time)"
    }

    private func subtitleColor(_ session: SessionInfo) -> Color {
        switch session.state {
        case .waitingQuestion, .waitingPermission: return Color(red: 0.94, green: 0.76, blue: 0.24)
        case .error: return Color(red: 0.89, green: 0.33, blue: 0.31)
        default: return .secondary
        }
    }

    @ViewBuilder
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 6)
            .padding(.bottom, 2)
    }

    private func divider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.vertical, 4)
            .padding(.horizontal, 4)
    }
}

/// A clickable, rounded, hover-highlighted menu row — the row-level building
/// block every plain (non-toggle) section reuses so they all share the same
/// edges and padding.
private struct Row<Content: View>: View {
    var action: (() -> Void)?
    @ViewBuilder var content: Content
    @State private var isHovered = false

    var body: some View {
        Button(action: { action?() }) {
            content
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .onHover { isHovered = $0 }
    }
}

/// A settings row with a real switch on the right, title on the left, and
/// an optional explanatory line underneath — used instead of a plain
/// clickable row + checkmark (2026-09-09: the user asked for actual toggles
/// here, matching the native macOS Settings convention, and for the
/// force-volume one specifically to explain what it does, not just show a
/// check).
private struct SwitchRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                Spacer()
                Toggle("", isOn: $isOn)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

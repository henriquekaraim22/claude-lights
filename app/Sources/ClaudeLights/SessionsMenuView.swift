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
                titleSize: 15,
                subtitle: "Briefly overrides your Mac's volume for every alert — also affects music or calls playing at that moment.",
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

/// A settings row with a dot indicator on the right, title on the left, and
/// an optional explanatory line underneath.
///
/// 2026-09-09: went from a plain row + checkmark, to a native `Toggle`
/// switch, and back to a check-style indicator again — the user tried the
/// switch live and found it "ficou muito ruim" (came out badly). What they
/// asked for instead: a filled dot when on, an outlined dot when off — not
/// the system switch, not a checkmark glyph either. `DotToggle` below.
private struct SwitchRow: View {
    let title: String
    var titleSize: CGFloat = 13
    let subtitle: String?
    @Binding var isOn: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(size: titleSize))
                    .foregroundColor(.primary)
                Spacer()
                DotToggle(isOn: $isOn)
            }

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}

/// A filled blue dot when on, an outlined dot when off — the check-style
/// indicator the user asked for in place of the native switch.
private struct DotToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button(action: { isOn.toggle() }) {
            Circle()
                .fill(isOn ? Color.accentColor : Color.clear)
                .overlay(
                    Circle().strokeBorder(isOn ? Color.clear : Color.white.opacity(0.45), lineWidth: 1.5)
                )
                .frame(width: 16, height: 16)
        }
        .buttonStyle(.plain)
    }
}

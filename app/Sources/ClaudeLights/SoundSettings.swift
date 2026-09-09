import Foundation
import Combine

/// Sound volume settings, shared with hooks/state.py through two small
/// files (same pattern as MuteManager's mute_until) — the app is the UI,
/// but afplay only ever runs from the hook.
///
/// Redesigned 2026-09-09 into one nested control, at the user's request:
/// "Force max volume" is the single on/off decision, and the percentage
/// only exists — and only matters — once it's on. (Replaces an earlier
/// two-independent-controls version: an always-on relative afplay -v
/// multiplier plus a separate always-100% force toggle. That shipped
/// initially but read, in the user's own words, like "do I turn on max and
/// then configure how intense the max is?" — which is exactly the nested
/// model this version actually is.)
///
/// Verified live on 2026-09-09: `afplay -v` is a multiplier RELATIVE to the
/// Mac's current system output volume, not an absolute level — `man afplay`
/// documents no such override, and testing confirmed a low system volume
/// still comes out quiet regardless of -v. Setting the real system volume
/// (what this does when on) is the only way to actually guarantee loudness.
final class SoundSettings: ObservableObject {
    private let enabledFile = SessionStore.statusDir.appendingPathComponent("force_max_volume")
    private let levelFile = SessionStore.statusDir.appendingPathComponent("force_volume_level")

    static let defaultLevel: Double = 100
    static let levelRange: ClosedRange<Double> = 50...100

    /// Off by default — genuinely invasive: when on, the hook briefly pushes
    /// the Mac's real system volume to `levelPercent` right before playing
    /// an alert and restores it after, which momentarily affects ANY audio
    /// playing at that instant (a call, music), not just our sound.
    @Published var isEnabled: Bool
    /// Only meaningful while `isEnabled` is true.
    @Published var levelPercent: Double

    init() {
        isEnabled = Self.readEnabled(from: SessionStore.statusDir.appendingPathComponent("force_max_volume"))
        levelPercent = Self.readLevel(from: SessionStore.statusDir.appendingPathComponent("force_volume_level"))
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        try? FileManager.default.createDirectory(at: SessionStore.statusDir, withIntermediateDirectories: true)
        try? (value ? "1" : "0").write(to: enabledFile, atomically: true, encoding: .utf8)
    }

    func setLevelPercent(_ value: Double) {
        levelPercent = value
        try? FileManager.default.createDirectory(at: SessionStore.statusDir, withIntermediateDirectories: true)
        try? String(format: "%.0f", value).write(to: levelFile, atomically: true, encoding: .utf8)
    }

    private static func readEnabled(from url: URL) -> Bool {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return false }
        return text.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }

    private static func readLevel(from url: URL) -> Double {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return defaultLevel }
        return min(max(value, levelRange.lowerBound), levelRange.upperBound)
    }
}

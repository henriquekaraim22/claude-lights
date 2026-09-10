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
    private let doneSoundFile = SessionStore.statusDir.appendingPathComponent("done_sound")

    static let defaultLevel: Double = 100
    static let levelRange: ClosedRange<Double> = 50...100

    /// The 14 real files in /System/Library/Sounds — confirmed by actually
    /// listing that directory and test-playing every one earlier in the
    /// project (see CLAUDE.md); never a guessed or translated name again
    /// after that whole saga. "done" is the only sound with a picker at all
    /// (2026-09-09, explicit request: "o único som que pode ser trocado é
    /// esse, todos os outros não podem ser alterados") — Ping and Sosumi
    /// stay hardcoded in hooks/state.py's SOUND_MAP, no UI for them.
    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero",
        "Morse", "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]
    static let defaultDoneSound = "Glass"

    /// Off by default — genuinely invasive: when on, the hook briefly pushes
    /// the Mac's real system volume to `levelPercent` right before playing
    /// an alert and restores it after, which momentarily affects ANY audio
    /// playing at that instant (a call, music), not just our sound.
    @Published var isEnabled: Bool
    /// Only meaningful while `isEnabled` is true.
    @Published var levelPercent: Double
    @Published var doneSound: String

    init() {
        isEnabled = Self.readEnabled(from: SessionStore.statusDir.appendingPathComponent("force_max_volume"))
        levelPercent = Self.readLevel(from: SessionStore.statusDir.appendingPathComponent("force_volume_level"))
        doneSound = Self.readDoneSound(from: SessionStore.statusDir.appendingPathComponent("done_sound"))
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

    func setDoneSound(_ value: String) {
        guard Self.availableSounds.contains(value) else { return }
        doneSound = value
        try? FileManager.default.createDirectory(at: SessionStore.statusDir, withIntermediateDirectories: true)
        try? value.write(to: doneSoundFile, atomically: true, encoding: .utf8)
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

    private static func readDoneSound(from url: URL) -> String {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return defaultDoneSound }
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return availableSounds.contains(name) ? name : defaultDoneSound
    }
}

import AppKit

/// Plays a system sound for preview purposes (hovering the "Done sound"
/// picker) — separate from hooks/state.py's afplay, which is what actually
/// plays alert sounds for real. This one uses NSSound directly since it's a
/// UI preview living in the app process, not something a hook needs to fire
/// independent of the app being open.
enum SoundPreview {
    private static var current: NSSound?

    /// Stops whatever preview is already playing first — hovering quickly
    /// across several options should never overlap two sounds at once.
    static func play(_ name: String) {
        current?.stop()
        let path = "/System/Library/Sounds/\(name).aiff"
        let sound = NSSound(contentsOfFile: path, byReference: true)
        current = sound
        sound?.play()
    }

    static func stop() {
        current?.stop()
    }
}

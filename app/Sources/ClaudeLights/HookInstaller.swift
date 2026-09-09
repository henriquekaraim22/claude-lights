import Foundation

/// Runs the app's own bundled `install.sh` (see app/package.sh, which
/// copies `install.sh` and `hooks/` into Contents/Resources) so a downloaded
/// .app can set up its own Claude Code integration — copying the hook
/// scripts to ~/.claude/claude-status/ and merging the hook entries into
/// ~/.claude/settings.json — without the recipient ever opening a terminal.
///
/// Added 2026-09-09 at the user's request ("enviar pras pessoas... tem como
/// criar um instalador de Mac?"): a plain .dmg only drags the app into
/// /Applications — it doesn't wire up the hooks Claude Code needs to ever
/// change this app's icon. This is the other half of that.
enum HookInstaller {
    /// True once the hook script exists at its installed location. Cheap
    /// enough to check on every SessionStore poll tick.
    static var isInstalled: Bool {
        FileManager.default.fileExists(
            atPath: SessionStore.statusDir.appendingPathComponent("hook.sh").path
        )
    }

    struct Result {
        let succeeded: Bool
        let output: String
    }

    static func install(completion: @escaping (Result) -> Void) {
        guard let scriptURL = Bundle.main.url(forResource: "install", withExtension: "sh") else {
            completion(Result(succeeded: false, output: "install.sh wasn't found inside the app bundle."))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [scriptURL.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            let result: Result
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                result = Result(succeeded: process.terminationStatus == 0, output: output)
            } catch {
                result = Result(succeeded: false, output: error.localizedDescription)
            }

            DispatchQueue.main.async { completion(result) }
        }
    }
}

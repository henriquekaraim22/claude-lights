# Claude Lights

A tiny macOS menu bar indicator for [Claude Code](https://claude.com/claude-code). One sparkle icon, colored by what Claude is doing right now, with a sound when it needs you.

![Claude Lights in the menu bar](assets/demo-menubar.png)

## What it does

- Shows a single sparkle in your menu bar. It never changes shape, only color and label:
  - **White, no label** — idle, nothing happening.
  - **White, "Working…"** — Claude is working.
  - **Yellow, "Waiting for reply" / "Waiting for permission"** — Claude needs you.
  - **White, "Done"** — a turn just finished (fades back to idle after a few seconds).
  - **Red, "Error"** — a turn failed.
- Plays a sound the moment Claude needs you or a turn fails, so you don't have to keep the window in view.
- Tracks every Claude Code session on your machine at once (multiple tabs, multiple projects) and shows the single most urgent one.
- Click the icon for the full list of active sessions.

## How it works

Claude Code can run a shell command on lifecycle events ([hooks](https://code.claude.com/docs/en/hooks)). This project installs a small hook script that writes one JSON file per session to `~/.claude/claude-status/sessions/`, and a tiny SwiftUI menu bar app that watches that folder.

```
Claude Code ──hooks──▶ hooks/state.py ──writes──▶ ~/.claude/claude-status/sessions/*.json
                            │                                      │
                            └─ afplay (sound)          ClaudeLights.app ──reads──▶ menu bar icon
```

The hook is the only thing that ever plays a sound, so alerts keep working even when the app isn't running. See [`docs/DISCOVERY.md`](docs/DISCOVERY.md) for the full technical background and [`docs/PRD.md`](docs/PRD.md) for the exact event-to-state mapping.

## Requirements

- macOS 13 or later.
- [Claude Code](https://claude.com/claude-code) installed and configured.
- Xcode Command Line Tools (for `swift build`) — a full Xcode install is not required.

## Install

```bash
git clone https://github.com/<your-username>/claude-lights.git
cd claude-lights
./install.sh          # copies the hook and merges it into ~/.claude/settings.json
cd app && ./package.sh release
open .build/ClaudeLights.app
```

`install.sh` backs up your existing `~/.claude/settings.json` before touching it, and only adds hook entries that aren't already there — running it again is safe.

Drag `app/.build/ClaudeLights.app` to `/Applications` and turn on **Open at login** in the menu if you want it to start automatically. Since the app is signed locally (not notarized by Apple), the first launch will show a "developer cannot be verified" warning — right-click the app and choose **Open** once to get past it.

## Customizing

- **Sounds**: edit `SOUND_MAP` in [`hooks/state.py`](hooks/state.py) — any file in `/System/Library/Sounds/` works. Re-run `./install.sh` after editing.
- **Icon colors**: edit `SessionState.color` in [`app/Sources/ClaudeLights/Models.swift`](app/Sources/ClaudeLights/Models.swift).
- **The icon itself**: [`assets/spark.svg`](assets/spark.svg) is traced directly into [`SparkShape.swift`](app/Sources/ClaudeLights/SparkShape.swift) as a native SwiftUI `Shape`; swap in your own mark by re-tracing its path.

## Uninstall

Remove the hook entries from `~/.claude/settings.json` (or restore one of the `settings.json.backup-*` files `install.sh` made), delete `~/.claude/claude-status/`, and remove the app from `/Applications`.

## License

[MIT](LICENSE)

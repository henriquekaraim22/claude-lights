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
- Click the icon for the full list of active sessions, plus a couple of settings: open at login, and an optional "force max volume" for alerts (briefly overrides your Mac's own volume so you don't miss one, even if it's turned down).

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

### From a .dmg (easiest — no terminal)

Download `ClaudeLights.dmg` from [Releases](../../releases), open it, and drag **Claude Lights** into **Applications**. On first launch, the app itself offers a **Set up integration** button — that's the only setup step, it copies the hook script and adds it to `~/.claude/settings.json` for you.

Since the app is signed locally (not notarized by Apple), the first launch will show a "developer cannot be verified" warning — right-click the app and choose **Open** once to get past it.

### From source

```bash
git clone https://github.com/henriquekaraim22/claude-lights.git
cd claude-lights
cd app && ./package.sh release   # builds and packages .build/ClaudeLights.app
open .build/ClaudeLights.app     # click "Set up integration" on first launch
```

Building the `.dmg` yourself: `cd app && ./make-dmg.sh` (packages the app first if needed, produces `app/.build/ClaudeLights.dmg`).

Prefer the terminal? `./install.sh` from the repo root does the same thing the app's **Set up integration** button does — copies the hook and merges it into `~/.claude/settings.json`, backing up your existing file first. Either one is safe to re-run.

## Customizing

- **Sounds**: edit `SOUND_MAP` in [`hooks/state.py`](hooks/state.py) — any file in `/System/Library/Sounds/` works. Re-run `./install.sh` after editing.
- **Icon colors**: edit `SessionState.color` in [`app/Sources/ClaudeLights/Models.swift`](app/Sources/ClaudeLights/Models.swift).
- **The menu bar sparkle**: [`assets/spark.svg`](assets/spark.svg) is traced directly into [`SparkShape.swift`](app/Sources/ClaudeLights/SparkShape.swift) as a native SwiftUI `Shape`; swap in your own mark by re-tracing its path.
- **The app icon** (Finder, Dock, the .dmg): replace [`assets/icon-source.png`](assets/icon-source.png) (a single 320x320-or-larger square PNG) — `app/make-icon.sh` derives every size macOS needs from it automatically, `package.sh` calls it on every build.

## Releasing

The version lives in one place, [`app/VERSION`](app/VERSION) — `package.sh` reads it into `Info.plist`, and the app reads it back from there at runtime for the menu footer, so it can't drift out of sync.

```bash
cd app && ./release.sh 0.2.0
```

This bumps `VERSION`, commits, builds, tags `v0.2.0`, pushes the commit and tag, and opens GitHub's new-release page with the tag and title already filled in. The only manual step left is dragging `app/.build/ClaudeLights.dmg` onto that page and clicking **Publish release** — there's no `gh` CLI dependency here, so that upload can't be scripted without a personal access token, which this project deliberately doesn't hold.

## Uninstall

Remove the hook entries from `~/.claude/settings.json` (or restore one of the `settings.json.backup-*` files `install.sh` made), delete `~/.claude/claude-status/`, and remove the app from `/Applications`.

## License

[MIT](LICENSE)

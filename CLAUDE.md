# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

```bash
./scripts/dev.sh              # Kill, build (debug), and restart Clawy
swift build                   # Debug build only
./scripts/build-app.sh        # Production build → dist/Clawy.app + Clawy.zip
```

No external dependencies. Pure Swift + AppKit, macOS 13+.

## Architecture

Clawy is a macOS desktop pet that sits above the Dock and reacts to Claude Code sessions via hooks.

### Data Flow

```
Claude Code session
  → hooks/clawy-hook.sh (parses event JSON, finds terminal PID)
  → writes ~/.clawy/sessions/{session_id}.json
  → SessionAggregator (polls + watches directory, aggregates across sessions)
  → AppDelegate (applies priority: alert > thinking > wave > idle)
  → PetView (animation) + ThoughtBubbleWindow (bubble)
```

### Key Components

- **AppDelegate** — Main coordinator. Manages idle walk, size changes, menu bar, bubble delay/fallback timers, and click-to-focus. Installs hooks on launch, removes on quit/SIGTERM.
- **SessionAggregator** — Watches `~/.clawy/sessions/` for per-session JSON files. Aggregates state across multiple Claude Code sessions with priority logic. Polls every 0.5s + uses DispatchSource.
- **SpriteRenderer** — Draws Clawy programmatically on an 18x16 pixel grid (no asset files). `pixelSize` (4/6/8) controls S/M/L scaling. All animation frames are grid arrays of NSColor.
- **PetWindow** — Borderless transparent window. Uses DockGeometry for positioning. Level above menu bar. `updateVerticalPosition()` adjusts Y only (preserves drag position).
- **PetView** — Pre-caches all animation frames on init. Timer-based frame cycling. Handles click (focus terminal + wave), drag (horizontal only), and right-click (context menu).
- **ThoughtBubble** — Maps command names → cute messages. Returns nil for unknown commands (no bubble shown). Also matches file extensions (.sh, .py, .js, etc.).
- **ThoughtBubbleWindow** — Pixel-art speech bubble, attached as child window of PetWindow so it follows during drag/walk.
- **HookInstaller** — Reads/writes `~/.claude/settings.json` to add/remove hook entries. Finds hook script path from Bundle.main (app) or by walking up from executable (dev).
- **DockGeometry** — Reads `com.apple.dock` UserDefaults + CGWindowList to calculate dock position, icon area bounds, and auto-hide visibility.
- **Config** — Persists to `~/.clawy/config.json`: idle_walk, size (S/M/L), last_x position.

### Hook Script (`hooks/clawy-hook.sh`)

Runs on every Claude Code event. Single python3 call parses the JSON from stdin. Walks process tree (`ps -o ppid`) to find the terminal app PID. Writes per-session state to `~/.clawy/sessions/{session_id}.json`.

### Bubble Delay Logic

Bubbles only show for Bash commands (the ones likely needing permission). A 300ms delay prevents flashing on auto-allowed commands — if PostToolUse arrives within 300ms, the bubble is cancelled. A 30s fallback timer handles cancelled permission prompts.

## File Locations at Runtime

| Path | Purpose |
|------|---------|
| `~/.clawy/config.json` | User config (size, position, idle walk) |
| `~/.clawy/sessions/*.json` | Per-session state from hook script |
| `~/.clawy/hook.log` | Hook debug log (with millisecond timestamps) |
| `~/.claude/settings.json` | Claude Code settings (hooks installed/removed here) |

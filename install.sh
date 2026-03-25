#!/bin/bash
# Installs Clawy hooks into Claude Code settings
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HOOK_SCRIPT="$SCRIPT_DIR/hooks/clawy-hook.sh"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "🐾 Installing Clawy hooks..."

# Make hook script executable
chmod +x "$HOOK_SCRIPT"

# Create status directory
mkdir -p "$HOME/.clawy"
echo "idle" > "$HOME/.clawy/status"

# Update Claude Code settings
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "{}" > "$SETTINGS_FILE"
fi

# Use python3 to merge hooks into settings.json
python3 << PYEOF
import json
import os

settings_path = os.path.expanduser("$SETTINGS_FILE")
hook_script = "$HOOK_SCRIPT"

with open(settings_path, "r") as f:
    settings = json.load(f)

if "hooks" not in settings:
    settings["hooks"] = {}

hook_entry = [{"matcher": "", "hooks": [{"type": "command", "command": hook_script}]}]

# Add hooks for the events we care about
for event in ["Notification", "PreToolUse", "PostToolUse", "Stop", "UserPromptSubmit"]:
    existing = settings["hooks"].get(event, [])
    # Check if we already have this hook installed
    already_installed = any(
        any(h.get("command", "").endswith("clawy-hook.sh") for h in entry.get("hooks", []))
        for entry in existing
    )
    if not already_installed:
        settings["hooks"][event] = existing + [
            {"matcher": "", "hooks": [{"type": "command", "command": hook_script}]}
        ]

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

print(f"Updated {settings_path}")
PYEOF

echo "✅ Clawy hooks installed!"
echo ""
echo "Hook events configured:"
echo "  - Notification  → alert animation"
echo "  - PreToolUse    → thinking animation"
echo "  - PostToolUse   → idle animation"
echo "  - Stop          → wave animation"
echo "  - UserPromptSubmit → thinking animation"
echo ""
echo "To build and run Clawy:"
echo "  cd $SCRIPT_DIR && swift build && .build/debug/Clawy"

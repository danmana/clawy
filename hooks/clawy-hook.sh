#!/bin/bash
# Clawy hook script for Claude Code
# Writes per-session state to ~/.clawy/sessions/<session_id>.json

STATUS_DIR="$HOME/.clawy"
SESSIONS_DIR="$STATUS_DIR/sessions"
LOG_FILE="$STATUS_DIR/hook.log"
mkdir -p "$SESSIONS_DIR"

# Find terminal app PID by walking up the process tree
find_terminal_pid() {
    local PID=$$
    while [ "$PID" -gt 1 ]; do
        local PNAME=$(ps -p "$PID" -o comm= 2>/dev/null)
        case "$PNAME" in
            */Ghostty.app/*|*/Terminal.app/*|*/iTerm2.app/*|*/Alacritty.app/*|*/kitty.app/*|*/WezTerm.app/*|*/Warp.app/*|*/Rio.app/*|*/Tabby.app/*|*/Hyper.app/*|*/Cursor.app/*|*/"Visual Studio Code.app"/*|*/VSCodium.app/*|*/Windsurf.app/*|*/Zed.app/*|*/Nova.app/*|*/"Sublime Text.app"/*|*/Emacs.app/*|*/WebStorm.app/*|*/"IntelliJ IDEA.app"/*|*/PyCharm.app/*|*/GoLand.app/*|*/CLion.app/*|*/Rider.app/*|*/RubyMine.app/*|*/PhpStorm.app/*|*/Fleet.app/*)
                echo "$PID"
                return
                ;;
        esac
        PID=$(ps -p "$PID" -o ppid= 2>/dev/null | tr -d ' ')
    done
}

# Parse everything in a single python3 call
eval "$(python3 -c "
import sys, json, datetime
ts = datetime.datetime.now().strftime('%H:%M:%S.%f')[:-3]
d = json.load(sys.stdin)
sid = d.get('session_id', 'unknown')
event = d.get('hook_event_name', '')
tool = d.get('tool_name', '')
cmd = ''
if tool == 'Bash':
    inp = d.get('tool_input', {})
    c = inp.get('command', '')
    cmd = c.split()[0] if c else ''
print(f'TS={ts!r}')
print(f'SESSION_ID={sid!r}')
print(f'EVENT={event!r}')
print(f'TOOL_NAME={tool!r}')
print(f'COMMAND={cmd!r}')
")"

TERM_PID=$(find_terminal_pid)
SESSION_FILE="$SESSIONS_DIR/${SESSION_ID}.json"

echo "[$TS] SID=${SESSION_ID:0:8} EVENT=$EVENT TOOL=$TOOL_NAME CMD=$COMMAND TERMPID=$TERM_PID" >> "$LOG_FILE"

# Determine state for this session
STATE="idle"
case "$EVENT" in
    "PreToolUse")
        if [ "$TOOL_NAME" = "Bash" ] || [ "$TOOL_NAME" = "WebFetch" ]; then
            STATE="alert"
        else
            STATE="thinking"
        fi
        ;;
    "PostToolUse")
        STATE="idle"
        ;;
    "Stop")
        STATE="wave"
        # Clean up session file after a delay (session ended)
        (sleep 5 && rm -f "$SESSION_FILE") &
        ;;
    "UserPromptSubmit")
        STATE="thinking"
        ;;
    "Notification")
        STATE=""  # No-op
        ;;
esac

# Write session state as JSON (atomic via temp file)
if [ -n "$STATE" ]; then
    python3 -c "
import json, time
d = {
    'state': '$STATE',
    'tool': '$TOOL_NAME',
    'command': '$COMMAND',
    'terminal_pid': ${TERM_PID:-0},
    'timestamp': time.time()
}
with open('$SESSION_FILE', 'w') as f:
    json.dump(d, f)
"
fi

echo '{"continue": true}'
exit 0

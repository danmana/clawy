#!/bin/bash
# Clawy hook script for Claude Code
# Shows bubble on PreToolUse for Bash commands (hides fast if auto-allowed,
# stays visible if permission needed since PostToolUse waits for user response)

STATUS_DIR="$HOME/.clawy"
STATUS_FILE="$STATUS_DIR/status"
TERMINAL_PID_FILE="$STATUS_DIR/terminal_pid"
LOG_FILE="$STATUS_DIR/hook.log"
mkdir -p "$STATUS_DIR"

# Find terminal app PID by walking up the process tree
find_terminal_pid() {
    local PID=$$
    while [ "$PID" -gt 1 ]; do
        local PNAME=$(ps -p "$PID" -o comm= 2>/dev/null)
        # Check if this is a known terminal app
        case "$PNAME" in
            */Ghostty.app/*|*/Terminal.app/*|*/iTerm2.app/*|*/Alacritty.app/*|*/kitty.app/*|*/WezTerm.app/*|*/Warp.app/*)
                echo "$PID"
                return
                ;;
        esac
        PID=$(ps -p "$PID" -o ppid= 2>/dev/null | tr -d ' ')
    done
}

# Parse everything in a single python3 call (including timestamp)
eval "$(python3 -c "
import sys, json, datetime
ts = datetime.datetime.now().strftime('%H:%M:%S.%f')[:-3]
d = json.load(sys.stdin)
event = d.get('hook_event_name', '')
tool = d.get('tool_name', '')
cmd = ''
if tool == 'Bash':
    inp = d.get('tool_input', {})
    c = inp.get('command', '')
    cmd = c.split()[0] if c else ''
print(f'TS={ts!r}')
print(f'EVENT={event!r}')
print(f'TOOL_NAME={tool!r}')
print(f'COMMAND={cmd!r}')
")"

# Save terminal PID on every event (cheap operation)
TERM_PID=$(find_terminal_pid)
if [ -n "$TERM_PID" ]; then
    echo "$TERM_PID" > "$TERMINAL_PID_FILE"
fi

echo "[$TS] EVENT=$EVENT TOOL=$TOOL_NAME CMD=$COMMAND TERMPID=$TERM_PID" >> "$LOG_FILE"

case "$EVENT" in
    "PreToolUse")
        if [ "$TOOL_NAME" = "Bash" ]; then
            echo "alert|${TOOL_NAME}|${COMMAND}" > "$STATUS_FILE"
        else
            echo "thinking" > "$STATUS_FILE"
        fi
        ;;
    "PostToolUse")
        echo "idle" > "$STATUS_FILE"
        ;;
    "Stop")
        echo "wave" > "$STATUS_FILE"
        ;;
    "UserPromptSubmit")
        echo "thinking" > "$STATUS_FILE"
        ;;
    "Notification")
        # No-op, we handle it via PreToolUse now
        ;;
    *)
        echo "idle" > "$STATUS_FILE"
        ;;
esac

echo '{"continue": true}'
exit 0

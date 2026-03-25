#!/bin/bash
# Clawy hook script for Claude Code
# Shows bubble on PreToolUse for Bash commands (hides fast if auto-allowed,
# stays visible if permission needed since PostToolUse waits for user response)

STATUS_DIR="$HOME/.clawd-pet"
STATUS_FILE="$STATUS_DIR/status"
LOG_FILE="$STATUS_DIR/hook.log"
mkdir -p "$STATUS_DIR"

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

echo "[$TS] EVENT=$EVENT TOOL=$TOOL_NAME CMD=$COMMAND" >> "$LOG_FILE"

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

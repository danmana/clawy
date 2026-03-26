#!/bin/bash
# Demo script for recording a Clawy showcase video
# Simulates Claude Code sessions by writing state files directly
#
# Usage: ./scripts/demo.sh
# Make sure Clawy is running before starting!

SESSIONS_DIR="$HOME/.clawy/sessions"
SESSION_ID="demo-session-$(date +%s)"
SESSION_FILE="$SESSIONS_DIR/${SESSION_ID}.json"
TERM_PID=$(pgrep -x "Ghostty" | head -1)  # Adjust if using a different terminal

mkdir -p "$SESSIONS_DIR"

# Colors for script output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

write_state() {
    local state="$1"
    local tool="${2:-}"
    local command="${3:-}"
    python3 -c "
import json, time
d = {
    'state': '$state',
    'tool': '$tool',
    'command': '$command',
    'terminal_pid': ${TERM_PID:-0},
    'timestamp': time.time()
}
with open('$SESSION_FILE', 'w') as f:
    json.dump(d, f)
"
}

cleanup() {
    rm -f "$SESSION_FILE"
    echo -e "\n${GREEN}✓ Cleaned up session file${NC}"
}
trap cleanup EXIT

announce() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}▶ $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

wait_for_enter() {
    echo -e "${GREEN}  Press Enter to continue...${NC}"
    read -r
}

# ─────────────────────────────────────────────────
echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║         🐾 Clawy Demo Script 🐾       ║"
echo "  ║                                       ║"
echo "  ║  Start your screen recorder, then     ║"
echo "  ║  press Enter to begin each scene.     ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"
echo "  Session: $SESSION_ID"
echo "  Terminal PID: ${TERM_PID:-unknown}"
echo ""
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 1: Idle — Clawy chills above the Dock"
echo "  Clawy is in its default idle state, gently bobbing."
echo "  (Let it idle for a few seconds for the recording)"
write_state "idle"
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 2: Thinking — Claude is working on something"
echo "  User submitted a prompt. Clawy looks up with thinking dots..."
write_state "thinking"
sleep 4
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 3: Alert — A git command needs permission!"
echo "  Clawy bounces excitedly with 'Gitty gitty?' bubble"
write_state "alert" "Bash" "git"
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 4: Back to thinking..."
write_state "thinking"
sleep 2

announce "Scene 5: Alert — rm command! Scary!"
echo "  'Trashy trashy?' — Clawy asks about a delete command"
write_state "alert" "Bash" "rm"
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 6: Back to thinking..."
write_state "thinking"
sleep 2

announce "Scene 7: Alert — Docker time!"
echo "  'Docky docky?'"
write_state "alert" "Bash" "docker"
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 8: Back to thinking..."
write_state "thinking"
sleep 2

announce "Scene 9: Alert — npm install"
echo "  'Packy packy?'"
write_state "alert" "Bash" "npm"
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 10: Alert — sudo!"
echo "  'Bossy bossy?' — the spiciest command"
write_state "alert" "Bash" "sudo"
wait_for_enter

# ─────────────────────────────────────────────────
announce "Scene 11: Wave — Session ends!"
echo "  Claude is done. Clawy waves goodbye!"
write_state "wave"
sleep 3

# ─────────────────────────────────────────────────
announce "Scene 12: Back to idle"
echo "  Clawy returns to chilling."
write_state "idle"
sleep 2

# ─────────────────────────────────────────────────
announce "Scene 13: Rapid sequence — realistic Claude session"
echo "  Simulating a realistic flow: think → alert → think → alert → wave"
echo ""

echo "  [thinking] Claude is analyzing code..."
write_state "thinking"
sleep 3

echo "  [alert] Running: git status"
write_state "alert" "Bash" "git"
sleep 3

echo "  [thinking] Claude is writing code..."
write_state "thinking"
sleep 3

echo "  [alert] Running: swift build"
write_state "alert" "Bash" "swift"
sleep 3

echo "  [thinking] Almost done..."
write_state "thinking"
sleep 2

echo "  [alert] Running: ./scripts/dev.sh"
write_state "alert" "Bash" "./scripts/dev.sh"
sleep 3

echo "  [wave] Session complete!"
write_state "wave"
sleep 3

write_state "idle"

# ─────────────────────────────────────────────────
echo ""
echo -e "${CYAN}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║        🎬 Demo complete! 🎬           ║"
echo "  ║                                       ║"
echo "  ║  Tip: You can also click Clawy to     ║"
echo "  ║  trigger a wave, or right-click for   ║"
echo "  ║  the context menu during recording.   ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

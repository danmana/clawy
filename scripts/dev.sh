#!/bin/bash
# Kill, build, and restart Clawy for development
set -e
pgrep -x Clawy | xargs kill 2>/dev/null || true
sleep 0.5
cd "$(dirname "$0")/.."
swift build 2>&1
.build/debug/Clawy &
echo "Clawy is running"

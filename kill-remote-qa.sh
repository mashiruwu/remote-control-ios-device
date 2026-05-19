#!/bin/bash
set -euo pipefail

# Remote QA kill script
#
# Stops processes started by run-remote-qa.sh and cleans common stale ports/processes.
#
# Usage:
#   ./kill-remote-qa.sh

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$PROJECT_DIR/.remoteqa.pids"

echo "Stopping Remote QA..."

kill_pid() {
  local name="$1"
  local pid="$2"

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "Stopping $name PID $pid..."
    kill "$pid" >/dev/null 2>&1 || true
  fi
}

kill_pid_force() {
  local name="$1"
  local pid="$2"

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "Force killing $name PID $pid..."
    kill -9 "$pid" >/dev/null 2>&1 || true
  fi
}

# 1. Stop tracked PIDs gracefully.
if [ -f "$PID_FILE" ]; then
  while IFS=: read -r name pid; do
    [ -z "${pid:-}" ] && continue
    kill_pid "$name" "$pid"
  done < "$PID_FILE"

  sleep 2

  while IFS=: read -r name pid; do
    [ -z "${pid:-}" ] && continue
    kill_pid_force "$name" "$pid"
  done < "$PID_FILE"

  rm -f "$PID_FILE"
fi

# 2. Kill common leftover processes.
echo "Killing common leftover processes..."

pkill -f "mediamtx" >/dev/null 2>&1 || true
pkill -f "appium" >/dev/null 2>&1 || true
pkill -f "node server.js" >/dev/null 2>&1 || true
pkill -f "WebDriverAgent" >/dev/null 2>&1 || true
pkill -f "xcodebuild.*WebDriverAgent" >/dev/null 2>&1 || true
pkill -f "iproxy" >/dev/null 2>&1 || true

# If your start-qa-iphone.sh starts the Swift QTWindowStream process, kill it too.
pkill -f "QTWindowStream" >/dev/null 2>&1 || true
pkill -f "swift run QTWindowStream" >/dev/null 2>&1 || true

# Optional: close OBS and QuickTime.
# Comment these two lines if you want to keep the apps open.
osascript -e 'tell application "OBS" to quit' >/dev/null 2>&1 || true
osascript -e 'tell application "QuickTime Player" to quit' >/dev/null 2>&1 || true

# 3. Free known ports.
echo "Freeing common ports..."

for port in 3000 4723 8100 8101 8889 8890; do
  pids="$(lsof -tiTCP:$port -sTCP:LISTEN 2>/dev/null || true)"
  if [ -n "$pids" ]; then
    echo "Killing port $port: $pids"
    echo "$pids" | xargs kill -9 >/dev/null 2>&1 || true
  fi
done

echo "Remote QA stopped."

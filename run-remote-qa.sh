#!/bin/bash
set -euo pipefail

# Remote QA startup script
#
# Runs:
# - MediaMTX
# - QuickTime setup script inside qt-window-stream/
# - Appium
# - Node web server
# - OBS launch script
#
# Usage:
#   chmod +x run-remote-qa.sh kill-remote-qa.sh
#   ./run-remote-qa.sh
#
# Optional:
#   DEVICE_NAME="iPad" ./run-remote-qa.sh
#   DEVICE_NAME="iPhone" OBS_SCRIPT="./run-iphone-obs.sh" ./run-remote-qa.sh

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$PROJECT_DIR/.remoteqa.pids"

DEVICE_NAME="${DEVICE_NAME:-iPhone}"

MEDIAMTX_CONFIG="${MEDIAMTX_CONFIG:-mediamtx.yml}"

QUICKTIME_DIR="${QUICKTIME_DIR:-$PROJECT_DIR/qt-window-stream}"
QUICKTIME_SCRIPT="${QUICKTIME_SCRIPT:-start-qa-iphone.sh}"

OBS_SCRIPT="${OBS_SCRIPT:-./run-ipad-obs.sh}"

mkdir -p "$LOG_DIR"
: > "$PID_FILE"

cd "$PROJECT_DIR"

save_pid() {
  local name="$1"
  local pid="$2"
  echo "$name:$pid" >> "$PID_FILE"
}

start_bg() {
  local name="$1"
  local log_file="$2"
  shift 2

  echo "Starting $name..."
  "$@" > "$log_file" 2>&1 &
  local pid=$!

  save_pid "$name" "$pid"

  echo "$name PID: $pid"
}

run_fg_in_dir() {
  local name="$1"
  local dir="$2"
  local log_file="$3"
  shift 3

  echo "Running $name in $dir..."

  (
    cd "$dir"
    "$@"
  ) > "$log_file" 2>&1

  echo "$name done."
}

is_port_busy() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

echo "Remote QA starting..."
echo "Project dir: $PROJECT_DIR"
echo "Logs: $LOG_DIR"
echo "Device: $DEVICE_NAME"
echo ""

if is_port_busy 3000; then
  echo "Port 3000 is already busy. Run ./kill-remote-qa.sh first."
  exit 1
fi

if is_port_busy 4723; then
  echo "Port 4723 is already busy. Run ./kill-remote-qa.sh first."
  exit 1
fi

if is_port_busy 8889; then
  echo "Port 8889 is already busy. Run ./kill-remote-qa.sh first."
  exit 1
fi

# 1. Start MediaMTX first because OBS publishes to it.
start_bg "mediamtx" "$LOG_DIR/mediamtx.log" mediamtx "$MEDIAMTX_CONFIG"

sleep 1

# 2. Open QuickTime / prepare iPhone or iPad capture.
# This runs from qt-window-stream/ because the script depends on that folder.
if [ -f "$QUICKTIME_DIR/$QUICKTIME_SCRIPT" ]; then
  chmod +x "$QUICKTIME_DIR/$QUICKTIME_SCRIPT" >/dev/null 2>&1 || true

  echo "Starting quicktime setup in $QUICKTIME_DIR..."

  (
    cd "$QUICKTIME_DIR"
    "./$QUICKTIME_SCRIPT" "$DEVICE_NAME"
  ) > "$LOG_DIR/quicktime.log" 2>&1 &

  quicktime_pid=$!
  save_pid "quicktime" "$quicktime_pid"

  echo "quicktime PID: $quicktime_pid"
  echo "Waiting for QuickTime to open/select device..."

  sleep 8

  echo "Continuing after QuickTime setup."
else
  echo "Skipping QuickTime script: $QUICKTIME_DIR/$QUICKTIME_SCRIPT not found"
fi

sleep 3

# 3. Start Appium for input/control.
start_bg "appium" "$LOG_DIR/appium.log" appium --address 127.0.0.1 --port 4723 --log-level error

sleep 2

# 4. Start Node web server.
start_bg "node-server" "$LOG_DIR/node-server.log" node server.js

sleep 2

# 5. Start OBS script last, after QuickTime and MediaMTX are ready.
if [ -x "$OBS_SCRIPT" ]; then
  start_bg "obs" "$LOG_DIR/obs.log" "$OBS_SCRIPT"
else
  echo "Skipping OBS script: $OBS_SCRIPT not found or not executable"
fi

echo ""
echo "Remote QA started."
echo ""
echo "Open:"
echo "  http://localhost:3000"
echo ""
echo "OBS should publish to:"
echo "  http://localhost:8889/simulator/whip"
echo ""
echo "Browser should load:"
echo "  http://localhost:8889/simulator"
echo ""
echo "Logs:"
echo "  tail -f logs/mediamtx.log"
echo "  tail -f logs/quicktime.log"
echo "  tail -f logs/appium.log"
echo "  tail -f logs/node-server.log"
echo "  tail -f logs/obs.log"
echo ""
echo "To stop everything:"
echo "  ./kill-remote-qa.sh"
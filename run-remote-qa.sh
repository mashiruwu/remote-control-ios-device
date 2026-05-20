#!/bin/bash
set -euo pipefail

# Remote QA startup script
#
# Runs:
# - MediaMTX
# - Appium
# - Node web server
# - OBS launch script
#
# QuickTime is NOT opened here.
# Open/configure QuickTime manually before running this script.
#
# Usage:
#   ./run-remote-qa.sh iphone "Henrick's iPhone"
#   ./run-remote-qa.sh ipad "Henrick's iPad"
#
# Alternative using env vars:
#   DEVICE_TYPE="iphone" DEVICE_NAME="Henrick's iPhone" ./run-remote-qa.sh
#   DEVICE_TYPE="ipad" DEVICE_NAME="Henrick's iPad" ./run-remote-qa.sh
#
# Optional:
#   APP_BUNDLE_ID="com.company.app" XCODE_ORG_ID="TEAMID1234" ./run-remote-qa.sh iphone "Henrick's iPhone"

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
PID_FILE="$PROJECT_DIR/.remoteqa.pids"

DEVICE_TYPE="${1:-${DEVICE_TYPE:-iphone}}"
DEVICE_NAME="${DEVICE_NAME:-}"
DEVICE_UDID="${DEVICE_UDID:-}"

MEDIAMTX_CONFIG="${MEDIAMTX_CONFIG:-mediamtx.yml}"

NODE_PORT="${NODE_PORT:-3000}"
APPIUM_PORT="${APPIUM_PORT:-4723}"
MEDIAMTX_PORT="${MEDIAMTX_PORT:-8889}"
WDA_LOCAL_PORT="${WDA_LOCAL_PORT:-8101}"

WEBRTC_PATH="${WEBRTC_PATH:-/simulator}"
PUBLIC_HOST="${PUBLIC_HOST:-}"

APP_BUNDLE_ID="${APP_BUNDLE_ID:-com.apple.Preferences}"
XCODE_ORG_ID="${XCODE_ORG_ID:-}"

WEBRTC_PATH="${WEBRTC_PATH:-/simulator}"
PUBLIC_HOST="${PUBLIC_HOST:-}"

mkdir -p "$LOG_DIR"
: > "$PID_FILE"

cd "$PROJECT_DIR"

usage() {
  echo "Usage:"
  echo "  ./run-remote-qa.sh iphone \"Device Name\""
  echo "  ./run-remote-qa.sh ipad \"Device Name\""
  echo ""
  echo "Examples:"
  echo "  ./run-remote-qa.sh iphone \"Henrick's iPhone\""
  echo "  ./run-remote-qa.sh ipad \"Henrick's iPad\""
  echo ""
  echo "You can list connected devices with:"
  echo "  xcrun xctrace list devices"
  echo "  idevice_id -l"
}

normalize_device_type() {
  local raw
  raw="$(echo "$1" | tr '[:upper:]' '[:lower:]')"

  case "$raw" in
    iphone|ios-phone|phone)
      echo "iphone"
      ;;
    ipad|ios-tablet|tablet)
      echo "ipad"
      ;;
    *)
      echo "Invalid DEVICE_TYPE: $1"
      echo "Allowed: iphone, ipad"
      exit 1
      ;;
  esac
}

default_obs_script_for_type() {
  local type="$1"

  case "$type" in
    iphone)
      echo "./run-iphone-obs.sh"
      ;;
    ipad)
      echo "./run-ipad-obs.sh"
      ;;
  esac
}

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

is_port_busy() {
  local port="$1"
  lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1
}

detect_public_host() {
  if [ -n "$PUBLIC_HOST" ]; then
    echo "$PUBLIC_HOST"
    return
  fi

  if command -v tailscale >/dev/null 2>&1; then
    local tailscale_ip
    tailscale_ip="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"

    if [ -n "$tailscale_ip" ]; then
      echo "$tailscale_ip"
      return
    fi
  fi

  echo "localhost"
}

find_udid_by_name_xctrace() {
  local name="$1"

  xcrun xctrace list devices 2>/dev/null \
    | grep "$name" \
    | grep -Eo '\([0-9A-Fa-f-]{25,}\)' \
    | head -n 1 \
    | tr -d '()' || true
}

find_first_real_device_udid() {
  if command -v idevice_id >/dev/null 2>&1; then
    idevice_id -l | head -n 1 || true
  fi
}

find_device_line_by_type() {
  local type="$1"

  xcrun xctrace list devices 2>/dev/null \
    | grep -v "Simulator" \
    | grep -E '\([0-9A-Fa-f-]{25,}\)' \
    | while read -r line; do
        local lower
        lower="$(echo "$line" | tr '[:upper:]' '[:lower:]')"

        if [ "$type" = "iphone" ] && echo "$lower" | grep -q "iphone"; then
          echo "$line"
          return 0
        fi

        if [ "$type" = "ipad" ] && echo "$lower" | grep -q "ipad"; then
          echo "$line"
          return 0
        fi
      done
}

extract_name_from_xctrace_line() {
  echo "$1" | sed -E 's/^[[:space:]]*//; s/[[:space:]]+\([0-9A-Fa-f-]{25,}\).*//'
}

extract_udid_from_xctrace_line() {
  echo "$1" | grep -Eo '\([0-9A-Fa-f-]{25,}\)' | head -n 1 | tr -d '()'
}

DEVICE_TYPE="$(normalize_device_type "$DEVICE_TYPE")"
OBS_SCRIPT="${OBS_SCRIPT:-$PROJECT_DIR/$(basename "$(default_obs_script_for_type "$DEVICE_TYPE")")}"

if [ -z "$DEVICE_NAME" ] || [ -z "$DEVICE_UDID" ]; then
  echo "Trying to find connected $DEVICE_TYPE using xcrun xctrace..."

  DEVICE_LINE="$(find_device_line_by_type "$DEVICE_TYPE" || true)"

  if [ -n "$DEVICE_LINE" ]; then
    DEVICE_NAME="${DEVICE_NAME:-$(extract_name_from_xctrace_line "$DEVICE_LINE")}"
    DEVICE_UDID="${DEVICE_UDID:-$(extract_udid_from_xctrace_line "$DEVICE_LINE")}"
  fi
fi

echo "Remote QA starting..."
echo "Project dir: $PROJECT_DIR"
echo "Logs: $LOG_DIR"
echo "Device type: $DEVICE_TYPE"
echo "Device name: $DEVICE_NAME"
echo ""

DEVICE_UDID="${DEVICE_UDID:-}"

if [ -z "$DEVICE_UDID" ]; then
  echo "Could not find a $DEVICE_TYPE using xcrun xctrace."
  echo "Trying first connected real device using idevice_id..."
  DEVICE_UDID="$(find_first_real_device_udid)"
fi

if [ -z "$DEVICE_NAME" ]; then
  DEVICE_NAME="$DEVICE_TYPE"
fi

if [ -z "$DEVICE_UDID" ]; then
  echo "Could not detect device UDID."
  echo ""
  echo "Make sure the device is:"
  echo "  - connected by USB"
  echo "  - unlocked"
  echo "  - trusted by this Mac"
  echo "  - visible in Xcode"
  echo ""
  usage
  exit 1
fi

echo "Detected device UDID: $DEVICE_UDID"
echo ""

if [ -z "$APP_BUNDLE_ID" ]; then
  echo "Warning: APP_BUNDLE_ID is empty."
  echo "The Node server must already know the appBundleId, or Appium session creation may fail."
fi

if [ -z "$XCODE_ORG_ID" ]; then
  echo "Warning: XCODE_ORG_ID is empty."
  echo "The Node server must already know the xcodeOrgId, or WebDriverAgent signing may fail."
fi

if is_port_busy "$NODE_PORT"; then
  echo "Port $NODE_PORT is already busy. Run ./kill-remote-qa.sh first."
  exit 1
fi

if is_port_busy "$APPIUM_PORT"; then
  echo "Port $APPIUM_PORT is already busy. Run ./kill-remote-qa.sh first."
  exit 1
fi

if is_port_busy "$MEDIAMTX_PORT"; then
  echo "Port $MEDIAMTX_PORT is already busy. Run ./kill-remote-qa.sh first."
  exit 1
fi

PUBLIC_HOST="$(detect_public_host)"

echo "Public host: $PUBLIC_HOST"

if [ "$PUBLIC_HOST" = "localhost" ]; then
  echo "Remote access: disabled or Tailscale not connected"
else
  echo "Remote access URL will use: $PUBLIC_HOST"
fi

echo ""

# 1. Start MediaMTX first because OBS publishes to it.
start_bg "mediamtx" "$LOG_DIR/mediamtx.log" mediamtx "$MEDIAMTX_CONFIG"

sleep 1

echo ""
echo "QuickTime is manual in this flow."
echo "Make sure QuickTime is already open and showing the $DEVICE_NAME screen."
echo ""

sleep 2

# 2. Start Appium for input/control.
start_bg "appium" "$LOG_DIR/appium.log" appium --address 127.0.0.1 --port "$APPIUM_PORT" --log-level error

sleep 2

# 3. Start Node web server.
start_bg "node-server" "$LOG_DIR/node-server.log" env \
  PORT="$NODE_PORT" \
  PUBLIC_HOST="$PUBLIC_HOST" \
  APPIUM_URL="http://127.0.0.1:$APPIUM_PORT" \
  MEDIAMTX_PORT="$MEDIAMTX_PORT" \
  DEVICE_TYPE="$DEVICE_TYPE" \
  DEVICE_NAME="$DEVICE_NAME" \
  DEVICE_UDID="$DEVICE_UDID" \
  APP_BUNDLE_ID="$APP_BUNDLE_ID" \
  XCODE_ORG_ID="$XCODE_ORG_ID" \
  WDA_LOCAL_PORT="$WDA_LOCAL_PORT" \
  WEBRTC_PATH="$WEBRTC_PATH" \
  node server.js

sleep 2

# 4. Start OBS script last, after QuickTime and MediaMTX are open.
if [ -f "$OBS_SCRIPT" ]; then
  chmod +x "$OBS_SCRIPT" >/dev/null 2>&1 || true
  start_bg "obs" "$LOG_DIR/obs.log" "$OBS_SCRIPT"
else
  echo "Skipping OBS script: $OBS_SCRIPT not found"
fi

echo ""
echo "Remote QA started."
echo ""
echo "Open:"
echo "Open locally:"
echo "  http://localhost:$NODE_PORT"
echo ""
echo "Open remotely:"
echo "  http://$PUBLIC_HOST:$NODE_PORT"
echo ""
echo "Remote browser video URL:"
echo "  http://$PUBLIC_HOST:$MEDIAMTX_PORT$WEBRTC_PATH"
echo ""
echo "OBS should publish to:"
echo "  http://localhost:$MEDIAMTX_PORT$WEBRTC_PATH/whip"
echo ""
echo "Browser should load:"
echo "  http://$PUBLIC_HOST:$MEDIAMTX_PORT$WEBRTC_PATH"
echo ""
echo "Device:"
echo "  Type: $DEVICE_TYPE"
echo "  Name: $DEVICE_NAME"
echo "  UDID: $DEVICE_UDID"
echo ""
echo "Logs:"
echo "  tail -f logs/mediamtx.log"
echo "  tail -f logs/appium.log"
echo "  tail -f logs/node-server.log"
echo "  tail -f logs/obs.log"
echo ""
echo "To stop everything:"
echo "  ./kill-remote-qa.sh"

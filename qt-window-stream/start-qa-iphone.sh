#!/bin/bash
set -e

DEVICE_NAME="iPad"
PORT="${2:-8090}"

echo "Starting QA iPad stream..."
echo "Device: $DEVICE_NAME"
echo "Port: $PORT"

swift run QTWindowStream \
  --device "$DEVICE_NAME" \
  --script ./open-iphone-quicktime.applescript \
  --port "$PORT"
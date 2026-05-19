#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
OBS_CONFIG="$HOME/Library/Application Support/obs-studio"

echo "Installing OBS RemoteQA template..."

mkdir -p "$OBS_CONFIG/basic/profiles"
mkdir -p "$OBS_CONFIG/basic/scenes"

cp -R "$PROJECT_DIR/obs-template/basic/profiles/RemoteQA" \
  "$OBS_CONFIG/basic/profiles/RemoteQA"

cp "$PROJECT_DIR/obs-template/basic/scenes/RemoteQA.json" \
  "$OBS_CONFIG/basic/scenes/RemoteQA.json"

echo "OBS template installed."
echo "Profile: RemoteQA"
echo "Scene Collection: RemoteQA"
echo "Scene: iPhone"
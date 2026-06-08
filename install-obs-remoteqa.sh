#!/bin/bash
set -euo pipefail

# install-obs-remoteqa.sh
#
# Installs OBS RemoteQA profiles/scenes.
#
# What it does:
# 1. Creates OBS config folders if needed.
# 2. If obs-template exists, copies profiles/scenes from it.
# 3. Always creates/updates RemoteQA-iPhone and RemoteQA-iPad profiles.
# 4. Configures both profiles to publish to MediaMTX WHIP.
#
# Usage:
#   chmod +x install-obs-remoteqa.sh
#   ./install-obs-remoteqa.sh
#
# Optional:
#   WHIP_BASE_URL="http://localhost" ./install-obs-remoteqa.sh

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OBS_CONFIG="$HOME/Library/Application Support/obs-studio"
WHIP_BASE_URL="${WHIP_BASE_URL:-http://localhost:8889}"

OBS_PROFILES_DIR="$OBS_CONFIG/basic/profiles"
OBS_SCENES_DIR="$OBS_CONFIG/basic/scenes"

echo "Installing OBS RemoteQA setup..."
echo "Project dir: $PROJECT_DIR"
echo "OBS config:  $OBS_CONFIG"
echo "WHIP URL:    $WHIP_BASE_URL/simulator/whip"
echo ""

mkdir -p "$OBS_PROFILES_DIR"
mkdir -p "$OBS_SCENES_DIR"

copy_template_if_exists() {
  local TEMPLATE_DIR="$PROJECT_DIR/obs-template/basic"

  if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "No obs-template/basic folder found. Skipping template copy."
    return
  fi

  echo "obs-template found. Copying available templates..."

  if [ -d "$TEMPLATE_DIR/profiles" ]; then
    cp -R "$TEMPLATE_DIR/profiles/"* "$OBS_PROFILES_DIR/" 2>/dev/null || true
    echo "Copied OBS profile templates."
  fi

  if [ -d "$TEMPLATE_DIR/scenes" ]; then
    cp "$TEMPLATE_DIR/scenes/"*.json "$OBS_SCENES_DIR/" 2>/dev/null || true
    echo "Copied OBS scene templates."
  fi
}

create_profile() {
  local NAME="$1"
  local CANVAS_W="$2"
  local CANVAS_H="$3"
  local OUTPUT_W="$4"
  local OUTPUT_H="$5"
  local FPS="$6"
  local BITRATE="$7"
  local STREAM_PATH="$8"

  local PROFILE_DIR="$OBS_PROFILES_DIR/$NAME"

  echo "Creating/updating OBS profile: $NAME"

  mkdir -p "$PROFILE_DIR"

  cat > "$PROFILE_DIR/basic.ini" <<EOF
[General]
Name=$NAME

[Video]
BaseCX=$CANVAS_W
BaseCY=$CANVAS_H
OutputCX=$OUTPUT_W
OutputCY=$OUTPUT_H
FPSType=0
FPSCommon=$FPS
ScaleType=bilinear
ColorFormat=NV12
ColorSpace=709
ColorRange=Partial

[Output]
Mode=Advanced

[AdvOut]
TrackIndex=1
RecType=Standard
RecFormat2=mkv
RecTracks=1
Encoder=obs_x264
ApplyServiceSettings=true
UseRescale=false
Track1Bitrate=96
VodTrackIndex=2
FFOutputToFile=true

[Stream1]
IgnoreRecommended=false
EOF

  cat > "$PROFILE_DIR/service.json" <<EOF
{
  "settings": {
    "server": "$WHIP_BASE_URL$STREAM_PATH/whip",
    "service": "WHIP"
  },
  "type": "whip_custom"
}
EOF
}

copy_template_if_exists

# Current setup uses the same MediaMTX path for both.
create_profile "RemoteQA-iPhone" 720 1560 360 780 30 800 "/simulator"
create_profile "RemoteQA-iPad" 1572 1092 960 667 30 1000 "/simulator"

echo ""
echo "OBS RemoteQA setup installed."
echo ""
echo "Profiles:"
echo "  RemoteQA-iPhone"
echo "  RemoteQA-iPad"
echo ""
echo "Expected scene collections:"
echo "  $OBS_SCENES_DIR/RemoteQA-iPhone.json"
echo "  $OBS_SCENES_DIR/RemoteQA-iPad.json"
echo ""
echo "If scenes were not copied from obs-template, open OBS and create:"
echo "  Scene Collection: RemoteQA-iPhone | Scene: iPhone"
echo "  Scene Collection: RemoteQA-iPad   | Scene: iPad"
echo ""
echo "OBS publishes to:"
echo "  $WHIP_BASE_URL/simulator/whip"

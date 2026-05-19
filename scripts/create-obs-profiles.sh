#!/bin/bash
set -e

OBS_CONFIG="$HOME/Library/Application Support/obs-studio"

create_profile() {
  local NAME="$1"
  local CANVAS_W="$2"
  local CANVAS_H="$3"
  local OUTPUT_W="$4"
  local OUTPUT_H="$5"
  local FPS="$6"
  local BITRATE="$7"

  local PROFILE_DIR="$OBS_CONFIG/basic/profiles/$NAME"

  echo "Creating OBS profile: $NAME"

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
ScaleType=bicubic
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
Track1Bitrate=160
VodTrackIndex=2

[AdvOut]
FFOutputToFile=true

[Stream1]
IgnoreRecommended=false
EOF
    PROFILE_NAME="RemoteQA-iPhone"
    PROFILE_DIR="$HOME/Library/Application Support/obs-studio/basic/profiles/$PROFILE_NAME"
  cat > "$PROFILE_DIR/service.json" <<EOF
{
  "settings": {
    "server": "http://localhost:8889/simulator/whip",
    "service": "WHIP"
  },
  "type": "whip_custom"
}
EOF
    PROFILE_NAME="RemoteQA-iPad"
    PROFILE_DIR="$HOME/Library/Application Support/obs-studio/basic/profiles/$PROFILE_NAME"
  cat > "$PROFILE_DIR/service.json" <<EOF
{
  "settings": {
    "server": "http://localhost:8889/simulator/whip",
    "service": "WHIP"
  },
  "type": "whip_custom"
}
EOF
}

mkdir -p "$OBS_CONFIG/basic/profiles"
mkdir -p "$OBS_CONFIG/basic/scenes"

create_profile "RemoteQA-iPhone" 1206 2633 400 876 60 2000
create_profile "RemoteQA-iPad" 2360 1640 1572 1092 60 2500

echo "OBS profiles created."
echo "Now create/copy scene collections:"
echo "$OBS_CONFIG/basic/scenes/RemoteQA-iPhone.json"
echo "$OBS_CONFIG/basic/scenes/RemoteQA-iPad.json"
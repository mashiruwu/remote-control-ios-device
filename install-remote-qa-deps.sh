#!/bin/bash
set -euo pipefail

# Remote QA dependency installer for macOS
#
# This script installs/checks:
# - Xcode Command Line Tools
# - Homebrew
# - Node.js + npm
# - Appium
# - Appium XCUITest driver
# - libimobiledevice
# - ios-deploy
# - OBS Studio
# - MediaMTX
# - Tailscale
#
# It cannot fully automate:
# - Installing full Xcode from the App Store / Apple Developer website
# - Accepting the USB "Trust This Computer" prompt on the iPhone/iPad
# - Creating/choosing your Apple Developer Team ID
# - Granting macOS Screen Recording permissions for OBS if needed
# - Manually configuring OBS scenes if your template is not already present
# - Running WebDriverAgent manually in Xcode the first time

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "=========================================="
echo "Remote QA macOS Setup"
echo "=========================================="
echo ""

if [[ "$(uname)" != "Darwin" ]]; then
  echo "This setup script is intended for macOS only."
  exit 1
fi

section() {
  echo ""
  echo "------------------------------------------"
  echo "$1"
  echo "------------------------------------------"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

section "1. Checking Xcode Command Line Tools"

if xcode-select -p >/dev/null 2>&1; then
  echo "Xcode Command Line Tools found:"
  xcode-select -p
else
  echo "Xcode Command Line Tools are not installed."
  echo "Opening Apple installer..."
  xcode-select --install || true
  echo ""
  echo "Finish the installer, then run this script again."
  exit 1
fi

section "2. Checking full Xcode"

if [[ -d "/Applications/Xcode.app" ]]; then
  echo "Xcode found at /Applications/Xcode.app"
  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept || true
  xcodebuild -version || true
else
  echo "Full Xcode was not found at /Applications/Xcode.app"
  echo ""
  echo "Install Xcode manually from the App Store or Apple Developer website."
  echo "After installing, run:"
  echo "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo "  sudo xcodebuild -license accept"
  echo ""
  echo "Then run this setup script again."
  exit 1
fi

section "3. Installing Homebrew if needed"

if command_exists brew; then
  echo "Homebrew found:"
  brew --version | head -n 1
else
  echo "Homebrew not found. Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

if ! command_exists brew; then
  echo "brew is still not available in PATH."
  echo "Restart the terminal or add Homebrew to your shell profile, then run this again."
  exit 1
fi

section "4. Installing system dependencies with Homebrew"

brew update

brew install node || brew upgrade node || true
brew install libimobiledevice || brew upgrade libimobiledevice || true
brew install ios-deploy || brew upgrade ios-deploy || true
brew install mediamtx || brew upgrade mediamtx || true
brew install --cask obs || brew upgrade --cask obs || true
brew install --cask tailscale || brew upgrade --cask tailscale || true

section "5. Installing Appium and XCUITest driver"

if command_exists npm; then
  echo "npm found:"
  npm --version
else
  echo "npm was not found after installing Node."
  exit 1
fi

npm install -g appium

if appium driver list --installed 2>/dev/null | grep -qi "xcuitest"; then
  echo "Appium XCUITest driver already installed."

  read -r -p "Do you want to update the XCUITest driver? [y/N] " UPDATE_XCUITEST

  if [[ "${UPDATE_XCUITEST:-N}" =~ ^[Yy]$ ]]; then
    appium driver update xcuitest || true
  else
    echo "Skipping XCUITest driver update."
  fi
else
  appium driver install xcuitest || {
    echo "XCUITest driver install failed."
    echo "If it is already installed, this is usually safe to ignore."
    echo "Installed drivers:"
    appium driver list --installed || true
  }
fi

section "6. Running Appium XCUITest doctor"

echo "This may show warnings if the device is not connected yet or signing is not configured."
appium driver doctor xcuitest || true

section "7. Preparing project scripts"

cd "$PROJECT_DIR"

chmod +x ./*.sh 2>/dev/null || true
chmod +x ./qt-window-stream/*.sh 2>/dev/null || true

mkdir -p logs
mkdir -p docs/images/remote-qa

echo "Created:"
echo "  logs/"
echo "  docs/images/remote-qa/"

section "8. Installing Node project dependencies if package.json exists"

if [[ -f "$PROJECT_DIR/package.json" ]]; then
  npm install
else
  echo "No package.json found in $PROJECT_DIR. Skipping npm install for the project."
fi

section "9. Creating OBS profiles if script exists"

if [[ -f "$PROJECT_DIR/create-obs-profiles.sh" ]]; then
  chmod +x "$PROJECT_DIR/create-obs-profiles.sh"
  "$PROJECT_DIR/create-obs-profiles.sh" || true
else
  echo "create-obs-profiles.sh not found. Skipping OBS profile creation."
fi

section "10. Detecting connected iOS devices"

if command_exists idevice_id; then
  CONNECTED_DEVICES="$(idevice_id -l || true)"
  if [[ -n "$CONNECTED_DEVICES" ]]; then
    echo "Connected device UDID(s):"
    echo "$CONNECTED_DEVICES"
  else
    echo "No iPhone/iPad detected by libimobiledevice."
    echo "Connect the device by USB, unlock it, and tap 'Trust This Computer'."
  fi
else
  echo "idevice_id command not found."
fi

section "11. Checking Tailscale"

if command_exists tailscale; then
  echo "Tailscale found:"
  tailscale version || true

  TAILSCALE_IP="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"

  if [[ -n "$TAILSCALE_IP" ]]; then
    echo "Tailscale IP:"
    echo "  $TAILSCALE_IP"
  else
    echo "Tailscale is installed but not connected."
    echo "Open Tailscale and log in, or run:"
    echo "  tailscale up"
  fi
else
  echo "Tailscale command not found."
  echo "Open the Tailscale app once after install."
fi

section "12. Optional: patch server.js config"

SERVER_FILE="$PROJECT_DIR/server.js"

if [[ -f "$SERVER_FILE" ]]; then
  echo "server.js found."
  echo ""
  read -r -p "Do you want to patch appBundleId, udid, and xcodeOrgId in server.js now? [y/N] " PATCH_SERVER

  if [[ "${PATCH_SERVER:-N}" =~ ^[Yy]$ ]]; then
    read -r -p "App bundle id, example com.company.app: " APP_BUNDLE_ID
    read -r -p "Device UDID, paste from the detected list above: " DEVICE_UDID
    read -r -p "Apple Developer Team ID: " TEAM_ID

    python3 - "$SERVER_FILE" "$APP_BUNDLE_ID" "$DEVICE_UDID" "$TEAM_ID" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
app_bundle_id = sys.argv[2]
device_udid = sys.argv[3]
team_id = sys.argv[4]

text = path.read_text()

replacements = {
    r'appBundleId:\s*"[^"]*"': f'appBundleId: "{app_bundle_id}"',
    r'udid:\s*"[^"]*"': f'udid: "{device_udid}"',
    r'xcodeOrgId:\s*"[^"]*"': f'xcodeOrgId: "{team_id}"',
}

for pattern, replacement in replacements.items():
    text = re.sub(pattern, replacement, text, count=1)

path.write_text(text)
print("server.js patched successfully.")
PY
  else
    echo "Skipping server.js patch."
  fi
else
  echo "server.js not found. Skipping config patch."
fi

section "13. Opening WebDriverAgent in Xcode"

WDA_PROJECT="$(
  find "$HOME/.appium" "$(npm root -g)" \
    -name "WebDriverAgent.xcodeproj" \
    -type d \
    2>/dev/null \
    | head -n 1 || true
)"

if [[ -n "$WDA_PROJECT" ]]; then
  echo "Found WebDriverAgent:"
  echo "  $WDA_PROJECT"
  echo ""
  echo "Opening WebDriverAgent in Xcode..."
  open -a Xcode "$WDA_PROJECT" || true
else
  echo "Could not find WebDriverAgent.xcodeproj automatically."
  echo ""
  echo "Try locating it manually with:"
  echo "  find \"$HOME/.appium\" \"$(npm root -g)\" -name WebDriverAgent.xcodeproj -type d"
fi

section "14. Making all scripts executable"

find "$PROJECT_DIR" -maxdepth 2 -name "*.sh" -type f -exec chmod +x {} \;

echo "All shell scripts are now executable."

section "15. Final manual steps"

echo "Setup finished."
echo ""
echo "Manual steps still required:"
echo "1. Connect the iPhone/iPad by USB."
echo "2. Unlock it and tap 'Trust This Computer'."
echo "3. Make sure your Apple Developer Team ID is configured in server.js or env vars."
echo "4. Open OBS once and allow macOS Screen Recording permissions if prompted."
echo "5. Check OBS scenes/profiles if your template was not installed automatically."
echo "6. In Xcode, select your real device and run WebDriverAgentRunner once."
echo ""
echo "To start the Remote QA stack locally:"
echo "  ./run-remote-qa.sh iphone"
echo ""
echo "To start and expose URLs using Tailscale:"
echo "  PUBLIC_HOST=\"\$(tailscale ip -4)\" ./run-remote-qa.sh iphone"
echo ""
echo "Then open:"
echo "  http://localhost:3000"
echo ""
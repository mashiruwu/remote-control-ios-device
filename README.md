# How to Run a Remote iPhone/iPad QA Session with QuickTime, OBS, MediaMTX, Appium, and a Browser UI

A simple, beginner-friendly guide for running a real iOS device remotely from a web browser.

The goal of this setup is simple:

- **QuickTime** mirrors the physical iPhone or iPad screen on the Mac.
- **OBS** captures that mirrored screen and publishes it as a WebRTC stream.
- **MediaMTX** receives the stream and makes it available in the browser.
- **Appium + WebDriverAgent** sends taps, swipes, Home button events, and app activation commands to the real device.
- **Node/Express** serves the web UI and proxies browser actions to Appium.

By the end, you should be able to open:

```txt
http://localhost:3000
```

and see/control the connected iPhone or iPad from the browser.

---

## Image guide: where to place screenshots

If you are turning this into a Medium article, upload the images directly inside Medium at the places marked below.

If you are keeping this article in the repo first, store the screenshots here:

```txt
docs/images/remote-qa/
```

Suggested image names:

| Image | Put it after | Suggested file path |
|---|---|---|
| Architecture diagram | “How the setup works” | `docs/images/remote-qa/01-architecture.png` |
| Installed tools terminal | “Install the required tools” | `docs/images/remote-qa/02-installed-tools.png` |
| Xcode Devices and Simulators | “Prepare the iPhone or iPad” | `docs/images/remote-qa/03-xcode-device.png` |
| QuickTime showing the device screen | “Test QuickTime capture” | `docs/images/remote-qa/04-quicktime-device.png` |
| OBS scene with the device window | “Configure OBS” | `docs/images/remote-qa/05-obs-scene.png` |
| MediaMTX / browser WebRTC stream loaded | “Test the video stream” | `docs/images/remote-qa/06-webrtc-stream.png` |
| Appium session running | “Start Appium” | `docs/images/remote-qa/07-appium-session.png` |
| Final browser UI controlling the device | “Run the full setup” | `docs/images/remote-qa/08-final-browser-ui.png` |
| Troubleshooting logs | “Troubleshooting” | `docs/images/remote-qa/09-logs.png` |

When writing the article in Markdown, you can use placeholders like this:

```md
![Architecture diagram](docs/images/remote-qa/01-architecture.png)
```

On Medium, replace each placeholder with the actual uploaded image.

---

## How the setup works

Before installing anything, it helps to understand the pipeline.

```txt
Physical iPhone/iPad
        │
        │ USB screen mirroring
        ▼
QuickTime Player on Mac
        │
        │ captured as a window
        ▼
OBS Studio
        │
        │ publishes WebRTC through WHIP
        ▼
MediaMTX
        │
        │ browser reads WebRTC stream
        ▼
Web UI at http://localhost:3000
        │
        │ taps / swipes / home / activate app
        ▼
Node server → Appium → WebDriverAgent → iOS device
```

**Image:** add `docs/images/remote-qa/01-architecture.png` here.

This setup separates video and control:

- **Video path:** iPhone/iPad → QuickTime → OBS → MediaMTX → browser.
- **Control path:** browser → Node server → Appium → WebDriverAgent → iPhone/iPad.

That is why the stream can stay smooth while Appium focuses only on input events.

---

## What you need to install

This guide assumes you are running everything on a Mac, because iOS real-device automation depends on Xcode and Apple’s developer tooling.

Install these tools first:

1. **Xcode**
2. **Xcode Command Line Tools**
3. **Homebrew**
4. **Node.js + npm**
5. **Appium**
6. **Appium XCUITest driver**
7. **libimobiledevice**
8. **ios-deploy**
9. **OBS Studio**
10. **MediaMTX**
11. **QuickTime Player** — already included with macOS
12. **An Apple Developer Team ID** for WebDriverAgent signing
13. **A real iPhone or iPad connected by USB**

---

## 1. Install Xcode and Command Line Tools

Install Xcode from the Mac App Store.

After Xcode is installed, open it once so it can finish installing components. Then run:

```bash
xcode-select --install
```

If you have more than one Xcode installed, make sure the correct one is selected:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

Accept the license if needed:

```bash
sudo xcodebuild -license accept
```

Check that Xcode is working:

```bash
xcodebuild -version
```

---

## 2. Install Homebrew

Homebrew makes the rest of the setup much easier.

Install it with:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then check it:

```bash
brew --version
```

---

## 3. Install Node.js, MediaMTX, and iOS helper tools

Run:

```bash
brew install node git mediamtx libimobiledevice ios-deploy
```

Check the versions:

```bash
node -v
npm -v
mediamtx --version
idevice_id -l
ios-deploy --version
```

`idevice_id -l` should show your connected device UDID after the device is trusted.

**Image:** add `docs/images/remote-qa/02-installed-tools.png` here.

---

## 4. Install Appium

Install Appium globally:

```bash
npm install -g appium
```

Install the iOS driver:

```bash
appium driver install xcuitest
```

Check that the driver is installed:

```bash
appium driver list --installed
```

Optional but recommended:

```bash
appium driver doctor xcuitest
```

Start Appium once to confirm it works:

```bash
appium
```

You should see Appium listening on port `4723`.

Stop it with `Control + C`. The project startup script will start Appium automatically later.

---

## 5. Prepare the iPhone or iPad

Connect the iPhone or iPad to the Mac using USB.

On the device:

1. Unlock it.
2. Tap **Trust This Computer** if prompted.
3. Keep the screen unlocked during setup.

On the Mac:

1. Open Xcode.
2. Go to **Window → Devices and Simulators**.
3. Select your connected iPhone or iPad.
4. Confirm that Xcode can see the device.

You need three values before running the project:

| Value | What it is | Where to find it |
|---|---|---|
| `udid` | Unique device ID | Xcode Devices and Simulators, or `idevice_id -l` |
| `xcodeOrgId` | Apple Developer Team ID | Apple Developer account membership page |
| `appBundleId` | Bundle ID of the app under test | Xcode project target, General tab |

**Image:** add `docs/images/remote-qa/03-xcode-device.png` here.

Do not publish your real UDID or Team ID in screenshots. Blur them before sharing the article.

---

## 6. Install OBS Studio

Install OBS Studio from the official website, or use Homebrew Cask:

```bash
brew install --cask obs
```

Open OBS once manually before using the scripts. macOS may ask for screen recording permissions.

Go to:

```txt
System Settings → Privacy & Security → Screen & System Audio Recording
```

Enable OBS.

You may also need to enable permissions for Terminal, iTerm, or the app you use to run the scripts.

---

## 7. Put the files in the right folders

A clean project structure should look like this:

```txt
remote-qa/
  server.js
  package.json
  mediamtx.yml
  run-remote-qa.sh
  run-iphone-obs.sh
  run-ipad-obs.sh
  create-obs-profiles.sh
  kill-remote-qa.sh

  public/
    index.html
    ...browser UI files...

  qt-window-stream/
    Package.swift
    Sources/
      QTWindowStream/
        ...Swift source files...
    open-iphone-quicktime.applescript
    start-qa-iphone.sh

  docs/
    images/
      remote-qa/
        01-architecture.png
        02-installed-tools.png
        ...
```

Important detail: the startup script expects the QuickTime helper script inside:

```txt
qt-window-stream/start-qa-iphone.sh
```

and that script expects the AppleScript beside it:

```txt
qt-window-stream/open-iphone-quicktime.applescript
```

---

## 8. Configure the Node server

Open `server.js` and fill the config block:

```js
const CONFIG = {
  appBundleId: "com.yourcompany.yourapp",

  udid: "YOUR_DEVICE_UDID",
  xcodeSigningId: "iPhone Developer",
  xcodeOrgId: "YOUR_APPLE_TEAM_ID",

  obsWebRtcPath: "/simulator"
};
```

Also make sure `xcodeOrgId` is passed into the Appium capabilities:

```js
"appium:xcodeOrgId": CONFIG.xcodeOrgId,
```

The Appium session should include at least:

```js
alwaysMatch: {
  platformName: "iOS",
  "appium:bundleId": CONFIG.appBundleId,
  "appium:automationName": "XCUITest",
  "appium:udid": CONFIG.udid,
  "appium:xcodeSigningId": CONFIG.xcodeSigningId,
  "appium:xcodeOrgId": CONFIG.xcodeOrgId,
  "appium:showXcodeLog": false,
  "appium:waitForIdleTimeout": 0,
  "appium:newCommandTimeout": 3600,
  "appium:wdaLocalPort": 8101,
  "appium:useNewWDA": false
}
```

Your server uses:

```txt
http://127.0.0.1:4723
```

as the Appium server URL.

It exposes browser endpoints such as:

```txt
GET  /api/config
POST /api/session/start
POST /api/session/stop
GET  /api/session/status
POST /api/device/tap
POST /api/device/swipe
POST /api/device/home
POST /api/device/activate-app
```

The tap/swipe endpoints receive ratios from the browser and convert them into real device coordinates. That keeps the touch layer working even when the browser video is resized.

---

## 9. Fix the device defaults before running

There are two easy defaults to align before running.

If you want the default device to be **iPhone**, update `start-qa-iphone.sh`:

```bash
DEVICE_NAME="${1:-iPhone}"
PORT="${2:-8090}"

 echo "Starting QA $DEVICE_NAME stream..."
 echo "Device: $DEVICE_NAME"
 echo "Port: $PORT"

swift run QTWindowStream \
  --device "$DEVICE_NAME" \
  --script ./open-iphone-quicktime.applescript \
  --port "$PORT"
```

Then update `run-remote-qa.sh` so the default OBS script also matches iPhone:

```bash
DEVICE_NAME="${DEVICE_NAME:-iPhone}"
OBS_SCRIPT="${OBS_SCRIPT:-./run-iphone-obs.sh}"
```

If you want the default device to be **iPad**, use:

```bash
DEVICE_NAME="${DEVICE_NAME:-iPad}"
OBS_SCRIPT="${OBS_SCRIPT:-./run-ipad-obs.sh}"
```

The important part is that the QuickTime device name and the OBS scene match the same target.

---

## 10. Configure OBS profiles

Run:

```bash
chmod +x create-obs-profiles.sh
./create-obs-profiles.sh
```

This creates two OBS profiles:

```txt
RemoteQA-iPhone
RemoteQA-iPad
```

Both profiles publish to:

```txt
http://localhost/simulator/whip
```

The browser reads from:

```txt
http://localhost/simulator
```

Now open OBS and create the scene collections if they do not already exist:

```txt
RemoteQA-iPhone → scene: iPhone
RemoteQA-iPad   → scene: iPad
```

For each scene:

1. Add a **Window Capture** source.
2. Select the QuickTime Player window.
3. Resize/crop it until only the device screen is visible.
4. Add audio capture if you want device audio.
5. Save the scene.

**Image:** add `docs/images/remote-qa/05-obs-scene.png` here.

---

## 11. Test QuickTime capture by itself

Before starting everything, test QuickTime capture alone.

Go into the `qt-window-stream` folder:

```bash
cd qt-window-stream
chmod +x start-qa-iphone.sh
./start-qa-iphone.sh iPhone
```

For iPad:

```bash
./start-qa-iphone.sh iPad
```

The AppleScript should:

1. Open QuickTime Player.
2. Start a new movie recording.
3. Open the source dropdown.
4. Select the iPhone or iPad screen.
5. Try to unmute the audio preview.

**Image:** add `docs/images/remote-qa/04-quicktime-device.png` here.

If this step fails, the full setup will also fail. Fix QuickTime first.

---

## 12. Test MediaMTX by itself

From the project root, run:

```bash
mediamtx mediamtx.yml
```

MediaMTX should start and listen on port `8889` for WebRTC.

In another terminal, check the port:

```bash
lsof -nP -iTCP:8889 -sTCP:LISTEN
```

Stop MediaMTX with `Control + C`.

---

## 13. Install Node dependencies

If your project does not have a `package.json` yet, create one:

```bash
npm init -y
npm pkg set type="module"
npm install express cors
```

Then test the server:

```bash
node server.js
```

Open:

```txt
http://localhost:3000
```

At this point, the page should load, even if the video and device session are not active yet.

---

## 14. Run the full setup

Make the scripts executable:

```bash
chmod +x run-remote-qa.sh
chmod +x run-iphone-obs.sh
chmod +x run-ipad-obs.sh
chmod +x create-obs-profiles.sh
```

For iPhone:

```bash
DEVICE_NAME="iPhone" OBS_SCRIPT="./run-iphone-obs.sh" ./run-remote-qa.sh
```

For iPad:

```bash
DEVICE_NAME="iPad" OBS_SCRIPT="./run-ipad-obs.sh" ./run-remote-qa.sh
```

The script starts services in this order:

1. MediaMTX
2. QuickTime setup
3. Appium
4. Node server
5. OBS

Then open:

```txt
http://localhost:3000
```

OBS should publish to:

```txt
http://localhost/simulator/whip
```

The browser should load the stream from:

```txt
http://localhost/simulator
```

**Image:** add `docs/images/remote-qa/08-final-browser-ui.png` here.

---

## 15. Start the Appium session from the browser

The browser UI should call:

```txt
POST /api/session/start
```

This creates an Appium session using the configured:

- bundle ID
- device UDID
- XCUITest driver
- signing identity
- Team ID

Once the session is active, the UI can send:

```txt
POST /api/device/tap
POST /api/device/swipe
POST /api/device/home
POST /api/device/activate-app
```

The browser should send ratios, not raw pixels. For example:

```json
{
  "xRatio": 0.5,
  "yRatio": 0.5
}
```

The server converts that into the real device coordinate based on the current device size.

---

## 16. Logs and debugging

Your startup script writes logs here:

```txt
logs/mediamtx.log
logs/quicktime.log
logs/appium.log
logs/node-server.log
logs/obs.log
```

Useful commands:

```bash
tail -f logs/mediamtx.log
```

```bash
tail -f logs/quicktime.log
```

```bash
tail -f logs/appium.log
```

```bash
tail -f logs/node-server.log
```

```bash
tail -f logs/obs.log
```

**Image:** add `docs/images/remote-qa/09-logs.png` here.

---

## Common problems

### Port already busy

The script checks ports `3000`, `4723`, and `8889` before starting.

If one is busy, find the process:

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
lsof -nP -iTCP:4723 -sTCP:LISTEN
lsof -nP -iTCP:8889 -sTCP:LISTEN
```

Then stop it, or run your cleanup script:

```bash
./kill-remote-qa.sh
```

### QuickTime does not select the device

Check:

- The device is connected by USB.
- The device is unlocked.
- The device trusts the Mac.
- QuickTime can manually select the iPhone/iPad screen.
- The AppleScript target name matches the device name, for example `iPhone` or `iPad`.

### OBS starts but the browser shows no video

Check:

- OBS is using the correct profile and scene.
- The scene contains the QuickTime window.
- OBS is streaming.
- MediaMTX is running.
- The WHIP server is set to `http://localhost/simulator/whip`.
- The browser is trying to read `http://localhost/simulator`.

### Appium fails with code signing errors

Usually this means WebDriverAgent could not be signed or trusted.

Check:

- Xcode has your Apple ID added.
- Your Team ID is correct.
- `xcodeOrgId` is passed in the Appium capabilities.
- The device is visible in Xcode.
- The device trusts the developer profile if iOS asks for it.
- The bundle ID under test is correct.

### Taps are offset

This usually means the video display size and touch layer are not using the same aspect ratio.

Fix by keeping the browser touch overlay exactly on top of the video element and always sending ratios:

```txt
xRatio = clickXInsideVideo / displayedVideoWidth
yRatio = clickYInsideVideo / displayedVideoHeight
```

The server should convert ratios into device coordinates.

---

## Running it from another network

For local testing, use:

```txt
http://localhost:3000
```

For someone outside your network, you need a secure tunnel or VPN to your Mac, then they open:

```txt
http://YOUR_MAC_IP_OR_TUNNEL_HOST:3000
```

If you expose this outside your machine, add authentication before sharing it with testers. This browser UI can control a real device, so do not leave it open publicly without protection.

---

## Final checklist

Before running a QA session, confirm:

- The iPhone/iPad is connected by USB.
- The device is unlocked and trusted.
- Xcode can see the device.
- `server.js` has the correct `appBundleId`, `udid`, and `xcodeOrgId`.
- Appium has the XCUITest driver installed.
- OBS has the correct RemoteQA profile and scene.
- MediaMTX can run with `mediamtx.yml`.
- QuickTime can manually mirror the device.
- `run-remote-qa.sh` points to the correct OBS script.
- The browser opens at `http://localhost:3000`.

Once all of that is ready, run:

```bash
DEVICE_NAME="iPhone" OBS_SCRIPT="./run-iphone-obs.sh" ./run-remote-qa.sh
```

or:

```bash
DEVICE_NAME="iPad" OBS_SCRIPT="./run-ipad-obs.sh" ./run-remote-qa.sh
```

Then open:

```txt
http://localhost:3000
```

You now have a browser-based remote QA setup for a real iPhone or iPad.

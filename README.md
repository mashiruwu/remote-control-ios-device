# iOS Remote QA

A local remote QA setup for controlling a real iPhone from a web page.

The video stream is handled by:

- QuickTime: displays the iPhone screen on the Mac
- OBS: captures the QuickTime window
- MediaMTX: receives the OBS stream and exposes it through WebRTC

The device control is handled by:

- Appium
- WebDriverAgent
- XCUITest
- A Node/Express backend that sends tap/swipe commands to Appium

## Architecture

```txt
QA Browser
  ├── watches iPhone video through MediaMTX WebRTC
  └── sends tap/swipe commands to Node backend

Node Backend
  └── sends W3C touch actions to Appium

Appium
  └── controls WebDriverAgent on the iPhone

Video Pipeline
  iPhone → QuickTime → OBS → MediaMTX → Browser
```

## Requirements

### Mac

- Xcode installed
- Node.js 22 recommended
- Appium installed
- XCUITest Appium driver installed
- MediaMTX installed
- OBS installed
- QuickTime Player
- Real iPhone connected through USB

### Recommended Node setup

```bash
nvm use 22
```

Check:

```bash
node -v
npm -v
which node
```

## Install dependencies

From the project folder:

```bash
npm install
```

Expected project structure:

```txt
remote_qa/
├── package.json
├── server.js
├── mediamtx.yml
└── public/
    └── index.html
```

## MediaMTX config

Create `mediamtx.yml`:

```yml
webrtc: yes
webrtcAddress: :8889

paths:
  iphone:
    source: publisher
```

Run MediaMTX with:

```bash
mediamtx mediamtx.yml
```

Expected log:

```txt
[WebRTC] listener opened on :8889
```

## QuickTime setup

1. Connect the iPhone through USB.
2. Unlock the iPhone.
3. Open QuickTime Player.
4. Go to:

```txt
File > New Movie Recording
```

5. Click the arrow next to the red record button.
6. Select the iPhone as the camera source.

Keep this QuickTime window open.

## OBS setup

1. Open OBS.
2. Add a source:

```txt
Sources > + > macOS Screen Capture
```

or:

```txt
Sources > + > Window Capture
```

3. Select the QuickTime window showing the iPhone.
4. Set OBS canvas to portrait.

Recommended:

```txt
Settings > Video
Base Canvas Resolution: 540x1170
Output Scaled Resolution: 540x1170
```

Or higher quality:

```txt
Base Canvas Resolution: 1080x2340
Output Scaled Resolution: 1080x2340
```

5. Crop black borders by selecting the source, holding `Option/Alt`, and dragging the red edges inward.

6. Configure stream:

```txt
Settings > Stream
Service: WHIP
Server: http://localhost:8889/iphone/whip
```

7. Click:

```txt
Start Streaming
```

Expected MediaMTX log:

```txt
is reading from path 'iphone', 2 tracks (H264, Opus)
```

## Appium tunnel

For real iPhones on newer iOS versions, start the RemoteXPC tunnel first.

Terminal 1:

```bash
sudo appium driver run xcuitest tunnel-creation --tunnel-registry-port 42000
```

Keep this terminal open.

Check tunnel:

```bash
curl http://localhost:42000/remotexpc/tunnels
```

Expected response should include the iPhone UDID.

## Appium server

Terminal 2:

```bash
appium --address 127.0.0.1 --port 4723 --log-level debug
```

Do not run the Appium server with `sudo`.

Only the tunnel command needs `sudo`.

## Start the web app

Terminal 3:

```bash
npm start
```

Or:

```bash
node server.js
```

Open locally:

```txt
http://localhost:3000
```

From another computer on the same network:

```txt
http://MAC_IP:3000
```

Only expose this through VPN/Tailscale/SSH tunnel. Do not expose the web UI, Appium, or MediaMTX directly to the public internet.

Find the Mac IP:

```bash
ipconfig getifaddr en0
```

## Web UI usage

1. Start MediaMTX.
2. Start QuickTime.
3. Start OBS streaming.
4. Start the Appium tunnel.
5. Start Appium server.
6. Start the Node backend.
7. Open the web UI.
8. Click:

```txt
Load OBS Video
```

9. Click:

```txt
Start Appium Session
```

## Control modes

The page has two modes.

### Control iPhone mode

Use this when you want mouse clicks and drags to control the iPhone.

```txt
Mode: Control iPhone
```

- Click = tap
- Drag = swipe

### Control Player mode

Use this when you need to interact with the WebRTC player itself.

```txt
Mode: Control Player
```

Use this to:

- unmute audio
- click player controls
- enter fullscreen

Then switch back to:

```txt
Mode: Control iPhone
```

## Important ports

```txt
3000  - Node web interface
4723  - Appium server
42000 - Appium RemoteXPC tunnel registry
8889  - MediaMTX WebRTC HTTP
8189  - MediaMTX WebRTC ICE UDP
```

Do not expose Appium ports publicly.

For remote access outside the local network, prefer VPN/Tailscale.

## Appium capabilities

Current basic capabilities:

```json
{
  "platformName": "iOS",
  "appium:bundleId": "com.company.app",
  "appium:automationName": "XCUITest",
  "appium:udid": "YOUR_DEVICE_UDID",
  "appium:xcodeSigningId": "iPhone Developer",
  "appium:xcodeOrgId": "YOUR_TEAM_ID",
  "appium:showXcodeLog": true,
  "appium:screenshotQuality": 2,
  "appium:waitForIdleTimeout": 1,
  "appium:newCommandTimeout": 3600
}
```

The video does not use WDA MJPEG anymore.

OBS/WebRTC handles video. Appium only sends commands.

## Common issues

### Video says "already loaded" but nothing appears

Check if the stream opens directly:

```txt
http://localhost:8889/iphone
```

If it does not open, the issue is OBS/MediaMTX, not the web app.

Restart in this order:

```txt
1. MediaMTX
2. OBS Start Streaming
3. Browser page
4. Load OBS Video
```

### MediaMTX says path 'iphone' is not configured

Make sure `mediamtx.yml` exists and contains:

```yml
paths:
  iphone:
    source: publisher
```

Run MediaMTX explicitly with:

```bash
mediamtx mediamtx.yml
```

### Audio is not playing in the browser

The browser may block autoplay audio.

Click:

```txt
Mode: Control Player
```

Then click the player and unmute it.

After that, switch back to:

```txt
Mode: Control iPhone
```

### Tap coordinates are wrong

Make sure the OBS canvas contains only the iPhone screen.

Avoid:

- black borders
- QuickTime window title bar
- extra desktop area
- landscape canvas

Use a portrait OBS canvas and crop the source.

Recommended canvas:

```txt
540x1170
```

or:

```txt
1080x2340
```

### Appium cannot find the device

Check:

```bash
idevice_id -l
xcrun devicectl list devices
```

Then restart the tunnel:

```bash
sudo appium driver run xcuitest tunnel-creation --tunnel-registry-port 42000
```

### Tunnel port is already in use

Kill old processes:

```bash
pkill -f appium
pkill -f tunnel-creation
pkill -f appium-ios-remotexpc

for port in 42000 42314 43000 50000 4723 8100 9100 8889 8189; do
  pids=$(sudo lsof -tiTCP:$port -sTCP:LISTEN)
  if [ -n "$pids" ]; then
    echo "Killing port $port: $pids"
    sudo kill -9 $pids
  fi
done
```

### WDA signing fails

Open WebDriverAgent manually:

```bash
open ~/.appium/node_modules/appium-xcuitest-driver/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj
```

In Xcode:

```txt
Target: WebDriverAgentRunner
Team: Your Apple Developer Team
Automatically manage signing: ON
Bundle Identifier: your WDA bundle id
Device: physical iPhone
Product > Test
```

Then retry Appium.

## Startup checklist

Run in this order:

```bash
# Terminal 1
mediamtx mediamtx.yml
```

```bash
# Terminal 2
sudo appium driver run xcuitest tunnel-creation --tunnel-registry-port 42000
```

```bash
# Terminal 3
appium --address 127.0.0.1 --port 4723 --log-level debug
```

```bash
# Terminal 4
npm start
```

Then:

```txt
1. Open QuickTime iPhone preview
2. Start OBS streaming
3. Open http://localhost:3000
4. Click Load OBS Video
5. Click Start Appium Session
6. Use Control iPhone mode
```

## Current design decision

We do not use WDA MJPEG for video because it is screenshot-based and can be slow or unstable.

Instead:

```txt
OBS/WebRTC = video
Appium/WDA = control
```

This gives better FPS and a smoother remote QA experience.

# iOS Remote QA — OBS Video + Appium Input

This setup uses **OBS + MediaMTX** for the video stream and **Appium** for device control.

```txt
iPhone/iPad USB → QuickTime → OBS → MediaMTX/WebRTC → Browser
Browser clicks/swipes → Node server → Appium → WebDriverAgent → iPhone/iPad
```

## Requirements

Install these first:

- OBS Studio
- MediaMTX
- Appium
- Appium XCUITest driver
- Node.js dependencies for this project

Example Appium setup:

```bash
npm install -g appium
appium driver install xcuitest
```

## 1. Connect the iOS device

Connect the iPhone/iPad to the Mac with USB.

Trust the computer on the device if iOS asks.

## 2. Open the device screen in QuickTime

Open QuickTime Player:

```txt
File > New Movie Recording
```

Then click the small arrow beside the record button and select the connected iPhone/iPad as the video source.

You do **not** need to start recording. QuickTime only needs to show the device screen.

## 3. Start MediaMTX

In one terminal:

```bash
mediamtx
```

MediaMTX will receive the OBS stream and expose it as a WebRTC page.

## 4. Configure OBS

In OBS:

1. Add a source:
   ```txt
   macOS Screen Capture / Window Capture
   ```

2. Select the QuickTime window showing the iPhone/iPad.

3. Configure streaming:

   ```txt
   Service: WHIP
   Server: http://localhost:8889/simulator/whip
   ```

4. Use a browser-compatible encoder:

   ```txt
   Video Encoder: H.264
   Audio: disabled or Opus
   ```

Avoid:

```txt
HEVC / H.265
AV1
```

Recommended settings:

```txt
Bitrate: 1500–2500 Kbps
Keyframe Interval: 1s or 2s
B-frames: OFF, if available
```

If using `x264`, you can add:

```txt
bframes=0
```

Then click:

```txt
Start Streaming
```

The browser video URL should be:

```txt
http://localhost:8889/simulator
```

For another machine on Tailscale/LAN:

```txt
http://MAC_IP:8889/simulator
```

## 5. Start Appium

In another terminal:

```bash
appium --address 127.0.0.1 --port 4723 --log-level error
```

If you need logs while debugging, use:

```bash
appium --address 127.0.0.1 --port 4723 --log-level debug
```

## 6. Start the Node server

In the project folder:

```bash
node server.js
```

The web panel runs at:

```txt
http://localhost:3000
```

For another machine on Tailscale/LAN:

```txt
http://MAC_IP:3000
```

## 7. Use the web panel

Open:

```txt
http://localhost:3000
```

Then:

1. Click **Load OBS Video**
2. Click **Start Appium Session**
3. Click/swipe on the video area to control the iPhone/iPad
4. Use **Home** or **Open App** if needed

## Expected project config

The backend should return the OBS/MediaMTX player URL:

```js
videoType: "webrtc",
videoUrl: `http://${host}:8889/simulator`
```

OBS should publish to:

```txt
http://localhost:8889/simulator/whip
```

The browser should watch:

```txt
http://localhost:8889/simulator
```

## Troubleshooting

### Missing video URL

Make sure `public/index.html` has only one input with this ID:

```html
<input id="videoUrlInput" placeholder="http://localhost:8889/simulator" />
```

Also make sure this button exists:

```html
<button id="applyVideoUrl" class="secondary">Apply Video URL</button>
```

Then hard refresh the browser:

```txt
Cmd + Shift + R
```

### Codecs not supported by client

In OBS, switch the video encoder to:

```txt
H.264
```

Do not use:

```txt
HEVC / H.265
AV1
```

Also try disabling audio first.

### WDA port busy

Kill old processes:

```bash
lsof -tiTCP:8100 -sTCP:LISTEN | xargs kill -9
pkill -f appium || true
pkill -f WebDriverAgent || true
pkill -f xcodebuild || true
pkill -f iproxy || true
```

Then restart Appium.

### Video works but clicks are wrong

Make sure the web frame aspect ratio is based on the Appium `deviceSize`.

The app should get the size after starting the Appium session using:

```txt
/session/:id/window/rect
```

### Stream is slow over Tailscale

Lower OBS settings:

```txt
Resolution: 720p or lower
FPS: 15–30
Bitrate: 1000–2000 Kbps
Encoder: H.264 hardware encoder
```

## Run order summary

```bash
# Terminal 1
mediamtx

# Terminal 2
appium --address 127.0.0.1 --port 4723 --log-level error

# Terminal 3
node server.js
```

Then:

```txt
1. Open QuickTime New Movie Recording
2. Select iPhone/iPad as source
3. Start OBS streaming to http://localhost:8889/simulator/whip
4. Open http://localhost:3000
5. Load OBS Video
6. Start Appium Session
```

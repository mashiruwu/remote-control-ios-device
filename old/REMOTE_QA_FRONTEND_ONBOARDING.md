# Remote QA Frontend — Product & Onboarding Guide

## 1. What this system does

Remote QA lets a teammate test an app on a real iPhone or iPad from another place, even if they are not on the same Wi‑Fi or local network.

The device stays physically connected by USB to a coworker’s Mac. That Mac acts as the “host machine”. The remote tester opens a web page, sees the live device screen, and can click, tap, swipe, press Home, or open the app.

The main goal is:

> A coworker leaves an idle iPhone or iPad connected to their Mac, and someone from another city, country, or network can test the app through a browser.

This is useful when QA needs access to a specific physical device but does not have it nearby.

---

## 2. Simple explanation for non-technical users

Think of it like a remote-control system for a real iPhone or iPad.

The coworker’s Mac does three things:

1. **Shows the device screen** using QuickTime Player.
2. **Streams that screen** to a browser using OBS and MediaMTX.
3. **Sends the tester’s clicks and swipes** to the real device using Appium.

The remote tester does not need to install Xcode, Appium, OBS, or QuickTime. They only open a web link.

---

## 3. High-level architecture

### Video flow

```text
Real iPhone/iPad
    ↓ USB cable
Coworker Mac
    ↓ QuickTime mirrors the device screen
OBS captures the QuickTime window
    ↓ WHIP/WebRTC
MediaMTX receives the stream
    ↓ Browser playback
Remote tester sees the live device screen
```

### Control flow

```text
Remote tester clicks/swipes in browser
    ↓
Remote QA frontend
    ↓
Node.js server
    ↓
Appium
    ↓
WebDriverAgent on the iPhone/iPad
    ↓
Real tap/swipe happens on the physical device
```

---

## 4. Main parts of the system

## 4.1 Physical iPhone or iPad

This is the real device being tested.

It must be:

- Connected to the host Mac by USB.
- Unlocked.
- Trusted by the Mac.
- Able to run the target app.
- Available for the remote session.

Recommended:

- Use a dedicated QA device, not someone’s personal phone.
- Keep the device awake during testing.
- Disable auto-lock during long QA sessions if allowed by company policy.

---

## 4.2 Host Mac

The host Mac is the machine physically connected to the device.

It runs:

- QuickTime Player
- OBS Studio
- MediaMTX
- Appium
- Node.js Remote QA server
- Optional VPN/tunnel tool such as Tailscale

The host Mac is the bridge between the real device and the remote tester.

---

## 4.3 QuickTime Player

QuickTime is used to mirror the iPhone/iPad screen on the Mac.

The user should understand:

> QuickTime is not used to record a video file. It is only used as a live screen mirror.

The setup script can open QuickTime and select the iPhone or iPad as the input source.

---

## 4.4 OBS Studio

OBS captures the QuickTime window and streams it.

In this setup, OBS should usually have separate profiles/scenes for:

- iPhone
- iPad

This helps because iPhone and iPad have different screen shapes.

OBS publishes the stream to MediaMTX using WHIP.

Example OBS publish URL:

```text
http://localhost/simulator/whip
```

---

## 4.5 MediaMTX

MediaMTX receives the OBS stream and exposes it to the browser.

The browser usually watches:

```text
http://localhost/simulator
```

The frontend should hide this detail from normal users and simply show a “Video Live” status.

---

## 4.6 Appium

Appium handles remote input.

When the tester clicks or swipes on the browser video, the frontend sends the action to the Node.js server. The Node.js server sends the action to Appium. Appium then controls the real iPhone/iPad through WebDriverAgent.

For non-technical users, explain it like this:

> Appium is the part that turns browser clicks into real taps on the device.

---

## 4.7 WebDriverAgent

WebDriverAgent is a helper app installed on the iPhone/iPad by Appium.

It is needed so Appium can tap, swipe, press Home, and open apps.

Most users do not need to know about it, but many errors will be related to WebDriverAgent signing or iOS device permissions.

---

## 4.8 Node.js Remote QA server

The Node.js server provides:

- The frontend page.
- API endpoints to start/stop the Appium session.
- API endpoints for tap, swipe, Home, and app activation.
- The video URL used by the browser.
- Device size information for correct click mapping.

Default local URL:

```text
http://localhost:3000
```

---

## 4.9 Tunnel or VPN

The remote tester is not on the same network as the host Mac, so the host Mac needs a secure way to expose the frontend.

Options:

- Tailscale
- Company VPN
- Secure tunnel
- Reverse proxy
- Internal network gateway

The frontend should not encourage exposing this directly to the public internet without authentication.

Simple explanation:

> The tunnel is the safe bridge that lets the remote tester open the host Mac’s QA page from another location.

---

## 5. What information should be input by the user

The frontend should collect inputs in a friendly way. Avoid showing everything as a technical config file.

---

## 5.1 Required inputs

| Input | Example | Who provides it | Why it is needed |
|---|---|---|---|
| Device type | `iPhone` or `iPad` | Host | Chooses the correct OBS scene/profile and screen layout. |
| Device display name | `iPhone`, `iPad`, `Diego’s iPhone` | Host | Helps QuickTime select the right device source. |
| App name | `Slumber` | Host/QA | Human-readable name shown in the UI. |
| App bundle ID | `com.company.app` | Developer/Host | Appium uses this to open/control the app. |
| Device UDID | `00008103-...` | Host/Developer | Appium uses this to target the physical device. |
| Apple Developer Team ID | `ABCDE12345` | Developer/Host | Required for WebDriverAgent signing. |
| OBS profile | `RemoteQA-iPhone` | Host/App | Opens the correct OBS setup. |
| OBS scene | `iPhone` | Host/App | Selects the right scene inside OBS. |
| Tester link / tunnel URL | `https://remote-qa-host...` | Host/App | Link shared with the remote tester. |

---

## 5.2 Optional inputs

| Input | Example | Why it helps |
|---|---|---|
| Session name | `Regression test - Build 123` | Makes sessions easier to identify. |
| Tester name | `Maria` | Shows who is connected. |
| Testing notes | `Test onboarding and subscription flow` | Gives the tester a goal. |
| Stream quality | `Low`, `Medium`, `High` | Helps adapt to slower networks. |
| WDA local port | `8101` | Useful when ports conflict. |
| Appium URL | `http://localhost:4723` | Advanced configuration. |
| MediaMTX playback URL | `http://host:8889/simulator` | Advanced stream configuration. |

---

## 6. What the frontend should show

The frontend should feel like a control room, not a terminal.

---

## 6.1 Main status cards

Show simple status cards:

```text
Device: Connected
QuickTime: Ready
OBS Stream: Live
Remote Control: Ready
Tester Link: Available
```

Recommended color meaning:

- Green: working
- Yellow: needs user attention
- Red: stopped or failed
- Gray: not started yet

---

## 6.2 Live device screen

The main part of the UI should be the live device screen.

It should show:

- The WebRTC video stream.
- A loading state while the stream connects.
- A clear error if video is unavailable.
- A transparent interaction layer for clicks/swipes.
- A “Reload Video” button.

Avoid black bars when possible, because black bars can break tap coordinate mapping.

---

## 6.3 Device controls

Basic controls:

- Start Remote Control
- Stop Remote Control
- Home
- Open App
- Reload Video
- Copy Tester Link
- Stop Everything

Advanced controls can be hidden:

- Restart Appium
- Restart Stream
- View logs
- Change WDA port
- Change stream URL

---

## 6.4 Checklist

Before sharing the tester link, show a checklist:

```text
[ ] iPhone/iPad connected by USB
[ ] Device unlocked
[ ] Device trusted this Mac
[ ] QuickTime shows the device screen
[ ] OBS shows the QuickTime screen
[ ] OBS stream is live
[ ] Appium session started
[ ] Tester link is reachable
```

This checklist is very important because many errors are setup-related, not code-related.

---

## 6.5 Advanced logs

Normal users should not see raw logs by default.

Have an expandable section:

```text
Advanced logs
- MediaMTX
- QuickTime
- OBS
- Appium
- Node server
```

Each error message should also have a friendly explanation above the logs.

---

## 7. Onboarding tutorial

The onboarding should explain the system one step at a time.

---

## Step 1 — Welcome

Suggested text:

```text
Remote QA lets someone test an app on this real iPhone or iPad from another location.

This Mac will stream the device screen and forward the tester’s clicks and swipes to the real device.
```

Show a simple diagram:

```text
Tester Browser → This Mac → Real iPhone/iPad
```

---

## Step 2 — Connect the device

Instructions:

1. Connect the iPhone/iPad to this Mac with a USB cable.
2. Unlock the device.
3. Tap “Trust This Computer” if prompted.
4. Keep the device unlocked.

Show confirmation checkbox:

```text
I can see the device connected to this Mac.
```

Possible warning:

```text
If the device locks, the tester may lose control or see the lock screen.
```

---

## Step 3 — Choose the device type

Ask:

```text
Which device are you sharing?
[ iPhone ] [ iPad ]
```

Also allow a device name:

```text
Device name shown in QuickTime:
[iPad]
```

This helps the QuickTime script select the correct source.

---

## Step 4 — Open QuickTime mirror

Explain:

```text
QuickTime will show the iPhone/iPad screen on this Mac.
OBS will later capture this QuickTime window.
```

Button:

```text
Open QuickTime Mirror
```

Expected result:

```text
You should now see the device screen inside QuickTime.
```

If not, show troubleshooting.

---

## Step 5 — Configure OBS

Explain:

```text
OBS is the video broadcaster.
It captures the QuickTime window and sends it to the tester’s browser.
```

First-time setup:

1. Open OBS.
2. Select the RemoteQA iPhone or iPad profile.
3. Select the matching scene.
4. Add or select `macOS Screen Capture`.
5. Choose the QuickTime Player window.
6. Resize/crop the source so the device fills the canvas.
7. Start streaming.

Important message:

```text
You usually only need to fit the OBS scene once per Mac/device type.
If the video is black later, reselect the QuickTime window in OBS source properties.
```

---

## Step 6 — Start local services

Button:

```text
Start Remote QA Services
```

This should start:

- MediaMTX
- QuickTime setup
- Appium
- Node server
- OBS launch script

Show progress:

```text
Starting MediaMTX...
Opening QuickTime...
Starting Appium...
Starting web server...
Opening OBS...
```

---

## Step 7 — Start remote control

Button:

```text
Start Remote Control
```

Explain:

```text
This creates the Appium session that allows browser clicks and swipes to control the real device.
```

Success message:

```text
Remote control is ready.
```

---

## Step 8 — Share tester link

Show:

```text
Tester link:
https://...
[Copy Link]
```

Explain:

```text
Send this link to the remote tester. They will be able to see and control the device while the session is active.
```

---

## 8. Suggested frontend pages

```text
/setup
First-time setup tutorial.

/session/new
Create a new QA session.

/session/live
Live device screen and controls.

/settings
Device, Appium, OBS, and stream settings.

/logs
Advanced diagnostics.
```

---

## 9. Suggested “New Session” form

Basic fields:

```text
Session name
Device type
Device display name
App name
App bundle ID
Tester instructions
Tunnel URL
```

Advanced fields:

```text
Device UDID
Apple Developer Team ID
Appium URL
WDA local port
OBS profile
OBS scene
MediaMTX WHIP URL
MediaMTX playback URL
Stream quality
```

---

## 10. Suggested live session screen

```text
--------------------------------------------------
Remote QA Session: Build 123 Regression Test

Status:
[Device Connected] [Video Live] [Control Ready] [Tester Link Ready]

--------------------------------------------------
|                                                |
|              Live Device Screen                |
|                                                |
--------------------------------------------------

Controls:
[Start Control] [Stop Control] [Home] [Open App] [Reload Video]

Tester:
[Copy Link] https://...

Checklist:
[x] Device connected
[x] QuickTime ready
[x] OBS streaming
[x] Remote control ready

Advanced:
[View Logs]
--------------------------------------------------
```

---

## 11. Common errors and how to explain them

---

## 11.1 Video is black

Possible causes:

- OBS is capturing an old QuickTime window.
- QuickTime is not showing the device screen.
- OBS source is hidden.
- OBS stream is not running.
- MediaMTX is not running.

User-facing message:

```text
The video is connected, but the screen is black.

Try this:
1. Open QuickTime and confirm the device screen is visible.
2. Open OBS.
3. Right-click the macOS Screen Capture source.
4. Open Properties.
5. Reselect the current QuickTime window.
6. Start streaming again.
```

---

## 11.2 Audio works, but screen does not

Possible cause:

OBS can capture QuickTime audio by application, but video capture may still point to an old QuickTime window.

User-facing message:

```text
OBS can hear QuickTime, but it is not seeing the current QuickTime window.

Open OBS source properties and reselect the QuickTime Movie Recording window.
```

---

## 11.3 QuickTime cannot find the iPhone/iPad

Possible causes:

- Device is not connected by USB.
- Device is locked.
- The Mac is not trusted.
- Cable only supports charging, not data.
- Another app is using the device source.

User-facing message:

```text
Could not find the device in QuickTime.

Check:
1. The device is connected with a data cable.
2. The device is unlocked.
3. You tapped Trust This Computer.
4. QuickTime can see the device in the source menu.
```

---

## 11.4 Appium session fails

Possible causes:

- Appium is not running.
- Device UDID is wrong.
- App bundle ID is wrong.
- Developer Mode is disabled.
- WebDriverAgent signing failed.
- Apple Developer Team ID is missing or wrong.
- Xcode does not support the connected iOS version.

User-facing message:

```text
Could not start remote control.

Check:
1. The device is unlocked.
2. Developer Mode is enabled.
3. The device UDID is correct.
4. The app bundle ID is correct.
5. The Apple Team ID is correct.
6. Appium is running.
```

---

## 11.5 Taps do not match the screen

Possible causes:

- OBS video has black bars.
- OBS scene is cropped incorrectly.
- Browser video size does not match the device aspect ratio.
- Wrong device size was detected.

User-facing message:

```text
The click position does not match the device screen.

Try:
1. Make the device fill the OBS canvas.
2. Avoid black bars around the device.
3. Reload the browser video.
4. Restart the remote control session.
```

---

## 11.6 Tester cannot open the page

Possible causes:

- Tunnel/VPN is not connected.
- Wrong URL was shared.
- Firewall blocks the connection.
- Node server is not running.
- Host Mac is asleep.

User-facing message:

```text
The tester cannot reach this Mac.

Check:
1. The tunnel or VPN is connected.
2. The Remote QA server is running.
3. The shared URL is correct.
4. The Mac is awake and online.
```

---

## 11.7 Stream is slow or laggy

Possible causes:

- Host Mac upload speed is weak.
- Tester network is slow.
- OBS bitrate is too high.
- OBS resolution is too high.
- VPN/tunnel adds latency.

User-facing message:

```text
The stream is slow.

Try:
1. Lower OBS bitrate.
2. Use a lower output resolution.
3. Close other network-heavy apps.
4. Use a faster network or VPN route.
```

Recommended settings:

```text
Codec: H.264
Resolution: 720p or similar
FPS: 24 or 30
Bitrate: 1500–2500 Kbps
```

---

## 11.8 Browser says codec not supported

Possible causes:

- OBS is using HEVC/H.265.
- OBS is using AV1.
- Browser expects H.264 for this stream.

User-facing message:

```text
The browser cannot play this stream.

Set OBS encoder to H.264.
Avoid HEVC/H.265 and AV1 for this setup.
```

---

## 11.9 Port already busy

Possible causes:

- Previous session is still running.
- Appium, MediaMTX, or Node did not close correctly.

User-facing message:

```text
A required port is already in use.

Click Stop Everything or run:
./kill-remote-qa.sh
```

Common ports:

```text
3000: Remote QA web server
4723: Appium
8889: MediaMTX WebRTC
8100/8101: WebDriverAgent/Appium support
```

---

## 11.10 Device locks during testing

Possible effects:

- Tester sees lock screen.
- Taps stop working.
- App goes to background.
- Stream may continue but testing is blocked.

User-facing message:

```text
The device appears to be locked.

Unlock the device and keep it awake during the QA session.
```

---

## 12. Recommended frontend status model

Use these states:

```text
idle
checking_requirements
device_connected
quicktime_ready
obs_ready
stream_live
appium_starting
control_ready
tester_connected
error
stopping
stopped
```

Each state should have:

- A short title.
- A plain-language explanation.
- One primary action.
- A troubleshooting action if needed.

---

## 13. What should be automated now

Good to automate:

- Start MediaMTX.
- Open QuickTime.
- Select iPhone/iPad in QuickTime.
- Start Appium.
- Start Node server.
- Open OBS with the selected profile.
- Show service logs/status.
- Copy tester link.

---

## 14. What should stay manual for the MVP

Better to keep manual for now:

- First-time OBS scene fitting.
- Reselecting QuickTime window if OBS captures an old window.
- Cropping/framing the device screen.
- Tunnel/VPN authentication.

Why?

OBS window capture depends on the Mac, the QuickTime window, the OBS version, permissions, and timing. A clear onboarding tutorial is more reliable than fragile UI automation for the MVP.

---

## 15. Security and privacy notes

This system gives a remote person control over a real device.

The UI should always show:

- Which device is being shared.
- Whether a tester is connected.
- Whether remote control is active.
- How to stop the session immediately.

Recommended safety controls:

- Always-visible “Stop Session” button.
- Authenticated tester links.
- Expiring session links.
- Dedicated QA devices when possible.
- No public unauthenticated access.
- Clear warning before starting remote control.

Suggested warning:

```text
Remote control is active. The tester can interact with this physical device until you stop the session.
```

---

## 16. One-sentence product description

Remote QA lets a teammate test an app on a real iPhone or iPad from another location by streaming the device screen through the host Mac and forwarding browser clicks back to the physical device.

---

## 17. MVP success criteria

The MVP is successful when:

```text
A host coworker can connect an idle iPhone/iPad to their Mac, start the Remote QA session, share a secure link, and a tester from another network can see and control the app from a browser.
```

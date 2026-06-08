# Remote Control iOS Device

This project lets you remotely view and control a real iPhone or iPad from a web browser.

It uses a Mac as the host machine. The iOS device stays connected to the Mac by USB, while a tester can access the device screen and control it from another computer.

## How it works

The setup uses:

- **QuickTime Player** to mirror the real iPhone/iPad screen
- **OBS** to capture the QuickTime window
- **MediaMTX** to expose the video stream through WebRTC
- **Appium** to create an automation session
- **WebDriverAgent** to control the real iOS device
- **Node.js** to serve the browser UI and send taps/swipes
- **Tailscale** to let remote testers access the host Mac privately

Basic flow:

```txt
Remote browser
    |
 Tailscale
    |
Host Mac
 |-- QuickTime mirrors the iPhone/iPad
 |-- OBS captures QuickTime
 |-- MediaMTX streams the video
 |-- Appium sends input commands
 |-- WebDriverAgent runs on the device
    |
Real iPhone/iPad connected by USB
```

## Requirements

You need:

- macOS
- A real iPhone or iPad connected by USB
- Xcode installed
- Apple Developer Team for signing WebDriverAgent
- Homebrew
- Node.js
- OBS Studio
- Tailscale
- Appium
- MediaMTX

## Installation

Clone the project:

```bash
git clone https://github.com/mashiruwu/remote-control-ios-device.git
cd remote-control-ios-device
```

Run the dependency installer:

```bash
chmod +x install-remote-qa-deps.sh
./install-remote-qa-deps.sh
```

This script installs or checks the required tools:

- Node.js
- Appium
- Appium XCUITest driver
- MediaMTX
- OBS
- Tailscale
- iOS device tools

At the end, it tries to open WebDriverAgent in Xcode.

## Configure WebDriverAgent in Xcode

When WebDriverAgent opens in Xcode:

1. Select the `WebDriverAgentRunner` target.
2. Select your real iPhone/iPad as the destination.
3. Open **Signing & Capabilities**.
4. Enable **Automatically manage signing**.
5. Select your Apple Developer Team.
6. Use a valid bundle identifier, for example:

```txt
com.yourname.webdriveragent
```

Then run:

```txt
Product → Test
```

or press:

```txt
Cmd + U
```

If the iPhone asks you to trust the developer profile, open:

```txt
Settings → General → VPN & Device Management
```

Trust the profile and run the test again.

If WebDriverAgent does not open automatically, try:

```bash
open -a Xcode "$HOME/.appium/node_modules/appium-xcuitest-driver/node_modules/appium-webdriveragent/WebDriverAgent.xcodeproj"
```

If that path does not exist, locate it with:

```bash
find "$HOME/.appium" "$(npm root -g)" -name "WebDriverAgent.xcodeproj" -type d 2>/dev/null
```

## Configure Tailscale

Tailscale allows another machine to access the host Mac privately.

On the host Mac:

```bash
tailscale ip -4
```

This returns an IP like:

```txt
100.x.x.x
```

The remote tester will use this IP to access the web UI:

```txt
http://TAILSCALE_IP:3000
```

You can either invite the tester to your Tailscale network or share only the host Mac.

Recommended:

```txt
Tailscale Admin → Machines → Host Mac → Share
```

Send the share link to the tester. After accepting, the tester should open:

```txt
http://TAILSCALE_IP:3000
```

Important:

OBS publishes locally on the host Mac:

```txt
http://localhost:8889/simulator/whip
```

The remote tester uses the Tailscale IP:

```txt
http://TAILSCALE_IP:3000
```

## Install OBS profiles

Run:

```bash
chmod +x install-obs-remoteqa.sh
./install-obs-remoteqa.sh
```

This creates or updates the OBS profiles:

```txt
RemoteQA-iPhone
RemoteQA-iPad
```

If you need to reset the profiles:

```bash
rm -rf "$HOME/Library/Application Support/obs-studio/basic/profiles/RemoteQA-iPhone"
rm -rf "$HOME/Library/Application Support/obs-studio/basic/profiles/RemoteQA-iPad"

./install-obs-remoteqa.sh
```

## Open QuickTime manually

QuickTime is not opened automatically by the startup script.

Before running the stack:

1. Connect the iPhone/iPad by USB.
2. Unlock the device.
3. Tap **Trust This Computer** if prompted.
4. Open **QuickTime Player**.
5. Go to:

```txt
File → New Movie Recording
```

6. Click the small arrow next to the record button.
7. Under **Screen**, select the connected iPhone/iPad.
8. If you need audio, select the device under **Speaker** too.
9. Keep the QuickTime window open.

You do not need to press record.

## Configure OBS

Open OBS and use the correct profile:

```txt
RemoteQA-iPhone
```

or:

```txt
RemoteQA-iPad
```

Then configure the capture source:

1. Select the macOS screen capture source.
2. Open **Properties**.
3. Set **Method** to:

```txt
Window Capture
```

4. Set **Window** to:

```txt
[QuickTime Player] Movie Recording
```

5. Click **OK**.
6. Resize or crop the source so only the device screen appears.

OBS should publish to:

```txt
http://localhost:8889/simulator/whip
```

## Run the Remote QA stack

For iPhone:

```bash
./run-remote-qa.sh iphone
```

For iPad:

```bash
./run-remote-qa.sh ipad
```

The script starts:

- MediaMTX
- Appium
- Node web server
- OBS launch script

QuickTime must already be open manually.

## Open the web UI

On the host Mac:

```txt
http://localhost:3000
```

From another device through Tailscale:

```txt
http://TAILSCALE_IP:3000
```

Example:

```txt
http://100.66.24.36:3000
```

## Using the web UI

Basic flow:

1. Click **Load OBS Video**.
2. Click **Start Appium Session**.
3. Tap and swipe inside the device frame.
4. Use **Home** to send the device to the Home screen.
5. Click **Stop Session** if control stops working.
6. Click **Start Appium Session** again to reconnect.

## Audio and player controls

The browser may start the stream muted.

To unmute:

1. Click **Control Player**.
2. Use the video player controls to unmute or adjust volume.
3. Click **Control iPhone** to go back to controlling the device.

Simple rule:

```txt
Control Player = control video/audio
Control iPhone = control the real iPhone/iPad
```

## If something stops working

### Taps or swipes do not work

Try:

```txt
Stop Session → Start Appium Session
```

If it still does not work, check:

- WebDriverAgent is still running
- Appium is running
- The device is connected and unlocked

### Video is black

Check:

- QuickTime is showing the iPhone/iPad screen
- OBS is capturing the QuickTime window
- OBS is publishing to MediaMTX
- MediaMTX is running

### Remote tester cannot see the website

Check:

- Tailscale is connected
- The tester is using the Tailscale IP, not localhost
- The host Mac is reachable
- The URL is:

```txt
http://TAILSCALE_IP:3000
```

### Remote tester can open the UI but not the video

Try opening the stream directly:

```txt
http://TAILSCALE_IP:8889/simulator
```

If it does not load, check OBS and MediaMTX.

### Video freezes

Try:

1. Click **Load OBS Video** again.
2. Restart OBS.
3. Check that QuickTime is still showing the device.
4. Restart the stack if needed.

## Stop everything

Run:

```bash
./kill-remote-qa.sh
```

Then start again:

```bash
./run-remote-qa.sh iphone
```

or:

```bash
./run-remote-qa.sh ipad
```

## Useful logs

```bash
tail -f logs/mediamtx.log
tail -f logs/appium.log
tail -f logs/node-server.log
tail -f logs/obs.log
```

## Common URLs

Local web UI:

```txt
http://localhost:3000
```

Local MediaMTX stream:

```txt
http://localhost:8889/simulator
```

OBS WHIP publish URL:

```txt
http://localhost:8889/simulator/whip
```

Remote web UI through Tailscale:

```txt
http://TAILSCALE_IP:3000
```

Remote stream through Tailscale:

```txt
http://TAILSCALE_IP:8889/simulator
```

## Current limitations

- QuickTime needs to be opened manually.
- OBS may need manual adjustment if the QuickTime window changes.
- This setup is mainly intended for one connected device per host Mac.
- Remote control depends on Appium and WebDriverAgent staying alive.
- Video latency depends on OBS settings, network conditions, and the remote tester connection.
- This is not a full BrowserStack replacement. It is a practical internal QA setup.

## License

Use this project as a practical starting point for internal iOS remote QA workflows.

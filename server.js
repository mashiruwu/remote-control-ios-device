import express from "express";

const app = express();

app.use(express.json());
app.use(express.static("public"));

const APPIUM_URL = "http://127.0.0.1:4723";

const CONFIG = {
  appBundleId: "com.company.app",
  
  udid: "YOUR_DEVICE_UDID",
  xcodeSigningId: "iPhone Developer",
  xcodeOrgId: "YOUR_TEAM_ID",

  // MediaMTX/OBS WebRTC viewer URL.
  // If QA is on another PC, replace localhost in the frontend automatically with the Mac IP.
  obsWebRtcPath: "/iphone"
};

let sessionId = null;

let deviceSize = {
  width: 393,
  height: 852
};

async function appiumRequest(path, options = {}) {
  const response = await fetch(`${APPIUM_URL}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(JSON.stringify(data, null, 2));
  }

  return data;
}

function ratioToDevicePoint(xRatio, yRatio) {
  const safeXRatio = Math.max(0, Math.min(1, Number(xRatio)));
  const safeYRatio = Math.max(0, Math.min(1, Number(yRatio)));

  return {
    x: Math.round(safeXRatio * deviceSize.width),
    y: Math.round(safeYRatio * deviceSize.height)
  };
}

app.get("/api/config", (req, res) => {
  const host = req.headers.host?.split(":")[0] || "localhost";

  res.json({
    ok: true,
    appBundleId: CONFIG.appBundleId,
    udid: CONFIG.udid,
    deviceSize,

    // MediaMTX default WebRTC HTTP port.
    // OBS publishes to: http://localhost:8889/iphone/whip
    // Browser watches: http://MAC_IP:8889/iphone
    videoUrl: `http://${host}:8889${CONFIG.obsWebRtcPath}`
  });
});

app.post("/api/session/start", async (req, res) => {
  try {
    if (sessionId) {
      return res.json({
        ok: true,
        reused: true,
        sessionId,
        deviceSize
      });
    }

    const data = await appiumRequest("/session", {
      method: "POST",
      body: JSON.stringify({
        capabilities: {
          alwaysMatch: {
            platformName: "iOS",
            "appium:bundleId": CONFIG.appBundleId,
            "appium:automationName": "XCUITest",
            "appium:udid": CONFIG.udid,
            "appium:xcodeSigningId": CONFIG.xcodeSigningId,
            "appium:xcodeOrgId": CONFIG.xcodeOrgId,
            "appium:showXcodeLog": true,

            // These still help Appium/WDA, even though video is OBS.
            "appium:screenshotQuality": 2,
            "appium:waitForIdleTimeout": 1,
            "appium:newCommandTimeout": 3600
          }
        }
      })
    });

    sessionId = data.value.sessionId;

    const rect = await appiumRequest(`/session/${sessionId}/window/rect`, {
      method: "GET"
    });

    deviceSize = {
      width: rect.value.width,
      height: rect.value.height
    };

    res.json({
      ok: true,
      sessionId,
      deviceSize
    });
  } catch (error) {
    console.error(error);

    sessionId = null;

    res.status(500).json({
      ok: false,
      error: String(error.message || error)
    });
  }
});

app.post("/api/session/stop", async (req, res) => {
  try {
    if (!sessionId) {
      return res.json({ ok: true, message: "No active session" });
    }

    const oldSessionId = sessionId;
    sessionId = null;

    await appiumRequest(`/session/${oldSessionId}`, {
      method: "DELETE"
    });

    res.json({ ok: true });
  } catch (error) {
    console.error(error);

    sessionId = null;

    res.status(500).json({
      ok: false,
      error: String(error.message || error)
    });
  }
});

app.get("/api/session/status", async (req, res) => {
  try {
    if (!sessionId) {
      return res.json({
        ok: true,
        active: false
      });
    }

    const status = await appiumRequest(`/session/${sessionId}/window/rect`, {
      method: "GET"
    });

    res.json({
      ok: true,
      active: true,
      sessionId,
      deviceSize,
      rect: status.value
    });
  } catch (error) {
    sessionId = null;

    res.status(500).json({
      ok: false,
      active: false,
      error: String(error.message || error)
    });
  }
});

app.post("/api/device/tap", async (req, res) => {
  try {
    if (!sessionId) {
      return res.status(400).json({ ok: false, error: "No active session" });
    }

    const { xRatio, yRatio } = req.body;
    const { x, y } = ratioToDevicePoint(xRatio, yRatio);

    await appiumRequest(`/session/${sessionId}/actions`, {
      method: "POST",
      body: JSON.stringify({
        actions: [
          {
            type: "pointer",
            id: "finger1",
            parameters: { pointerType: "touch" },
            actions: [
              { type: "pointerMove", duration: 0, x, y },
              { type: "pointerDown", button: 0 },
              { type: "pause", duration: 80 },
              { type: "pointerUp", button: 0 }
            ]
          }
        ]
      })
    });

    res.json({ ok: true, x, y });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      ok: false,
      error: String(error.message || error)
    });
  }
});

app.post("/api/device/swipe", async (req, res) => {
  try {
    if (!sessionId) {
      return res.status(400).json({ ok: false, error: "No active session" });
    }

    const {
      startXRatio,
      startYRatio,
      endXRatio,
      endYRatio,
      duration = 500
    } = req.body;

    const start = ratioToDevicePoint(startXRatio, startYRatio);
    const end = ratioToDevicePoint(endXRatio, endYRatio);

    await appiumRequest(`/session/${sessionId}/actions`, {
      method: "POST",
      body: JSON.stringify({
        actions: [
          {
            type: "pointer",
            id: "finger1",
            parameters: { pointerType: "touch" },
            actions: [
              {
                type: "pointerMove",
                duration: 0,
                x: start.x,
                y: start.y
              },
              {
                type: "pointerDown",
                button: 0
              },
              {
                type: "pointerMove",
                duration,
                x: end.x,
                y: end.y
              },
              {
                type: "pointerUp",
                button: 0
              }
            ]
          }
        ]
      })
    });

    res.json({
      ok: true,
      start,
      end
    });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      ok: false,
      error: String(error.message || error)
    });
  }
});

app.post("/api/device/home", async (req, res) => {
  try {
    if (!sessionId) {
      return res.status(400).json({ ok: false, error: "No active session" });
    }

    await appiumRequest(`/session/${sessionId}/appium/device/press_button`, {
      method: "POST",
      body: JSON.stringify({
        name: "home"
      })
    });

    res.json({ ok: true });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      ok: false,
      error: String(error.message || error)
    });
  }
});

app.post("/api/device/activate-app", async (req, res) => {
  try {
    if (!sessionId) {
      return res.status(400).json({ ok: false, error: "No active session" });
    }

    const bundleId = req.body.bundleId || CONFIG.appBundleId;

    await appiumRequest(`/session/${sessionId}/appium/device/activate_app`, {
      method: "POST",
      body: JSON.stringify({
        bundleId
      })
    });

    res.json({ ok: true, bundleId });
  } catch (error) {
    console.error(error);

    res.status(500).json({
      ok: false,
      error: String(error.message || error)
    });
  }
});

app.listen(3000, "0.0.0.0", () => {
  console.log("iOS Remote QA running at http://0.0.0.0:3000");
  console.log("Open http://localhost:3000");
});
import express from "express";
import cors from "cors";

const app = express();

app.use(
  cors({
    origin: [
      "http://localhost:8080",
      "http://127.0.0.1:8080",
      "http://localhost:5173",
      "http://127.0.0.1:5173",
    ],
    methods: ["GET", "POST", "OPTIONS"],
    allowedHeaders: ["Content-Type"],
  })
);

app.use(express.json());
app.use(express.static("public"));

const APPIUM_URL = "http://127.0.0.1:4723";

const CONFIG = {
  appBundleId: "",

  udid: "",
  xcodeSigningId: "iPhone Developer",
  xcodeOrgId: "",

  // OBS publishes to:
  // http://localhost:8889/simulator/whip
  //
  // Browser watches:
  // http://MAC_IP:8889/simulator
  obsWebRtcPath: "/simulator"
};

let sessionId = null;

let deviceSize = {
  width: 393,
  height: 852
};

let deviceActionInFlight = false;

let deviceActionBusy = false;

async function runDeviceAction(actionName, action, timeoutMs = 800) {
  if (deviceActionBusy) {
    return {
      accepted: false,
      skipped: true,
      reason: "Device action already running"
    };
  }

  deviceActionBusy = true;

  try {
    await action(timeoutMs);

    return {
      accepted: true,
      skipped: false,
      timedOut: false
    };
  } catch (error) {
    if (error.code === "APPIUM_TIMEOUT") {
      console.warn(`${actionName} timed out, but it may have already executed on device`);

      return {
        accepted: true,
        skipped: false,
        timedOut: true
      };
    }

    throw error;
  } finally {
    setTimeout(() => {
      deviceActionBusy = false;
    }, 120);
  }
}

async function runDeviceActionOnce(actionName, action) {
  if (deviceActionInFlight) {
    return {
      skipped: true,
      reason: "Previous device action still running"
    };
  }

  deviceActionInFlight = true;

  try {
    await action();

    return {
      skipped: false
    };
  } finally {
    deviceActionInFlight = false;
  }
}
async function appiumRequest(path, options = {}, config = {}) {
  const timeoutMs = config.timeoutMs ?? 10_000;

  const controller = new AbortController();

  const timeout = setTimeout(() => {
    controller.abort();
  }, timeoutMs);

  try {
    const response = await fetch(`${APPIUM_URL}${path}`, {
      ...options,
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        "Connection": "close",
        ...(options.headers || {})
      }
    });

    const data = await response.json().catch(() => ({}));

    if (!response.ok) {
      throw new Error(JSON.stringify(data, null, 2));
    }

    return data;
  } catch (error) {
    if (error.name === "AbortError") {
      const timeoutError = new Error(`Appium request timed out after ${timeoutMs}ms`);
      timeoutError.code = "APPIUM_TIMEOUT";
      throw timeoutError;
    }

    throw error;
  } finally {
    clearTimeout(timeout);
  }
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

    videoType: "webrtc",
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
            "appium:showXcodeLog": false,
            "appium:waitForIdleTimeout": 0,
            "appium:newCommandTimeout": 3600,
            "appium:wdaLocalPort": 8101,
            "appium:useNewWDA": false
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

    const result = await runDeviceAction("tap", async (timeoutMs) => {
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
                { type: "pause", duration: 40 },
                { type: "pointerUp", button: 0 }
              ]
            }
          ]
        })
      }, {
        timeoutMs
      });
    }, 700);

    res.json({ ok: true, x, y, ...result });
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
    const result = await runDeviceAction("swipe", async (timeoutMs) => {
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
      }, {
        timeoutMs
      });
    }, duration + 900);

    res.json({
      ok: true,
      start,
      end,
      ...result
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
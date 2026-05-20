const statusEl = document.getElementById("status");

const loadVideoButton = document.getElementById("loadVideo");
const startSessionButton = document.getElementById("startSession");
const stopSessionButton = document.getElementById("stopSession");
const homeButton = document.getElementById("homeButton");
const openAppButton = document.getElementById("openAppButton");
const applyVideoUrlButton = document.getElementById("applyVideoUrl");

const videoFrame = document.getElementById("videoFrame");
const videoUrlInput = document.getElementById("videoUrlInput");
const configInfo = document.getElementById("configInfo");

const touchLayer = document.getElementById("touchLayer");
const touchDot = document.getElementById("touchDot");
const toggleModeButton = document.getElementById("toggleMode");

const phoneFrame = document.getElementById("phoneFrame");
const sizeSlider = document.getElementById("sizeSlider");
const decreaseSizeButton = document.getElementById("decreaseSize");
const increaseSizeButton = document.getElementById("increaseSize");

let playerMode = false;

let appBundleId = null;
let deviceSize = null;
let pointerStart = null;
let actionBusy = false;

function setStatus(message) {
  statusEl.textContent = message;
}

function clamp(value, min, max) {
  return Math.max(min, Math.min(max, value));
}

function setPhoneWidth(width) {
  const safeWidth = clamp(Number(width), 280, 900);

  document.documentElement.style.setProperty("--phone-width", `${safeWidth}px`);
  sizeSlider.value = String(safeWidth);

  localStorage.setItem("remoteqa-phone-width", String(safeWidth));
}

function restorePhoneWidth() {
  const savedWidth = localStorage.getItem("remoteqa-phone-width");

  if (savedWidth) {
    setPhoneWidth(savedWidth);
  }
}

function applyDeviceSize(size) {
  if (!size || !size.width || !size.height) return;

  document.documentElement.style.setProperty(
    "--device-aspect",
    `${size.width} / ${size.height}`
  );

  const currentWidth = Number(sizeSlider.value || 390);
  setPhoneWidth(currentWidth);
}

function showTouchDot(x, y) {
  touchDot.style.left = `${x}px`;
  touchDot.style.top = `${y}px`;
  touchDot.style.display = "block";

  setTimeout(() => {
    touchDot.style.display = "none";
  }, 180);
}

function getRatioFromPointerEvent(event) {
  const rect = touchLayer.getBoundingClientRect();

  const x = event.clientX - rect.left;
  const y = event.clientY - rect.top;

  return {
    x,
    y,
    xRatio: x / rect.width,
    yRatio: y / rect.height
  };
}

async function postJson(url, body = {}) {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json"
    },
    body: JSON.stringify(body)
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok || data.ok === false) {
    throw new Error(data.error || JSON.stringify(data));
  }

  return data;
}

async function loadConfig() {
  const response = await fetch("/api/config");
  const data = await response.json();

  appBundleId = data.appBundleId;
  deviceSize = data.deviceSize;

  applyDeviceSize(deviceSize);

  videoUrlInput.value = data.videoUrl;

  configInfo.textContent =
    `App: ${data.appBundleId}\n` +
    `Device: ${data.deviceName || "unknown"}\n` +
    `Type: ${data.deviceType || "unknown"}\n` +
    `UDID: ${data.udid}\n` +
    `Device size: ${data.deviceSize.width} x ${data.deviceSize.height}\n` +
    `Video URL: ${data.videoUrl}`;
}

function loadVideo() {
  const url = videoUrlInput.value.trim();

  if (!url) {
    setStatus("Missing video URL");
    return;
  }

  setStatus("Loading OBS/WebRTC video...");

  videoFrame.removeAttribute("src");

  setTimeout(() => {
    videoFrame.setAttribute("src", url);
    setStatus("OBS/WebRTC video loaded");
  }, 150);
}

function setupResizeControls() {
  restorePhoneWidth();

  sizeSlider.addEventListener("input", event => {
    setPhoneWidth(event.target.value);
  });

  decreaseSizeButton.addEventListener("click", () => {
    setPhoneWidth(Number(sizeSlider.value) - 40);
  });

  increaseSizeButton.addEventListener("click", () => {
    setPhoneWidth(Number(sizeSlider.value) + 40);
  });
}

loadVideoButton.addEventListener("click", loadVideo);
applyVideoUrlButton.addEventListener("click", loadVideo);

toggleModeButton.addEventListener("click", () => {
  playerMode = !playerMode;

  document.body.classList.toggle("player-mode", playerMode);

  toggleModeButton.textContent = playerMode
    ? "Mode: Control iPhone"
    : "Mode: Control Player";

  setStatus(
    playerMode
      ? "iPhone mode: clicks control the device."
      : "Player mode: you can click the video player controls."
  );
});

startSessionButton.addEventListener("click", async () => {
  try {
    setStatus("Starting Appium session...");

    const data = await postJson("/api/session/start");

    deviceSize = data.deviceSize;
    applyDeviceSize(deviceSize);

    setStatus(
      `Appium connected. Device: ${deviceSize.width} x ${deviceSize.height}`
    );
  } catch (error) {
    console.error(error);
    setStatus(`Failed to start session: ${error.message}`);
  }
});

stopSessionButton.addEventListener("click", async () => {
  try {
    setStatus("Stopping Appium session...");
    await postJson("/api/session/stop");
    setStatus("Session stopped");
  } catch (error) {
    console.error(error);
    setStatus(`Failed to stop session: ${error.message}`);
  }
});

homeButton.addEventListener("click", async () => {
  try {
    await postJson("/api/device/home");
    setStatus("Home pressed");
  } catch (error) {
    console.error(error);
    setStatus(`Home failed: ${error.message}`);
  }
});

openAppButton.addEventListener("click", async () => {
  try {
    await postJson("/api/device/activate-app", {
      bundleId: appBundleId
    });

    setStatus(`Opened ${appBundleId}`);
  } catch (error) {
    console.error(error);
    setStatus(`Open app failed: ${error.message}`);
  }
});

touchLayer.addEventListener("pointerdown", event => {
  event.preventDefault();

  touchLayer.setPointerCapture(event.pointerId);

  const point = getRatioFromPointerEvent(event);

  pointerStart = {
    ...point,
    time: Date.now()
  };

  showTouchDot(point.x, point.y);
});

touchLayer.addEventListener("pointerup", async event => {
  event.preventDefault();

  if (!pointerStart) return;

  const end = getRatioFromPointerEvent(event);

  showTouchDot(end.x, end.y);

  const dx = end.xRatio - pointerStart.xRatio;
  const dy = end.yRatio - pointerStart.yRatio;
  const distance = Math.sqrt(dx * dx + dy * dy);

  if (actionBusy) {
    setStatus("Device busy, ignoring extra input...");
    pointerStart = null;
    return;
  }

  actionBusy = true;

  try {
    if (distance < 0.025) {
      const result = await postJson("/api/device/tap", {
        xRatio: end.xRatio,
        yRatio: end.yRatio
      });

      if (result.skipped) {
        setStatus("Device busy, tap skipped");
      } else if (result.timedOut) {
        setStatus(
          `Tap sent, response timed out: ${(end.xRatio * 100).toFixed(1)}%, ${(end.yRatio * 100).toFixed(1)}%`
        );
      } else {
        setStatus(
          `Tap: ${(end.xRatio * 100).toFixed(1)}%, ${(end.yRatio * 100).toFixed(1)}%`
        );
      }
    } else {
      const result = await postJson("/api/device/swipe", {
        startXRatio: pointerStart.xRatio,
        startYRatio: pointerStart.yRatio,
        endXRatio: end.xRatio,
        endYRatio: end.yRatio,
        duration: 500
      });

      if (result.skipped) {
        setStatus("Device busy, swipe skipped");
      } else if (result.timedOut) {
        setStatus("Swipe sent, response timed out");
      } else {
        setStatus("Swipe sent");
      }
    }
  } catch (error) {
    console.error(error);
    setStatus(`Action failed: ${error.message}`);
  } finally {
    actionBusy = false;
    pointerStart = null;
  }
});

touchLayer.addEventListener("pointercancel", () => {
  pointerStart = null;
});

setupResizeControls();

loadConfig().then(() => {
  setStatus("Ready. Load OBS video, then start Appium session.");
});
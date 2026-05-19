import Foundation
import AppKit
import ScreenCaptureKit
import CoreMedia
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import Network

final class FrameStore {
    private let lock = NSLock()
    private var jpeg: Data?

    func update(_ data: Data) {
        lock.lock()
        jpeg = data
        lock.unlock()
    }

    func latest() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return jpeg
    }
}

final class MJPEGServer {
    private let port: UInt16
    private let store: FrameStore
    private var listener: NWListener?

    init(port: UInt16, store: FrameStore) {
        self.port = port
        self.store = store
    }

    func start() throws {
        let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        self.listener = listener

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }

        listener.start(queue: .global(qos: .userInitiated))
        print("MJPEG server running at http://localhost:\(port)")
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else { return }

            let request = String(data: data ?? Data(), encoding: .utf8) ?? ""

            if request.contains("GET /stream.mjpg") {
                self.stream(connection)
            } else {
                self.sendIndex(connection)
            }
        }
    }

    private func sendIndex(_ connection: NWConnection) {
        let html = """
        <!doctype html>
        <html>
          <head>
            <meta charset="utf-8" />
            <title>QA iPhone Preview</title>
            <style>
              html, body {
                margin: 0;
                height: 100%;
                background: #111;
                display: grid;
                place-items: center;
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
              }

              .wrap {
                display: flex;
                flex-direction: column;
                gap: 16px;
                align-items: center;
              }

              img {
                max-width: 95vw;
                max-height: 90vh;
                border-radius: 28px;
                box-shadow: 0 20px 80px rgba(0,0,0,.45);
                background: #000;
              }

              p {
                color: #aaa;
                margin: 0;
              }
            </style>
          </head>
          <body>
            <div class="wrap">
              <img id="phone" src="/stream.mjpg" />
              <script>
                    const img = document.getElementById("phone");
                    const ws = new WebSocket(`ws://${location.hostname}:8091/input`);

                    let isDown = false;
                    let seq = 0;

                    let calibrationMode = false;
                    let calibrationPoints = [];

                    let phoneRect = JSON.parse(localStorage.getItem("phoneRect") || "null");

                    document.addEventListener("keydown", (event) => {
                        if (event.key === "c") {
                        calibrationMode = true;
                        calibrationPoints = [];
                        alert("Calibration mode: click TOP-LEFT of the real iPhone screen, then BOTTOM-RIGHT.");
                        }

                        if (event.key === "r") {
                        localStorage.removeItem("phoneRect");
                        phoneRect = null;
                        alert("Calibration reset.");
                        }
                    });

                    function rawPointFromEvent(event) {
                        const rect = img.getBoundingClientRect();

                        return {
                        x: Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width)),
                        y: Math.max(0, Math.min(1, (event.clientY - rect.top) / rect.height)),
                        };
                    }

                    function pointFromEvent(event) {
                        const raw = rawPointFromEvent(event);

                        if (!phoneRect) {
                        return raw;
                        }

                        const x = (raw.x - phoneRect.left) / (phoneRect.right - phoneRect.left);
                        const y = (raw.y - phoneRect.top) / (phoneRect.bottom - phoneRect.top);

                        return {
                        x: Math.max(0, Math.min(1, x)),
                        y: Math.max(0, Math.min(1, y)),
                        };
                    }

                    function handleCalibrationClick(event) {
                        if (!calibrationMode) return false;

                        const p = rawPointFromEvent(event);
                        calibrationPoints.push(p);

                        if (calibrationPoints.length === 1) {
                        alert("Now click BOTTOM-RIGHT of the real iPhone screen.");
                        }

                        if (calibrationPoints.length === 2) {
                        const a = calibrationPoints[0];
                        const b = calibrationPoints[1];

                        phoneRect = {
                            left: Math.min(a.x, b.x),
                            top: Math.min(a.y, b.y),
                            right: Math.max(a.x, b.x),
                            bottom: Math.max(a.y, b.y),
                        };

                        localStorage.setItem("phoneRect", JSON.stringify(phoneRect));

                        calibrationMode = false;
                        calibrationPoints = [];

                        alert(`Calibration saved:
                    left=${phoneRect.left.toFixed(4)}
                    top=${phoneRect.top.toFixed(4)}
                    right=${phoneRect.right.toFixed(4)}
                    bottom=${phoneRect.bottom.toFixed(4)}`);
                        }

                        return true;
                    }

                    function send(type, event) {
                        if (ws.readyState !== WebSocket.OPEN) return;

                        const p = pointFromEvent(event);

                        ws.send(JSON.stringify({
                        kind: "touch",
                        seq: seq++,
                        data: {
                            type,
                            x: p.x,
                            y: p.y
                        }
                        }));
                    }

                    img.addEventListener("pointerdown", (event) => {
                        if (handleCalibrationClick(event)) return;

                        isDown = true;
                        img.setPointerCapture(event.pointerId);
                        send("begin", event);
                    });

                    img.addEventListener("pointermove", (event) => {
                        if (!isDown) return;
                        send("move", event);
                    });

                    img.addEventListener("pointerup", (event) => {
                        if (!isDown) return;
                        isDown = false;
                        send("end", event);
                    });

                    img.addEventListener("pointercancel", (event) => {
                        if (!isDown) return;
                        isDown = false;
                        send("end", event);
                    });
                </script>
              <p>Live iPhone preview via QuickTime + ScreenCaptureKit</p>
            </div>
          </body>
          
        </html>
        """

        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func stream(_ connection: NWConnection) {
        let boundary = "qtframe"

        let header = """
        HTTP/1.1 200 OK\r
        Content-Type: multipart/x-mixed-replace; boundary=\(boundary)\r
        Cache-Control: no-cache, no-store, must-revalidate\r
        Pragma: no-cache\r
        Expires: 0\r
        Connection: close\r
        \r

        """

        connection.send(content: Data(header.utf8), completion: .contentProcessed { _ in })

        Task.detached { [store] in
            while true {
                guard let jpeg = store.latest() else {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    continue
                }

                let partHeader = """
                --\(boundary)\r
                Content-Type: image/jpeg\r
                Content-Length: \(jpeg.count)\r
                \r

                """

                var packet = Data(partHeader.utf8)
                packet.append(jpeg)
                packet.append(Data("\r\n".utf8))

                let ok = await Self.send(packet, on: connection)
                if !ok { break }

                try? await Task.sleep(nanoseconds: 83_000_000) // ~30 fps max
            }

            connection.cancel()
        }
    }

    private static func send(_ data: Data, on connection: NWConnection) async -> Bool {
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                continuation.resume(returning: error == nil)
            })
        }
    }
}

final class QuickTimeWindowCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    private let store: FrameStore
    private let context = CIContext()
    private var stream: SCStream?

    init(store: FrameStore) {
        self.store = store
    }

    func start() async throws {
        let content = try await SCShareableContent.excludingDesktopWindows(
            false,
            onScreenWindowsOnly: true
        )

        let quickTimeWindows = content.windows.filter { window in
            window.owningApplication?.bundleIdentifier == "com.apple.QuickTimePlayerX"
        }

        guard let window = quickTimeWindows.first(where: { window in
            let title = (window.title ?? "").lowercased()
            return title.contains("movie recording") ||
                   title.contains("recording") ||
                   title.isEmpty
        }) ?? quickTimeWindows.first else {
            print("Available windows:")
            for window in content.windows {
                let app = window.owningApplication?.applicationName ?? "Unknown"
                print("- \(app): \(window.title ?? "(no title)")")
            }

            throw NSError(
                domain: "QTWindowStream",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey: "Could not find QuickTime recording window"
                ]
            )
        }

        print("Capturing QuickTime window:")
        print("App: \(window.owningApplication?.applicationName ?? "QuickTime")")
        print("Title: \(window.title ?? "(no title)")")
        print("Frame: \(window.frame)")

        let filter = SCContentFilter(desktopIndependentWindow: window)

        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let configuration = SCStreamConfiguration()

        configuration.width = max(320, Int(window.frame.width * scale))
        configuration.height = max(320, Int(window.frame.height * scale))
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 12)
        configuration.queueDepth = 2
        configuration.showsCursor = false
        configuration.capturesAudio = false

        let stream = SCStream(
            filter: filter,
            configuration: configuration,
            delegate: self
        )

        try stream.addStreamOutput(
            self,
            type: SCStreamOutputType.screen,
            sampleHandlerQueue: DispatchQueue(label: "qt-window-stream.screen")
        )

        self.stream = stream

        try await stream.startCapture()
        print("ScreenCaptureKit capture started")
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        guard sampleBuffer.isValid else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return
        }

        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return
        }

        CGImageDestinationAddImage(destination, cgImage, [
            kCGImageDestinationLossyCompressionQuality: 0.40
        ] as CFDictionary)

        guard CGImageDestinationFinalize(destination) else {
            return
        }

        store.update(data as Data)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        print("ScreenCaptureKit stopped with error: \(error.localizedDescription)")
    }
}

struct Config {
    var deviceName = "iPhone"
    var scriptPath = "./open-iphone-quicktime.applescript"
    var port: UInt16 = 8090
    var skipQuickTime = false
}

func parseArgs() -> Config {
    var config = Config()
    let args = CommandLine.arguments
    var index = 1

    while index < args.count {
        switch args[index] {
        case "--device":
            if index + 1 < args.count {
                config.deviceName = args[index + 1]
                index += 1
            }

        case "--script":
            if index + 1 < args.count {
                config.scriptPath = args[index + 1]
                index += 1
            }

        case "--port":
            if index + 1 < args.count, let port = UInt16(args[index + 1]) {
                config.port = port
                index += 1
            }

        case "--skip-quicktime":
            config.skipQuickTime = true

        default:
            break
        }

        index += 1
    }

    return config
}

func runQuickTimeScript(path: String, deviceName: String) throws {
    print("Opening QuickTime with device: \(deviceName)")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = [path, deviceName]

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    if process.terminationStatus != 0 {
        throw NSError(
            domain: "QTWindowStream",
            code: Int(process.terminationStatus),
            userInfo: [
                NSLocalizedDescriptionKey: "QuickTime script failed:\n\(output)"
            ]
        )
    }

    if !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        print(output)
    }

    print("QuickTime ready")
}

@main
struct App {
    static func main() async {
        let config = parseArgs()

        do {
            if !config.skipQuickTime {
                try runQuickTimeScript(path: config.scriptPath, deviceName: config.deviceName)
            }

            let store = FrameStore()
            let server = MJPEGServer(port: config.port, store: store)
            try server.start()

            let capture = QuickTimeWindowCapture(store: store)
            try await capture.start()

            print("")
            print("Open this on the QA machine/browser:")
            print("http://localhost:\(config.port)")
            print("")
            print("For another machine on the same VPN/LAN, use:")
            print("http://<mac-host-ip>:\(config.port)")
            print("")

            while true {
                try await Task.sleep(nanoseconds: 60_000_000_000)
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            exit(1)
        }
    }
}
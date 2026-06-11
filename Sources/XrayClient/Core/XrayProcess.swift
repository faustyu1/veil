import Foundation

/// Locates the bundled (or system) `xray` executable.
enum XrayBinary {
    static func locate() -> URL? {
        // 1. SPM resource bundle (Bundle.module) — where `.copy("Resources/xray")` lands.
        if let resourceURL = Bundle.module.url(forResource: "xray", withExtension: nil) {
            return resourceURL
        }
        // 2. Main bundle (in case resources are flattened into the app bundle).
        if let resourceURL = Bundle.main.url(forResource: "xray", withExtension: nil) {
            return resourceURL
        }
        // 2. Next to the running binary (handy for `swift run`).
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        let sibling = exeDir.appendingPathComponent("xray")
        if FileManager.default.isExecutableFile(atPath: sibling.path) {
            return sibling
        }
        // 3. A few common install locations / PATH fallbacks.
        for candidate in ["/usr/local/bin/xray", "/opt/homebrew/bin/xray"] {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
}

/// Manages the lifecycle of the `xray` core subprocess and streams its logs.
final class XrayProcess {
    private var process: Process?
    private let queue = DispatchQueue(label: "xray.process")

    /// Called on the main queue with each new log line.
    var onLog: (@Sendable (String) -> Void)?
    /// Called on the main queue when the process exits unexpectedly.
    var onExit: (@Sendable (Int32) -> Void)?

    var isRunning: Bool { process?.isRunning ?? false }

    /// Writes the config to a temp file and launches xray with `run -c`.
    /// `assetDir` is exported as `XRAY_LOCATION_ASSET` so geosite:/geoip: rules
    /// can find geoip.dat / geosite.dat.
    func start(configData: Data, binary: URL, assetDir: URL? = nil) throws {
        stop()

        let tmpDir = FileManager.default.temporaryDirectory
        let configURL = tmpDir.appendingPathComponent("xray-config-\(UUID().uuidString).json")
        try configData.write(to: configURL)

        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["run", "-c", configURL.path]
        if let assetDir {
            var env = ProcessInfo.processInfo.environment
            env["XRAY_LOCATION_ASSET"] = assetDir.path
            proc.environment = env
        }

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe

        let logCallback = onLog
        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async { logCallback?(text) }
        }

        let exitCallback = onExit
        proc.terminationHandler = { p in
            pipe.fileHandleForReading.readabilityHandler = nil
            try? FileManager.default.removeItem(at: configURL)
            let status = p.terminationStatus
            DispatchQueue.main.async { exitCallback?(status) }
        }

        try proc.run()
        self.process = proc
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            process = nil
            return
        }
        proc.terminationHandler = nil
        proc.terminate()
        process = nil
    }
}

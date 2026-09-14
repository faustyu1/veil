// macOS-only: this file drives the system proxy / tun2socks / a bundled
// core subprocess, none of which exist on iOS. The iOS build runs Xray
// in-process inside the NetworkExtension instead (see ios/Tunnel).
#if os(macOS)
import Foundation
import CryptoKit
import Darwin

/// Safe replacement for the SPM-synthesized `Bundle.module`.
///
/// `Bundle.module` is a `static let` whose initializer calls `fatalError(…)`
/// when the `XrayClient_XrayClient.bundle` resource bundle can't be located —
/// so *merely accessing it* hard-crashes the app (e.g. when the .app is run
/// from a copy/volume where the resource bundle didn't come along). This finder
/// performs the same candidate search but returns `nil` instead of trapping.
enum ResourceBundle {
    private final class BundleFinder {}

    static let module: Bundle? = {
        let bundleName = "XrayClient_XrayClient"

        var candidates = [
            Bundle.main.resourceURL,
            Bundle(for: BundleFinder.self).resourceURL,
            Bundle.main.bundleURL,
        ]

        // Bundle next to the running executable (handy for `swift run`).
        let exeDir = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
        candidates.append(exeDir)
        candidates.append(exeDir.deletingLastPathComponent())

        for candidate in candidates {
            let url = candidate?.appendingPathComponent(bundleName + ".bundle")
            if let url, let bundle = Bundle(url: url) {
                return bundle
            }
        }
        return nil
    }()
}

/// Locates a cryptographically pinned core executable.
///
/// Release builds accept bundled cores only. Debug builds may use an explicit
/// path, but only when the matching expected SHA-256 is also supplied. There is
/// deliberately no PATH/Homebrew/sibling fallback.
enum CoreBinary {
    /// Finds an executable named `name` (e.g. "xray" or "sing-box").
    static func locate(_ name: String) -> URL? {
        // SPM resource bundle — where `.copy("Resources/…")` lands.
        if let resourceURL = ResourceBundle.module?.url(forResource: name, withExtension: nil) {
            return CoreVerifier.verifyBundled(resourceURL, name: name) ? resourceURL : nil
        }
        // Main bundle (in case resources are flattened into the app bundle).
        if let resourceURL = Bundle.main.url(forResource: name, withExtension: nil) {
            return CoreVerifier.verifyBundled(resourceURL, name: name) ? resourceURL : nil
        }
#if DEBUG
        if let override = CoreVerifier.verifiedDevelopmentOverride(name: name) {
            return override
        }
#endif
        return nil
    }

    /// Resolves the executable for a given core engine.
    static func locate(for engine: CoreEngine) -> URL? {
        switch engine {
        case .xray:    return locate("xray")
        case .singbox: return locate("sing-box")
        }
    }

    static func isUnsafeDevelopmentOverride(_ url: URL, name: String) -> Bool {
#if DEBUG
        let key = name.uppercased().replacingOccurrences(of: "-", with: "_")
        guard let path = ProcessInfo.processInfo.environment["VEIL_UNSAFE_\(key)_PATH"] else {
            return false
        }
        return URL(fileURLWithPath: path).standardizedFileURL == url.standardizedFileURL
#else
        return false
#endif
    }
}

enum CoreVerifier {
    struct Manifest: Equatable {
        let sha256: String
        let architecture: String

        init?(text: String) {
            let fields = text.split(whereSeparator: { $0.isWhitespace })
            guard fields.count == 2 else { return nil }
            let hash = String(fields[0]).lowercased()
            let arch = String(fields[1])
            guard hash.count == 64, hash.allSatisfy({ $0.isHexDigit }),
                  arch == "arm64" || arch == "x86_64" else { return nil }
            sha256 = hash
            architecture = arch
        }
    }

    static func verifyBundled(_ binary: URL, name: String) -> Bool {
        let sidecar = binary.deletingLastPathComponent()
            .appendingPathComponent("\(name).sha256")
        guard let text = try? String(contentsOf: sidecar, encoding: .utf8),
              let manifest = Manifest(text: text) else { return false }
        return verify(binary, manifest: manifest)
    }

    static func verify(_ binary: URL, manifest: Manifest) -> Bool {
        guard FileManager.default.isExecutableFile(atPath: binary.path),
              manifest.architecture == currentArchitecture,
              let data = try? Data(contentsOf: binary, options: [.mappedIfSafe]) else {
            return false
        }
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return actual == manifest.sha256
    }

#if DEBUG
    static func verifiedDevelopmentOverride(name: String) -> URL? {
        let key = name.uppercased().replacingOccurrences(of: "-", with: "_")
        let env = ProcessInfo.processInfo.environment
        guard let path = env["VEIL_UNSAFE_\(key)_PATH"],
              let expected = env["VEIL_UNSAFE_\(key)_SHA256"],
              let manifest = Manifest(text: "\(expected) \(currentArchitecture)") else {
            return nil
        }
        let url = URL(fileURLWithPath: path)
        return verify(url, manifest: manifest) ? url : nil
    }
#endif

    static var currentArchitecture: String {
#if arch(arm64)
        return "arm64"
#elseif arch(x86_64)
        return "x86_64"
#else
        return "unsupported"
#endif
    }
}

/// Locates the bundled (or system) `xray` executable.
enum XrayBinary {
    static func locate() -> URL? { CoreBinary.locate("xray") }
}

/// Manages the lifecycle of the `xray` core subprocess and streams its logs.
final class XrayProcess {
    private var process: Process?
    private var configURL: URL?
    private let queue = DispatchQueue(label: "xray.process")

    /// Called on the main queue with each new log line.
    var onLog: (@Sendable (String) -> Void)?
    /// Called on the main queue when the process exits unexpectedly.
    var onExit: (@Sendable (Int32) -> Void)?

    var isRunning: Bool { process?.isRunning ?? false }

    init() {
        SecureCoreConfig.cleanupStaleFiles()
    }

    /// Writes the config to a temp file and launches xray with `run -c`.
    /// `assetDir` is exported as `XRAY_LOCATION_ASSET` so geosite:/geoip: rules
    /// can find geoip.dat / geosite.dat.
    func start(configData: Data, binary: URL, assetDir: URL? = nil) throws {
        stop()

        let configURL = try SecureCoreConfig.create(configData)
        self.configURL = configURL

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
            SecureCoreConfig.remove(configURL)
            let status = p.terminationStatus
            DispatchQueue.main.async { exitCallback?(status) }
        }

        do {
            try proc.run()
        } catch {
            SecureCoreConfig.remove(configURL)
            self.configURL = nil
            throw error
        }
        self.process = proc
    }

    func stop() {
        guard let proc = process, proc.isRunning else {
            process = nil
            if let configURL { SecureCoreConfig.remove(configURL) }
            configURL = nil
            return
        }
        proc.terminationHandler = nil
        proc.terminate()
        if let configURL { SecureCoreConfig.remove(configURL) }
        configURL = nil
        process = nil
    }

    deinit {
        if let configURL { SecureCoreConfig.remove(configURL) }
    }
}

enum SecureCoreConfig {
    private static let prefix = "core-config-"

    static var directory: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("dev.local.veil/runtime", isDirectory: true)
    }

    static func create(_ data: Data, in targetDirectory: URL = directory) throws -> URL {
        guard SecureFile.ensureDirectory(targetDirectory) else {
            throw CocoaError(.fileWriteNoPermission)
        }
        cleanupStaleFiles(in: targetDirectory)
        let url = targetDirectory.appendingPathComponent(prefix + UUID().uuidString)
        guard FileManager.default.createFile(
            atPath: url.path, contents: data,
            attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o600],
                                              ofItemAtPath: url.path)
        return url
    }

    static func remove(_ url: URL, from targetDirectory: URL = directory) {
        guard url.deletingLastPathComponent().standardizedFileURL == targetDirectory.standardizedFileURL,
              url.lastPathComponent.hasPrefix(prefix) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func cleanupStaleFiles(in targetDirectory: URL = directory) {
        guard SecureFile.ensureDirectory(targetDirectory),
              let files = try? FileManager.default.contentsOfDirectory(
                at: targetDirectory, includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]) else { return }
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
#endif

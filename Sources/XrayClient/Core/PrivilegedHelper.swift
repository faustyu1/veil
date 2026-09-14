// macOS-only: the privileged helper exists to change routes and DNS, neither
// of which the iOS build does — there the tunnel is a NetworkExtension.
#if os(macOS)
import Foundation
import VeilHelperKit

/// The app's side of the XPC conversation with the privileged helper.
///
/// Every call is synchronous: the connection manager already runs off the main
/// thread for tunnel work, and a semaphore is far easier to reason about than
/// threading async through a callback API that must never be half-applied.
enum PrivilegedHelper {

    struct TunnelStatus {
        let isUp: Bool
        let device: String?
        let strictKillSwitch: Bool
        let protectsIPv6: Bool
    }

    enum HelperError: LocalizedError {
        case notInstalled
        case versionMismatch(installed: Int, expected: Int)
        case unreachable(String)
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notInstalled:
                return "The Veil helper is not installed."
            case .versionMismatch(let installed, let expected):
                return "The installed helper speaks version \(installed), this build needs \(expected). Reinstall it in Settings."
            case .unreachable(let message):
                return "Could not reach the Veil helper: \(message)"
            case .failed(let message):
                return message
            }
        }
    }

    /// Where the app's copy of the helper and its payload live inside the
    /// bundle, ready for the installer to copy into place.
    static var bundledPayloadDirectory: URL? {
        let url = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/VeilHelper", isDirectory: true)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// True when the LaunchDaemon and its payload are present on disk. This is
    /// a file check, not a handshake — see `isReady` for that.
    static var isInstalled: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: VeilHelperInfo.launchDaemonPath)
            && fm.isExecutableFile(atPath: VeilHelperInfo.installDirectory + "/VeilHelper")
    }

    /// Protocol version the installed helper answers with, or nil if it cannot
    /// be reached (not installed, refused the connection, or crashed).
    static var installedVersion: Int? {
        guard isInstalled else { return nil }
        let box = Box<Int>()
        try? perform(timeout: 5) { proxy, finish in
            proxy.helperVersion { version in
                box.value = version
                finish(nil)
            }
        }
        return box.value
    }

    /// True when the helper is installed, reachable and speaks our protocol.
    static var isReady: Bool {
        installedVersion == VeilHelperInfo.protocolVersion
    }

    // MARK: - Commands

    static func startTunnel(socksHost: String, socksPort: Int,
                            serverIPs: [String], dnsServers: [String],
                            strictKillSwitch: Bool, protectIPv6: Bool) throws {
        try perform(timeout: 30) { proxy, finish in
            proxy.startTunnel(socksHost: socksHost, socksPort: socksPort,
                              serverIPs: serverIPs, dnsServers: dnsServers,
                              strictKillSwitch: strictKillSwitch,
                              protectIPv6: protectIPv6,
                              reply: finish.finish)
        }
    }

    static func stopTunnel() throws {
        try perform(timeout: 20) { proxy, finish in
            proxy.stopTunnel(reply: finish.finish)
        }
    }

    static func pinServerIPs(_ ips: [String]) throws {
        try perform(timeout: 15) { proxy, finish in
            proxy.pinServerIPs(ips, reply: finish.finish)
        }
    }

    static func addProbeRoutes(_ ips: [String]) throws {
        try perform(timeout: 15) { proxy, finish in
            proxy.addProbeRoutes(ips, reply: finish.finish)
        }
    }

    static func removeProbeRoutes() throws {
        try perform(timeout: 15) { proxy, finish in
            proxy.removeProbeRoutes(reply: finish.finish)
        }
    }

    /// Whether a tunnel is currently up according to the helper itself, rather
    /// than according to a file someone could have left behind.
    static var tunnelIsUp: Bool {
        tunnelStatus?.isUp ?? false
    }

    /// The helper's authoritative protection state for UI/diagnostics.
    static var tunnelStatus: TunnelStatus? {
        guard isInstalled else { return nil }
        let box = Box<TunnelStatus>()
        try? perform(timeout: 5) { proxy, finish in
            proxy.tunnelStatus { isUp, device, strict, ipv6 in
                box.value = TunnelStatus(isUp: isUp, device: device,
                                         strictKillSwitch: strict,
                                         protectsIPv6: ipv6)
                finish(nil)
            }
        }
        return box.value
    }

    // MARK: - Plumbing

    /// Carries the reply block into `perform`'s body.
    ///
    /// A bare closure parameter would be non-escaping, and the protocol's reply
    /// blocks are `@escaping`; `@escaping` cannot be spelled on a nested
    /// function type, so the closure travels as a stored property instead.
    struct Completion {
        let finish: (String?) -> Void
        func callAsFunction(_ message: String?) { finish(message) }
    }

    /// Opens a connection, runs one command, and waits for its single reply.
    private static func perform(
        timeout: TimeInterval,
        _ body: (VeilHelperProtocol, Completion) -> Void
    ) throws {
        guard isInstalled else { throw HelperError.notInstalled }

        let connection = NSXPCConnection(machServiceName: VeilHelperInfo.machServiceName,
                                         options: .privileged)
        connection.remoteObjectInterface = NSXPCInterface(with: VeilHelperProtocol.self)
        connection.resume()
        defer { connection.invalidate() }

        let semaphore = DispatchSemaphore(value: 0)
        // Holds the failure message, if there is one. Success leaves it empty.
        let failure = Box<String>()

        // The error handler fires instead of the reply when the helper refuses
        // the connection or dies mid-call; either way exactly one wait returns.
        let proxy = connection.remoteObjectProxyWithErrorHandler { error in
            failure.value = error.localizedDescription
            semaphore.signal()
        }
        guard let helper = proxy as? VeilHelperProtocol else {
            throw HelperError.unreachable("unexpected proxy type")
        }

        body(helper, Completion { message in
            if let message, !message.isEmpty { failure.value = message }
            semaphore.signal()
        })

        guard semaphore.wait(timeout: .now() + timeout) == .success else {
            throw HelperError.unreachable("timed out after \(Int(timeout))s")
        }
        if let message = failure.value {
            throw HelperError.failed(message)
        }
    }

    /// Minimal lock-guarded box: XPC replies arrive on its own queue.
    private final class Box<T>: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: T?

        var value: T? {
            get { lock.lock(); defer { lock.unlock() }; return storage }
            set { lock.lock(); storage = newValue; lock.unlock() }
        }
    }
}
#endif

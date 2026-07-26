import Foundation
import Observation
import NetworkExtension
import UserNotifications

/// Drives the VPN from the app side.
///
/// The app owns no networking of its own: it writes the Xray config into the
/// shared container, installs/updates the tunnel profile, and then asks
/// NetworkExtension to start it. Everything after that happens in the provider
/// process; state and counters come back over `sendProviderMessage`.
@MainActor
@Observable
final class TunnelController {

    private(set) var state: ConnectionState = .disconnected
    private(set) var activeServerID: UUID?
    private(set) var activeServerName: String = ""
    private(set) var coreVersion: String = ""
    private(set) var uplinkBytes: Int64 = 0
    private(set) var downlinkBytes: Int64 = 0
    private(set) var logs: String = ""
    private(set) var uptimeText: String = ""
    private(set) var isInstalled: Bool = false

    /// Post a local notification on connect / disconnect.
    var notifyOnConnect: Bool = false

    private var manager: NETunnelProviderManager?
    private var connectedSince: Date?
    /// Held in a box so `deinit` — which is never main-actor isolated — can
    /// still unregister the observer.
    private let statusObserver = ObserverToken()
    private var pollTask: Task<Void, Never>?
    /// Server the user asked for, kept so a switch can reuse the live tunnel.
    private var pendingServerID: UUID?

    var isConnected: Bool { state == .connected }

    init() {
        Task { await loadManager() }
    }

    deinit {
        statusObserver.clear()
    }

    // MARK: - Profile

    /// Loads the existing VPN profile, if the user has already allowed one.
    func loadManager() async {
        let managers = (try? await NETunnelProviderManager.loadAllFromPreferences()) ?? []
        let existing = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?
                .providerBundleIdentifier == AppGroup.tunnelBundleIdentifier
        }
        manager = existing
        isInstalled = existing != nil
        if let existing {
            observe(existing)
            syncState(from: existing.connection.status)
        }
    }

    /// Creates the profile if needed and points it at the current server. iOS
    /// asks the user to allow the VPN configuration the first time this runs.
    private func prepareManager(server: ProxyConfig) async throws -> NETunnelProviderManager {
        let target = manager ?? NETunnelProviderManager()

        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = AppGroup.tunnelBundleIdentifier
        // Shown in Settings > VPN. Routing is Xray's job, this is cosmetic.
        proto.serverAddress = server.address
        proto.providerConfiguration = ["server": server.name]
        // Bring the tunnel back automatically if the provider is ever killed.
        proto.disconnectOnSleep = false

        target.protocolConfiguration = proto
        target.localizedDescription = "Veil"
        target.isEnabled = true

        try await target.saveToPreferences()
        // A save invalidates the in-memory object; NE requires a reload before
        // the connection can be started.
        try await target.loadFromPreferences()

        manager = target
        isInstalled = true
        observe(target)
        return target
    }

    private func observe(_ manager: NETunnelProviderManager) {
        statusObserver.clear()
        statusObserver.value = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] notification in
            guard let connection = notification.object as? NEVPNConnection else { return }
            let status = connection.status
            Task { @MainActor in self?.syncState(from: status) }
        }
    }

    // MARK: - Connect / disconnect

    /// Connects to `server`, or switches to it without dropping the tunnel when
    /// one is already up.
    func connect(to server: ProxyConfig, settings: AppSettings) async {
        guard server.xraySupported else {
            fail(TunnelConfigWriter.WriteError.unsupportedProtocol(server.proto).localizedDescription)
            return
        }

        do {
            try TunnelConfigWriter.write(server: server, settings: settings)
        } catch {
            fail(error.localizedDescription)
            return
        }

        pendingServerID = server.id
        activeServerName = server.name

        // Live tunnel: just tell the provider to reload. The utun stays up, iOS
        // never sees a reconnect, and the switch takes well under a second.
        if state == .connected, let session = manager?.connection as? NETunnelProviderSession {
            do {
                try session.sendProviderMessage(TunnelRequest(.reload).encoded()) { [weak self] data in
                    Task { @MainActor in
                        self?.activeServerID = server.id
                        if let data, let status = TunnelStatus.decode(data) {
                            self?.apply(status)
                        }
                    }
                }
                return
            } catch {
                // Provider not reachable — fall through to a full restart.
            }
        }

        state = .connecting
        do {
            let target = try await prepareManager(server: server)
            try target.connection.startVPNTunnel()
        } catch {
            fail(Self.describe(error))
        }
    }

    /// NetworkExtension reports its problems as bare `NEVPNError`s whose
    /// `localizedDescription` is developer-speak ("IPC failed"). Translate the
    /// ones a user can actually act on.
    private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        guard nsError.domain == NEVPNErrorDomain,
              let code = NEVPNError.Code(rawValue: nsError.code) else {
            return error.localizedDescription
        }
        switch code {
        case .configurationInvalid:
            return "The VPN configuration was rejected by the system."
        case .configurationDisabled:
            return "The VPN configuration is turned off in Settings."
        case .connectionFailed:
            return "The tunnel could not start. Check the log for details."
        case .configurationStale:
            return "The VPN configuration changed — try again."
        case .configurationReadWriteFailed:
            // Also what the Simulator returns: it has no VPN stack at all.
            return "Could not talk to the VPN service. "
                 + "NetworkExtension does not run in the Simulator — use a real device."
        case .configurationUnknown:
            return "No VPN configuration is installed yet."
        @unknown default:
            return error.localizedDescription
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        pendingServerID = nil
    }

    /// Removes the VPN profile from system settings.
    func removeProfile() async {
        guard let manager else { return }
        try? await manager.removeFromPreferences()
        self.manager = nil
        isInstalled = false
        state = .disconnected
    }

    // MARK: - State

    private func syncState(from status: NEVPNStatus) {
        switch status {
        case .connected:
            let wasConnected = (state == .connected)
            activeServerID = pendingServerID ?? activeServerID
            state = .connected
            if connectedSince == nil { connectedSince = Date() }
            startPolling()
            if notifyOnConnect && !wasConnected {
                notify(title: "Connected", body: activeServerName)
            }
        case .connecting, .reasserting, .disconnecting:
            state = .connecting
        case .disconnected, .invalid:
            let wasActive = (state == .connected || state == .connecting)
            stopPolling()
            connectedSince = nil
            uptimeText = ""
            activeServerID = nil
            if let reason = readLastError(), wasActive {
                state = .failed(reason)
            } else {
                state = .disconnected
                if notifyOnConnect && wasActive {
                    notify(title: "Disconnected", body: activeServerName)
                }
            }
        @unknown default:
            state = .disconnected
        }
    }

    private func fail(_ message: String) {
        state = .failed(message)
    }

    private func readLastError() -> String? {
        guard let data = try? Data(contentsOf: AppGroup.lastErrorURL),
              let text = String(data: data, encoding: .utf8),
              !text.isEmpty else { return nil }
        try? FileManager.default.removeItem(at: AppGroup.lastErrorURL)
        return text
    }

    // MARK: - Live status

    /// Polls the provider once a second for counters, log and uptime. Only runs
    /// while connected, so an idle app costs nothing.
    private func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshStatus()
                self?.tickUptime()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refreshStatus() async {
        guard let session = manager?.connection as? NETunnelProviderSession,
              session.status == .connected else { return }
        let response: Data? = await withCheckedContinuation { continuation in
            do {
                try session.sendProviderMessage(TunnelRequest(.status).encoded()) { data in
                    continuation.resume(returning: data)
                }
            } catch {
                continuation.resume(returning: nil)
            }
        }
        guard let response, let status = TunnelStatus.decode(response) else { return }
        apply(status)
    }

    func clearLogs() {
        logs = ""
        guard let session = manager?.connection as? NETunnelProviderSession else { return }
        try? session.sendProviderMessage(TunnelRequest(.clearLog).encoded(), responseHandler: nil)
    }

    private func apply(_ status: TunnelStatus) {
        coreVersion = status.coreVersion
        uplinkBytes = status.uplinkBytes
        downlinkBytes = status.downlinkBytes
        logs = status.log
        if !status.serverName.isEmpty { activeServerName = status.serverName }
        if let startedAt = status.startedAt, connectedSince == nil {
            connectedSince = startedAt
        }
    }

    private func tickUptime() {
        guard let since = connectedSince else { uptimeText = ""; return }
        let total = Int(Date().timeIntervalSince(since))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        uptimeText = h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    // MARK: - Notifications

    private func notify(title: String, body: String) {
        NotificationManager.notify(title: title, body: body)
    }
}

/// Holds a NotificationCenter observer token outside of any actor, so both the
/// main-actor code that installs it and `deinit` can reach it.
private final class ObserverToken: @unchecked Sendable {
    var value: NSObjectProtocol?

    func clear() {
        guard let value else { return }
        NotificationCenter.default.removeObserver(value)
        self.value = nil
    }
}

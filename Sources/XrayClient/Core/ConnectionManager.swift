import Foundation
import Observation
import Network

// The macOS coordinator drives an out-of-process core plus the system proxy or
// tun2socks. iOS has neither: there the tunnel lives in a NetworkExtension and
// is driven by `TunnelController` (ios/App), which speaks to the provider over
// NETunnelProviderSession. `ConnectionState` is shared by both.
enum ConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var label: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connecting:   return "Connecting…"
        case .connected:    return "Connected"
        case .failed(let m): return "Failed: \(m)"
        }
    }
}

#if os(macOS)
import AppKit

/// Top-level coordinator: owns the xray process, the active transport mode
/// (system proxy or TUN), uptime tracking, and logs.
@MainActor
@Observable
final class ConnectionManager {
    private(set) var state: ConnectionState = .disconnected
    private(set) var activeServerID: UUID?
    private(set) var activeServerName: String = ""
    private(set) var logs: String = ""
    private(set) var connectedSince: Date?
    private(set) var uptimeText: String = ""

    var mode: TunnelMode = .systemProxy
    var ports = InboundPorts()
    /// The ordered routing rules to apply on the next (re)connect.
    var routingRules: [RoutingRule] = []
    /// Xray core log verbosity.
    var logLevel: LogLevel = .warning

    /// Auto-reconnect when the link silently dies (NAT/firewall idle timeout).
    var autoReconnect: Bool = true

    /// Everything the profile builder needs that lives in the store. Kept in
    /// sync by `applyStore`, because a profile is no longer built from one
    /// server — it is built from the whole list, the groups and the rules.
    var settings = AppSettings()
    var allServers: [ProxyConfig] = []
    /// Groups the subscriptions' panels declared, alongside the user's own.
    var subscriptionGroups: [ServerGroup] = []

    /// The store this connection reads its profile from. Held weakly and
    /// re-read on every connect, so a rule edited in a sheet takes effect on
    /// the next switch without every call site having to remember to push it.
    private weak var store: ServerStore?

    /// Post a macOS notification on connect / disconnect / reconnect events.
    var notifyOnConnect: Bool = false

    private let xray = XrayProcess()
    private let bridges = BridgeManager()
    private var activeMode: TunnelMode = .systemProxy
    /// True when the active connection is a full profile rather than the
    /// single-server + tun2socks path, so teardown knows what to undo.
    private var activeUsedProfile = false
    /// Token the local control API is protected with. Random per launch: it is
    /// never persisted, and nothing outside this process needs it to survive a
    /// restart.
    private let controlSecret = UUID().uuidString
    private var uptimeTimer: Timer?

    /// Network path monitoring and recovery after sleep / network changes.
    private var networkMonitor: NWPathMonitor?
    private var networkRecoveryTask: Task<Void, Never>?
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var isNetworkSatisfied: Bool = true
    private var isSleeping: Bool = false

    /// The server we're currently connected to, kept so the watchdog can
    /// transparently restart the tunnel without user input.
    private var activeServer: ProxyConfig?
    private var watchdogTask: Task<Void, Never>?
    /// Core output waiting to be shown, and the task that will show it.
    private var pendingLog = ""
    private var logFlushTask: Task<Void, Never>?

    /// Pulls the root-owned core log into the app's log while TUN mode is up.
    private var coreLogTask: Task<Void, Never>?
    /// Last line already shown, so a repeated tail is not printed twice.
    private var coreLogSeen = ""

    /// When the current connect attempt began, for the "ready in Ns" log line.
    private var connectStarted: Date?

    /// True while a watchdog-driven reconnect is in flight, so the UI doesn't
    /// flicker through .connecting and the uptime clock isn't reset.
    private var isReconnecting = false

    init() {
        xray.onLog = { [weak self] line in
            Task { @MainActor in self?.appendLog(line) }
        }
        xray.onExit = { [weak self] code in
            Task { @MainActor in
                guard let self else { return }
                // Ignore exits we triggered ourselves (stop/restart).
                guard self.state == .connected || self.state == .connecting else { return }
                if self.autoReconnect, self.activeServer != nil {
                    self.appendLog("[warn] xray exited (code \(code)) — reconnecting\n")
                    self.reconnect()
                } else {
                    self.teardownTransport()
                    self.state = .failed("xray exited (code \(code))")
                    self.stopUptime()
                }
            }
        }
        setupNetworkMonitoring()
    }

    var isConnected: Bool { state == .connected }

    /// Connect to a server. If already connected, switches by restarting only
    /// xray and re-pinning the route — the transport (TUN/proxy) stays up, so a
    /// switch is sub-second and never re-prompts for a password.
    func connect(to server: ProxyConfig, forceTransportRefresh: Bool = false) {
        if let store { applyStore(store) }
        if ConnectionManager.usesProfile(mode: mode, useNativeTun: settings.useNativeTun) {
            connectWithProfile(to: server, forceTransportRefresh: forceTransportRefresh)
        } else {
            connectLegacy(to: server, forceTransportRefresh: forceTransportRefresh)
        }
    }

    /// Whether this setup is built from the full profile.
    ///
    /// `useNativeTun` governs one thing: who owns the tunnel interface. In
    /// system-proxy mode there is no interface to own, so turning the native
    /// inbound off there used to cost the whole outbound graph — every rule
    /// naming a node or a group silently collapsed onto the single proxy
    /// outbound, which is the "send this domain through the WireGuard peer"
    /// that quietly did nothing.
    nonisolated static func usesProfile(mode: TunnelMode, useNativeTun: Bool) -> Bool {
        mode == .systemProxy || useNativeTun
    }

    /// Re-reads the routing out of the store and relaunches the core with it.
    ///
    /// Edited rules otherwise reach the connection on the next connect, which
    /// is correct but reads as "the rule did nothing" while the old graph is
    /// still live.
    func reconnectForRoutingChange() {
        guard isConnected, let store else { return }
        applyStore(store)
        reconnect()
    }

    /// Binds the store and takes a first copy of its settings.
    func bind(_ store: ServerStore) {
        self.store = store
        applyStore(store)
    }

    /// Copies the parts of the store the connection needs. Called on every
    /// connect, so a rule edited in a sheet applies on the next switch.
    func applyStore(_ store: ServerStore) {
        settings = store.settings
        allServers = store.allServers
        subscriptionGroups = store.declaredGroups
        mode = store.settings.mode
        logLevel = store.settings.logLevel
        ports.socks = store.settings.socksPort
        ports.http = store.settings.httpPort
        routingRules = store.settings.effectiveRoutingRules
        notifyOnConnect = store.settings.notifyOnConnect
    }

    /// The single-server path: one core, one outbound, tun2socks in front when
    /// the mode is TUN. Kept for anyone who turns the native inbound off.
    private func connectLegacy(to server: ProxyConfig, forceTransportRefresh: Bool = false) {
        let wasConnected = (state == .connected || state == .connecting)
        let keepTransport = wasConnected && (activeMode == mode) && !forceTransportRefresh

        activeServer = server
        if wasConnected && !keepTransport {
            // Mode actually changed → full teardown.
            teardownTransport()
        }
        activeUsedProfile = false
        xray.stop()

        guard let binary = CoreBinary.locate(for: server.engine) else {
            let missing = server.engine == .singbox ? "sing-box" : "xray"
            let script = server.engine == .singbox ? "fetch-singbox.sh" : "fetch-xray.sh"
            fail("\(missing) binary not found. Run Scripts/\(script)")
            return
        }
        connectStarted = Date()
        state = .connecting
        if !isReconnecting { logs = ""; pendingLog = "" }
        activeServerName = server.name
        let coreName = server.engine == .singbox ? "sing-box" : "xray"
        appendLog("[info] \(keepTransport ? "switching to" : "starting") \(server.name) (\(mode.title), \(coreName))\n")

        do {
            let data: Data
            switch server.engine {
            case .xray:
                data = try XrayConfigBuilder.jsonData(for: server, ports: ports,
                                                      rules: routingRules,
                                                      logLevel: logLevel.rawValue)
            case .singbox:
                data = try SingBoxConfigBuilder.jsonData(for: server, ports: ports,
                                                         rules: routingRules,
                                                         logLevel: logLevel.rawValue)
            }
            // Point the core at the geo .dat dir only when Xray rules reference
            // geosite/geoip (sing-box doesn't use this env).
            let needsGeo = server.engine == .xray && routingRules.contains { rule in
                rule.domains.contains { $0.hasPrefix("geosite:") }
                    || rule.ips.contains { $0.hasPrefix("geoip:") }
            }
            let assetDir = needsGeo ? GeoAssetManager.shared.directory : nil
            try xray.start(configData: data, binary: binary, assetDir: assetDir)
        } catch {
            fail(error.localizedDescription)
            return
        }

        let chosenMode = mode
        let socksAddr = "\(ports.listen):\(ports.socks)"
        let serverHosts = server.allAddresses
        let socksHost = ports.listen
        let socksPort = ports.socks

        // Poll the SOCKS inbound until it accepts connections, then bring up the
        // transport immediately — much faster than a fixed delay.
        Task.detached(priority: .userInitiated) {
            let ready = await ConnectionManager.waitForPort(host: socksHost,
                                                            port: socksPort,
                                                            timeout: 2.0)
            await MainActor.run {
                guard self.state == .connecting else { return }
                guard self.xray.isRunning else { return } // onExit reports failure
                guard ready else {
                    self.xray.stop()
                    self.fail("xray did not start listening")
                    return
                }
                self.bringUpTransport(mode: chosenMode,
                                      socksAddr: socksAddr,
                                      serverHosts: serverHosts,
                                      serverID: server.id,
                                      keepTransport: keepTransport)
            }
        }
    }

    // MARK: - Profile path (sing-box owns the routing)

    /// Builds the whole profile and runs it.
    ///
    /// In TUN mode the helper runs the core as root so it can own the
    /// interface — that is the only arrangement in which a `process_name` rule
    /// can match, because tun2socks would have thrown the PID away before the
    /// core ever saw the connection. In system-proxy mode the same profile runs
    /// as the user behind the local SOCKS/HTTP inbounds.
    private func connectWithProfile(to server: ProxyConfig, forceTransportRefresh: Bool) {
        let wasConnected = (state == .connected || state == .connecting)
        let keepTransport = wasConnected && activeMode == mode
            && activeUsedProfile && !forceTransportRefresh

        activeServer = server
        if wasConnected && !keepTransport { teardownTransport() }

        connectStarted = Date()
        state = .connecting
        if !isReconnecting { logs = ""; pendingLog = "" }
        activeServerName = server.name
        appendLog("[info] \(keepTransport ? "switching to" : "starting") \(server.name) (\(mode.title), sing-box)\n")
        if mode == .tun && !settings.dns.enabled {
            appendLog("[warn] DNS handling is off: names are resolved by the network's own resolver, so domains it blocks stay broken inside the tunnel\n")
        }

        let data: Data
        do {
            data = try renderProfile(for: server)
        } catch {
            fail(error.localizedDescription)
            return
        }

        switch mode {
        case .tun:
            startProfileInHelper(data, serverID: server.id, reusing: keepTransport)
        case .systemProxy:
            startProfileLocally(data, serverID: server.id, reusing: keepTransport)
        }
    }

    /// Renders the configuration for `server`, starting whatever bridge
    /// processes the profile turns out to need.
    private func renderProfile(for server: ProxyConfig) throws -> Data {
        var input = ProfileAssembler.Input()
        // A group's representative is not a node: its id names the group, and
        // appending it would emit a second outbound for the member it borrowed
        // its address from.
        let namesAGroup = subscriptionGroups.contains { $0.id == server.id }
            || settings.serverGroups.contains { $0.id == server.id }
        let known = namesAGroup || allServers.contains { $0.id == server.id }
        input.servers = known ? allServers : allServers + [server]
        input.settings = settings
        input.activeServerID = server.id
        input.ports = ports
        input.includeTun = (mode == .tun)
        input.subscriptionGroups = subscriptionGroups
        input.clashSecret = controlSecret
        // In TUN mode the helper picks the cache path itself — it will not open
        // a filename this side chose.
        input.cacheFilePath = mode == .tun ? "" : ProfileAssembler.userCachePath

        let needBridges = ProfileAssembler.bridgedServers(input)
        if !needBridges.isEmpty {
            appendLog("[info] \(needBridges.count) node(s) need the Xray bridge\n")
        }
        bridges.onLog = { [weak self] line in self?.appendLog(line) }
        input.bridgePorts = bridges.sync(servers: needBridges,
                                         basePort: ports.socks + 1000,
                                         logLevel: settings.logLevel.rawValue)
        return try SingBoxProfileBuilder.jsonData(ProfileAssembler.profile(input))
    }

    /// TUN mode: hand the profile to the privileged helper.
    private func startProfileInHelper(_ data: Data, serverID: UUID, reusing: Bool) {
        Task.detached(priority: .userInitiated) {
            do {
                if reusing {
                    try TunManager.reloadNativeCore(config: data)
                } else {
                    try TunManager.startNativeCore(config: data)
                }
                await MainActor.run {
                    guard self.state == .connecting else { return }
                    self.activeUsedProfile = true
                    self.finishConnect(serverID: serverID, mode: .tun)
                    self.appendLog("[info] tunnel up (sing-box owns the interface)\n")
                    self.startCoreLogPump()
                }
            } catch {
                let tail = TunManager.nativeCoreStatus.log
                await MainActor.run {
                    self.bridges.stopAll()
                    if let tail, !tail.isEmpty { self.appendLog("[core] \(tail)\n") }
                    self.fail(error.localizedDescription)
                }
            }
        }
    }

    /// System-proxy mode: run the same profile as the user and point the
    /// system's proxy settings at its inbounds.
    private func startProfileLocally(_ data: Data, serverID: UUID, reusing: Bool) {
        guard let binary = CoreBinary.locate(for: .singbox) else {
            fail("sing-box binary not found. Run Scripts/fetch-singbox.sh")
            return
        }
        // This core logs to the app directly, so the helper's log is no longer
        // the one to watch.
        stopCoreLogPump()
        xray.stop()
        do {
            try xray.start(configData: data, binary: binary)
        } catch {
            fail(error.localizedDescription)
            return
        }
        activeUsedProfile = true

        let socksHost = ports.listen
        let socksPort = ports.socks
        Task.detached(priority: .userInitiated) {
            let ready = await ConnectionManager.waitForPort(host: socksHost,
                                                            port: socksPort,
                                                            timeout: 3.0)
            await MainActor.run {
                guard self.state == .connecting else { return }
                guard self.xray.isRunning else { return }   // onExit reports why
                guard ready else {
                    self.xray.stop()
                    self.bridges.stopAll()
                    self.fail("the core did not start listening")
                    return
                }
                if reusing {
                    self.finishConnect(serverID: serverID, mode: .systemProxy)
                    return
                }
                let socks = self.ports.socks
                let http = self.ports.http
                Task.detached(priority: .userInitiated) {
                    let ok = SystemProxy.enable(socksPort: socks, httpPort: http)
                    await MainActor.run {
                        guard self.state == .connecting else { return }
                        if ok {
                            self.finishConnect(serverID: serverID, mode: .systemProxy)
                            self.appendLog("[info] system proxy enabled\n")
                        } else {
                            self.xray.stop()
                            self.bridges.stopAll()
                            self.fail("could not set system proxy")
                        }
                    }
                }
            }
        }
    }

    /// Polls a TCP port until connectable or the timeout elapses.
    private nonisolated static func waitForPort(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await PingTester.tcpLatency(host: host, port: port, timeout: 0.25) != nil {
                return true
            }
            try? await Task.sleep(nanoseconds: 25_000_000) // 25ms
        }
        return false
    }

    private func bringUpTransport(mode: TunnelMode, socksAddr: String,
                                  serverHosts: [String], serverID: UUID,
                                  keepTransport: Bool) {
        switch mode {
        case .systemProxy:
            // The system proxy points at the same SOCKS port, so when we're just
            // switching servers it's already active — nothing to do.
            if keepTransport {
                finishConnect(serverID: serverID, mode: mode)
                return
            }
            // Six `networksetup` calls, each one a subprocess: off the main
            // thread so the window keeps drawing while they run.
            let socks = ports.socks
            let http = ports.http
            Task.detached(priority: .userInitiated) {
                let ok = SystemProxy.enable(socksPort: socks, httpPort: http)
                await MainActor.run {
                    guard self.state == .connecting else { return }
                    if ok {
                        self.finishConnect(serverID: serverID, mode: mode)
                        self.appendLog("[info] system proxy enabled\n")
                    } else {
                        self.xray.stop()
                        self.fail("could not set system proxy")
                    }
                }
            }
        case .tun:
            // tun2socks keeps running across switches; the helper's fast path just
            // re-pins the new server IP(s) (sub-second, no utun re-create).
            // For a balancer group we pin every node so the tunnel never loops.
            Task.detached(priority: .userInitiated) {
                let ips = Set(serverHosts.flatMap { TunManager.resolveIPs(host: $0) })
                do {
                    try TunManager.up(socksAddr: socksAddr, serverIPs: Array(ips))
                    await MainActor.run {
                        self.finishConnect(serverID: serverID, mode: mode)
                        self.appendLog("[info] TUN \(keepTransport ? "re-pinned" : "up") (\(ips.joined(separator: ", ")))")
                    }
                } catch {
                    await MainActor.run {
                        self.xray.stop()
                        self.fail(error.localizedDescription)
                    }
                }
            }
        }
    }

    private func finishConnect(serverID: UUID, mode: TunnelMode) {
        if let started = connectStarted {
            appendLog(String(format: "[info] ready in %.1fs\n",
                             Date().timeIntervalSince(started)))
            connectStarted = nil
        }
        let wasReconnecting = isReconnecting
        activeServerID = serverID
        activeMode = mode
        state = .connected
        isReconnecting = false
        if connectedSince == nil { startUptime() }
        startWatchdog()
        if notifyOnConnect {
            NotificationManager.notify(
                title: wasReconnecting ? "Reconnected" : "Connected",
                body: activeServerName)
        }
    }

    func disconnect() {
        networkRecoveryTask?.cancel()
        networkRecoveryTask = nil
        let wasConnected = (state == .connected)
        let name = activeServerName
        stopWatchdog()
        stopCoreLogPump()
        activeServer = nil
        teardownTransport()
        xray.stop()
        activeUsedProfile = false
        activeServerID = nil
        state = .disconnected
        stopUptime()
        appendLog("[info] disconnected\n")
        if notifyOnConnect && wasConnected {
            NotificationManager.notify(title: "Disconnected", body: name)
        }
    }

    private func teardownTransport() {
        switch activeMode {
        case .systemProxy:
            SystemProxy.disable()
        case .tun:
            // The two TUN transports own the interface in different ways, so
            // undoing the wrong one would leave the machine without a route.
            if activeUsedProfile {
                TunManager.stopNativeCore()
            } else {
                TunManager.down()
            }
        }
        bridges.stopAll()
    }

    private func fail(_ message: String) {
        stopCoreLogPump()
        isReconnecting = false
        state = .failed(message)
        appendLog("[error] \(message)\n")
        stopUptime()
    }

    // MARK: - Watchdog / auto-reconnect

    /// Restarts the tunnel for the active server without tearing down the
    /// transport or resetting the uptime clock. Used by the watchdog and by the
    /// xray.onExit handler when the link dies unexpectedly.
    private func reconnect(forceTransportRefresh: Bool = false) {
        guard let server = activeServer else { return }
        isReconnecting = true
        // connect() keeps the transport up when the mode is unchanged, so this
        // just relaunches xray and re-pins the route — sub-second, no prompts.
        connect(to: server, forceTransportRefresh: forceTransportRefresh)
    }

    /// Periodically probes end-to-end connectivity through the SOCKS proxy and
    /// silently reconnects if the link has gone dead (e.g. NAT idle timeout,
    /// where xray stays alive but no traffic flows).
    private func startWatchdog() {
        watchdogTask?.cancel()
        guard autoReconnect else { return }
        let host = ports.listen
        let socksPort = ports.socks
        watchdogTask = Task { [weak self] in
            // Number of consecutive failed probes before forcing a reconnect.
            let maxFailures = 2
            var failures = 0
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30s
                if Task.isCancelled { return }
                guard let self else { return }
                // Only probe while we believe we're connected and idle.
                let busy = await MainActor.run { self.state != .connected || self.isReconnecting }
                if busy { failures = 0; continue }

                let alive = await HealthProbe.throughSocks(host: host, port: socksPort)
                if alive {
                    failures = 0
                    continue
                }
                failures += 1
                if failures >= maxFailures {
                    failures = 0
                    await MainActor.run {
                        guard self.state == .connected, !self.isReconnecting else { return }
                        self.appendLog("[warn] health check failed — reconnecting\n")
                        self.reconnect()
                    }
                }
            }
        }
    }

    private func stopWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = nil
    }

    // MARK: - Core log (TUN mode)

    /// Mirrors the routing core's log into the app's log window.
    ///
    /// In system-proxy mode the core is a child of this process and its output
    /// is piped straight into the log. In TUN mode it is the helper's child and
    /// writes to a root-owned file the app cannot open, so the only thing the
    /// window ever showed was the Xray bridge — a core that came up and then
    /// misbehaved left no trace at all, and "it just does not work" was the
    /// whole of the available evidence. The helper hands out the tail over XPC;
    /// this polls it and prints what is new.
    private func startCoreLogPump() {
        // A server switch restarts the core but keeps the same log; leaving the
        // existing pump alone is what stops the last few lines being reprinted.
        guard coreLogTask == nil else { return }
        coreLogTask = Task { [weak self] in
            while !Task.isCancelled {
                let tail = await Task.detached(priority: .utility) {
                    TunManager.nativeCoreStatus.log
                }.value
                if Task.isCancelled { return }
                await MainActor.run {
                    guard let self, self.activeMode == .tun else { return }
                    if let tail { self.emitCoreLog(tail) }
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func stopCoreLogPump() {
        coreLogTask?.cancel()
        coreLogTask = nil
        coreLogSeen = ""
    }

    /// Prints the lines of `tail` that have not been printed yet.
    private func emitCoreLog(_ tail: String) {
        let lines = tail.split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)
        guard !lines.isEmpty else { return }
        // The tail is a fixed number of trailing lines, so consecutive reads
        // overlap. Resume after the last line already shown; when it has fallen
        // out of the window entirely, everything in hand is new.
        let start = coreLogSeen.isEmpty ? 0
            : (lines.lastIndex(of: coreLogSeen).map { $0 + 1 } ?? 0)
        guard start < lines.count else { return }
        for line in lines[start...] { appendLog("[core] \(line)\n") }
        coreLogSeen = lines[lines.count - 1]
    }

    // MARK: - Uptime

    private func startUptime() {
        connectedSince = Date()
        uptimeText = "00:00"
        uptimeTimer?.invalidate()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickUptime() }
        }
        RunLoop.main.add(timer, forMode: .common)
        uptimeTimer = timer
    }

    private func tickUptime() {
        guard let since = connectedSince else { return }
        let s = Int(Date().timeIntervalSince(since))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        uptimeText = h > 0
            ? String(format: "%d:%02d:%02d", h, m, sec)
            : String(format: "%02d:%02d", m, sec)
    }

    private func stopUptime() {
        uptimeTimer?.invalidate()
        uptimeTimer = nil
        connectedSince = nil
        uptimeText = ""
    }

    // MARK: - Sleep / network recovery

    private func setupNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let satisfied = (path.status == .satisfied)
            // The default route may now run over a different interface, so the
            // cached network-service name is no longer trustworthy.
            SystemProxy.invalidateServiceCache()
            Task { @MainActor in
                self?.handleNetworkChange(satisfied: satisfied)
            }
        }
        let queue = DispatchQueue(label: "xray.network")
        monitor.start(queue: queue)
        networkMonitor = monitor

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleWillSleep()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleDidWake()
            }
        }
    }

    private func handleNetworkChange(satisfied: Bool) {
        let wasSatisfied = isNetworkSatisfied
        isNetworkSatisfied = satisfied
        if satisfied {
            if state == .connected { startWatchdog() }
            if !wasSatisfied && activeServer != nil && !isSleeping {
                appendLog("[info] network connectivity restored\n")
                scheduleRecovery(forceTransportRefresh: true, reason: "network restored", delay: 1.0)
            }
        } else if !isSleeping {
            stopWatchdog()
            appendLog("[info] network connectivity lost\n")
        }
    }

    private func handleWillSleep() {
        isSleeping = true
        stopWatchdog()
        appendLog("[info] system going to sleep\n")
    }

    private func handleDidWake() {
        isSleeping = false
        appendLog("[info] system woke up\n")
        scheduleRecovery(forceTransportRefresh: true, reason: "wake", delay: 2.0)
    }

    private func scheduleRecovery(forceTransportRefresh: Bool, reason: String, delay: TimeInterval) {
        networkRecoveryTask?.cancel()
        networkRecoveryTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self else { return }
                self.performRecovery(forceTransportRefresh: forceTransportRefresh, reason: reason)
            }
        }
    }

    private func performRecovery(forceTransportRefresh: Bool, reason: String) {
        guard autoReconnect, activeServer != nil else { return }
        guard state != .connecting else { return }

        // Core died while we were asleep/offline: do a full reconnect. Which
        // process to ask about depends on who is running the core — in TUN mode
        // with the native inbound it belongs to the helper, and `xray` here is
        // idle by design.
        if !coreIsRunning {
            appendLog("[warn] core not running after \(reason) — reconnecting\n")
            reconnect(forceTransportRefresh: forceTransportRefresh)
            return
        }

        // Core is alive. Re-apply transport in case the primary interface changed.
        if forceTransportRefresh {
            refreshTransport(reason: reason)
        }

        // Verify the tunnel actually works; if not, restart the core.
        let host = ports.listen
        let port = ports.socks
        Task.detached(priority: .userInitiated) { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard let self else { return }
            let alive = await HealthProbe.throughSocks(host: host, port: port, timeout: 5.0)
            await MainActor.run {
                guard self.state == .connected, !self.isReconnecting else { return }
                if !alive {
                    self.appendLog("[warn] health check failed after \(reason) — reconnecting\n")
                    self.reconnect(forceTransportRefresh: forceTransportRefresh)
                }
            }
        }
    }

    /// Whether the core carrying the active connection is alive.
    private var coreIsRunning: Bool {
        if activeUsedProfile && activeMode == .tun {
            return TunManager.nativeCoreStatus.running
        }
        return xray.isRunning
    }

    private func refreshTransport(reason: String) {
        guard let server = activeServer else { return }
        let listen = ports.listen
        let socks = ports.socks
        // The native core installs its own routes and re-detects the interface
        // itself; re-pinning is a tun2socks concern and there is nothing to
        // re-apply here.
        if activeUsedProfile && activeMode == .tun {
            appendLog("[info] core keeps its own routes after \(reason)\n")
            return
        }
        switch activeMode {
        case .systemProxy:
            let ok = SystemProxy.enable(socksPort: socks, httpPort: ports.http)
            appendLog(ok ? "[info] system proxy re-applied after \(reason)\n"
                        : "[error] could not re-apply system proxy after \(reason)\n")
        case .tun:
            let socksAddr = "\(listen):\(socks)"
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                let ips = Set(server.allAddresses.flatMap { TunManager.resolveIPs(host: $0) })
                do {
                    try TunManager.up(socksAddr: socksAddr, serverIPs: Array(ips))
                    await MainActor.run {
                        self.appendLog("[info] TUN re-pinned after \(reason)\n")
                    }
                } catch {
                    await MainActor.run {
                        self.appendLog("[error] TUN re-pin failed after \(reason): \(error.localizedDescription)\n")
                    }
                }
            }
        }
    }

    // MARK: - Logs

    /// Clears the in-memory log buffer (does not affect the running core).
    func clearLogs() { logs = "" }

    /// Appends a line to the log the UI shows. Anything that runs alongside
    /// the tunnel — the bridges, the control API — reports through here, so
    /// there is one place to look when something misbehaves.
    func appendLog(_ text: String) {
        // A misbehaving core can emit thousands of lines a second. Appending
        // each one straight to `logs` republishes the view that many times and
        // wedges the UI, so lines are collected and flushed five times a
        // second, and a burst is summarised rather than kept.
        pendingLog += ConnectionManager.withoutANSI(text)
        if pendingLog.count > 64_000 {
            let dropped = pendingLog.count - 32_000
            pendingLog = "[warn] \(dropped) characters of core output dropped\n"
                + String(pendingLog.suffix(32_000))
        }
        guard logFlushTask == nil else { return }
        logFlushTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 200_000_000)
            self?.flushLog()
        }
    }

    /// Moves whatever the cores printed since the last flush into `logs`.
    /// The same text with terminal colour codes removed.
    ///
    /// sing-box colours its output whether or not anything is attached to a
    /// terminal, and it has no option to stop — the log window is not a
    /// terminal, so the escapes arrive as `[31m` littered through every line.
    nonisolated static func withoutANSI(_ text: String) -> String {
        guard text.contains("\u{1B}") else { return text }
        var out = ""
        out.reserveCapacity(text.count)
        var rest = Substring(text)
        while let escape = rest.firstIndex(of: "\u{1B}") {
            out += rest[rest.startIndex..<escape]
            rest = rest[rest.index(after: escape)...]
            guard rest.first == "[" else { continue }
            // CSI: parameter bytes, then one final byte in @ through ~.
            guard let final = rest.dropFirst().firstIndex(where: {
                ("\u{40}"..."\u{7E}").contains($0)
            }) else { return out + rest }
            rest = rest[rest.index(after: final)...]
        }
        return out + rest
    }

    private func flushLog() {
        logFlushTask = nil
        guard !pendingLog.isEmpty else { return }
        logs += pendingLog
        pendingLog = ""
        if logs.count > 20_000 {
            logs = String(logs.suffix(16_000))
        }
    }
}
#endif

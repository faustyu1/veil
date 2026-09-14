import Foundation

/// Names and paths shared by the app and the privileged helper.
public enum VeilHelperInfo {

    /// Mach service the daemon advertises and the app connects to.
    public static let machServiceName = "dev.local.veil.helper"

    /// Bumped whenever the protocol changes. The app refuses to talk to a
    /// helper that does not match and asks the user to reinstall it.
    public static let protocolVersion = 5

    /// Root-owned directory holding the helper, `tun2socks`, the pinned client
    /// requirement and the tunnel state. Nothing here is writable by the user,
    /// and nothing lives in `/tmp` where another process could pre-create it.
    public static let installDirectory = "/Library/Application Support/Veil/helper"

    /// Code-signing requirement the connecting app must satisfy. Written by the
    /// installer; if it is missing the helper accepts nobody.
    public static var clientRequirementPath: String {
        installDirectory + "/client.requirement"
    }

    public static var tun2socksPath: String { installDirectory + "/tun2socks" }
    public static var statePath: String { installDirectory + "/tunnel-state.json" }
    public static var logPath: String { installDirectory + "/tun2socks.log" }

    /// LaunchDaemon plist installed by `Scripts/install-daemon.sh`.
    public static var launchDaemonPath: String {
        "/Library/LaunchDaemons/\(machServiceName).plist"
    }
}

/// What the helper is allowed to do, spelled out.
///
/// The old design handed root a shell script plus a string; this one takes
/// nothing but validated values. There is no argument that names a binary, a
/// path or a command, so there is nothing for a caller to redirect.
@objc public protocol VeilHelperProtocol {

    /// Protocol version the installed helper implements.
    func helperVersion(reply: @escaping (Int) -> Void)

    /// Brings the tunnel up: starts `tun2socks` against the app's local SOCKS
    /// port, pins the VPN server addresses to the physical gateway, installs
    /// the split-default routes and points DNS at the tunnel.
    /// Replies with nil on success or a message on failure.
    func startTunnel(socksHost: String,
                     socksPort: Int,
                     serverIPs: [String],
                     dnsServers: [String],
                     strictKillSwitch: Bool,
                     protectIPv6: Bool,
                     reply: @escaping (String?) -> Void)

    /// Tears everything down and restores the DNS the user had.
    func stopTunnel(reply: @escaping (String?) -> Void)

    /// Re-pins server addresses without restarting the tunnel — this is what
    /// makes switching servers sub-second.
    func pinServerIPs(_ ips: [String], reply: @escaping (String?) -> Void)

    /// Temporarily routes addresses around the tunnel so latency probes measure
    /// the server rather than the tunnel.
    func addProbeRoutes(_ ips: [String], reply: @escaping (String?) -> Void)

    /// Removes the probe routes added above.
    func removeProbeRoutes(reply: @escaping (String?) -> Void)

    /// Whether a tunnel is currently up, and the device it is on.
    func tunnelStatus(reply: @escaping (Bool, String?, Bool, Bool) -> Void)
}

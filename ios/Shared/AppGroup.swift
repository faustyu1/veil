import Foundation

/// Every path the app and the tunnel extension both need.
///
/// A NetworkExtension runs in its own process with its own container, so the
/// only way the two sides can exchange the config, the geo databases and the
/// core log is through the shared app group container.
enum AppGroup {

    /// Must match the App Groups entitlement on both targets.
    static let identifier = "group.dev.local.veil"

    /// Bundle identifier of the packet tunnel provider extension.
    static let tunnelBundleIdentifier = "dev.local.veil.tunnel"

    /// Root of the shared container. Falls back to the process-local caches
    /// directory when the app group is unavailable (unsigned local builds), so
    /// nothing crashes — the tunnel simply won't have anything to read.
    static let containerURL: URL = {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)
            ?? FileManager.default.temporaryDirectory
    }()

    /// Where `ServerStore` keeps store.json.
    static let supportDirectory: URL = ensure(containerURL.appendingPathComponent("Veil",
                                                                                 isDirectory: true))

    /// geoip.dat / geosite.dat, downloaded by the app, read by the core.
    static let geoDirectory: URL = ensure(supportDirectory.appendingPathComponent("geo",
                                                                                  isDirectory: true))

    /// The generated Xray configuration the tunnel provider boots from.
    static let configURL = supportDirectory.appendingPathComponent("xray-config.json")

    /// Sidecar describing the session the config belongs to (server name, MTU…).
    static let sessionURL = supportDirectory.appendingPathComponent("session.json")

    /// Xray writes its error log here; the app tails it for the log screen.
    static let logURL = supportDirectory.appendingPathComponent("xray.log")

    /// Why the tunnel last refused to come up. The provider process is already
    /// gone by the time the app notices the failed connection, so it leaves the
    /// reason here on its way out.
    static let lastErrorURL = supportDirectory.appendingPathComponent("last-error.txt")

    private static func ensure(_ url: URL) -> URL {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}

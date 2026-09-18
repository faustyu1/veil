import Foundation
import VeilHelperKit

/// What the helper changed on the system, written to a root-owned file so a
/// crashed or force-quit helper can still put everything back.
///
/// The old design kept this in `/tmp/xrayclient-tun.state`, which any process
/// on the machine could read — or pre-create, to feed the teardown script
/// addresses of its choosing.
struct TunnelState: Codable {
    var device: String
    var originalGateway: String
    var originalInterface: String
    var pinnedIPs: [String] = []
    var probeIPs: [String] = []
    /// Resolvers each network service had before the tunnel touched it.
    var savedDNS: [String: [String]] = [:]
    var tun2socksPID: Int32?
    /// PID of the routing core when the helper runs it directly (native TUN).
    /// Mutually exclusive with `tun2socksPID` — the two are different ways of
    /// owning the same interface.
    var corePID: Int32?

    static var fileURL: URL { URL(fileURLWithPath: VeilHelperInfo.statePath) }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        let path = Self.fileURL.path
        let fm = FileManager.default
        if fm.fileExists(atPath: path) {
            try? data.write(to: Self.fileURL, options: [.atomic])
        } else {
            fm.createFile(atPath: path, contents: data,
                          attributes: [.posixPermissions: 0o600])
        }
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: path)
    }

    static func load() -> TunnelState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(TunnelState.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}

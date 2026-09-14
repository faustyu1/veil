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
    var originalIPv6Gateway: String?
    var originalIPv6Interface: String?
    var pinnedIPs: [String] = []
    var probeIPs: [String] = []
    /// Resolvers each network service had before the tunnel touched it.
    var savedDNS: [String: [String]] = [:]
    var tun2socksPID: Int32?
    var strictKillSwitch: Bool = false
    var protectsIPv6: Bool = false
    var pfEnableToken: String?

    enum CodingKeys: String, CodingKey {
        case device, originalGateway, originalInterface
        case originalIPv6Gateway, originalIPv6Interface
        case pinnedIPs, probeIPs, savedDNS, tun2socksPID
        case strictKillSwitch, protectsIPv6, pfEnableToken
    }

    init(device: String, originalGateway: String, originalInterface: String,
         originalIPv6Gateway: String? = nil, originalIPv6Interface: String? = nil,
         strictKillSwitch: Bool = false, protectsIPv6: Bool = false) {
        self.device = device
        self.originalGateway = originalGateway
        self.originalInterface = originalInterface
        self.originalIPv6Gateway = originalIPv6Gateway
        self.originalIPv6Interface = originalIPv6Interface
        self.strictKillSwitch = strictKillSwitch
        self.protectsIPv6 = protectsIPv6
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        device = try c.decode(String.self, forKey: .device)
        originalGateway = try c.decode(String.self, forKey: .originalGateway)
        originalInterface = try c.decode(String.self, forKey: .originalInterface)
        originalIPv6Gateway = try c.decodeIfPresent(String.self, forKey: .originalIPv6Gateway)
        originalIPv6Interface = try c.decodeIfPresent(String.self, forKey: .originalIPv6Interface)
        pinnedIPs = try c.decodeIfPresent([String].self, forKey: .pinnedIPs) ?? []
        probeIPs = try c.decodeIfPresent([String].self, forKey: .probeIPs) ?? []
        savedDNS = try c.decodeIfPresent([String: [String]].self, forKey: .savedDNS) ?? [:]
        tun2socksPID = try c.decodeIfPresent(Int32.self, forKey: .tun2socksPID)
        strictKillSwitch = try c.decodeIfPresent(Bool.self, forKey: .strictKillSwitch) ?? false
        protectsIPv6 = try c.decodeIfPresent(Bool.self, forKey: .protectsIPv6) ?? false
        pfEnableToken = try c.decodeIfPresent(String.self, forKey: .pfEnableToken)
    }

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

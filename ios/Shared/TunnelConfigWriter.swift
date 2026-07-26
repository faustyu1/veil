import Foundation

/// Renders a `ProxyConfig` into the Xray configuration the tunnel provider
/// boots from, and drops it in the shared container.
///
/// The iOS config differs from the desktop one in exactly one place: instead of
/// local SOCKS/HTTP inbounds it uses Xray's native layer-3 `tun` inbound, which
/// reads the descriptor NetworkExtension handed us. Outbounds, transports,
/// Reality, XHTTP and the routing rules are the same code path as macOS.
enum TunnelConfigWriter {

    enum WriteError: LocalizedError {
        case unsupportedProtocol(ProxyProtocol)

        var errorDescription: String? {
            switch self {
            case .unsupportedProtocol(let proto):
                return "\(proto.rawValue.uppercased()) needs the sing-box core, "
                     + "which the iOS build does not ship. Use a VLESS, VMess, "
                     + "Trojan, Shadowsocks or WireGuard server."
            }
        }
    }

    /// Builds the config + session sidecar and writes both to the app group.
    @discardableResult
    static func write(server: ProxyConfig, settings: AppSettings) throws -> TunnelSession {
        guard server.xraySupported else {
            throw WriteError.unsupportedProtocol(server.proto)
        }

        let session = TunnelSession(
            serverName: server.name,
            serverAddress: server.address,
            mtu: settings.tunnelMTU,
            ipv6Enabled: settings.ipv6Enabled,
            dnsServers: settings.effectiveDNSServers,
            maxMemoryMB: 48
        )

        let json = try XrayConfigBuilder.jsonString(
            for: server,
            // On iOS the name is unused: Xray takes the descriptor from the
            // `xray.tun.fd` environment flag instead of opening an interface
            // itself. It still has to be a well-formed `utunN` so the very same
            // config can be validated with a desktop `xray run -test`.
            inbound: .tun(name: "utun9", mtu: session.mtu),
            rules: settings.effectiveRoutingRules,
            logLevel: settings.logLevel.rawValue,
            logFile: AppGroup.logURL.path,
            dnsServers: session.dnsServers,
            stats: true
        )

        try Data(json.utf8).write(to: AppGroup.configURL, options: .atomic)
        try session.write()
        return session
    }

    /// Reads back the config the extension should boot.
    static func loadConfig() throws -> String {
        let data = try Data(contentsOf: AppGroup.configURL)
        return String(decoding: data, as: UTF8.self)
    }
}

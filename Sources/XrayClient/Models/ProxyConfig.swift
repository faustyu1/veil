import Foundation

/// Supported proxy protocols, mirroring what Xray-core can handle.
enum ProxyProtocol: String, Codable, CaseIterable {
    case vless
    case vmess
    case trojan
    case shadowsocks = "ss"
}

/// Transport-layer network used by the outbound stream.
enum TransportNetwork: String, Codable {
    case tcp
    case ws
    case grpc
    case http
    case kcp
    case quic
}

/// Security applied on top of the transport.
enum StreamSecurity: String, Codable {
    case none
    case tls
    case reality
}

/// A single proxy server entry. This is the canonical representation parsed from
/// share links / subscriptions and later compiled into an Xray-core config.
struct ProxyConfig: Codable, Identifiable, Equatable {
    var id: UUID = UUID()

    // Display
    var name: String

    // Core connection
    var proto: ProxyProtocol
    var address: String
    var port: Int

    // Auth / identity
    var uuid: String?          // vless / vmess user id
    var password: String?      // trojan password / shadowsocks password
    var method: String?        // shadowsocks cipher (e.g. aes-256-gcm)
    var alterId: Int?          // vmess legacy alterId
    var flow: String?          // vless flow, e.g. xtls-rprx-vision
    var encryption: String?    // vless encryption (usually "none")

    // Transport
    var network: TransportNetwork = .tcp
    var security: StreamSecurity = .none

    // TLS / Reality
    var sni: String?
    var alpn: [String]?
    var fingerprint: String?   // utls fingerprint, e.g. chrome
    var allowInsecure: Bool = false
    var publicKey: String?     // reality
    var shortId: String?       // reality
    var spiderX: String?       // reality

    // ws / http / grpc specifics
    var path: String?
    var host: String?          // ws/http Host header
    var serviceName: String?   // grpc

    init(
        name: String,
        proto: ProxyProtocol,
        address: String,
        port: Int
    ) {
        self.name = name
        self.proto = proto
        self.address = address
        self.port = port
    }
}

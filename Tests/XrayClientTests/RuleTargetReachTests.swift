import XCTest
@testable import XrayClient

/// Whether a rule that names a specific node actually sends traffic there.
///
/// "This domain through the WireGuard peer" is the thing routing is for, and it
/// is also the thing that fails silently: the rule is stored, the UI shows it,
/// and the traffic goes out of the default outbound because the node it names
/// was never built into the configuration.
final class RuleTargetReachTests: XCTestCase {

    func testARuleNamingAWireGuardPeerBuildsThatPeer() throws {
        let active = vless("NL-01")
        let peer = wireguard("Home")
        var profile = SingBoxProfile()
        profile.servers = [active, peer]
        profile.defaultTarget = .server(active.id)
        var rule = RoutingRule()
        rule.domains = ["office.example"]
        rule.target = .server(peer.id)
        profile.rules = [rule]

        let built = SingBoxProfileBuilder.build(profile)
        let endpointTags = ((built["endpoints"] as? [[String: Any]]) ?? [])
            .compactMap { $0["tag"] as? String }
        let rules = ((built["route"] as? [String: Any])?["rules"] as? [[String: Any]]) ?? []
        let targeted = rules.compactMap { $0["outbound"] as? String }

        XCTAssertTrue(endpointTags.contains(ProfileTags.server(peer.id)),
                      "the peer the rule names is not in the configuration")
        XCTAssertTrue(targeted.contains(ProfileTags.server(peer.id)),
                      "the rule does not send anything to the peer")
    }

    func testTheSameProfileIsAcceptedByTheRealCore() async throws {
        try XCTSkipUnless(CoreBinary.locate(for: .singbox) != nil,
                          "sing-box is not fetched in this checkout")
        let active = vless("NL-01")
        let peer = wireguard("Home")
        var profile = SingBoxProfile()
        profile.servers = [active, peer]
        profile.defaultTarget = .server(active.id)
        var rule = RoutingRule()
        rule.domains = ["office.example"]
        rule.target = .server(peer.id)
        profile.rules = [rule]

        let data = try SingBoxProfileBuilder.jsonData(profile)
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-reach-\(UUID().uuidString).json")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let process = Process()
        process.executableURL = CoreBinary.locate(for: .singbox)!
        process.arguments = ["check", "-c", file.path]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let output = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()

        XCTAssertEqual(process.terminationStatus, 0,
                       String(data: output, encoding: .utf8) ?? "")
    }

    // MARK: - Helpers

    private func vless(_ name: String) -> ProxyConfig {
        var node = ProxyConfig(name: name, proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = UUID().uuidString
        node.security = .tls
        node.sni = "example.com"
        return node
    }

    private func wireguard(_ name: String) -> ProxyConfig {
        var node = ProxyConfig(name: name, proto: .wireguard, address: "5.6.7.8", port: 51820)
        node.privateKey = "SL1yR4sCSlTfAkFLAo0T0LOQkpCVQ0kSKXJ3Zm1IeVk="
        node.peerPublicKey = "1J0kRXNnaUdRb3BWWkR0QlhzUGxKc2JFaGZ0VnZBUT0="
        node.localAddresses = ["10.0.0.2/32"]
        return node
    }
}

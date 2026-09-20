import XCTest
@testable import XrayClient

/// A node can be looked at, and edited, in whichever form suits it: the share
/// link it arrived as, the outbound its core will actually run, or — for
/// WireGuard — the `wg-quick` file every other client uses. Whatever is edited
/// has to come back as the same node.
final class NodeRepresentationTests: XCTestCase {

    // MARK: - Which forms a node has

    func testWireGuardIsTheOnlyNodeWithAConfFile() {
        XCTAssertEqual(NodeRepresentation.kinds(for: wireguard()), [.wireguard, .json, .link])
        XCTAssertEqual(NodeRepresentation.kinds(for: vless()), [.json, .link])
    }

    // MARK: - Round trips

    func testAShareLinkSurvivesAnEditThatChangesNothing() throws {
        let node = vless()
        let text = NodeRepresentation.text(.link, for: node)
        let parsed = try NodeRepresentation.parse(.link, text: text, keeping: node)

        XCTAssertEqual(parsed.address, node.address)
        XCTAssertEqual(parsed.port, node.port)
        XCTAssertEqual(parsed.uuid, node.uuid)
        XCTAssertEqual(parsed.id, node.id, "editing a node does not make it a different node")
    }

    func testTheOutboundJSONSurvivesAnEditThatChangesNothing() throws {
        let node = vless()
        let text = NodeRepresentation.text(.json, for: node)
        XCTAssertTrue(text.contains("\"type\" : \"vless\"") || text.contains("\"type\": \"vless\""),
                      "the JSON shown is the outbound sing-box will run")

        let parsed = try NodeRepresentation.parse(.json, text: text, keeping: node)
        XCTAssertEqual(parsed.address, node.address)
        XCTAssertEqual(parsed.uuid, node.uuid)
    }

    func testAWireGuardConfSurvivesAnEditThatChangesNothing() throws {
        let node = wireguard()
        let text = NodeRepresentation.text(.wireguard, for: node)
        XCTAssertTrue(text.contains("[Interface]"))
        XCTAssertTrue(text.contains("[Peer]"))

        let parsed = try NodeRepresentation.parse(.wireguard, text: text, keeping: node)
        XCTAssertEqual(parsed.address, node.address)
        XCTAssertEqual(parsed.port, node.port)
        XCTAssertEqual(parsed.privateKey, node.privateKey)
        XCTAssertEqual(parsed.peerPublicKey, node.peerPublicKey)
        XCTAssertEqual(parsed.localAddresses, node.localAddresses)
        XCTAssertEqual(parsed.allowedIPs, ["0.0.0.0/0", "::/0"])
    }

    /// The editor used to write `AllowedIPs = 0.0.0.0/0, ::/0` no matter what
    /// the node said, so narrowing a peer to one private network was undone
    /// the moment its config was opened.
    func testAWireGuardConfShowsAndKeepsItsOwnAllowedIPs() throws {
        var node = wireguard()
        node.allowedIPs = ["172.16.4.0/24"]

        let text = NodeRepresentation.text(.wireguard, for: node)
        XCTAssertTrue(text.contains("AllowedIPs = 172.16.4.0/24"), text)

        let parsed = try NodeRepresentation.parse(.wireguard, text: text, keeping: node)
        XCTAssertEqual(parsed.allowedIPs, ["172.16.4.0/24"])
    }

    func testTheOutboundJSONCarriesAllowedIPsBothWays() throws {
        var node = wireguard()
        node.allowedIPs = ["172.16.4.0/24"]

        let text = NodeRepresentation.text(.json, for: node)
        XCTAssertTrue(text.contains("172.16.4.0/24"), text)

        let parsed = try NodeRepresentation.parse(.json, text: text, keeping: node)
        XCTAssertEqual(parsed.allowedIPs, ["172.16.4.0/24"])
    }

    func testEditingAllowedIPsReachesTheOutbound() throws {
        let node = wireguard()
        let text = NodeRepresentation.text(.wireguard, for: node)
            .replacingOccurrences(of: "AllowedIPs = 0.0.0.0/0, ::/0",
                                  with: "AllowedIPs = 172.16.4.0/24")

        let parsed = try NodeRepresentation.parse(.wireguard, text: text, keeping: node)
        let endpoint = SingBoxOutbound.endpoint(parsed, tag: "wg")
        let peer = (endpoint["peers"] as! [[String: Any]])[0]
        XCTAssertEqual(peer["allowed_ips"] as? [String], ["172.16.4.0/24"])
    }

    func testAnEditIsWhatTakesEffect() throws {
        let node = vless()
        let text = NodeRepresentation.text(.link, for: node)
            .replacingOccurrences(of: "1.2.3.4", with: "5.6.7.8")

        let parsed = try NodeRepresentation.parse(.link, text: text, keeping: node)

        XCTAssertEqual(parsed.address, "5.6.7.8")
    }

    // MARK: - What a mistake looks like

    func testNonsenseIsRefusedWithSomethingToRead() {
        XCTAssertThrowsError(try NodeRepresentation.parse(.link, text: "not a link",
                                                          keeping: vless())) { error in
            XCTAssertFalse((error as? LocalizedError)?.errorDescription?.isEmpty ?? true)
        }
        XCTAssertThrowsError(try NodeRepresentation.parse(.json, text: "{",
                                                          keeping: vless()))
        XCTAssertThrowsError(try NodeRepresentation.parse(.wireguard, text: "[Interface]",
                                                          keeping: wireguard()))
    }

    func testJSONThatDescribesNoNodeIsRefused() {
        XCTAssertThrowsError(try NodeRepresentation.parse(.json,
                                                          text: #"{"type":"direct"}"#,
                                                          keeping: vless()))
    }

    // MARK: - Helpers

    private func vless() -> ProxyConfig {
        var node = ProxyConfig(name: "NL-01", proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = "11111111-2222-3333-4444-555555555555"
        node.security = .reality
        node.sni = "example.com"
        node.publicKey = "PBK"
        node.shortId = "ab"
        node.fingerprint = "chrome"
        return node
    }

    private func wireguard() -> ProxyConfig {
        var node = ProxyConfig(name: "office", proto: .wireguard,
                               address: "10.20.30.40", port: 51820)
        node.privateKey = "aPrivateKeyThatIsBase64Like="
        node.peerPublicKey = "aPeerPublicKeyThatIsBase64="
        node.localAddresses = ["10.0.0.2/32"]
        node.mtu = 1420
        return node
    }
}

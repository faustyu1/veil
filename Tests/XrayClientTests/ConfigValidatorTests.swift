import XCTest
@testable import XrayClient

/// An edited configuration is checked by the core that will run it, so a typo
/// is caught at the moment it is typed rather than becoming a connection that
/// never comes up. These run the real binaries, the way `CLAUDE.md` documents.
final class ConfigValidatorTests: XCTestCase {

    func testACoreAcceptsAProfileTheAppBuilds() async throws {
        try XCTSkipUnless(CoreBinary.locate(for: .xray) != nil, "core not fetched")
        var node = ProxyConfig(name: "NL", proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = "11111111-2222-3333-4444-555555555555"
        node.security = .reality
        node.publicKey = "jNXHt1yRo0vDuchQlIP6Z0ZvjT3KtzVI-T4E7RoLJS0"
        node.fingerprint = "chrome"

        let outcome = await ConfigValidator.check(node)

        XCTAssertEqual(outcome, .ok)
    }

    func testTheCoresOwnComplaintIsWhatComesBack() async throws {
        try XCTSkipUnless(CoreBinary.locate(for: .singbox) != nil, "core not fetched")
        // A node the credential check has nothing to say about, so the message
        // that comes back is the core's own.
        var node = ProxyConfig(name: "broken", proto: .hysteria2,
                               address: "", port: 0)
        node.password = "pw"

        let outcome = await ConfigValidator.check(node)

        guard case .failed(let message) = outcome else {
            return XCTFail("expected the core to refuse this, got \(outcome)")
        }
        XCTAssertFalse(message.isEmpty, "the core's own message is what the user reads")
    }

    /// A Hysteria2 node with no auth string is refused before the core sees it.
    ///
    /// sing-box dials such a node happily and the server answers with its
    /// masquerade page — "authentication failed, status code: 404" — which
    /// reads as a problem at the far end when the link simply never carried a
    /// password.
    func testANodeWithNoCredentialIsNamedAsSuch() async {
        var node = ProxyConfig(name: "no auth", proto: .hysteria2,
                               address: "37.0.0.1", port: 30555)
        node.password = nil

        let outcome = await ConfigValidator.check(node)

        XCTAssertEqual(outcome, .failed("This node has no password."))
    }

    func testEveryProtocolNamesTheCredentialItNeeds() {
        var vless = ProxyConfig(name: "v", proto: .vless, address: "h", port: 443)
        XCTAssertEqual(ConfigValidator.missingCredential(vless), "This node has no UUID.")
        vless.uuid = "11111111-2222-3333-4444-555555555555"
        XCTAssertNil(ConfigValidator.missingCredential(vless))

        var tuic = ProxyConfig(name: "t", proto: .tuic, address: "h", port: 443)
        tuic.uuid = "u"
        XCTAssertEqual(ConfigValidator.missingCredential(tuic), "This node has no password.")

        var wg = ProxyConfig(name: "w", proto: .wireguard, address: "h", port: 51820)
        wg.privateKey = "k"
        XCTAssertEqual(ConfigValidator.missingCredential(wg), "This node has no peer public key.")
    }
}

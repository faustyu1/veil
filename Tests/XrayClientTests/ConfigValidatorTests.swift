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
        // A Hysteria2 node with no password at all: sing-box parses the profile
        // and rejects it, which is exactly the case worth surfacing.
        var node = ProxyConfig(name: "broken", proto: .hysteria2,
                               address: "", port: 0)
        node.password = nil

        let outcome = await ConfigValidator.check(node)

        guard case .failed(let message) = outcome else {
            return XCTFail("expected the core to refuse this, got \(outcome)")
        }
        XCTAssertFalse(message.isEmpty, "the core's own message is what the user reads")
    }
}

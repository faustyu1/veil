import XCTest
@testable import XrayClient

/// The add screen offers a single action and infers what was pasted, so the
/// inference is the thing that has to be right.
final class AddInputTests: XCTestCase {

    private let vless = "vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443"
        + "?encryption=none&security=reality&sni=www.microsoft.com&fp=chrome"
        + "&pbk=xr0PXbLQvB0qCLLm7d5MO_9y2Bqk5DoMHKcVAKTZ1UA&sid=0123abcd"
        + "&type=tcp&flow=xtls-rprx-vision#NL"

    func testSingleShareLink() {
        guard case .servers(let servers) = AddInputClassifier.classify(vless) else {
            return XCTFail("expected servers")
        }
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers[0].name, "NL")
    }

    func testMultipleLinksOnePerLine() {
        let text = """
        \(vless)
        trojan://pw@us.example.com:443?security=tls#US
        ss://YWVzLTI1Ni1nY206aHVudGVyMg@jp.example.com:8388#JP
        """
        guard case .servers(let servers) = AddInputClassifier.classify(text) else {
            return XCTFail("expected servers")
        }
        XCTAssertEqual(servers.count, 3)
    }

    func testLinksSurvivedLeadingAndTrailingWhitespace() {
        guard case .servers = AddInputClassifier.classify("\n  \(vless)  \n\n") else {
            return XCTFail("expected servers")
        }
    }

    /// Balancer members must already be folded together here, so the add sheet
    /// reports "1 server", not "3", and the store gets the grouped entry.
    func testNumberedNodesAreGrouped() {
        let text = """
        \(vless.replacingOccurrences(of: "#NL", with: "#NL-01"))
        \(vless.replacingOccurrences(of: "#NL", with: "#NL-02"))
        \(vless.replacingOccurrences(of: "#NL", with: "#NL-03"))
        """
        guard case .servers(let servers) = AddInputClassifier.classify(text) else {
            return XCTFail("expected servers")
        }
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers[0].alternates?.count, 2)
    }

    func testHTTPSSubscriptionURL() {
        XCTAssertEqual(AddInputClassifier.classify("https://panel.example.com/sub/abc"),
                       .subscription("https://panel.example.com/sub/abc"))
        XCTAssertEqual(AddInputClassifier.classify("  http://panel.example.com/s  "),
                       .subscription("http://panel.example.com/s"))
    }

    /// Some panels hand out the subscription URL base64-wrapped.
    func testBase64WrappedSubscriptionURL() {
        let encoded = Data("https://panel.example.com/sub/abc".utf8).base64EncodedString()
        XCTAssertEqual(AddInputClassifier.classify(encoded),
                       .subscription("https://panel.example.com/sub/abc"))
    }

    /// …and a user may paste the subscription *body* rather than its URL.
    func testBase64SubscriptionBodyBecomesServers() {
        let body = Data("\(vless)\ntrojan://pw@us.example.com:443#US".utf8)
            .base64EncodedString()
        guard case .servers(let servers) = AddInputClassifier.classify(body) else {
            return XCTFail("expected servers")
        }
        XCTAssertEqual(servers.count, 2)
    }

    func testWireGuardConfProfile() {
        let conf = """
        [Interface]
        PrivateKey = cHJpdmF0ZQ==
        Address = 10.2.0.2/32
        MTU = 1420

        [Peer]
        PublicKey = cHVibGlj
        Endpoint = wg.example.com:51820
        """
        guard case .servers(let servers) = AddInputClassifier.classify(conf) else {
            return XCTFail("expected servers")
        }
        XCTAssertEqual(servers.count, 1)
        XCTAssertEqual(servers[0].proto, .wireguard)
        XCTAssertEqual(servers[0].port, 51820)
    }

    func testGarbageAndEmptyAreRejected() {
        XCTAssertEqual(AddInputClassifier.classify(""), .unrecognized)
        XCTAssertEqual(AddInputClassifier.classify("   \n "), .unrecognized)
        XCTAssertEqual(AddInputClassifier.classify("hello world"), .unrecognized)
        XCTAssertEqual(AddInputClassifier.classify("ftp://example.com/x"), .unrecognized)
        // A scheme we do not support must not be mistaken for a subscription.
        XCTAssertEqual(AddInputClassifier.classify("ssh://host"), .unrecognized)
    }

    /// A bare hostname is not a subscription — requiring a scheme keeps typos
    /// from silently becoming a download attempt.
    func testHostWithoutSchemeIsRejected() {
        XCTAssertEqual(AddInputClassifier.classify("panel.example.com/sub"), .unrecognized)
    }
}

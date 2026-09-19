import XCTest
@testable import XrayClient

/// Parsing drops whatever it cannot use, and until now it did so in silence —
/// which is indistinguishable, from the list, from a server that was never
/// offered. These cover what the sources page reports about a fetch.
final class PayloadDiagnosticsTests: XCTestCase {

    func testALineThatIsNotAServerIsReported() {
        let body = [
            "vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443?encryption=none&type=tcp#NL",
            "not-a-link-at-all",
            "gopher://example.com",
        ].joined(separator: "\n")

        let payload = SubscriptionPayloadParser.parse(body)

        XCTAssertEqual(payload.servers.count, 1)
        XCTAssertEqual(payload.skipped.map(\.count).reduce(0, +), 2)
    }

    func testAnOutboundTypeVeilCannotRunIsNamed() {
        let body = """
        {"outbounds":[
          {"type":"vless","tag":"ok","server":"1.2.3.4","server_port":443,
           "uuid":"11111111-2222-3333-4444-555555555555"},
          {"type":"ssh","tag":"nope","server":"5.6.7.8","server_port":22},
          {"type":"direct","tag":"direct"}
        ]}
        """

        let payload = SubscriptionPayloadParser.parse(body)

        XCTAssertEqual(payload.servers.count, 1)
        XCTAssertEqual(payload.skipped.map(\.label), ["ssh"],
                       "direct is not a server and is no surprise; ssh is one Veil cannot run")
    }

    func testAFormatVeilDoesNotReadYetSaysSo() {
        let body = """
        proxies:
          - name: NL
            type: vless
            server: 1.2.3.4
            port: 443
        rules:
          - MATCH,PROXY
        """

        let payload = SubscriptionPayloadParser.parse(body)

        XCTAssertEqual(payload.format, .mihomoYAML)
        XCTAssertFalse(payload.skipped.isEmpty,
                       "a format that yields nothing has to say that it yielded nothing")
    }

    func testACleanBodyReportsNothing() {
        let body = "vless://11111111-2222-3333-4444-555555555555@1.2.3.4:443?encryption=none&type=tcp#NL"

        XCTAssertTrue(SubscriptionPayloadParser.parse(body).skipped.isEmpty)
    }
}

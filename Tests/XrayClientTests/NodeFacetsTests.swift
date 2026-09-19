import XCTest
@testable import XrayClient

/// Facets are what a node says about itself: where it is, what it speaks, how
/// it is carried. They are read out of the name and the config on every draw
/// and never stored, so a provider that renames a node simply produces
/// different facets next time.
final class NodeFacetsTests: XCTestCase {

    // MARK: - Country

    func testAFlagEmojiNamesTheCountry() {
        XCTAssertEqual(country(of: "🇳🇱 Amsterdam 01"), "NL")
        XCTAssertEqual(country(of: "🇩🇪"), "DE")
    }

    func testAnIsoCodeInTheNameNamesTheCountry() {
        XCTAssertEqual(country(of: "NL-01"), "NL")
        XCTAssertEqual(country(of: "vless | DE | 3"), "DE")
        XCTAssertEqual(country(of: "us-west-2"), "US")
    }

    func testACityNamesTheCountry() {
        XCTAssertEqual(country(of: "Amsterdam 3"), "NL")
        XCTAssertEqual(country(of: "Франкфурт"), "DE")
    }

    func testACountryNameIsReadInEnglishAndRussian() {
        XCTAssertEqual(country(of: "Netherlands premium"), "NL")
        XCTAssertEqual(country(of: "Нидерланды 01"), "NL")
    }

    func testAProtocolTokenIsNotAPlace() {
        // SS is South Sudan's ISO code and a Shadowsocks node's usual prefix.
        var node = ProxyConfig(name: "SS-01", proto: .shadowsocks,
                               address: "1.2.3.4", port: 443)
        node.password = "x"
        XCTAssertNil(NodeFacets(for: node).country)
        XCTAssertNil(country(of: "WS + TLS"))
    }

    func testANameWithNoPlaceHasNoCountry() {
        XCTAssertNil(country(of: "Fast Server"))
        XCTAssertNil(country(of: ""))
    }

    func testACountryCodeRendersAsAFlagAndAName() {
        XCTAssertEqual(NodeFacets.flag(for: "NL"), "🇳🇱")
        XCTAssertEqual(NodeFacets.countryName(for: "NL", locale: Locale(identifier: "en_US")),
                       "Netherlands")
        XCTAssertEqual(NodeFacets.countryName(for: "NL", locale: Locale(identifier: "ru_RU")),
                       "Нидерланды")
        XCTAssertEqual(NodeFacets.countryName(for: "ZZ"), "ZZ",
                       "an unknown code is still shown, not swallowed")
    }

    // MARK: - The rest

    func testTheTrailingNumberIsTheBalancerIndex() {
        XCTAssertEqual(NodeFacets(for: node(named: "NL-01")).balancerIndex, 1)
        XCTAssertEqual(NodeFacets(for: node(named: "NL — 12")).balancerIndex, 12)
        XCTAssertNil(NodeFacets(for: node(named: "NL")).balancerIndex)
    }

    func testFacetsCarryTheProtocolEngineAndTransport() {
        var wg = ProxyConfig(name: "office", proto: .wireguard,
                             address: "1.2.3.4", port: 51820)
        wg.peerPublicKey = "k"
        let facets = NodeFacets(for: wg)
        XCTAssertEqual(facets.proto, .wireguard)
        XCTAssertEqual(facets.engine, .singbox)

        var vless = node(named: "NL-01")
        vless.network = .ws
        XCTAssertEqual(NodeFacets(for: vless).transport, .ws)
        XCTAssertEqual(NodeFacets(for: vless).engine, .xray)
    }

    // MARK: - Helpers

    private func country(of name: String) -> String? {
        NodeFacets(for: node(named: name)).country
    }

    private func node(named name: String) -> ProxyConfig {
        var node = ProxyConfig(name: name, proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = "11111111-2222-3333-4444-555555555555"
        return node
    }
}

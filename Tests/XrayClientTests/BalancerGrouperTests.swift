import XCTest
@testable import XrayClient

final class BalancerGrouperTests: XCTestCase {

    func testGroupsNumberedNodesByBaseName() {
        let nodes = [
            ProxyConfig(name: "NL-01", proto: .vless, address: "nl-1.example.com", port: 443),
            ProxyConfig(name: "NL-02", proto: .vless, address: "nl-2.example.com", port: 443),
            ProxyConfig(name: "NL-03", proto: .vless, address: "nl-3.example.com", port: 443),
            ProxyConfig(name: "DE-01", proto: .vless, address: "de-1.example.com", port: 443),
            ProxyConfig(name: "DE-02", proto: .vless, address: "de-2.example.com", port: 443),
        ]
        // Give same UUID so they are treated as balancer members.
        var mutable = nodes
        for i in mutable.indices { mutable[i].uuid = "shared-uuid" }

        let grouped = BalancerGrouper.group(mutable)
        XCTAssertEqual(grouped.count, 2)

        let nl = grouped.first { $0.name == "NL" }
        XCTAssertNotNil(nl)
        XCTAssertEqual(nl?.isBalancer, true)
        XCTAssertEqual(nl?.alternates?.count, 2)
        XCTAssertEqual(nl?.address, "nl-1.example.com")

        let de = grouped.first { $0.name == "DE" }
        XCTAssertNotNil(de)
        XCTAssertEqual(de?.alternates?.count, 1)
    }

    func testDoesNotGroupDifferentProtocols() {
        var vless = ProxyConfig(name: "NL-01", proto: .vless, address: "a.com", port: 443)
        vless.uuid = "u1"
        var trojan = ProxyConfig(name: "NL-01", proto: .trojan, address: "a.com", port: 443)
        trojan.password = "p1"

        let grouped = BalancerGrouper.group([vless, trojan])
        XCTAssertEqual(grouped.count, 2)
        XCTAssertFalse(grouped.contains { $0.isBalancer })
    }

    func testDoesNotGroupDifferentAuthKeys() {
        var a = ProxyConfig(name: "NL-01", proto: .vless, address: "a.com", port: 443)
        a.uuid = "uuid-a"
        var b = ProxyConfig(name: "NL-02", proto: .vless, address: "b.com", port: 443)
        b.uuid = "uuid-b"

        let grouped = BalancerGrouper.group([a, b])
        XCTAssertEqual(grouped.count, 2)
        XCTAssertFalse(grouped.contains { $0.isBalancer })
    }

    func testKeepsSingleNodeUnchanged() {
        var node = ProxyConfig(name: "Rubbridge", proto: .vless, address: "r.com", port: 443)
        node.uuid = "u1"
        let grouped = BalancerGrouper.group([node])
        XCTAssertEqual(grouped.count, 1)
        XCTAssertEqual(grouped[0].name, "Rubbridge")
        XCTAssertFalse(grouped[0].isBalancer)
    }

    func testXrayBalancerConfigHasMultipleProxyOutbounds() {
        var main = ProxyConfig(name: "NL", proto: .vless, address: "nl-1.example.com", port: 443)
        main.uuid = "u"
        var alt = ProxyConfig(name: "NL-02", proto: .vless, address: "nl-2.example.com", port: 443)
        alt.uuid = "u"
        main.alternates = [alt]

        let dict = XrayConfigBuilder.build(for: main)
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let proxyTags = outbounds.compactMap { $0["tag"] as? String }
        XCTAssertTrue(proxyTags.contains("proxy-0"))
        XCTAssertTrue(proxyTags.contains("proxy-1"))
        XCTAssertFalse(proxyTags.contains("proxy-2"))

        let routing = dict["routing"] as! [String: Any]
        let rules = routing["rules"] as! [[String: Any]]
        let finalRule = rules.last!
        XCTAssertEqual(finalRule["balancerTag"] as? String, "proxy")

        let balancers = routing["balancers"] as! [[String: Any]]
        XCTAssertEqual(balancers[0]["tag"] as? String, "proxy")
        let selector = balancers[0]["selector"] as! [String]
        XCTAssertTrue(selector.contains("proxy-0"))
        XCTAssertTrue(selector.contains("proxy-1"))
    }

    func testSingBoxBalancerConfigHasUrltestOutbound() {
        var main = ProxyConfig(name: "NL", proto: .hysteria2, address: "nl-1.example.com", port: 443)
        main.password = "p"
        var alt = ProxyConfig(name: "NL-02", proto: .hysteria2, address: "nl-2.example.com", port: 443)
        alt.password = "p"
        main.alternates = [alt]

        let dict = SingBoxConfigBuilder.build(for: main)
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let tags = outbounds.compactMap { $0["tag"] as? String }
        XCTAssertTrue(tags.contains("proxy-0"))
        XCTAssertTrue(tags.contains("proxy-1"))
        XCTAssertTrue(tags.contains("proxy"))

        let urltest = outbounds.first { $0["tag"] as? String == "proxy" }
        XCTAssertEqual(urltest?["type"] as? String, "urltest")
        let selector = urltest?["outbounds"] as! [String]
        XCTAssertTrue(selector.contains("proxy-0"))
        XCTAssertTrue(selector.contains("proxy-1"))
    }
}

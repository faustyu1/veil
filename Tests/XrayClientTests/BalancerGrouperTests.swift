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
        // Nodes now carry stable per-server tags, and the balancer is a group
        // over them; `proxy` is the selector that fronts the whole graph.
        let mainTag = ProfileTags.server(main.id)
        let altTag = ProfileTags.server(alt.id)
        let groupTag = ProfileTags.group(main.id)
        XCTAssertTrue(tags.contains(mainTag))
        XCTAssertTrue(tags.contains(altTag))
        XCTAssertTrue(tags.contains(groupTag))
        XCTAssertTrue(tags.contains(ProfileTags.defaultSelector))

        let urltest = outbounds.first { $0["tag"] as? String == groupTag }
        XCTAssertEqual(urltest?["type"] as? String, "urltest")
        let members = urltest?["outbounds"] as! [String]
        XCTAssertTrue(members.contains(mainTag))
        XCTAssertTrue(members.contains(altTag))

        let selector = outbounds.first { $0["tag"] as? String == ProfileTags.defaultSelector }
        XCTAssertEqual(selector?["default"] as? String, groupTag)
    }
}

/// The name heuristic is a last resort. It exists because a share-link list has
/// no way to say "these three are one balancer"; a config document does, and
/// second-guessing what the panel declared there is how a deliberate grouping
/// gets replaced by a guess.
final class BalancerHeuristicScopeTests: XCTestCase {

    func testShareLinksStillGetTheHeuristic() {
        let body = [
            "vless://11111111-2222-3333-4444-555555555555@1.1.1.1:443?type=tcp#NL%20-%201",
            "vless://11111111-2222-3333-4444-555555555555@2.2.2.2:443?type=tcp#NL%20-%202"
        ].joined(separator: "\n")
        let payload = BalancerGrouper.applied(to: SubscriptionPayloadParser.parse(body))
        XCTAssertEqual(payload.servers.count, 1)
        XCTAssertEqual(payload.servers.first?.alternates?.count, 1)
    }

    func testDeclaredConfigIsLeftAlone() {
        // Two nodes the heuristic would happily merge, and a panel that grouped
        // them itself. The declaration wins and the nodes stay separate.
        let body = """
        {"outbounds": [
          {"type": "vless", "tag": "NL - 1", "server": "1.1.1.1", "server_port": 443,
           "uuid": "11111111-2222-3333-4444-555555555555"},
          {"type": "vless", "tag": "NL - 2", "server": "2.2.2.2", "server_port": 443,
           "uuid": "11111111-2222-3333-4444-555555555555"},
          {"type": "urltest", "tag": "NL", "outbounds": ["NL - 1", "NL - 2"]}
        ], "route": {}}
        """
        let payload = BalancerGrouper.applied(to: SubscriptionPayloadParser.parse(body))
        XCTAssertEqual(payload.servers.count, 2)
        XCTAssertNil(payload.servers.first?.alternates)
        XCTAssertEqual(payload.groups.count, 1)
    }

    func testDeclaredGroupReachesTheAssembledProfile() {
        let body = """
        {"outbounds": [
          {"type": "vless", "tag": "NL - 1", "server": "1.1.1.1", "server_port": 443,
           "uuid": "11111111-2222-3333-4444-555555555555"},
          {"type": "vless", "tag": "NL - 2", "server": "2.2.2.2", "server_port": 443,
           "uuid": "11111111-2222-3333-4444-555555555555"},
          {"type": "urltest", "tag": "NL", "outbounds": ["NL - 1", "NL - 2"]}
        ], "route": {}}
        """
        let payload = BalancerGrouper.applied(to: SubscriptionPayloadParser.parse(body))
        let group = payload.groups[0]

        var input = ProfileAssembler.Input()
        input.servers = payload.servers
        input.subscriptionGroups = payload.groups
        input.activeServerID = group.id

        let outbounds = SingBoxProfileBuilder
            .build(ProfileAssembler.profile(input))["outbounds"] as! [[String: Any]]
        let urltest = outbounds.first { $0["tag"] as? String == ProfileTags.group(group.id) }
        XCTAssertEqual(urltest?["type"] as? String, "urltest")
        XCTAssertEqual(urltest?["outbounds"] as? [String],
                       payload.servers.map { ProfileTags.server($0.id) })

        let selector = outbounds.first { $0["tag"] as? String == ProfileTags.defaultSelector }
        XCTAssertEqual(selector?["default"] as? String, ProfileTags.group(group.id),
                       "connecting to the group is connecting to the whole balancer")
    }

    func testConfigWithoutGroupsIsAlsoLeftAlone() {
        // A config that declares no balancer is not an oversight to correct.
        let body = """
        {"outbounds": [
          {"type": "vless", "tag": "NL - 1", "server": "1.1.1.1", "server_port": 443,
           "uuid": "11111111-2222-3333-4444-555555555555"},
          {"type": "vless", "tag": "NL - 2", "server": "2.2.2.2", "server_port": 443,
           "uuid": "11111111-2222-3333-4444-555555555555"}
        ], "route": {}}
        """
        let payload = BalancerGrouper.applied(to: SubscriptionPayloadParser.parse(body))
        XCTAssertEqual(payload.servers.count, 2)
        XCTAssertTrue(payload.groups.isEmpty)
    }
}

/// A group the panel declared has to be clickable, or supporting it properly
/// amounts to hiding it.
final class DeclaredGroupRowTests: XCTestCase {

    private func node(_ name: String, _ address: String) -> ProxyConfig {
        var config = ProxyConfig(name: name, proto: .trojan, address: address, port: 443)
        config.password = "p"
        return config
    }

    func testRepresentativeCarriesTheGroupIdentityAndTheMembers() throws {
        let a = node("nl-1", "1.1.1.1")
        let b = node("nl-2", "2.2.2.2")
        let group = ServerGroup(name: "NL", kind: .urltest, memberIDs: [a.id, b.id])

        let row = try XCTUnwrap(group.representative(in: [a, b]))
        XCTAssertEqual(row.id, group.id, "clicking the row must connect to the group")
        XCTAssertEqual(row.name, "NL")
        XCTAssertEqual(row.address, a.address, "it still has to be dialable")
        XCTAssertEqual(row.alternates?.map(\.id), [b.id])
        XCTAssertTrue(row.isBalancer, "so the list shows it with its member count")
    }

    func testAGroupWhoseMembersAreGoneHasNoRow() {
        let group = ServerGroup(name: "NL", kind: .urltest, memberIDs: [UUID()])
        XCTAssertNil(group.representative(in: []))
    }
}

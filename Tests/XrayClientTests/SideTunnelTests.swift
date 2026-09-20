import XCTest
@testable import XrayClient

/// A WireGuard peer used as a *side* tunnel: the subscription's server carries
/// the internet, and a handful of private addresses go through the peer
/// instead. Three separate things had to be true for that to work, and none of
/// them were.
final class SideTunnelTests: XCTestCase {

    // MARK: - Fixtures

    private func mainServer() -> ProxyConfig {
        var cfg = ProxyConfig(name: "NL", proto: .vless, address: "1.2.3.4", port: 443)
        cfg.uuid = "11111111-2222-3333-4444-555555555555"
        cfg.security = .reality
        cfg.sni = "www.microsoft.com"
        cfg.publicKey = "xr0PXbLQvB0qCLLm7d5MO_9y2Bqk5DoMHKcVAKTZ1UA"
        cfg.shortId = "0123abcd"
        return cfg
    }

    private func officePeer() -> ProxyConfig {
        var cfg = ProxyConfig(name: "office", proto: .wireguard,
                              address: "9.9.9.9", port: 51820)
        cfg.privateKey = "aPrivateKeyThatIsBase64Like="
        cfg.peerPublicKey = "aPeerPublicKeyThatIsBase64="
        cfg.localAddresses = ["172.16.4.2/32"]
        cfg.allowedIPs = ["172.16.4.0/24"]
        return cfg
    }

    private func input(tun: Bool) -> ProfileAssembler.Input {
        let server = mainServer()
        let peer = officePeer()
        var settings = AppSettings()
        settings.routingPreset = .bypassLAN
        settings.customRules = [
            RoutingRule(name: "Office host", target: .server(peer.id),
                        ips: ["172.16.4.10/32"])
        ]
        var input = ProfileAssembler.Input()
        input.servers = [server, peer]
        input.settings = settings
        input.activeServerID = server.id
        input.includeTun = tun
        return input
    }

    // MARK: - The graph

    func testThePeerIsBuiltEvenThoughTheUserConnectedToTheSubscription() {
        let input = self.input(tun: false)
        let peerID = input.servers[1].id
        let config = SingBoxProfileBuilder.build(ProfileAssembler.profile(input))

        let endpoints = config["endpoints"] as! [[String: Any]]
        XCTAssertEqual(endpoints.map { $0["tag"] as? String },
                       [ProfileTags.server(peerID)])

        // …and it keeps the narrow AllowedIPs the peer was handed out with.
        let peer = (endpoints[0]["peers"] as! [[String: Any]])[0]
        XCTAssertEqual(peer["allowed_ips"] as? [String], ["172.16.4.0/24"])
    }

    func testTheAddressGoesToThePeerAndEverythingElseToTheSubscription() {
        let input = self.input(tun: false)
        let peerID = input.servers[1].id
        let config = SingBoxProfileBuilder.build(ProfileAssembler.profile(input))
        let route = config["route"] as! [String: Any]
        let rules = route["rules"] as! [[String: Any]]

        let office = rules.firstIndex { ($0["ip_cidr"] as? [String]) == ["172.16.4.10/32"] }
        XCTAssertNotNil(office, "the rule never reached the config")
        XCTAssertEqual(rules[office!]["outbound"] as? String, ProfileTags.server(peerID))

        // The LAN bypass must not have swallowed it on the way past.
        let lan = rules.firstIndex {
            ($0["ip_cidr"] as? [String])?.contains("172.16.0.0/12") ?? false
        }
        XCTAssertNotNil(lan)
        XCTAssertLessThan(office!, lan!)

        XCTAssertEqual(route["final"] as? String, ProfileTags.defaultSelector)
    }

    // MARK: - The tunnel

    /// `route_exclude_address` keeps the private ranges off the interface, so
    /// a packet to 172.16.4.10 never reached the core at all and the rule read
    /// as broken.
    func testTheClaimedRangeIsNoLongerRoutedAroundTheTunnel() {
        let profile = ProfileAssembler.profile(input(tun: true))
        let excludes = profile.tun!.routeExcludeAddress

        XCTAssertFalse(excludes.contains("172.16.0.0/12"))
        // Only the block that was claimed opens up.
        XCTAssertTrue(excludes.contains("192.168.0.0/16"))
        XCTAssertTrue(excludes.contains("10.0.0.0/8"))
    }

    func testAnUntouchedTunnelKeepsEveryExclusion() {
        var input = self.input(tun: true)
        input.settings.customRules = []
        let profile = ProfileAssembler.profile(input)

        XCTAssertEqual(profile.tun!.routeExcludeAddress,
                       TunInboundSettings().routeExcludeAddress)
    }

    /// A rule sending a private range *direct* is what the bypass already
    /// does, so it is no reason to route that range through the interface.
    func testADirectRuleDoesNotOpenTheTunnel() {
        var input = self.input(tun: true)
        input.settings.customRules = [
            RoutingRule(name: "NAS", target: .direct, ips: ["192.168.1.9/32"])
        ]
        let profile = ProfileAssembler.profile(input)

        XCTAssertTrue(profile.tun!.routeExcludeAddress.contains("192.168.0.0/16"))
    }

    // MARK: - Ranges

    func testOverlapIsDecidedByTheRangeNotTheSpelling() {
        XCTAssertTrue(IPRange("172.16.0.0/12")!.overlaps(IPRange("172.16.4.10/32")!))
        XCTAssertTrue(IPRange("172.16.4.10")!.overlaps(IPRange("172.16.0.0/12")!))
        XCTAssertFalse(IPRange("192.168.0.0/16")!.overlaps(IPRange("172.16.4.10/32")!))
        XCTAssertTrue(IPRange("172.16.0.0/12")!.contains(IPRange("172.16.4.0/24")!))
        XCTAssertFalse(IPRange("172.16.4.0/24")!.contains(IPRange("172.16.0.0/12")!))
        XCTAssertNil(IPRange("fc00::/7"))
        XCTAssertNil(IPRange("geoip:private"))
    }
}

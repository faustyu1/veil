import XCTest
@testable import XrayClient

/// The response-header contract panels speak, and the body formats they send.
final class RemnawaveHeaderTests: XCTestCase {

    func testHeaderNamesAreCaseInsensitive() {
        let meta = RemnawaveHeaders.parse(lowercased: [
            "profile-title": "My Panel",
            "subscription-userinfo": "upload=1; download=2; total=3; expire=1700000000",
        ])
        XCTAssertEqual(meta.profileTitle, "My Panel")
        XCTAssertEqual(meta.userinfo?.upload, 1)
        XCTAssertEqual(meta.userinfo?.total, 3)
    }

    func testMixedCaseHeadersFromURLResponse() {
        let meta = RemnawaveHeaders.parse(["Profile-Title": "Mixed", "X-HWID-Active": "true"])
        XCTAssertEqual(meta.profileTitle, "Mixed")
        XCTAssertEqual(meta.hwidStatus, .active)
    }

    func testBase64Titles() {
        let encoded = Data("Тариф Pro".utf8).base64EncodedString()
        let meta = RemnawaveHeaders.parse(lowercased: ["profile-title": "base64:" + encoded])
        XCTAssertEqual(meta.profileTitle, "Тариф Pro")
    }

    func testHWIDRefusalOutranksActive() {
        let meta = RemnawaveHeaders.parse(lowercased: [
            "x-hwid-active": "true",
            "x-hwid-max-devices-reached": "true",
        ])
        XCTAssertEqual(meta.hwidStatus, .maxDevicesReached)
        XCTAssertTrue(meta.needsUserAction)
    }

    func testHWIDNotSupported() {
        let meta = RemnawaveHeaders.parse(lowercased: ["x-hwid-not-supported": "1"])
        XCTAssertEqual(meta.hwidStatus, .notSupported)
    }

    func testExplicitlyFalseFlagIsNotSet() {
        let meta = RemnawaveHeaders.parse(lowercased: ["x-hwid-active": "false"])
        XCTAssertEqual(meta.hwidStatus, .unknown)
    }

    func testUpdateIntervalUnits() {
        XCTAssertEqual(RemnawaveHeaders.updateInterval("30m"), 30)
        XCTAssertEqual(RemnawaveHeaders.updateInterval("6h"), 360)
        XCTAssertEqual(RemnawaveHeaders.updateInterval("2d"), 2880)
        // A bare small number is days, the way Remnawave documents it.
        XCTAssertEqual(RemnawaveHeaders.updateInterval("1"), 1440)
        // A bare large number is already minutes.
        XCTAssertEqual(RemnawaveHeaders.updateInterval("720"), 720)
        XCTAssertNil(RemnawaveHeaders.updateInterval(""))
        XCTAssertNil(RemnawaveHeaders.updateInterval("soon"))
    }

    func testUpdateIntervalHoursRoundsUpAndClamps() {
        var meta = SubscriptionMetadata()
        meta.updateIntervalMinutes = 30
        XCTAssertEqual(meta.updateIntervalHours, 1)
        meta.updateIntervalMinutes = 90
        XCTAssertEqual(meta.updateIntervalHours, 2)
        meta.updateIntervalMinutes = 60 * 24 * 400
        XCTAssertEqual(meta.updateIntervalHours, 24 * 7)
    }

    func testRefillDateFormats() {
        XCTAssertNotNil(RemnawaveHeaders.date("2026-01-31"))
        XCTAssertNotNil(RemnawaveHeaders.date("2026-01-31T12:00:00Z"))
        XCTAssertEqual(RemnawaveHeaders.date("1700000000"),
                       Date(timeIntervalSince1970: 1_700_000_000))
        // Milliseconds, as some panels send them.
        XCTAssertEqual(RemnawaveHeaders.date("1700000000000"),
                       Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertNil(RemnawaveHeaders.date(""))
    }

    func testSupportAndPageLinks() {
        let meta = RemnawaveHeaders.parse(lowercased: [
            "support-url": "https://t.me/support",
            "profile-web-page-url": "https://panel.example.com/app",
        ])
        XCTAssertEqual(meta.supportURL, "https://t.me/support")
        XCTAssertEqual(meta.webPageURL, "https://panel.example.com/app")
    }

    func testPanelIntervalWinsOverTheAppSetting() {
        var sub = Subscription(name: "s", url: "https://example.com/sub")
        var meta = SubscriptionMetadata()
        meta.updateIntervalMinutes = 60 * 6
        sub.apply(meta)
        XCTAssertEqual(sub.refreshInterval(defaultHours: 12), 6 * 3600)

        var untold = Subscription(name: "s", url: "https://example.com/sub")
        untold.apply(SubscriptionMetadata())
        XCTAssertEqual(untold.refreshInterval(defaultHours: 12), 12 * 3600)
    }
}

/// Format recognition: the body has to be classified before it is parsed, or a
/// full config gets flattened into a node list and loses everything else.
final class SubscriptionPayloadTests: XCTestCase {

    private let xrayJSON = """
    {
      "log": {"loglevel": "warning"},
      "outbounds": [
        {
          "tag": "DE-01",
          "protocol": "vless",
          "settings": {"vnext": [{
            "address": "1.2.3.4", "port": 443,
            "users": [{"id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
                       "flow": "xtls-rprx-vision", "encryption": "none"}]
          }]},
          "streamSettings": {
            "network": "tcp", "security": "reality",
            "realitySettings": {"serverName": "www.example.com",
                                "publicKey": "PUBKEY", "shortId": "ab",
                                "fingerprint": "chrome"}
          }
        },
        {"tag": "direct", "protocol": "freedom"}
      ],
      "routing": {"balancers": [{"tag": "all", "selector": ["DE"]}]}
    }
    """

    private let singboxJSON = """
    {
      "outbounds": [
        {"type": "hysteria2", "tag": "FI-01", "server": "5.6.7.8",
         "server_port": 8443, "password": "pw",
         "obfs": {"type": "salamander", "password": "op"},
         "tls": {"enabled": true, "server_name": "a.example.com", "insecure": false}},
        {"type": "selector", "tag": "auto", "outbounds": ["FI-01"]}
      ],
      "route": {"rules": []}
    }
    """

    func testXrayJSONIsRecognisedAndKept() {
        let payload = SubscriptionPayloadParser.parse(xrayJSON)
        XCTAssertEqual(payload.format, .xrayJSON)
        XCTAssertTrue(payload.format.isFullConfig)
        // The whole document survives: routing and balancers are still in there.
        XCTAssertNotNil(payload.configJSON)
        XCTAssertTrue(payload.configJSON?.contains("balancers") ?? false)
    }

    func testXrayOutboundsBecomeServers() {
        let payload = SubscriptionPayloadParser.parse(xrayJSON)
        XCTAssertEqual(payload.servers.count, 1, "freedom is not a server")
        let server = payload.servers.first
        XCTAssertEqual(server?.name, "DE-01")
        XCTAssertEqual(server?.proto, .vless)
        XCTAssertEqual(server?.address, "1.2.3.4")
        XCTAssertEqual(server?.port, 443)
        XCTAssertEqual(server?.security, .reality)
        XCTAssertEqual(server?.publicKey, "PUBKEY")
        XCTAssertEqual(server?.shortId, "ab")
        XCTAssertEqual(server?.sni, "www.example.com")
        XCTAssertEqual(server?.flow, "xtls-rprx-vision")
    }

    func testSingBoxIsToldApartFromXray() {
        let payload = SubscriptionPayloadParser.parse(singboxJSON)
        XCTAssertEqual(payload.format, .singbox)
        XCTAssertEqual(payload.servers.count, 1, "a selector is not a server")
        let server = payload.servers.first
        XCTAssertEqual(server?.proto, .hysteria2)
        XCTAssertEqual(server?.address, "5.6.7.8")
        XCTAssertEqual(server?.port, 8443)
        XCTAssertEqual(server?.obfs, "salamander")
        XCTAssertEqual(server?.obfsPassword, "op")
        XCTAssertEqual(server?.security, .tls)
        XCTAssertEqual(server?.sni, "a.example.com")
    }

    func testBase64WrappedConfigIsStillAConfig() {
        let wrapped = Data(xrayJSON.utf8).base64EncodedString()
        let payload = SubscriptionPayloadParser.parse(wrapped)
        XCTAssertEqual(payload.format, .xrayBase64)
        XCTAssertEqual(payload.servers.count, 1)
        XCTAssertNotNil(payload.configJSON)
    }

    func testMihomoYAMLIsRecognisedRatherThanMisparsed() {
        let yaml = """
        proxies:
          - {name: DE, type: vless, server: 1.2.3.4, port: 443}
        proxy-groups:
          - {name: auto, type: url-test, proxies: [DE]}
        rules:
          - MATCH,auto
        """
        let payload = SubscriptionPayloadParser.parse(yaml)
        XCTAssertEqual(payload.format, .mihomoYAML)
        XCTAssertTrue(payload.servers.isEmpty)
    }

    func testPlainAndBase64LinkLists() {
        let links = "vless://3F2504E0-4F89-11D3-9A0C-0305E82C3301@1.2.3.4:443?type=tcp#DE-01"
        XCTAssertEqual(SubscriptionPayloadParser.parse(links).format, .links)

        let wrapped = Data(links.utf8).base64EncodedString()
        XCTAssertEqual(SubscriptionPayloadParser.parse(wrapped).format, .base64Links)
    }

    func testRawBodyIsAlwaysPreserved() {
        let payload = SubscriptionPayloadParser.parse(xrayJSON)
        XCTAssertEqual(payload.raw, xrayJSON)
    }

    func testEmptyBody() {
        let payload = SubscriptionPayloadParser.parse("   \n ")
        XCTAssertEqual(payload.format, .unknown)
        XCTAssertTrue(payload.servers.isEmpty)
    }
}

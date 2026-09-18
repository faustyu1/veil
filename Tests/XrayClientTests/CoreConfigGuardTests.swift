import XCTest
import VeilHelperKit
@testable import XrayClient

/// The routing core runs as root when it owns the TUN interface, so the
/// configuration it is handed is the one thing that decides what root will
/// open, write and download. These cover the guard that vets it.
final class CoreConfigGuardTests: XCTestCase {

    private let cachePath = "/Library/Application Support/Veil/helper/core/cache.db"
    private let workDir = "/Library/Application Support/Veil/helper/core"

    private func sanitize(_ object: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: object)
        let out = try CoreConfigGuard.sanitize(data, cachePath: cachePath,
                                               workingDirectory: workDir)
        return try JSONSerialization.jsonObject(with: out) as! [String: Any]
    }

    func testAcceptsAProfileTheAppActuallyBuilds() throws {
        var cfg = ProxyConfig(name: "DE", proto: .vless, address: "1.2.3.4", port: 443)
        cfg.uuid = "11111111-2222-3333-4444-555555555555"
        cfg.security = .reality
        cfg.publicKey = "k"
        cfg.fingerprint = "chrome"

        var profile = SingBoxProfile()
        profile.servers = [cfg]
        profile.defaultTarget = .server(cfg.id)
        profile.tun = TunInboundSettings()
        profile.cacheFilePath = "/somewhere/else/cache.db"

        let data = try SingBoxProfileBuilder.jsonData(profile)
        let sanitized = try CoreConfigGuard.sanitize(data, cachePath: cachePath,
                                                     workingDirectory: workDir)
        let object = try JSONSerialization.jsonObject(with: sanitized) as! [String: Any]
        let experimental = object["experimental"] as! [String: Any]
        let cache = experimental["cache_file"] as! [String: Any]
        // Whatever path the app asked for, the helper's own is what is used.
        XCTAssertEqual(cache["path"] as? String, cachePath)
    }

    func testRejectsAnUnknownSection() {
        XCTAssertThrowsError(try sanitize(["outbounds": [], "script": ["run": "x"]])) {
            XCTAssertEqual($0 as? CoreConfigGuard.GuardError, .unknownSection("script"))
        }
    }

    func testRejectsCertificatePaths() {
        let config: [String: Any] = [
            "outbounds": [[
                "type": "trojan", "tag": "p", "server": "h", "server_port": 443,
                "tls": ["enabled": true, "certificate_path": "/etc/shadow"]
            ]]
        ]
        XCTAssertThrowsError(try sanitize(config)) {
            XCTAssertEqual($0 as? CoreConfigGuard.GuardError,
                           .forbiddenKey("certificate_path"))
        }
    }

    func testRejectsAnExternalUiDownload() {
        let config: [String: Any] = [
            "experimental": ["clash_api": [
                "external_controller": "127.0.0.1:9090",
                "external_ui": "ui",
                "external_ui_download_url": "http://example.com/ui.zip"
            ]]
        ]
        // Downloading and unpacking an archive as root is exactly the kind of
        // thing this config must never ask for.
        XCTAssertThrowsError(try sanitize(config))
    }

    func testRejectsAControlApiThatListensOffTheLoopback() {
        let config: [String: Any] = [
            "experimental": ["clash_api": ["external_controller": "0.0.0.0:9090"]]
        ]
        XCTAssertThrowsError(try sanitize(config)) {
            XCTAssertEqual($0 as? CoreConfigGuard.GuardError,
                           .remoteController("0.0.0.0:9090"))
        }
    }

    func testRejectsALocalRuleSet() {
        let config: [String: Any] = [
            "route": ["rule_set": [[
                "tag": "x", "type": "local", "format": "binary",
                "path": "/Users/someone/evil.srs"
            ]]]
        ]
        XCTAssertThrowsError(try sanitize(config)) {
            XCTAssertEqual($0 as? CoreConfigGuard.GuardError, .localRuleSet)
        }
    }

    func testStripsALogFileDestination() throws {
        let object = try sanitize([
            "log": ["level": "warn", "output": "/var/log/anything"],
            "outbounds": []
        ])
        let log = object["log"] as! [String: Any]
        XCTAssertNil(log["output"])
        XCTAssertEqual(log["level"] as? String, "warn")
    }

    func testKeepsTransportPathsAlone() throws {
        // `path` means a URL far more often than a filename, and banning it
        // would break every websocket and DoH server.
        let object = try sanitize([
            "outbounds": [[
                "type": "vless", "tag": "p", "server": "h", "server_port": 443,
                "uuid": "u", "transport": ["type": "ws", "path": "/ws"]
            ]],
            "dns": ["servers": [[
                "type": "https", "tag": "d", "server": "1.1.1.1", "path": "/dns-query"
            ]]]
        ])
        let outbound = (object["outbounds"] as! [[String: Any]])[0]
        let transport = outbound["transport"] as! [String: Any]
        XCTAssertEqual(transport["path"] as? String, "/ws")
    }

    func testRejectsSomethingThatIsNotAnObject() {
        let data = "[1,2,3]".data(using: .utf8)!
        XCTAssertThrowsError(try CoreConfigGuard.sanitize(data, cachePath: cachePath,
                                                          workingDirectory: workDir)) {
            XCTAssertEqual($0 as? CoreConfigGuard.GuardError, .notAnObject)
        }
    }

    func testRejectsAnAbsurdlyLargeConfig() {
        let filler = String(repeating: "a", count: CoreConfigGuard.maxConfigBytes + 1)
        let data = Data(("{\"log\":\"" + filler + "\"}").utf8)
        XCTAssertThrowsError(try CoreConfigGuard.sanitize(data, cachePath: cachePath,
                                                          workingDirectory: workDir))
    }

    func testLoopbackEndpointRecognisesTheUsualSpellings() {
        XCTAssertTrue(CoreConfigGuard.isLoopbackEndpoint("127.0.0.1:9090"))
        XCTAssertTrue(CoreConfigGuard.isLoopbackEndpoint("localhost:9090"))
        XCTAssertTrue(CoreConfigGuard.isLoopbackEndpoint("[::1]:9090"))
        XCTAssertFalse(CoreConfigGuard.isLoopbackEndpoint("192.168.1.5:9090"))
        XCTAssertFalse(CoreConfigGuard.isLoopbackEndpoint("127.0.0.1"))
        XCTAssertFalse(CoreConfigGuard.isLoopbackEndpoint("127.0.0.1:0"))
    }
}

import XCTest
@testable import XrayClient

final class LinkParserTests: XCTestCase {

    func testVLESSReality() throws {
        let link = "vless://11111111-2222-3333-4444-555555555555@example.com:443?encryption=none&security=reality&sni=www.microsoft.com&fp=chrome&pbk=somepublickey&sid=abcd&type=tcp&flow=xtls-rprx-vision#MyServer"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.proto, .vless)
        XCTAssertEqual(cfg.address, "example.com")
        XCTAssertEqual(cfg.port, 443)
        XCTAssertEqual(cfg.uuid, "11111111-2222-3333-4444-555555555555")
        XCTAssertEqual(cfg.security, .reality)
        XCTAssertEqual(cfg.sni, "www.microsoft.com")
        XCTAssertEqual(cfg.fingerprint, "chrome")
        XCTAssertEqual(cfg.publicKey, "somepublickey")
        XCTAssertEqual(cfg.shortId, "abcd")
        XCTAssertEqual(cfg.flow, "xtls-rprx-vision")
        XCTAssertEqual(cfg.name, "MyServer")
    }

    func testVLESSWebSocketTLS() throws {
        let link = "vless://abc@host.net:8443?encryption=none&security=tls&type=ws&path=%2Fwspath&host=cdn.host.net&sni=cdn.host.net#WS"
        let cfg = try LinkParser.parse(link)
        XCTAssertEqual(cfg.network, .ws)
        XCTAssertEqual(cfg.security, .tls)
        XCTAssertEqual(cfg.path, "/wspath")
        XCTAssertEqual(cfg.host, "cdn.host.net")
    }

    func testVMessBase64() throws {
        let json = """
        {"v":"2","ps":"VMessNode","add":"1.2.3.4","port":"443","id":"aaaa-bbbb","aid":"0","net":"ws","type":"none","host":"h.com","path":"/p","tls":"tls"}
        """
        let b64 = Data(json.utf8).base64EncodedString()
        let cfg = try LinkParser.parse("vmess://\(b64)")
        XCTAssertEqual(cfg.proto, .vmess)
        XCTAssertEqual(cfg.address, "1.2.3.4")
        XCTAssertEqual(cfg.port, 443)
        XCTAssertEqual(cfg.uuid, "aaaa-bbbb")
        XCTAssertEqual(cfg.network, .ws)
        XCTAssertEqual(cfg.security, .tls)
        XCTAssertEqual(cfg.name, "VMessNode")
    }

    func testTrojanDefaultsTLS() throws {
        let cfg = try LinkParser.parse("trojan://pass123@t.example.com:443?sni=t.example.com#Trojan")
        XCTAssertEqual(cfg.proto, .trojan)
        XCTAssertEqual(cfg.password, "pass123")
        XCTAssertEqual(cfg.security, .tls)
        XCTAssertEqual(cfg.sni, "t.example.com")
    }

    func testShadowsocksSIP002() throws {
        // userinfo = base64("aes-256-gcm:secretpass")
        let userinfo = Data("aes-256-gcm:secretpass".utf8).base64EncodedString()
        let cfg = try LinkParser.parse("ss://\(userinfo)@ss.example.com:8388#SS")
        XCTAssertEqual(cfg.proto, .shadowsocks)
        XCTAssertEqual(cfg.method, "aes-256-gcm")
        XCTAssertEqual(cfg.password, "secretpass")
        XCTAssertEqual(cfg.address, "ss.example.com")
        XCTAssertEqual(cfg.port, 8388)
    }

    func testParseManySkipsInvalid() {
        let text = """
        vless://abc@h1.com:443?encryption=none#A
        not-a-link
        trojan://p@h2.com:443#B
        """
        let result = LinkParser.parseMany(text)
        XCTAssertEqual(result.count, 2)
    }

    func testUnsupportedScheme() {
        XCTAssertThrowsError(try LinkParser.parse("ftp://whatever"))
    }
}

final class XrayConfigBuilderTests: XCTestCase {

    func testVLESSConfigStructure() throws {
        var cfg = ProxyConfig(name: "t", proto: .vless, address: "h.com", port: 443)
        cfg.uuid = "uuid-1"
        cfg.security = .reality
        cfg.publicKey = "pbk"
        cfg.flow = "xtls-rprx-vision"

        let dict = XrayConfigBuilder.build(for: cfg)
        let outbounds = dict["outbounds"] as! [[String: Any]]
        let proxy = outbounds.first { ($0["tag"] as? String) == "proxy" }!
        XCTAssertEqual(proxy["protocol"] as? String, "vless")

        let settings = proxy["settings"] as! [String: Any]
        let vnext = settings["vnext"] as! [[String: Any]]
        XCTAssertEqual(vnext[0]["address"] as? String, "h.com")
        let user = (vnext[0]["users"] as! [[String: Any]])[0]
        XCTAssertEqual(user["id"] as? String, "uuid-1")
        XCTAssertEqual(user["flow"] as? String, "xtls-rprx-vision")

        let stream = proxy["streamSettings"] as! [String: Any]
        XCTAssertEqual(stream["security"] as? String, "reality")
        let reality = stream["realitySettings"] as! [String: Any]
        XCTAssertEqual(reality["publicKey"] as? String, "pbk")
    }

    func testInboundsPresent() throws {
        let cfg = ProxyConfig(name: "t", proto: .trojan, address: "h", port: 1)
        let dict = XrayConfigBuilder.build(for: cfg)
        let inbounds = dict["inbounds"] as! [[String: Any]]
        let protocols = inbounds.compactMap { $0["protocol"] as? String }
        XCTAssertTrue(protocols.contains("socks"))
        XCTAssertTrue(protocols.contains("http"))
    }

    func testProducesValidJSON() throws {
        let cfg = ProxyConfig(name: "t", proto: .shadowsocks, address: "h", port: 1)
        let data = try XrayConfigBuilder.jsonData(for: cfg)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }
}

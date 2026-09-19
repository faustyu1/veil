import XCTest
@testable import XrayClient

/// The router is covered without a socket elsewhere; this one proves the
/// transport around it actually serves, and that the token is enforced by the
/// thing listening rather than only by the tests' idea of it.

@MainActor
final class ControlServerLiveTests: XCTestCase {
    private final class Backend: ControlBackend {
        func state() -> ControlState {
            ControlState(version: "t", connection: "disconnected", mode: "tun",
                         activeServerID: nil, activeServerName: "", uptimeSeconds: nil,
                         preset: "bypassLAN", ruleCount: 0, groupCount: 0,
                         serverCount: 0, nativeCore: true, processRoutingAvailable: true)
        }
        func servers() -> [ControlServerInfo] { [] }
        func apps(matching query: String, limit: Int) -> [ControlApp] { [] }
        func rules() -> [RoutingRule] { [] }
        func setRules(_ rules: [RoutingRule]) {}
        func groups() -> [ServerGroup] { [] }
        func setGroups(_ groups: [ServerGroup]) {}
        func dns() -> DNSSettings { DNSSettings() }
        func setDNS(_ dns: DNSSettings) {}
        func preset() -> RoutingPreset { .bypassLAN }
        func setPreset(_ preset: RoutingPreset) {}
        func connect(serverID: UUID) throws {}
        func disconnect() {}
        func renderedProfile() throws -> String { "{}" }
        func sources() -> [ControlSource] { [] }
        func refreshSources() {}
        func annotations() -> [UUID: NodeAnnotation] { [:] }
        func setAnnotations(_ annotations: [UUID: NodeAnnotation]) {}
        func log() -> String { "" }
        func diagnostics() -> String { "" }
        func apply() {}
    }

    func testServesOverTheLoopback() async throws {
        let server = ControlServer()
        // A fixed port would collide with whatever else the machine — or CI —
        // happens to be running.
        guard let port = PortAllocator.free(count: 1, from: 19400).first else {
            return XCTFail("no free port to test on")
        }
        server.start(port: port, backend: Backend(), token: "tok")
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertTrue(server.isRunning, server.lastError ?? "not running")

        var request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/state")!)
        request.setValue("Bearer tok", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["connection"] as? String, "disconnected")

        var bad = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/v1/state")!)
        bad.setValue("Bearer nope", forHTTPHeaderField: "Authorization")
        let (_, badResponse) = try await URLSession.shared.data(for: bad)
        XCTAssertEqual((badResponse as? HTTPURLResponse)?.statusCode, 401)
        server.stop()
    }
}

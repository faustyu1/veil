// macOS-only.
#if os(macOS)
import Foundation

/// What a control-API caller may do, expressed without any transport.
///
/// The router below turns HTTP into these calls and back, so the interesting
/// half — what each endpoint means, and what it refuses — is testable without
/// opening a socket.
@MainActor
protocol ControlBackend: AnyObject {
    func state() -> ControlState
    func servers() -> [ControlServerInfo]
    func apps(matching query: String, limit: Int) -> [ControlApp]

    func rules() -> [RoutingRule]
    func setRules(_ rules: [RoutingRule])
    func groups() -> [ServerGroup]
    func setGroups(_ groups: [ServerGroup])
    func dns() -> DNSSettings
    func setDNS(_ dns: DNSSettings)
    func preset() -> RoutingPreset
    func setPreset(_ preset: RoutingPreset)

    func connect(serverID: UUID) throws
    func disconnect()
    /// The configuration the current settings would produce, for a caller that
    /// wants to check its own edit before asking for a reconnect.
    func renderedProfile() throws -> String
}

// MARK: - Wire types

/// A snapshot an assistant can orient itself with in one request.
struct ControlState: Codable {
    var version: String
    var connection: String          // disconnected | connecting | connected | failed
    var mode: String                // systemProxy | tun
    var activeServerID: UUID?
    var activeServerName: String
    var uptimeSeconds: Int?
    var preset: String
    var ruleCount: Int
    var groupCount: Int
    var serverCount: Int
    var nativeCore: Bool
    /// True when process rules can actually be enforced right now.
    var processRoutingAvailable: Bool
}

struct ControlServerInfo: Codable {
    var id: UUID
    var name: String
    var proto: String
    var address: String
    var port: Int
    var engine: String
    var group: String
    /// The outbound tag a rule would use to name this server.
    var tag: String
}

/// One application a rule can be written against.
struct ControlApp: Codable {
    var name: String
    /// What a rule must contain — sing-box matches the executable, not the
    /// name on the icon.
    var processName: String
    var path: String
    var bundleID: String?
    var running: Bool
}

struct ControlRequest {
    var method: String
    var path: String
    var query: [String: String] = [:]
    var body: Data = Data()
    var token: String?
    /// Present when a browser made the request. Any value at all is a reason
    /// to refuse: a page the user happened to open must not be able to drive
    /// the tunnel just because it can reach the loopback.
    var origin: String?
}

struct ControlResponse {
    var status: Int
    var body: Data
    var contentType = "application/json"

    static func json(_ object: Any, status: Int = 200) -> ControlResponse {
        let data = (try? JSONSerialization.data(withJSONObject: object,
                                                options: [.prettyPrinted, .sortedKeys]))
            ?? Data("{}".utf8)
        return ControlResponse(status: status, body: data)
    }

    static func encode<T: Encodable>(_ value: T, status: Int = 200) -> ControlResponse {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return .error("could not encode the response", status: 500)
        }
        return ControlResponse(status: status, body: data)
    }

    static func error(_ message: String, status: Int) -> ControlResponse {
        json(["error": message], status: status)
    }

    static let ok = ControlResponse.json(["ok": true])
}

// MARK: - Router

/// Maps requests onto the backend.
///
/// Everything here is deliberately small and boring: the API exists so an
/// assistant can read the current configuration, look up what an application
/// is really called, write rules back and ask for a reconnect. It cannot add
/// servers or read a subscription URL, because neither is needed to configure
/// routing and both are worth keeping out of reach.
@MainActor
struct ControlRouter {
    let backend: ControlBackend
    let token: String

    func handle(_ request: ControlRequest) -> ControlResponse {
        if request.origin != nil {
            return .error("cross-origin requests are not accepted", status: 403)
        }
        guard let presented = request.token,
              ControlRouter.constantTimeEqual(presented, token) else {
            return .error("missing or invalid bearer token", status: 401)
        }

        let path = request.path.hasSuffix("/") && request.path.count > 1
            ? String(request.path.dropLast()) : request.path

        switch (request.method, path) {
        case ("GET", "/v1/schema"):
            return .json(ControlRouter.schema)
        case ("GET", "/v1/state"):
            return .encode(backend.state())
        case ("GET", "/v1/servers"):
            return .encode(backend.servers())
        case ("GET", "/v1/apps"):
            let limit = Int(request.query["limit"] ?? "") ?? 50
            return .encode(backend.apps(matching: request.query["q"] ?? "",
                                        limit: max(1, min(limit, 500))))

        case ("GET", "/v1/rules"):
            return .encode(backend.rules())
        case ("PUT", "/v1/rules"):
            return decode([RoutingRule].self, request) { rules in
                backend.setRules(rules)
                return .encode(backend.rules())
            }

        case ("GET", "/v1/groups"):
            return .encode(backend.groups())
        case ("PUT", "/v1/groups"):
            return decode([ServerGroup].self, request) { groups in
                backend.setGroups(groups)
                return .encode(backend.groups())
            }

        case ("GET", "/v1/dns"):
            return .encode(backend.dns())
        case ("PUT", "/v1/dns"):
            return decode(DNSSettings.self, request) { dns in
                backend.setDNS(dns)
                return .encode(backend.dns())
            }

        case ("GET", "/v1/preset"):
            return .json(["preset": backend.preset().rawValue,
                          "available": RoutingPreset.allCases.map(\.rawValue)])
        case ("PUT", "/v1/preset"):
            return decode(PresetBody.self, request) { body in
                guard let preset = RoutingPreset(rawValue: body.preset) else {
                    return .error("unknown preset \"\(body.preset)\"", status: 400)
                }
                backend.setPreset(preset)
                return .json(["preset": preset.rawValue])
            }

        case ("GET", "/v1/config"):
            do {
                return ControlResponse(status: 200,
                                       body: Data(try backend.renderedProfile().utf8))
            } catch {
                return .error(error.localizedDescription, status: 500)
            }

        case ("POST", "/v1/connect"):
            return decode(ConnectBody.self, request) { body in
                guard let id = UUID(uuidString: body.serverID) else {
                    return .error("serverID is not a uuid", status: 400)
                }
                do {
                    try backend.connect(serverID: id)
                    return .ok
                } catch {
                    return .error(error.localizedDescription, status: 404)
                }
            }
        case ("POST", "/v1/disconnect"):
            backend.disconnect()
            return .ok

        default:
            return .error("no such endpoint: \(request.method) \(path)", status: 404)
        }
    }

    private struct ConnectBody: Decodable { var serverID: String }
    private struct PresetBody: Decodable { var preset: String }

    private func decode<T: Decodable>(_ type: T.Type, _ request: ControlRequest,
                                      _ body: (T) -> ControlResponse) -> ControlResponse {
        do {
            return body(try JSONDecoder().decode(type, from: request.body))
        } catch {
            return .error("could not read the request body: \(error)", status: 400)
        }
    }

    /// Compares without leaking where two tokens start to differ.
    static func constantTimeEqual(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.utf8), b = Array(rhs.utf8)
        guard a.count == b.count, !a.isEmpty else { return false }
        var difference: UInt8 = 0
        for index in a.indices { difference |= a[index] ^ b[index] }
        return difference == 0
    }

    /// Enough for a caller to work the API without documentation — which is
    /// the point: the assistant reads this first and goes from there.
    static let schema: [String: Any] = [
        "name": "Veil control API",
        "auth": "Authorization: Bearer <token from Veil → Settings → Control API>",
        "notes": [
            "Rules are ordered; the first match wins.",
            "A rule's target is \"proxy\", \"direct\", \"block\", \"server:<uuid>\" or \"group:<uuid>\".",
            "processNames must hold executable names — look them up with GET /v1/apps.",
            "Changes take effect on the next connect; POST /v1/connect to apply them now."
        ],
        "endpoints": [
            ["GET /v1/state", "connection, mode, counts, whether process rules can be enforced"],
            ["GET /v1/servers", "servers with the tag a rule uses to name them"],
            ["GET /v1/apps?q=&limit=", "installed and running applications, with executable names"],
            ["GET /v1/rules", "the ordered routing rules"],
            ["PUT /v1/rules", "replace the routing rules with the posted array"],
            ["GET /v1/groups", "server groups"],
            ["PUT /v1/groups", "replace the groups"],
            ["GET /v1/dns", "resolver settings"],
            ["PUT /v1/dns", "replace the resolver settings"],
            ["GET /v1/preset", "current preset and the available ones"],
            ["PUT /v1/preset", "{\"preset\": \"bypassLAN\"}"],
            ["GET /v1/config", "the configuration the current settings would produce"],
            ["POST /v1/connect", "{\"serverID\": \"<uuid>\"}"],
            ["POST /v1/disconnect", "stop the tunnel"]
        ]
    ]
}
#endif

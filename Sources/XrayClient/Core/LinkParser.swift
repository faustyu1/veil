import Foundation

enum LinkParseError: Error, LocalizedError {
    case unsupportedScheme(String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedScheme(let s): return "Unsupported link scheme: \(s)"
        case .malformed(let s): return "Malformed link: \(s)"
        }
    }
}

/// Parses proxy share links into `ProxyConfig`.
///
/// Supported:
///   vless://uuid@host:port?params#name
///   vmess://<base64 json>
///   trojan://password@host:port?params#name
///   ss://<base64 method:password>@host:port#name  (and SIP002 variants)
enum LinkParser {

    static func parse(_ raw: String) throws -> ProxyConfig {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let schemeEnd = line.range(of: "://") else {
            throw LinkParseError.malformed(line)
        }
        let scheme = String(line[line.startIndex..<schemeEnd.lowerBound]).lowercased()

        switch scheme {
        case "vless":   return try parseVLESS(line)
        case "vmess":   return try parseVMess(line)
        case "trojan":  return try parseTrojan(line)
        case "ss":      return try parseShadowsocks(line)
        default:        throw LinkParseError.unsupportedScheme(scheme)
        }
    }

    /// Parse many links separated by newlines, skipping any that fail.
    static func parseMany(_ text: String) -> [ProxyConfig] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            try? parse(String(line))
        }
    }

    // MARK: - VLESS

    private static func parseVLESS(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let uuid = comps.user,
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .vless, address: host, port: port)
        cfg.uuid = uuid
        let q = queryDict(comps)
        cfg.encryption = q["encryption"] ?? "none"
        cfg.flow = q["flow"]
        applyTransport(&cfg, query: q)
        applySecurity(&cfg, query: q)
        return cfg
    }

    // MARK: - VMess (base64-encoded JSON payload)

    private static func parseVMess(_ line: String) throws -> ProxyConfig {
        let b64 = String(line.dropFirst("vmess://".count))
        guard let data = decodeBase64(b64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LinkParseError.malformed(line)
        }
        func str(_ k: String) -> String? {
            if let s = json[k] as? String { return s }
            if let n = json[k] as? NSNumber { return n.stringValue }
            return nil
        }
        guard let host = str("add"),
              let portStr = str("port"), let port = Int(portStr),
              let id = str("id") else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: str("ps") ?? host,
                              proto: .vmess, address: host, port: port)
        cfg.uuid = id
        cfg.alterId = Int(str("aid") ?? "0")
        cfg.network = TransportNetwork(rawValue: str("net") ?? "tcp") ?? .tcp
        cfg.path = str("path")
        cfg.host = str("host")
        cfg.serviceName = str("path") // grpc uses path field for serviceName in vmess links
        let tls = (str("tls") ?? "").lowercased()
        cfg.security = tls.contains("reality") ? .reality : (tls == "tls" ? .tls : .none)
        cfg.sni = str("sni") ?? str("host")
        if let alpn = str("alpn") { cfg.alpn = alpn.split(separator: ",").map(String.init) }
        return cfg
    }

    // MARK: - Trojan

    private static func parseTrojan(_ line: String) throws -> ProxyConfig {
        guard let comps = URLComponents(string: line),
              let pwd = comps.user,
              let host = comps.host,
              let port = comps.port else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: fragmentName(comps) ?? host,
                              proto: .trojan, address: host, port: port)
        cfg.password = pwd.removingPercentEncoding ?? pwd
        let q = queryDict(comps)
        applyTransport(&cfg, query: q)
        // Trojan defaults to TLS unless explicitly told otherwise.
        if q["security"] == nil { cfg.security = .tls }
        applySecurity(&cfg, query: q)
        return cfg
    }

    // MARK: - Shadowsocks (SIP002 + legacy base64)

    private static func parseShadowsocks(_ line: String) throws -> ProxyConfig {
        let name = URLComponents(string: line).flatMap(fragmentName)
        // Strip scheme and fragment.
        var body = String(line.dropFirst("ss://".count))
        if let hash = body.firstIndex(of: "#") { body = String(body[body.startIndex..<hash]) }

        var method: String?
        var password: String?
        var host: String?
        var port: Int?

        if let atIdx = body.firstIndex(of: "@") {
            // SIP002: ss://base64(method:pass)@host:port  OR  ss://method:pass@host:port
            let userInfo = String(body[body.startIndex..<atIdx])
            let hostPart = String(body[body.index(after: atIdx)...])
            let decodedUserInfo = decodeBase64(userInfo).flatMap { String(data: $0, encoding: .utf8) } ?? userInfo
            let mp = decodedUserInfo.split(separator: ":", maxSplits: 1).map(String.init)
            if mp.count == 2 { method = mp[0]; password = mp[1] }
            (host, port) = splitHostPort(hostPart)
        } else {
            // Legacy: ss://base64(method:pass@host:port)
            guard let data = decodeBase64(body),
                  let decoded = String(data: data, encoding: .utf8),
                  let atIdx = decoded.firstIndex(of: "@") else {
                throw LinkParseError.malformed(line)
            }
            let userInfo = String(decoded[decoded.startIndex..<atIdx])
            let hostPart = String(decoded[decoded.index(after: atIdx)...])
            let mp = userInfo.split(separator: ":", maxSplits: 1).map(String.init)
            if mp.count == 2 { method = mp[0]; password = mp[1] }
            (host, port) = splitHostPort(hostPart)
        }

        guard let h = host, let p = port, let m = method, let pw = password else {
            throw LinkParseError.malformed(line)
        }
        var cfg = ProxyConfig(name: name ?? h, proto: .shadowsocks, address: h, port: p)
        cfg.method = m
        cfg.password = pw
        return cfg
    }

    // MARK: - Shared helpers

    private static func applyTransport(_ cfg: inout ProxyConfig, query q: [String: String]) {
        if let net = q["type"] ?? q["net"] {
            cfg.network = TransportNetwork(rawValue: net) ?? .tcp
        }
        cfg.path = q["path"]?.removingPercentEncoding ?? q["path"]
        cfg.host = q["host"]?.removingPercentEncoding ?? q["host"]
        cfg.serviceName = q["serviceName"]?.removingPercentEncoding ?? q["serviceName"]
    }

    private static func applySecurity(_ cfg: inout ProxyConfig, query q: [String: String]) {
        if let sec = q["security"] {
            cfg.security = StreamSecurity(rawValue: sec) ?? .none
        }
        cfg.sni = q["sni"] ?? q["peer"] ?? cfg.host
        cfg.fingerprint = q["fp"]
        if let alpn = q["alpn"]?.removingPercentEncoding {
            cfg.alpn = alpn.split(separator: ",").map(String.init)
        }
        cfg.allowInsecure = (q["allowInsecure"] == "1" || q["allowInsecure"] == "true")
        // Reality
        cfg.publicKey = q["pbk"]
        cfg.shortId = q["sid"]
        cfg.spiderX = q["spx"]?.removingPercentEncoding
    }

    private static func queryDict(_ comps: URLComponents) -> [String: String] {
        var dict: [String: String] = [:]
        for item in comps.queryItems ?? [] {
            dict[item.name] = item.value
        }
        return dict
    }

    private static func fragmentName(_ comps: URLComponents) -> String? {
        guard let frag = comps.fragment, !frag.isEmpty else { return nil }
        return frag.removingPercentEncoding ?? frag
    }

    private static func splitHostPort(_ s: String) -> (String?, Int?) {
        guard let colon = s.lastIndex(of: ":") else { return (s, nil) }
        let host = String(s[s.startIndex..<colon])
        let port = Int(s[s.index(after: colon)...])
        return (host, port)
    }

    /// Decode base64 tolerant of URL-safe alphabet and missing padding.
    static func decodeBase64(_ s: String) -> Data? {
        var str = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let remainder = str.count % 4
        if remainder > 0 {
            str.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: str)
    }
}

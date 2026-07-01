import Foundation

/// Fetches a subscription URL and decodes it into servers + optional metadata.
enum SubscriptionFetcher {

    struct Result {
        var servers: [ProxyConfig]
        var userinfo: SubscriptionUserinfo.Info?
        var profileTitle: String?   // from Profile-Title header, if present
        var announce: String?       // from Announce header (provider description)
    }

    static func fetch(_ urlString: String, hwid: String? = nil) async throws -> Result {
        guard var components = URLComponents(string: urlString) else {
            throw LinkParseError.malformed(urlString)
        }
        if let hwid, !hwid.isEmpty {
            var items = components.queryItems ?? []
            items.removeAll { $0.name == "hwid" }
            items.append(URLQueryItem(name: "hwid", value: hwid))
            components.queryItems = items
        }
        guard let url = components.url else {
            throw LinkParseError.malformed(urlString)
        }
        var request = URLRequest(url: url)
        request.setValue("Veil/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let body = String(data: data, encoding: .utf8) else {
            throw LinkParseError.malformed("subscription: non-text response")
        }
        let servers = decode(body)

        var info: SubscriptionUserinfo.Info?
        var title: String?
        var announce: String?
        if let http = response as? HTTPURLResponse {
            if let header = headerValue(http, "Subscription-Userinfo") {
                info = SubscriptionUserinfo.parse(header)
            }
            title = decodeMaybeBase64(headerValue(http, "Profile-Title"))
            announce = decodeMaybeBase64(headerValue(http, "Announce"))
        }
        return Result(servers: servers, userinfo: info,
                      profileTitle: title, announce: announce)
    }

    /// Decodes a header that may be prefixed with "base64:" (panels use this for
    /// Profile-Title and Announce). Returns the plain string otherwise.
    private static func decodeMaybeBase64(_ value: String?) -> String? {
        guard let v = value, !v.isEmpty else { return nil }
        if v.lowercased().hasPrefix("base64:"),
           let d = LinkParser.decodeBase64(String(v.dropFirst(7))),
           let decoded = String(data: d, encoding: .utf8) {
            return decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return v
    }

    private static func headerValue(_ http: HTTPURLResponse, _ name: String) -> String? {
        if #available(macOS 13.0, *) {
            return http.value(forHTTPHeaderField: name)
        }
        return http.allHeaderFields[name] as? String
    }

    /// Decode a subscription body that may be base64-wrapped or plain text.
    static func decode(_ body: String) -> [ProxyConfig] {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = LinkParser.decodeBase64(trimmed),
           let decoded = String(data: data, encoding: .utf8),
           decoded.contains("://") {
            return LinkParser.parseMany(decoded)
        }
        return LinkParser.parseMany(trimmed)
    }
}

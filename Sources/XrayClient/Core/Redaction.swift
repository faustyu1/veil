import Foundation

/// Strips secrets out of anything that leaves the app: system log lines, the
/// in-app log view and the diagnostics export.
///
/// Subscription URLs are bearer credentials — the path segment *is* the token
/// for every panel Veil talks to — so a URL is never logged whole. The same
/// goes for the HWID, UUIDs, passwords and pre-shared keys that live inside a
/// share link or a core config.
enum Redaction {

    /// Placeholder written in place of a secret.
    static let placeholder = "<redacted>"

    // MARK: - URLs

    /// Keeps only the parts of a URL that are useful in a log — scheme, host
    /// and port — and drops the path, query, fragment and any userinfo.
    ///
    ///     https://panel.example.com:8443/sub/abc123?hwid=x
    ///     -> https://panel.example.com:8443/<redacted>
    static func url(_ string: String) -> String {
        guard let components = URLComponents(string: string),
              let host = components.host, !host.isEmpty else {
            return placeholder
        }
        let scheme = components.scheme ?? "https"
        var result = "\(scheme)://\(host)"
        if let port = components.port { result += ":\(port)" }
        let hasTail = !(components.path.isEmpty || components.path == "/")
            || components.query != nil
            || components.fragment != nil
        if hasTail { result += "/\(placeholder)" }
        return result
    }

    // MARK: - Identifiers

    /// Renders an identifier as a short fingerprint: enough to correlate two
    /// log lines, not enough to reuse the value.
    ///
    ///     3F2504E0-4F89-11D3-9A0C-0305E82C3301 -> 3F25…3301
    static func fingerprint(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "<none>" }
        guard value.count > 12 else { return placeholder }
        return "\(value.prefix(4))…\(value.suffix(4))"
    }

    // MARK: - Free-form text

    /// Redacts every secret-looking substring in a block of text. Used for the
    /// core's own log output and for the diagnostics export, where the content
    /// is not under our control.
    ///
    /// `knownSecrets` are literal values (subscription URLs, HWIDs, UUIDs held
    /// in memory) that are replaced first, before the heuristics run.
    static func text(_ input: String, knownSecrets: [String] = []) -> String {
        var output = input

        for secret in knownSecrets.sorted(by: { $0.count > $1.count })
        where secret.count >= 6 {
            output = output.replacingOccurrences(of: secret, with: placeholder)
        }

        output = replaceURLs(in: output)
        output = replace(in: output, pattern: sensitiveAssignmentPattern,
                         template: "$1$2\(placeholder)")
        output = replace(in: output, pattern: uuidPattern, template: placeholder)
        output = replace(in: output, pattern: longTokenPattern, template: placeholder)
        return output
    }

    // MARK: - Patterns

    /// `scheme://…` up to the first whitespace or quote.
    private static let urlPattern = "[a-zA-Z][a-zA-Z0-9+.-]*://[^\\s\"'<>`]+"

    /// `password: xxx`, `token=xxx`, `"uuid" : "xxx"` and friends. Group 1 is
    /// the key, group 2 the separator, so the shape of the line survives.
    private static let sensitiveAssignmentPattern =
        "(?i)(\"?(?:password|passwd|pass|token|secret|api[-_]?key|authorization|"
        + "auth|hwid|device[-_]?id|uuid|user[-_]?id|psk|pre[-_]?shared[-_]?key|"
        + "private[-_]?key|privatekey|seed)\"?)(\\s*[:=]\\s*\"?)([^\\s\",;}]+)"

    private static let uuidPattern =
        "\\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\\b"

    /// A long run of base64url/hex characters — subscription tokens, Reality
    /// keys, short IDs. Short enough words are left alone so prose survives.
    private static let longTokenPattern = "\\b[A-Za-z0-9_-]{28,}\\b"

    private static func replaceURLs(in input: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: urlPattern) else { return input }
        let full = NSRange(input.startIndex..<input.endIndex, in: input)
        var output = input
        // Walk matches back-to-front so earlier ranges stay valid.
        for match in regex.matches(in: input, range: full).reversed() {
            guard let range = Range(match.range, in: input) else { continue }
            let redacted = url(String(input[range]))
            guard let outRange = Range(match.range, in: output) else { continue }
            output.replaceSubrange(outRange, with: redacted)
        }
        return output
    }

    private static func replace(in input: String, pattern: String, template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return input }
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: template)
    }
}

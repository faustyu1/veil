import Foundation

/// Everything a panel tells the client in the response headers of a
/// subscription fetch.
///
/// Veil used to read three of these (`subscription-userinfo`, `profile-title`,
/// `announce`) and drop the rest, so the update interval the panel asked for,
/// its support links and every HWID error were invisible. This type carries the
/// whole contract.
struct SubscriptionMetadata: Equatable {

    /// What the panel said about the HWID we presented.
    enum HWIDStatus: String, Codable, Equatable {
        /// The panel said nothing about the HWID.
        case unknown
        /// The device is registered and in good standing.
        case active
        /// The panel does not do HWID at all — stop sending it.
        case notSupported
        /// The account is at its device limit; this device was refused.
        case maxDevicesReached
    }

    var userinfo: SubscriptionUserinfo.Info?
    var profileTitle: String?
    var announce: String?
    /// Minutes between refreshes, as requested by the panel.
    var updateIntervalMinutes: Int?
    var supportURL: String?
    var webPageURL: String?
    /// When the plan's traffic allowance is next topped up.
    var refillDate: Date?
    var hwidStatus: HWIDStatus = .unknown

    /// Hours the client should wait between refreshes, rounded up to a whole
    /// hour and clamped to something sane. `nil` when the panel didn't say.
    var updateIntervalHours: Int? {
        guard let minutes = updateIntervalMinutes, minutes > 0 else { return nil }
        return min(max(1, (minutes + 59) / 60), 24 * 7)
    }

    /// True when the panel refused the device and the user has to act.
    var needsUserAction: Bool { hwidStatus == .maxDevicesReached }
}

/// Parses the Remnawave / Happ subscription response headers.
enum RemnawaveHeaders {

    /// Header names are case-insensitive per RFC 9110, and panels are
    /// inconsistent about them (`Profile-Title` vs `profile-title`), so the
    /// whole dictionary is lowercased before anything is looked up.
    static func parse(_ headers: [AnyHashable: Any]) -> SubscriptionMetadata {
        var lower: [String: String] = [:]
        for (key, value) in headers {
            guard let name = key as? String else { continue }
            lower[name.lowercased()] = String(describing: value)
        }
        return parse(lowercased: lower)
    }

    static func parse(lowercased headers: [String: String]) -> SubscriptionMetadata {
        var meta = SubscriptionMetadata()

        if let raw = headers["subscription-userinfo"] {
            meta.userinfo = SubscriptionUserinfo.parse(raw)
        }
        meta.profileTitle = decodeMaybeBase64(headers["profile-title"])
        meta.announce = decodeMaybeBase64(headers["announce"])
        meta.supportURL = trimmed(headers["support-url"])
        meta.webPageURL = trimmed(headers["profile-web-page-url"])

        if let raw = headers["profile-update-interval"] {
            meta.updateIntervalMinutes = updateInterval(raw)
        }
        if let raw = headers["subscription-refill-date"] {
            meta.refillDate = date(raw)
        }
        meta.hwidStatus = hwidStatus(headers)
        return meta
    }

    // MARK: - Pieces

    /// `profile-update-interval` is documented in days, but panels in the wild
    /// send hours and minutes too. The unit is inferred from the magnitude,
    /// with an explicit suffix (`30m`, `6h`, `2d`) always winning.
    static func updateInterval(_ raw: String) -> Int? {
        let value = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !value.isEmpty else { return nil }

        let digits = value.prefix { $0.isNumber || $0 == "." }
        guard let number = Double(digits), number > 0 else { return nil }
        let suffix = value.dropFirst(digits.count).trimmingCharacters(in: .whitespaces)

        switch suffix {
        case "m", "min", "mins", "minute", "minutes": return Int(number)
        case "h", "hr", "hrs", "hour", "hours":       return Int(number * 60)
        case "d", "day", "days":                      return Int(number * 24 * 60)
        case "":
            // Bare numbers: Remnawave documents days, and no panel asks a client
            // to refresh more than a handful of times a day, so small values are
            // days and anything large is already minutes.
            return number <= 30 ? Int(number * 24 * 60) : Int(number)
        default:
            return nil
        }
    }

    /// Accepts an ISO-8601 timestamp, a bare `YYYY-MM-DD` date, or epoch
    /// seconds — all three turn up in the wild.
    static func date(_ raw: String) -> Date? {
        let value = raw.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return nil }

        if let epoch = TimeInterval(value), epoch > 0 {
            // Panels that send milliseconds are far past any plausible date.
            return Date(timeIntervalSince1970: epoch > 4_000_000_000 ? epoch / 1000 : epoch)
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = iso.date(from: value) { return parsed }
        iso.formatOptions = [.withInternetDateTime]
        if let parsed = iso.date(from: value) { return parsed }

        let plain = DateFormatter()
        plain.locale = Locale(identifier: "en_US_POSIX")
        plain.timeZone = TimeZone(secondsFromGMT: 0)
        plain.dateFormat = "yyyy-MM-dd"
        return plain.date(from: value)
    }

    private static func hwidStatus(_ headers: [String: String]) -> SubscriptionMetadata.HWIDStatus {
        // Order matters: a refusal outranks "active" if a panel sends both.
        if isSet(headers["x-hwid-max-devices-reached"]) { return .maxDevicesReached }
        if isSet(headers["x-hwid-not-supported"]) { return .notSupported }
        if isSet(headers["x-hwid-active"]) { return .active }
        return .unknown
    }

    /// A flag header counts as set unless it explicitly says otherwise — panels
    /// send `true`, `1`, or an empty value to mean the same thing.
    private static func isSet(_ value: String?) -> Bool {
        guard let value else { return false }
        let normalized = value.trimmingCharacters(in: .whitespaces).lowercased()
        return !["false", "0", "no", "off"].contains(normalized)
    }

    /// Decodes a header that may be prefixed with `base64:` (panels use this
    /// for Profile-Title and Announce). Returns the plain string otherwise.
    static func decodeMaybeBase64(_ value: String?) -> String? {
        guard let raw = trimmed(value) else { return nil }
        guard raw.lowercased().hasPrefix("base64:") else { return raw }
        guard let data = LinkParser.decodeBase64(String(raw.dropFirst(7))),
              let decoded = String(data: data, encoding: .utf8) else {
            return raw
        }
        let result = decoded.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }
}

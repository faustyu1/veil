import Foundation

/// A subscription profile: a named group of servers fetched from one URL,
/// with optional traffic/expiry metadata (parsed from the Subscription-Userinfo
/// HTTP header that most panels return).
struct Subscription: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var url: String?               // nil for the manual/local group
    var servers: [ProxyConfig] = []
    /// Groups this subscription's panel declared in its config, over
    /// `servers`. Refreshed with the node list and never merged with the
    /// user's own groups: the panel owns these, the user owns those.
    ///
    /// Optional so that stores written by older builds still decode — the
    /// whole file is read with one `try?`, so a key a 1.6.3 store cannot
    /// contain would empty every subscription on upgrade.
    var groups: [ServerGroup]?

    /// The declared groups, or none.
    var declaredGroups: [ServerGroup] { groups ?? [] }
    var lastUpdated: Date?
    var autoUpdate: Bool = true
    var isCollapsed: Bool = false
    var note: String?              // free-form description

    /// True when `url` lives in the Keychain rather than in `store.json`.
    /// Optional so that stores written by older builds still decode.
    var hasStoredURL: Bool?

    // Panel metadata (see `SubscriptionMetadata`). All optional: a panel that
    // says nothing leaves them nil.
    var supportURL: String?
    var webPageURL: String?
    var updateIntervalHours: Int?  // refresh cadence the panel asked for
    var refillDate: Date?          // when the traffic allowance is topped up
    var hwidStatus: SubscriptionMetadata.HWIDStatus?
    var lastFormat: SubscriptionPayload.Format?

    /// Per-subscription overrides. nil means "follow the global setting".
    var sendHWID: Bool?
    var userAgentOverride: String?

    // Traffic accounting (bytes). nil when the panel doesn't report it.
    var uploadBytes: Int64?
    var downloadBytes: Int64?
    var totalBytes: Int64?
    var expiresAt: Date?           // from `expire=` epoch seconds

    init(name: String, url: String? = nil) {
        self.name = name
        self.url = url
    }

    var usedBytes: Int64? {
        guard let up = uploadBytes, let down = downloadBytes else { return nil }
        return up + down
    }

    /// 0...1 fraction of traffic used, when both used and total are known.
    var usageFraction: Double? {
        guard let used = usedBytes, let total = totalBytes, total > 0 else { return nil }
        return min(1.0, Double(used) / Double(total))
    }

    /// True when the plan has no traffic cap. Panels say so by sending
    /// `total=0` — which `ByteCountFormatter` renders as "Zero KB", a quota of
    /// nothing rather than the unlimited one it means.
    var isUnlimitedTraffic: Bool {
        guard let total = totalBytes else { return false }
        return total <= 0
    }

    /// True when there is any traffic figure worth putting on screen.
    var hasTrafficInfo: Bool { usedBytes != nil }

    /// The manual/local group is the one that never had a URL. A subscription
    /// whose URL is in the Keychain is not manual even while `url` is nil.
    var isManual: Bool { url == nil && hasStoredURL != true }

    /// Applies what the panel reported in the response headers.
    mutating func apply(_ metadata: SubscriptionMetadata) {
        if let info = metadata.userinfo {
            uploadBytes = info.upload
            downloadBytes = info.download
            totalBytes = info.total
            expiresAt = info.expire
        }
        if let announce = metadata.announce { note = announce }
        if let support = metadata.supportURL { supportURL = support }
        if let page = metadata.webPageURL { webPageURL = page }
        if let hours = metadata.updateIntervalHours { updateIntervalHours = hours }
        if let refill = metadata.refillDate { refillDate = refill }
        if metadata.hwidStatus != .unknown { hwidStatus = metadata.hwidStatus }
    }

    /// How long to wait before refreshing, honouring the panel's own request
    /// when it made one.
    func refreshInterval(defaultHours: Int) -> TimeInterval {
        TimeInterval(max(1, updateIntervalHours ?? defaultHours) * 3600)
    }
}

/// Parses the `Subscription-Userinfo` response header, e.g.
/// `upload=1234; download=5678; total=10737418240; expire=1700000000`.
enum SubscriptionUserinfo {
    struct Info: Equatable {
        var upload: Int64?
        var download: Int64?
        var total: Int64?
        var expire: Date?
    }

    static func parse(_ header: String) -> Info {
        var info = Info()
        for pair in header.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            let key = kv[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = kv[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "upload":   info.upload = Int64(value)
            case "download": info.download = Int64(value)
            case "total":    info.total = Int64(value)
            case "expire":
                if let epoch = TimeInterval(value), epoch > 0 {
                    info.expire = Date(timeIntervalSince1970: epoch)
                }
            default: break
            }
        }
        return info
    }
}

/// Human-readable byte formatting (GB/MB/etc.).
enum ByteFormat {
    static func string(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        return formatter.string(fromByteCount: bytes)
    }
}

import Foundation

/// A ready-made list of domains (and, where one exists, the matching subnets)
/// maintained by the community.
///
/// These come from `itdoginfo/allow-domains`, the same source OpenWrt's podkop
/// and a dozen router scripts use. The point is that the user picks "Telegram"
/// or "Russia inside" instead of pasting a thousand domains into a rule: the
/// list is fetched, cached and refreshed on its own.
struct CommunityList: Identifiable, Hashable, Sendable {

    enum Category: String, CaseIterable, Identifiable, Sendable {
        case region, service, content
        var id: String { rawValue }

        var title: String {
            switch self {
            case .region:  return "Regions"
            case .service: return "Services"
            case .content: return "Categories"
            }
        }
    }

    /// Stable identifier stored in `store.json`. Never derived from the title,
    /// which is translated.
    let id: String
    /// English title; the localisation table carries the rest.
    let title: String
    let category: Category
    /// Path of the domain list inside the repository.
    let domainPath: String
    /// Path of the IPv4 subnet list, when the source publishes one. Some
    /// services (Telegram, Discord, Meta) hand out addresses their domains
    /// never resolve to, so the subnets matter as much as the names.
    let ipv4Path: String?
    let ipv6Path: String?

    init(id: String, title: String, category: Category,
         domainPath: String, ipv4Path: String? = nil, ipv6Path: String? = nil) {
        self.id = id
        self.title = title
        self.category = category
        self.domainPath = domainPath
        self.ipv4Path = ipv4Path
        self.ipv6Path = ipv6Path
    }
}

/// Everything Veil offers, in the order it is shown.
enum CommunityListCatalog {

    /// Where the lists are published, and the branch they are read from.
    static let repository = "itdoginfo/allow-domains"
    static let branch = "main"
    static let homepage = "https://github.com/itdoginfo/allow-domains"

    static func rawURL(_ path: String) -> URL {
        URL(string: "https://raw.githubusercontent.com/\(repository)/\(branch)/\(path)")!
    }

    static let all: [CommunityList] = [
        // Regions
        .init(id: "ru-inside", title: "Russia inside", category: .region,
              domainPath: "Russia/inside-raw.lst"),
        .init(id: "ru-outside", title: "Russia outside", category: .region,
              domainPath: "Russia/outside-raw.lst"),
        .init(id: "ua-inside", title: "Ukraine", category: .region,
              domainPath: "Ukraine/inside-raw.lst"),

        // Categories
        .init(id: "geoblock", title: "Geo Block", category: .content,
              domainPath: "Categories/geoblock.lst"),
        .init(id: "block", title: "Block", category: .content,
              domainPath: "Categories/block.lst"),
        .init(id: "news", title: "News", category: .content,
              domainPath: "Categories/news.lst"),
        .init(id: "anime", title: "Anime", category: .content,
              domainPath: "Categories/anime.lst"),
        .init(id: "porn", title: "Porn", category: .content,
              domainPath: "Categories/porn.lst"),
        .init(id: "hodca", title: "H.O.D.C.A", category: .content,
              domainPath: "Categories/hodca.lst"),

        // Services
        .init(id: "youtube", title: "YouTube", category: .service,
              domainPath: "Services/youtube.lst"),
        .init(id: "telegram", title: "Telegram", category: .service,
              domainPath: "Services/telegram.lst",
              ipv4Path: "Subnets/IPv4/telegram.lst",
              ipv6Path: "Subnets/IPv6/telegram.lst"),
        .init(id: "discord", title: "Discord", category: .service,
              domainPath: "Services/discord.lst",
              ipv4Path: "Subnets/IPv4/discord.lst",
              ipv6Path: "Subnets/IPv6/discord.lst"),
        .init(id: "meta", title: "Meta", category: .service,
              domainPath: "Services/meta.lst",
              ipv4Path: "Subnets/IPv4/meta.lst",
              ipv6Path: "Subnets/IPv6/meta.lst"),
        .init(id: "twitter", title: "Twitter (X)", category: .service,
              domainPath: "Services/twitter.lst",
              ipv4Path: "Subnets/IPv4/twitter.lst",
              ipv6Path: "Subnets/IPv6/twitter.lst"),
        .init(id: "tiktok", title: "TikTok", category: .service,
              domainPath: "Services/tiktok.lst"),
        .init(id: "hdrezka", title: "HDRezka", category: .service,
              domainPath: "Services/hdrezka.lst"),
        .init(id: "roblox", title: "Roblox", category: .service,
              domainPath: "Services/roblox.lst",
              ipv4Path: "Subnets/IPv4/roblox.lst"),
        .init(id: "google-ai", title: "Google AI", category: .service,
              domainPath: "Services/google_ai.lst"),
        .init(id: "google-play", title: "Google Play", category: .service,
              domainPath: "Services/google_play.lst"),
        .init(id: "google-meet", title: "Google Meet", category: .service,
              domainPath: "Services/google_meet.lst",
              ipv4Path: "Subnets/IPv4/google_meet.lst"),
        .init(id: "cloudflare", title: "Cloudflare", category: .service,
              domainPath: "Services/cloudflare.lst",
              ipv4Path: "Subnets/IPv4/cloudflare.lst",
              ipv6Path: "Subnets/IPv6/cloudflare.lst"),
        .init(id: "cloudfront", title: "CloudFront", category: .service,
              domainPath: "Services/cloudfront.lst",
              ipv4Path: "Subnets/IPv4/cloudfront.lst"),
        .init(id: "digitalocean", title: "DigitalOcean", category: .service,
              domainPath: "Services/digitalocean.lst",
              ipv4Path: "Subnets/IPv4/digitalocean.lst"),
        .init(id: "hetzner", title: "Hetzner", category: .service,
              domainPath: "Services/hetzner.lst",
              ipv4Path: "Subnets/IPv4/hetzner.lst"),
        .init(id: "ovh", title: "OVH", category: .service,
              domainPath: "Services/ovh.lst",
              ipv4Path: "Subnets/IPv4/ovh.lst"),
    ]

    static func list(id: String) -> CommunityList? {
        all.first { $0.id == id }
    }

    static func lists(in category: CommunityList.Category) -> [CommunityList] {
        all.filter { $0.category == category }
    }
}

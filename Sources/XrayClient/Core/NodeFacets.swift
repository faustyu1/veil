import Foundation

/// What a node says about itself: where it is, what it speaks, and how it is
/// carried.
///
/// Facets are derived on demand and never stored. A provider that renames a
/// node simply produces different facets on the next draw, so there is nothing
/// here that can fall out of sync with the source and nothing to migrate.
struct NodeFacets: Equatable {
    /// ISO 3166-1 alpha-2, uppercased. Nil when the name names no place.
    var country: String?
    var proto: ProxyProtocol
    var engine: CoreEngine
    var transport: TransportNetwork
    /// The trailing number in `NL-01`, which is what makes a set of nodes look
    /// like one balancer to the user.
    var balancerIndex: Int?

    init(for server: ProxyConfig) {
        country = NodeFacets.country(in: server.name, proto: server.proto)
        proto = server.proto
        engine = server.engine
        transport = server.network
        balancerIndex = NodeFacets.trailingIndex(in: server.name)
    }

    // MARK: - Display

    /// The flag emoji for an ISO code, built from its two regional indicators.
    static func flag(for code: String) -> String {
        let letters = code.uppercased().unicodeScalars
        guard letters.count == 2,
              letters.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else { return "" }
        var flag = ""
        for letter in letters {
            guard let scalar = Unicode.Scalar(letter.value - 65 + 0x1F1E6) else { return "" }
            flag.unicodeScalars.append(scalar)
        }
        return flag
    }

    /// The country's name in the given locale, or the bare code when the system
    /// does not know it — an unrecognised code is still something to show.
    static func countryName(for code: String, locale: Locale = .current) -> String {
        let code = code.uppercased()
        // An unassigned code still resolves, to "Unknown Region", which says
        // less than the code itself does.
        guard Locale.Region.isoRegions.contains(Locale.Region(code)),
              let name = locale.localizedString(forRegionCode: code) else { return code }
        return name
    }

    // MARK: - Reading a name

    /// Looks for a place in a node's name, in descending order of confidence:
    /// a flag emoji, a spelled-out country, a well-known city, and finally a
    /// bare two-letter code.
    static func country(in name: String, proto: ProxyProtocol? = nil) -> String? {
        if let fromFlag = flagCode(in: name) { return fromFlag }

        let lowered = name.lowercased()
        if let spelled = spelledOut.first(where: { lowered.contains($0.key) })?.value {
            return spelled
        }
        for token in tokens(in: lowered) where token.count == 2 {
            let code = token.uppercased()
            guard knownCodes.contains(code), !nonPlaces.contains(code) else { continue }
            // A Shadowsocks node called `SS-01` is announcing its protocol, not
            // South Sudan.
            if let proto, code == proto.rawValue.uppercased() { continue }
            return code
        }
        return nil
    }

    /// The first pair of regional indicator symbols in the name.
    private static func flagCode(in name: String) -> String? {
        let indicators = name.unicodeScalars.filter { (0x1F1E6...0x1F1FF).contains($0.value) }
        guard indicators.count >= 2 else { return nil }
        let letters = indicators.prefix(2).compactMap {
            Unicode.Scalar($0.value - 0x1F1E6 + 65).map(Character.init)
        }
        return letters.count == 2 ? String(letters) : nil
    }

    /// The trailing `-01` / `— 12` / `| 3` a provider appends to the members of
    /// one balancer.
    static func trailingIndex(in name: String) -> Int? {
        let pattern = #"[—–\-|]\s*(\d+)\s*$"#
        guard let match = name.range(of: pattern, options: .regularExpression) else { return nil }
        let digits = name[match].filter(\.isNumber)
        return Int(digits)
    }

    private static func tokens(in lowered: String) -> [String] {
        lowered.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
    }

    // MARK: - Tables

    /// The places a proxy provider actually sells. Restricting the two-letter
    /// match to this set keeps `IT`, `IS` and `AT` in a node name from turning
    /// every English word into a country.
    private static let knownCodes: Set<String> = [
        "NL", "DE", "US", "GB", "FR", "SE", "FI", "NO", "DK", "PL", "CZ", "AT",
        "CH", "ES", "IT", "PT", "IE", "RO", "BG", "HU", "SK", "LT", "LV", "EE",
        "UA", "TR", "RU", "KZ", "AM", "GE", "AZ", "MD", "RS", "HR", "SI", "GR",
        "CY", "IL", "AE", "SA", "QA", "IN", "SG", "JP", "KR", "HK", "TW", "CN",
        "TH", "VN", "MY", "ID", "PH", "AU", "NZ", "CA", "BR", "AR", "MX", "CL",
        "ZA", "EG", "NG", "KE", "LU", "BE", "IS", "MT",
    ]

    /// Codes that read as a place but almost never mean one in a node name.
    private static let nonPlaces: Set<String> = ["SS", "WS", "TG", "IO", "TV", "CC", "MU"]

    /// Cities and countries spelled out, longest first so that "New York"
    /// wins over "york" and "Нидерланды" is not cut short by a shorter entry.
    private static let spelledOut: [(key: String, value: String)] = {
        var table: [String: String] = [:]

        // Country names come from the system in both the languages a node name
        // is likely to be written in, so there is no list to maintain.
        let english = Locale(identifier: "en_US")
        let russian = Locale(identifier: "ru_RU")
        for code in knownCodes {
            for locale in [english, russian] {
                guard let name = locale.localizedString(forRegionCode: code),
                      name.count >= 4 else { continue }
                table[name.lowercased()] = code
            }
        }

        let cities: [String: String] = [
            "amsterdam": "NL", "roosendaal": "NL", "амстердам": "NL",
            "frankfurt": "DE", "berlin": "DE", "munich": "DE", "düsseldorf": "DE",
            "франкфурт": "DE", "берлин": "DE", "мюнхен": "DE",
            "london": "GB", "manchester": "GB", "лондон": "GB",
            "paris": "FR", "marseille": "FR", "париж": "FR",
            "stockholm": "SE", "стокгольм": "SE",
            "helsinki": "FI", "хельсинки": "FI",
            "oslo": "NO", "copenhagen": "DK", "warsaw": "PL", "варшава": "PL",
            "prague": "CZ", "прага": "CZ", "vienna": "AT", "вена": "AT",
            "zurich": "CH", "цюрих": "CH", "geneva": "CH",
            "madrid": "ES", "barcelona": "ES", "milan": "IT", "милан": "IT",
            "rome": "IT", "lisbon": "PT", "dublin": "IE", "bucharest": "RO",
            "sofia": "BG", "budapest": "HU", "vilnius": "LT", "riga": "LV",
            "tallinn": "EE", "таллин": "EE",
            "kyiv": "UA", "kiev": "UA", "киев": "UA",
            "istanbul": "TR", "стамбул": "TR",
            "moscow": "RU", "москва": "RU", "петербург": "RU",
            "almaty": "KZ", "алматы": "KZ", "yerevan": "AM", "ереван": "AM",
            "tbilisi": "GE", "тбилиси": "GE", "dubai": "AE", "дубай": "AE",
            "tokyo": "JP", "токио": "JP", "osaka": "JP", "seoul": "KR",
            "hong kong": "HK", "гонконг": "HK", "singapore": "SG", "сингапур": "SG",
            "taipei": "TW", "bangkok": "TH", "mumbai": "IN", "sydney": "AU",
            "toronto": "CA", "montreal": "CA", "new york": "US", "los angeles": "US",
            "silicon valley": "US", "ashburn": "US", "dallas": "US", "miami": "US",
            "seattle": "US", "chicago": "US", "phoenix": "US",
            "sao paulo": "BR", "buenos aires": "AR",
        ]
        table.merge(cities) { existing, _ in existing }

        return table.sorted { $0.key.count > $1.key.count }.map { ($0.key, $0.value) }
    }()
}

import Foundation
import Observation

/// Downloads and stores the geoip.dat / geosite.dat rule databases that Xray
/// needs to resolve `geosite:` and `geoip:` routing matchers. Files live in
/// Application Support/XrayClient/geo/ and Xray is pointed there via the
/// `XRAY_LOCATION_ASSET` environment variable.
@MainActor
@Observable
final class GeoAssetManager {
    static let shared = GeoAssetManager()

    private(set) var isDownloading = false
    private(set) var lastError: String?
    private(set) var lastUpdated: Date?

    let directory: URL

    private let geoipName = "geoip.dat"
    private let geositeName = "geosite.dat"

    init() {
        #if os(iOS)
        // Shared app group: the app downloads the .dat files, the tunnel
        // extension is the one that actually reads them.
        let dir = AppGroup.geoDirectory
        #else
        let fm = FileManager.default
        let base = (try? fm.url(for: .applicationSupportDirectory,
                                in: .userDomainMask,
                                appropriateFor: nil,
                                create: true)) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("XrayClient/geo", isDirectory: true)
        #endif
        SecureFile.ensureDirectory(dir)
        self.directory = dir
        refreshState()
    }

    var geoipURL: URL { directory.appendingPathComponent(geoipName) }
    var geositeURL: URL { directory.appendingPathComponent(geositeName) }

    /// True when both .dat files are present on disk.
    var hasAssets: Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: geoipURL.path)
            && fm.fileExists(atPath: geositeURL.path)
    }

    private func refreshState() {
        let attrs = try? FileManager.default.attributesOfItem(atPath: geoipURL.path)
        lastUpdated = attrs?[.modificationDate] as? Date
    }

    /// Downloads both .dat files from the given source.
    ///
    /// Both are staged and checked before either is swapped in, and the
    /// previous pair is kept so a half-applied update can be rolled back —
    /// routing with one new and one old database is worse than not updating.
    func download(source: GeoAssetSource,
                  customGeoip: String = "",
                  customGeosite: String = "") async {
        guard !isDownloading else { return }
        isDownloading = true
        lastError = nil
        defer { isDownloading = false }

        let geoip = source.geoipURL(custom: customGeoip)
        let geosite = source == .custom ? customGeosite
                                        : source.geositeURL(custom: customGeosite)

        do {
            let stagedGeoip = try await stage(urlString: geoip)
            let stagedGeosite = try await stage(urlString: geosite)
            defer {
                try? FileManager.default.removeItem(at: stagedGeoip)
                try? FileManager.default.removeItem(at: stagedGeosite)
            }

            guard SecureFile.replaceKeepingBackup(at: geoipURL, with: stagedGeoip) else {
                throw AssetError.installFailed(geoip)
            }
            guard SecureFile.replaceKeepingBackup(at: geositeURL, with: stagedGeosite) else {
                SecureFile.rollback(geoipURL)
                throw AssetError.installFailed(geosite)
            }
            refreshState()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Downloads one file to a temp location and checks it looks like a rule
    /// database rather than an error page or a redirect stub.
    private func stage(urlString: String) async throws -> URL {
        guard let url = URL(string: urlString), url.scheme == "https" else {
            throw AssetError.badURL(urlString)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (tempURL, response) = try await URLSession.shared.download(for: request)

        // Move it somewhere we own straight away: URLSession's temporary file
        // is only guaranteed for the length of this call, and both downloads
        // have to survive until the pair is swapped in together.
        let staged = directory.appendingPathComponent(".staging-\(UUID().uuidString)")
        try? FileManager.default.removeItem(at: staged)
        do {
            try FileManager.default.moveItem(at: tempURL, to: staged)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AssetError.installFailed(urlString)
        }

        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: staged)
            throw AssetError.httpStatus(urlString)
        }
        do {
            try validate(staged, source: urlString)
        } catch {
            try? FileManager.default.removeItem(at: staged)
            throw error
        }
        return staged
    }

    /// A real geoip/geosite database is a multi-megabyte protobuf. Anything
    /// small, or anything that starts like markup, is a captive portal or an
    /// error page and must never be installed.
    private func validate(_ file: URL, source: String) throws {
        let size = (try? FileManager.default
            .attributesOfItem(atPath: file.path)[.size] as? Int) ?? 0
        guard (size ?? 0) >= 64 * 1024 else { throw AssetError.tooSmall(source) }

        guard let handle = try? FileHandle(forReadingFrom: file) else {
            throw AssetError.notADatabase(source)
        }
        defer { try? handle.close() }
        let head = (try? handle.read(upToCount: 16)) ?? Data()
        if head.first == 0x3C {                   // '<' — an HTML error page
            throw AssetError.notADatabase(source)
        }
    }

    enum AssetError: LocalizedError {
        case badURL(String)
        case httpStatus(String)
        case tooSmall(String)
        case notADatabase(String)
        case installFailed(String)

        var errorDescription: String? {
            switch self {
            case .badURL(let u):    return "Invalid URL: \(u)"
            case .httpStatus(let u): return "Download failed: \(u)"
            case .tooSmall(let u):  return "File too small (not a .dat): \(u)"
            case .notADatabase(let u): return "Not a rule database: \(u)"
            case .installFailed(let u): return "Could not install: \(u)"
            }
        }
    }
}

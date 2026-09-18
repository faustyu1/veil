// macOS-only: the update flow replaces an .app bundle on disk.
#if os(macOS)
import Foundation
import AppKit
import Observation

/// Checks GitHub for a newer Veil release, downloads it and swaps the bundle.
///
/// Veil ships outside the App Store and is signed ad-hoc, so there is no
/// developer ID to hang Sparkle's EdDSA appcast off. The releases API is the
/// distribution channel that already exists — the tag, the notes and the
/// `Veil.app.zip` asset are all published by `release.yml` — so this reads that
/// directly rather than adding a second one that could drift out of sync.
@MainActor
@Observable
final class UpdateChecker {

    /// `owner/repo` the releases are published from.
    nonisolated static let repository = "faustyu1/veil"

    /// The asset `release.yml` attaches to every tag.
    nonisolated static let assetName = "Veil.app.zip"

    /// Every published release, newest first — the changelog as it is actually
    /// maintained, since `release.yml` fills each release body from CHANGELOG.md.
    nonisolated static var releasesURL: URL {
        URL(string: "https://github.com/\(repository)/releases")!
    }

    struct Release: Equatable, Sendable {
        var version: String          // "1.6.0" — the tag without its leading v
        var notes: String            // release body, Markdown as published
        var downloadURL: URL
        var downloadSize: Int64
        var pageURL: URL
        var publishedAt: Date?
    }

    /// How far the download has got. `total` is 0 while the server has not
    /// said how big the asset is, which is what the bar reads as indeterminate.
    struct DownloadProgress: Equatable, Sendable {
        var received: Int64
        var total: Int64

        var fraction: Double? {
            guard total > 0 else { return nil }
            return min(1, Double(received) / Double(total))
        }
    }

    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(DownloadProgress)
        case readyToInstall(Release)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    /// True when the user asked for the check, which is what decides whether a
    /// "you're up to date" answer is worth a window.
    private(set) var isUserInitiated = false

    /// Set by the settings toggle: check on launch and once a day after that.
    var automaticallyChecks: Bool {
        get { defaults.bool(forKey: Keys.automatic) }
        set { defaults.set(newValue, forKey: Keys.automatic) }
    }

    /// Set by the update window's checkbox: download and install without asking
    /// again. Only ever turned on deliberately.
    var automaticallyInstalls: Bool {
        get { defaults.bool(forKey: Keys.autoInstall) }
        set { defaults.set(newValue, forKey: Keys.autoInstall) }
    }

    var lastCheck: Date? {
        defaults.object(forKey: Keys.lastCheck) as? Date
    }

    /// The release currently on offer, if any.
    var pendingRelease: Release? {
        switch phase {
        case .available(let release), .readyToInstall(let release): return release
        default: return nil
        }
    }

    private enum Keys {
        static let automatic = "update.automatic"
        static let autoInstall = "update.autoInstall"
        static let skipped = "update.skippedVersion"
        static let lastCheck = "update.lastCheck"
    }

    private let defaults = UserDefaults.standard
    private var downloadedArchive: URL?
    private var downloadTask: Task<URL, Error>?

    init() {
        // Checking for updates is the expected default for an app distributed
        // as a zip; it is a HEAD-sized request once a day.
        if defaults.object(forKey: Keys.automatic) == nil {
            defaults.set(true, forKey: Keys.automatic)
        }
    }

    // MARK: - Checking

    /// Runs a check at most once a day. Called at launch.
    func checkInBackgroundIfDue() {
        guard automaticallyChecks else { return }
        if let last = lastCheck, Date().timeIntervalSince(last) < 24 * 3600 { return }
        Task { await check(userInitiated: false) }
    }

    /// Asks GitHub what the newest release is.
    ///
    /// A background check that finds nothing stays silent; one the user asked
    /// for always reports, including "you already have the newest build",
    /// because silence there reads as a broken button.
    func check(userInitiated: Bool) async {
        isUserInitiated = userInitiated
        phase = .checking
        do {
            let release = try await fetchLatest()
            guard let release else {
                phase = .upToDate
                defaults.set(Date(), forKey: Keys.lastCheck)
                return
            }
            defaults.set(Date(), forKey: Keys.lastCheck)
            if !userInitiated, skippedVersion == release.version {
                phase = .idle
                return
            }
            phase = .available(release)
            if automaticallyInstalls { await download() }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// The newest release, or nil when it is not newer than what is running.
    private func fetchLatest() async throws -> Release? {
        var request = URLRequest(
            url: URL(string: "https://api.github.com/repos/\(Self.repository)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(DeviceInfo.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw UpdateError.network("No response from GitHub")
        }
        guard http.statusCode == 200 else {
            throw UpdateError.network("GitHub answered \(http.statusCode)")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateError.network("Unreadable answer from GitHub")
        }

        let tag = (json["tag_name"] as? String) ?? ""
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard !version.isEmpty else { throw UpdateError.network("Release has no tag") }
        guard Self.isNewer(version, than: AppVersion.current) else { return nil }

        let assets = (json["assets"] as? [[String: Any]]) ?? []
        guard let asset = assets.first(where: { ($0["name"] as? String) == Self.assetName }),
              let urlString = asset["browser_download_url"] as? String,
              let url = URL(string: urlString) else {
            throw UpdateError.noAsset(version)
        }

        var published: Date?
        if let raw = json["published_at"] as? String {
            published = ISO8601DateFormatter().date(from: raw)
        }
        let page = (json["html_url"] as? String)
            .flatMap(URL.init(string:))
            ?? URL(string: "https://github.com/\(Self.repository)/releases")!

        return Release(version: version,
                       notes: (json["body"] as? String) ?? "",
                       downloadURL: url,
                       downloadSize: Int64((asset["size"] as? Int) ?? 0),
                       pageURL: page,
                       publishedAt: published)
    }

    // MARK: - Downloading

    func download() async {
        guard let release = pendingRelease else { return }
        phase = .downloading(DownloadProgress(received: 0, total: release.downloadSize))

        let task = Task { try await downloadArchive(release) }
        downloadTask = task
        defer { downloadTask = nil }

        do {
            let archive = try await task.value
            downloadedArchive = archive
            phase = .readyToInstall(release)
            if automaticallyInstalls { install() }
        } catch {
            // A cancelled download is a choice, not a failure: go back to the
            // offer so the button reads "Install Update" again.
            if isCancellation(error) {
                phase = .available(release)
            } else {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    /// Stops a download in progress. The partial file is dropped by URLSession.
    func cancelDownload() {
        downloadTask?.cancel()
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }

    private func downloadArchive(_ release: UpdateChecker.Release) async throws -> URL {
        // The plain `download(from:)` reports nothing until it finishes, so the
        // byte counter comes from a delegate attached to this one task.
        let observer = DownloadObserver { [weak self] received, expected in
            Task { @MainActor in
                guard let self, case .downloading = self.phase else { return }
                let total = expected > 0 ? expected : release.downloadSize
                self.phase = .downloading(DownloadProgress(received: received, total: total))
            }
        }
        let (temp, response) = try await URLSession.shared.download(
            from: release.downloadURL, delegate: observer)
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw UpdateError.network("Download failed (\(http.statusCode))")
        }
        // URLSession deletes the temporary file as soon as this returns, so it
        // is moved somewhere we own before anything else touches it.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("VeilUpdate-\(release.version)", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let destination = dir.appendingPathComponent(Self.assetName)
        try FileManager.default.moveItem(at: temp, to: destination)
        return destination
    }

    // MARK: - Installing

    /// Unpacks the archive and hands the swap to a detached script.
    ///
    /// The bundle being replaced is the one running this code, so the move
    /// cannot happen in-process: the script waits for this process to exit,
    /// swaps the directories, and launches the new build.
    func install() {
        guard let archive = downloadedArchive, let release = pendingRelease else { return }
        do {
            let staged = try unpack(archive)
            let script = try writeInstallScript(newBundle: staged,
                                                target: Bundle.main.bundleURL)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [script.path]
            try task.run()
            // The script blocks until this pid is gone, so quitting is the
            // signal that the bundle is free to replace.
            NSApplication.shared.terminate(nil)
        } catch {
            phase = .failed("\(release.version): \(error.localizedDescription)")
        }
    }

    /// Unzips the asset and returns the `.app` inside it.
    private func unpack(_ archive: URL) throws -> URL {
        let unpacked = archive.deletingLastPathComponent()
            .appendingPathComponent("unpacked", isDirectory: true)
        try? FileManager.default.removeItem(at: unpacked)
        try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)

        let unzip = Process()
        unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        unzip.arguments = ["-x", "-k", archive.path, unpacked.path]
        unzip.standardOutput = Pipe()
        unzip.standardError = Pipe()
        try unzip.run()
        unzip.waitUntilExit()
        guard unzip.terminationStatus == 0 else {
            throw UpdateError.install("Could not unpack the download")
        }

        let contents = try FileManager.default.contentsOfDirectory(
            at: unpacked, includingPropertiesForKeys: nil)
        guard let app = contents.first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.install("The download contained no application")
        }
        // A file fetched over the network carries a quarantine flag, and an
        // ad-hoc signature has no notarisation to clear it. Left in place it
        // makes the new build refuse to launch.
        let clear = Process()
        clear.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        clear.arguments = ["-dr", "com.apple.quarantine", app.path]
        clear.standardError = Pipe()
        try? clear.run()
        clear.waitUntilExit()
        return app
    }

    private func writeInstallScript(newBundle: URL, target: URL) throws -> URL {
        let backup = target.deletingLastPathComponent()
            .appendingPathComponent(target.deletingPathExtension().lastPathComponent
                                    + ".old.app")
        // The old bundle is kept until the new one is in place, so a failed
        // move leaves a working app behind rather than an empty slot.
        let script = """
        #!/bin/bash
        set -e
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do
          sleep 0.2
        done
        rm -rf "\(backup.path)"
        if [ -d "\(target.path)" ]; then
          mv "\(target.path)" "\(backup.path)"
        fi
        if ! ditto "\(newBundle.path)" "\(target.path)"; then
          rm -rf "\(target.path)"
          mv "\(backup.path)" "\(target.path)"
          open "\(target.path)"
          exit 1
        fi
        rm -rf "\(backup.path)"
        rm -rf "\(newBundle.deletingLastPathComponent().deletingLastPathComponent().path)"
        open "\(target.path)"
        """
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-install-\(UUID().uuidString).sh")
        try script.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: url.path)
        return url
    }

    // MARK: - Dismissal

    /// Never offer this version again.
    func skipPending() {
        if let release = pendingRelease {
            defaults.set(release.version, forKey: Keys.skipped)
        }
        phase = .idle
    }

    /// Ask again on the next scheduled check.
    func remindLater() {
        phase = .idle
    }

    func dismiss() {
        phase = .idle
    }

    private var skippedVersion: String? {
        defaults.string(forKey: Keys.skipped)
    }

    // MARK: - Version comparison

    /// True when `candidate` sorts after `current`. Both are dotted numbers,
    /// with anything non-numeric (a `-dev` suffix on an unbundled build) read
    /// as zero, so a development build always sees a release as newer.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = numbers(candidate), b = numbers(current)
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    private static func numbers(_ version: String) -> [Int] {
        version.split(separator: ".").map { component in
            Int(component.prefix { $0.isNumber }) ?? 0
        }
    }

    enum UpdateError: LocalizedError {
        case network(String)
        case noAsset(String)
        case install(String)

        var errorDescription: String? {
            switch self {
            case .network(let message): return message
            case .noAsset(let version): return "Release \(version) has no \(UpdateChecker.assetName)"
            case .install(let message): return message
            }
        }
    }
}

/// Reports bytes as they arrive for one download task.
///
/// `URLSession` calls this off the main actor, so the closure hops back itself
/// rather than making the delegate `@MainActor`.
private final class DownloadObserver: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Int64, Int64) -> Void

    init(onProgress: @escaping @Sendable (Int64, Int64) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        onProgress(totalBytesWritten, totalBytesExpectedToWrite)
    }

    /// Required by the protocol; the async `download(from:delegate:)` hands the
    /// file back through its return value, so nothing is needed here.
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {}
}
#endif

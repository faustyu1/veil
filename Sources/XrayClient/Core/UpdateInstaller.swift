// macOS-only: this replaces an .app bundle on disk.
#if os(macOS)
import Foundation

/// The half of the update that outlives the app.
///
/// Replacing the running bundle cannot happen in-process, so the swap is done
/// by a detached script — which means the app is already gone when anything
/// goes wrong, and nothing it does can be reported through the usual channels.
/// This type is what makes that half observable: it refuses the installs that
/// cannot work before the app quits, and the script it writes records a verdict
/// the next launch can read.
enum UpdateInstaller {

    /// A reason the running bundle cannot be replaced in place.
    enum Blocker: Equatable {
        /// macOS is running the app from a read-only copy it made itself,
        /// which happens to any quarantined bundle launched outside
        /// `/Applications`. The path the app sees is not the one the user
        /// double-clicked, so replacing it updates nothing.
        case translocated
        case notWritable
        case notABundle
    }

    /// What the previous install attempt did, as read back from its log.
    enum Outcome: Equatable {
        case none
        case installed(String)
        case failed(String)
    }

    /// Where the script writes what it did. Under `~/Library/Logs` so Console
    /// shows it next to everything else the machine logs.
    static var logPath: String {
        let base = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Veil", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("update.log").path
    }

    // MARK: - Before the app quits

    /// Why this bundle cannot be updated in place, or nil when it can.
    ///
    /// Checked before the app terminates, because after that there is nobody
    /// left to tell.
    static func blocker(for bundleURL: URL) -> Blocker? {
        let path = bundleURL.path
        // Checked first, and by path: a translocated bundle lives in a
        // directory that macOS discards, so nothing else about it is worth
        // examining.
        if path.contains("/AppTranslocation/") { return .translocated }

        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        guard bundleURL.pathExtension == "app", exists, isDirectory.boolValue else {
            return .notABundle
        }

        // The swap moves the bundle aside and copies a new one in, so the
        // directory holding it has to be writable, not only the bundle.
        let parent = bundleURL.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: parent),
              FileManager.default.isWritableFile(atPath: path) else {
            return .notWritable
        }
        return nil
    }

    // MARK: - The script

    /// The swap, as a script that runs after the app is gone.
    ///
    /// There is no `set -e`: an abort partway through is how a half-installed
    /// update used to leave no application at all. Every step is checked and
    /// every failure rolls back to the bundle that was working a moment ago.
    ///
    /// - Parameters:
    ///   - pid: the app's process id; the script waits for it to exit.
    ///   - staging: a directory to delete once the swap succeeded.
    ///   - openTool: how to relaunch. Tests pass something that does nothing.
    static func script(pid: Int32, newBundle: URL, target: URL,
                       logPath: String, expectedVersion: String,
                       staging: URL? = nil,
                       openTool: String = "/usr/bin/open") -> String {
        let backup = target.deletingLastPathComponent()
            .appendingPathComponent(
                target.deletingPathExtension().lastPathComponent + ".old.app")
        let plist = target.appendingPathComponent("Contents/Info.plist")
        let cleanup = staging.map { "rm -rf \(quote($0.path))\n" } ?? ""

        return """
        #!/bin/bash
        log=\(quote(logPath))
        mkdir -p "$(dirname "$log")"
        exec >>"$log" 2>&1
        echo "--- $(date -u '+%Y-%m-%dT%H:%M:%SZ') installing \(expectedVersion)"

        restore() {
          rm -rf \(quote(target.path))
          if [ -d \(quote(backup.path)) ]; then
            mv \(quote(backup.path)) \(quote(target.path))
          fi
        }

        fail() {
          echo "veil-update: failed $1"
          exit 1
        }

        while kill -0 \(pid) 2>/dev/null; do
          sleep 0.2
        done

        rm -rf \(quote(backup.path))
        if [ -d \(quote(target.path)) ]; then
          if ! mv \(quote(target.path)) \(quote(backup.path)); then
            fail "could not move the old bundle aside"
          fi
        fi

        if ! ditto \(quote(newBundle.path)) \(quote(target.path)); then
          restore
          \(quote(openTool)) \(quote(target.path))
          fail "could not copy the new bundle into place"
        fi

        installed=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \(quote(plist.path)) 2>/dev/null)
        if [ "$installed" != \(quote(expectedVersion)) ]; then
          restore
          \(quote(openTool)) \(quote(target.path))
          fail "installed ${installed:-nothing}, expected \(expectedVersion)"
        fi

        rm -rf \(quote(backup.path))
        \(cleanup)echo "veil-update: ok \(expectedVersion)"
        \(quote(openTool)) \(quote(target.path))
        """
    }

    // MARK: - After the next launch

    /// The verdict of the last install, read back from the log.
    ///
    /// The app is not running while the swap happens, so this is the only way
    /// it learns that the update it started never landed.
    static func lastOutcome(logPath: String) -> Outcome {
        guard let text = try? String(contentsOfFile: logPath, encoding: .utf8) else {
            return .none
        }
        for line in text.split(separator: "\n").reversed() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if let version = trimmed.dropPrefix("veil-update: ok ") {
                return .installed(version)
            }
            if let reason = trimmed.dropPrefix("veil-update: failed ") {
                return .failed(reason)
            }
        }
        return .none
    }

    /// Forgets the recorded verdict, so the same one is not reported twice.
    static func clearLog(at path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Shell quoting

    /// Wraps a path for `bash`. Single quotes take everything literally, which
    /// is what a path containing `$`, a space or a quote needs.
    private static func quote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}

private extension String {
    /// The remainder after `prefix`, or nil when the string does not start
    /// with it.
    func dropPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}
#endif

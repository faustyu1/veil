import Foundation

/// File helpers that keep Veil's on-disk state private to the user account.
///
/// Application Support is world-readable by default on macOS, and the store
/// holds server addresses, UUIDs and passwords. Every directory Veil creates is
/// `0700` and every file it writes is `0600`, written atomically so a crash
/// mid-write cannot leave a truncated config behind.
enum SecureFile {

    /// Creates `url` if needed and clamps it to `0700`.
    @discardableResult
    static func ensureDirectory(_ url: URL) -> Bool {
        let fm = FileManager.default
        do {
            if !fm.fileExists(atPath: url.path) {
                try fm.createDirectory(at: url, withIntermediateDirectories: true,
                                       attributes: [.posixPermissions: 0o700])
            } else {
                try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
            }
            return true
        } catch {
            return false
        }
    }

    /// Writes `data` atomically and clamps the result to `0600`.
    @discardableResult
    static func write(_ data: Data, to url: URL) -> Bool {
        let fm = FileManager.default
        ensureDirectory(url.deletingLastPathComponent())
        guard (try? data.write(to: url, options: [.atomic])) != nil else { return false }
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return true
    }

    /// Replaces `destination` with `source` and keeps the previous contents as
    /// `<name>.bak`, so a bad download can be rolled back. The swap itself is a
    /// single `replaceItemAt`, so readers never see a half-written file.
    @discardableResult
    static func replaceKeepingBackup(at destination: URL, with source: URL) -> Bool {
        let fm = FileManager.default
        let backup = destination.appendingPathExtension("bak")
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: backup)
            try? fm.copyItem(at: destination, to: backup)
        }
        do {
            if fm.fileExists(atPath: destination.path) {
                _ = try fm.replaceItemAt(destination, withItemAt: source)
            } else {
                try fm.moveItem(at: source, to: destination)
            }
            try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
            return true
        } catch {
            return false
        }
    }

    /// Puts `<name>.bak` back in place after a failed update.
    @discardableResult
    static func rollback(_ destination: URL) -> Bool {
        let fm = FileManager.default
        let backup = destination.appendingPathExtension("bak")
        guard fm.fileExists(atPath: backup.path) else { return false }
        try? fm.removeItem(at: destination)
        do {
            try fm.moveItem(at: backup, to: destination)
            return true
        } catch {
            return false
        }
    }
}

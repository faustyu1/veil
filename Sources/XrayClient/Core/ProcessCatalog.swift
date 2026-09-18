// macOS-only.
#if os(macOS)
import AppKit
import Foundation
import Observation

/// One thing a rule can be written against.
///
/// `executableName` is what sing-box's `process_name` compares — the file name
/// of the running binary, not the app's display name. They differ often enough
/// to matter: the bundle is "Visual Studio Code", the executable is "Electron".
/// Picking from this list instead of typing is the whole point.
struct ProcessEntry: Identifiable, Hashable {
    enum Origin: Hashable {
        case application     // an .app bundle on disk
        case running         // a process that is running right now
    }

    var displayName: String
    var executableName: String
    var executablePath: String
    var bundleID: String?
    var origin: Origin
    var isRunning: Bool

    var id: String { executablePath.isEmpty ? executableName : executablePath }

    /// The `.app` bundle this belongs to, for the icon.
    var bundlePath: String? {
        guard let range = executablePath.range(of: ".app/Contents/MacOS/") else {
            return nil
        }
        return String(executablePath[executablePath.startIndex..<range.lowerBound]) + ".app"
    }

    /// True when the display name and the executable differ, which is worth
    /// showing: the rule will be written against the executable.
    var nameDiffersFromExecutable: Bool {
        displayName.caseInsensitiveCompare(executableName) != .orderedSame
    }
}

/// Finds the applications and processes a rule can name.
///
/// Three sources, merged: what is running now (which catches helper processes
/// like `Google Chrome Helper`, the ones that actually open the sockets), the
/// application bundles on disk, and the daemons in between.
@MainActor
@Observable
final class ProcessCatalog {

    private(set) var entries: [ProcessEntry] = []
    private(set) var isLoading = false

    static let shared = ProcessCatalog()

    nonisolated private static let searchDirectories = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications"
    ]

    /// Rebuilds the list. Cheap enough to call each time the picker opens —
    /// the disk scan is one level deep and the rest is in-memory.
    func reload() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let running = runningApplications()
        let installed = await Self.installedApplications()
        let processes = await Self.runningProcesses()

        var merged: [String: ProcessEntry] = [:]
        // Later sources must not overwrite the richer earlier ones, but they
        // may mark an entry as running.
        func insert(_ entry: ProcessEntry) {
            let key = entry.id.lowercased()
            if var existing = merged[key] {
                existing.isRunning = existing.isRunning || entry.isRunning
                if existing.displayName.isEmpty { existing.displayName = entry.displayName }
                if existing.bundleID == nil { existing.bundleID = entry.bundleID }
                merged[key] = existing
            } else {
                merged[key] = entry
            }
        }
        running.forEach(insert)
        installed.forEach(insert)
        processes.forEach(insert)

        entries = merged.values.sorted {
            // Running first, then alphabetically: the thing the user wants to
            // route is almost always open at the time they go looking for it.
            if $0.isRunning != $1.isRunning { return $0.isRunning }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    /// Case-insensitive match over the display name, the executable and the
    /// bundle id, so "chrome", "Google" and "com.google" all find Chrome.
    func search(_ query: String) -> [ProcessEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return entries }
        return entries.filter { entry in
            entry.displayName.localizedCaseInsensitiveContains(trimmed)
                || entry.executableName.localizedCaseInsensitiveContains(trimmed)
                || (entry.bundleID?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    // MARK: - Sources

    private func runningApplications() -> [ProcessEntry] {
        NSWorkspace.shared.runningApplications.compactMap { app in
            guard let url = app.executableURL else { return nil }
            let name = app.localizedName ?? url.lastPathComponent
            return ProcessEntry(displayName: name,
                                executableName: url.lastPathComponent,
                                executablePath: url.path,
                                bundleID: app.bundleIdentifier,
                                origin: .application,
                                isRunning: true)
        }
    }

    private static func installedApplications() async -> [ProcessEntry] {
        await Task.detached(priority: .utility) { () -> [ProcessEntry] in
            let fm = FileManager.default
            var found: [ProcessEntry] = []
            for directory in searchDirectories {
                guard let names = try? fm.contentsOfDirectory(atPath: directory) else {
                    continue
                }
                for name in names where name.hasSuffix(".app") {
                    let bundlePath = directory + "/" + name
                    guard let bundle = Bundle(path: bundlePath),
                          let executable = bundle.executableURL else { continue }
                    let display = (bundle.infoDictionary?["CFBundleDisplayName"] as? String)
                        ?? (bundle.infoDictionary?["CFBundleName"] as? String)
                        ?? String(name.dropLast(4))
                    found.append(ProcessEntry(displayName: display,
                                              executableName: executable.lastPathComponent,
                                              executablePath: executable.path,
                                              bundleID: bundle.bundleIdentifier,
                                              origin: .application,
                                              isRunning: false))
                }
            }
            return found
        }.value
    }

    /// Everything running, including the helpers and daemons that do the
    /// actual networking for an app.
    private static func runningProcesses() async -> [ProcessEntry] {
        await Task.detached(priority: .utility) { () -> [ProcessEntry] in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/ps")
            process.arguments = ["-axo", "comm="]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            guard (try? process.run()) != nil else { return [] }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard let text = String(data: data, encoding: .utf8) else { return [] }

            var seen = Set<String>()
            var found: [ProcessEntry] = []
            for line in text.split(separator: "\n") {
                let path = line.trimmingCharacters(in: .whitespaces)
                guard path.hasPrefix("/"), seen.insert(path).inserted else { continue }
                let name = (path as NSString).lastPathComponent
                found.append(ProcessEntry(displayName: name,
                                          executableName: name,
                                          executablePath: path,
                                          bundleID: nil,
                                          origin: .running,
                                          isRunning: true))
            }
            return found
        }.value
    }
}
#endif

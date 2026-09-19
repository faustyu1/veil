#if os(macOS)
import Foundation

/// Runs an edited configuration past the core that will execute it.
///
/// The cores can check a config without running it — `xray run -test` and
/// `sing-box check` — and their complaints name the offending field. Showing
/// that message is the difference between a typo caught while it is being typed
/// and a connection that never comes up for no stated reason.
enum ConfigValidator {

    enum Outcome: Equatable {
        case ok
        /// The core refused it, with its own message.
        case failed(String)
        /// The core is not on disk. A development build with unfetched
        /// binaries, not something the user can act on.
        case unavailable
    }

    static func check(_ server: ProxyConfig) async -> Outcome {
        let engine = server.engine
        guard let binary = CoreBinary.locate(for: engine) else { return .unavailable }

        let data: Data
        do {
            switch engine {
            case .singbox:
                var profile = SingBoxProfile()
                profile.servers = [server]
                profile.defaultTarget = .server(server.id)
                data = try SingBoxProfileBuilder.jsonData(profile)
            case .xray:
                data = try XrayConfigBuilder.jsonData(for: server)
            }
        } catch {
            return .failed(error.localizedDescription)
        }

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-check-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: file) }
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            return .failed(error.localizedDescription)
        }

        let arguments = engine == .singbox
            ? ["check", "-c", file.path]
            : ["run", "-test", "-config", file.path]
        return await run(binary, arguments)
    }

    private static func run(_ binary: URL, _ arguments: [String]) async -> Outcome {
        await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = binary
            process.arguments = arguments
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
            } catch {
                return continuation.resume(returning: .failed(error.localizedDescription))
            }
            // Read before waiting: a core with plenty to say would otherwise
            // fill the pipe and block forever.
            let output = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
            process.waitUntilExit()

            guard process.terminationStatus != 0 else {
                return continuation.resume(returning: .ok)
            }
            let message = String(data: output, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            continuation.resume(returning: .failed(message.isEmpty
                ? "The core refused this configuration."
                : message))
        }
    }
}
#endif

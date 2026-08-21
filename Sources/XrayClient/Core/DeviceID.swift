import Foundation

/// Generates a stable hardware identifier (HWID). Some subscription providers
/// require it to identify the device.
///
/// On macOS this is the `IOPlatformUUID`. iOS exposes no system-wide hardware
/// identifier at all, so we mint one on first use and persist it in the shared
/// app group — that keeps the HWID stable across launches and identical between
/// the app and the tunnel extension, which is what panels expect.
enum DeviceID {

    /// Cached HWID — computed once on first access.
    static let hwid: String = generate()

    #if os(macOS)
    /// Reads `IOPlatformUUID` via `ioreg` and returns it.
    /// Falls back to a random UUID if the value cannot be obtained.
    private static func generate() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-d2", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
            process.waitUntilExit()
            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(),
                                encoding: .utf8) ?? ""
            // ioreg prints: "IOPlatformUUID" = "XXXX-XXXX-XXXX"
            // Find the UUID value after the `= "` separator.
            if let range = output.range(of: "IOPlatformUUID") {
                let rest = output[range.upperBound...]
                if let eqRange = rest.range(of: "= \"") {
                    let afterEq = rest[eqRange.upperBound...]
                    if let closeQ = afterEq.firstIndex(of: "\"") {
                        return String(afterEq[..<closeQ])
                    }
                }
            }
        } catch {}
        return UUID().uuidString
    }
    #else
    /// Reads (or mints) the identifier stored in the shared app group.
    ///
    /// `UIDevice.identifierForVendor` would be the obvious choice, but it is
    /// main-actor isolated and this runs from wherever the first subscription
    /// fetch happens — including inside the tunnel extension. A stored UUID has
    /// the same lifetime anyway: both reset when the app is removed.
    private static func generate() -> String {
        let key = "hwid"
        let defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        if let stored = defaults.string(forKey: key), !stored.isEmpty {
            return stored
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: key)
        return generated
    }
    #endif
}

/// Describes the device to subscription panels: model, OS name and OS version.
/// Panels (Remnawave and friends) show these next to the HWID in their device
/// list, and leave them empty when the client sends nothing.
enum DeviceInfo {

    /// Hardware model identifier, e.g. `iPhone16,2` or `Mac14,7`.
    static let model: String = {
        #if targetEnvironment(simulator)
        if let id = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !id.isEmpty {
            return id
        }
        #endif
        #if os(macOS)
        let key = "hw.model"
        #else
        let key = "hw.machine"
        #endif
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return "Unknown" }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return "Unknown" }
        let bytes = buffer.prefix { $0 != 0 }
        let value = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "Unknown" : value
    }()

    /// Platform name as panels expect it: `iOS`, `iPadOS` or `macOS`.
    static let osName: String = {
        #if os(macOS)
        return "macOS"
        #else
        return model.hasPrefix("iPad") ? "iPadOS" : "iOS"
        #endif
    }()

    /// OS version, e.g. `18.5` (the patch component is dropped when it is 0).
    static let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.patchVersion == 0
            ? "\(v.majorVersion).\(v.minorVersion)"
            : "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    /// User-Agent carrying the same facts, for panels that only parse the UA.
    static func userAgent(hwid: String?) -> String {
        var parts = ["\(osName) \(osVersion)", model]
        if let hwid, !hwid.isEmpty {
            parts.append("hwid: \(hwid)")
        }
        return "Veil/\(AppVersion.current) (" + parts.joined(separator: "; ") + ")"
    }
}

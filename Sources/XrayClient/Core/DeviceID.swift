import Foundation

/// The HWID Veil presents to subscription panels.
///
/// This used to be the Mac's `IOPlatformUUID`, which is the worst possible
/// choice: it is stable across reinstalls, identical for every panel, and lets
/// two unrelated providers recognise the same machine. Veil now mints a random
/// identifier instead, keeps it in the Keychain, and lets the user rotate it or
/// give a single subscription its own.
///
/// An install that already talked to a panel keeps the identifier it was using
/// — rotating it silently would burn a device slot and could lock the user out
/// with `x-hwid-max-devices-reached`. Rotation is a deliberate action.
enum DeviceID {

    /// Keychain/`UserDefaults` account for the default identifier.
    static let defaultAccount = "device.hwid"

    /// The identifier used when a subscription has no HWID of its own.
    static var hwid: String { hwid(for: nil) }

    /// The identifier presented to one subscription's panel. Subscriptions
    /// without their own fall back to the default identifier.
    static func hwid(for subscriptionID: UUID?) -> String {
        let account = account(for: subscriptionID)
        if let cached = cache.value(for: account) { return cached }
        if let stored = read(account: account) {
            cache.set(stored, for: account)
            return stored
        }
        if subscriptionID != nil {
            // No per-subscription override: use the default identifier.
            return hwid(for: nil)
        }
        let minted = legacyIdentifier() ?? UUID().uuidString
        write(minted, account: account)
        cache.set(minted, for: account)
        return minted
    }

    /// Mints a fresh identifier. Pass a subscription id to give that one
    /// subscription its own HWID; pass nil to rotate the default.
    @discardableResult
    static func regenerate(for subscriptionID: UUID? = nil) -> String {
        let account = account(for: subscriptionID)
        let minted = UUID().uuidString
        write(minted, account: account)
        cache.set(minted, for: account)
        return minted
    }

    /// Drops a subscription's own identifier; it falls back to the default.
    static func clearOverride(for subscriptionID: UUID) {
        let account = account(for: subscriptionID)
        Keychain.remove(account: account)
        defaults?.removeObject(forKey: account)
        cache.set(nil, for: account)
    }

    /// True when this subscription has an identifier of its own.
    static func hasOverride(for subscriptionID: UUID) -> Bool {
        read(account: account(for: subscriptionID)) != nil
    }

    // MARK: - Storage

    private static func account(for subscriptionID: UUID?) -> String {
        guard let subscriptionID else { return defaultAccount }
        return KeychainAccount.subscriptionHWID(subscriptionID)
    }

    private static func read(account: String) -> String? {
        if let value = Keychain.get(account: account), !value.isEmpty { return value }
        if let value = defaults?.string(forKey: account), !value.isEmpty { return value }
        return nil
    }

    private static func write(_ value: String, account: String) {
        if Keychain.set(value, account: account) {
            // Drop any earlier plaintext copy now that the Keychain holds it.
            defaults?.removeObject(forKey: account)
            return
        }
        // An unsigned build can fail every Keychain write. Losing the HWID
        // would re-register the device on every launch, so fall back.
        defaults?.set(value, forKey: account)
    }

    private static var defaults: UserDefaults? {
        #if os(macOS)
        return .standard
        #else
        return UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        #endif
    }

    /// The identifier an older build would have used, so upgrading does not
    /// look like a new device to the panel.
    private static func legacyIdentifier() -> String? {
        #if os(macOS)
        return platformUUID()
        #else
        // Older iOS builds kept a minted UUID under this app-group key.
        let legacy = defaults?.string(forKey: "hwid")
        return (legacy?.isEmpty == false) ? legacy : nil
        #endif
    }

    #if os(macOS)
    /// Reads `IOPlatformUUID` via `ioreg`. Only used once, to carry an existing
    /// install's identity forward — never to mint a new one.
    private static func platformUUID() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/ioreg")
        process.arguments = ["-d2", "-c", "IOPlatformExpertDevice"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let output = String(data: data, encoding: .utf8) ?? ""
            // ioreg prints: "IOPlatformUUID" = "XXXX-XXXX-XXXX"
            guard let key = output.range(of: "IOPlatformUUID") else { return nil }
            let rest = output[key.upperBound...]
            guard let eq = rest.range(of: "= \"") else { return nil }
            let afterEq = rest[eq.upperBound...]
            guard let close = afterEq.firstIndex(of: "\"") else { return nil }
            let value = String(afterEq[..<close])
            return value.isEmpty ? nil : value
        } catch {
            return nil
        }
    }
    #endif

    /// Small lock-guarded cache so a SwiftUI redraw does not hit the Keychain
    /// on every frame.
    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String: String] = [:]

        func value(for account: String) -> String? {
            lock.lock(); defer { lock.unlock() }
            return values[account]
        }

        func set(_ value: String?, for account: String) {
            lock.lock(); defer { lock.unlock() }
            values[account] = value
        }
    }

    private static let cache = Cache()
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

    /// Default User-Agent. It carries the same device facts as the `X-Device-*`
    /// headers and deliberately **not** the HWID — the UA is visible to every
    /// proxy on the path, and the panel already gets the HWID in `X-Hwid`.
    static var defaultUserAgent: String {
        "Veil/\(AppVersion.current) (\(osName) \(osVersion); \(model))"
    }

    /// The User-Agent to send, honouring a user override for panels with
    /// custom Response Rules that key off it.
    static func userAgent(override: String?) -> String {
        let trimmed = override?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultUserAgent : trimmed
    }
}

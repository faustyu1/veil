import XCTest
@testable import XrayClient
import VeilHelperKit
#if os(macOS)
import CryptoKit
#endif

/// Covers the pieces that stand between a user's credentials and a log file,
/// a diagnostics paste, or a root process.
final class RedactionTests: XCTestCase {

    func testURLKeepsOnlyTheHost() {
        XCTAssertEqual(Redaction.url("https://panel.example.com/sub/abc123?hwid=x"),
                       "https://panel.example.com/<redacted>")
        XCTAssertEqual(Redaction.url("https://panel.example.com:8443/sub/abc"),
                       "https://panel.example.com:8443/<redacted>")
        // Nothing to hide when there is no path, query or fragment.
        XCTAssertEqual(Redaction.url("https://panel.example.com"),
                       "https://panel.example.com")
    }

    func testURLDropsUserinfo() {
        let redacted = Redaction.url("https://user:hunter2@panel.example.com/sub/abc")
        XCTAssertFalse(redacted.contains("hunter2"))
        XCTAssertFalse(redacted.contains("user"))
    }

    func testUnparseableURLIsFullyRedacted() {
        XCTAssertEqual(Redaction.url("not a url at all"), "<redacted>")
        XCTAssertEqual(Redaction.url(""), "<redacted>")
    }

    func testFingerprintIsNotReusable() {
        XCTAssertEqual(Redaction.fingerprint("3F2504E0-4F89-11D3-9A0C-0305E82C3301"),
                       "3F25…3301")
        XCTAssertEqual(Redaction.fingerprint(nil), "<none>")
        // Too short to fingerprint without giving most of it away.
        XCTAssertEqual(Redaction.fingerprint("abc123"), "<redacted>")
    }

    func testTextRedactsSubscriptionURLs() {
        let line = "fetching https://panel.example.com/sub/TOKEN123 now"
        let redacted = Redaction.text(line)
        XCTAssertFalse(redacted.contains("TOKEN123"))
        XCTAssertTrue(redacted.contains("panel.example.com"))
    }

    func testTextRedactsKnownSecretsFirst() {
        let redacted = Redaction.text("psk is s3cret-value-here",
                                      knownSecrets: ["s3cret-value-here"])
        XCTAssertFalse(redacted.contains("s3cret-value-here"))
    }

    func testTextRedactsAssignmentsAndIdentifiers() {
        let redacted = Redaction.text(
            #"{"password": "hunter2", "uuid": "3F2504E0-4F89-11D3-9A0C-0305E82C3301"}"#)
        XCTAssertFalse(redacted.contains("hunter2"))
        XCTAssertFalse(redacted.contains("3F2504E0"))
        // The shape of the line survives, so the report is still readable.
        XCTAssertTrue(redacted.contains("password"))
    }

    func testTextLeavesOrdinaryProseAlone() {
        let prose = "The tunnel came up on utun123 after 2 retries."
        XCTAssertEqual(Redaction.text(prose), prose)
    }
}

/// The helper runs as root, so everything crossing into it is checked twice.
final class HelperValidationTests: XCTestCase {

    func testAcceptsDottedQuadsOnly() {
        XCTAssertTrue(HelperValidation.isIPv4("192.168.1.1"))
        XCTAssertTrue(HelperValidation.isIPv4("8.8.8.8"))
        XCTAssertFalse(HelperValidation.isIPv4("256.1.1.1"))
        XCTAssertFalse(HelperValidation.isIPv4("1.2.3"))
        XCTAssertFalse(HelperValidation.isIPv4("1.2.3.4.5"))
        XCTAssertFalse(HelperValidation.isIPv4("example.com"))
        XCTAssertFalse(HelperValidation.isIPv4(""))
        XCTAssertFalse(HelperValidation.isIPv4("1.2.3.4; rm -rf /"))
    }

    func testRejectsOctalLookingOctets() {
        // `010` is 8, not 10, to some resolvers — never pin a route on it.
        XCTAssertFalse(HelperValidation.isIPv4("010.1.1.1"))
        XCTAssertTrue(HelperValidation.isIPv4("10.1.1.1"))
    }

    func testSanitizeDropsJunkDeduplicatesAndCaps() {
        let input = ["1.2.3.4", "1.2.3.4", "bad", "5.6.7.8", ""]
        XCTAssertEqual(HelperValidation.sanitizeAddresses(input), ["1.2.3.4", "5.6.7.8"])

        let many = (1...200).map { "10.0.0.\($0 % 255)" }
        XCTAssertLessThanOrEqual(HelperValidation.sanitizeAddresses(many).count,
                                 HelperValidation.maxAddresses)
    }

    func testOnlyLoopbackMayHostTheSOCKSProxy() {
        XCTAssertTrue(HelperValidation.isLoopback("127.0.0.1"))
        XCTAssertTrue(HelperValidation.isLoopback("::1"))
        XCTAssertFalse(HelperValidation.isLoopback("10.0.0.1"))
        XCTAssertFalse(HelperValidation.isLoopback("evil.example.com"))
    }

    func testIPv6LiteralsAreValidatedWithoutScopeInjection() {
        XCTAssertTrue(HelperValidation.isIPv6("2001:db8::1"))
        XCTAssertTrue(HelperValidation.isIPv6("::1"))
        XCTAssertFalse(HelperValidation.isIPv6("2001:db8::1%en0"))
        XCTAssertFalse(HelperValidation.isIPv6("example.com"))
        XCTAssertFalse(HelperValidation.isIPv6("::1; touch /tmp/pwned"))
    }

    func testAddressSanitizationAcceptsBothFamiliesAndRejectsCommands() {
        let values = ["192.0.2.1", "2001:db8::2", "2001:db8::2", "::1;id"]
        XCTAssertEqual(HelperValidation.sanitizeAddresses(values),
                       ["192.0.2.1", "2001:db8::2"])
    }

    func testClientRequirementMustBeNarrow() {
        XCTAssertTrue(HelperValidation.isAllowedClientRequirement(
            #"anchor apple generic and identifier "dev.local.veil" and certificate leaf[subject.OU] = "TEAM123""#))
        XCTAssertTrue(HelperValidation.isAllowedClientRequirement(
            #"identifier "dev.local.veil" and cdhash H"0123456789abcdef0123456789abcdef01234567""#))
        XCTAssertFalse(HelperValidation.isAllowedClientRequirement("anchor apple"))
        XCTAssertFalse(HelperValidation.isAllowedClientRequirement(
            #"identifier "com.attacker.app" and cdhash H"0123""#))
        XCTAssertFalse(HelperValidation.isAllowedClientRequirement(
            "identifier \"dev.local.veil\"\nor anchor apple"))
        XCTAssertFalse(HelperValidation.isAllowedClientRequirement(
            #"anchor apple generic and identifier "dev.local.veil" and certificate leaf[subject.OU] = "TEAM123" or anchor apple"#))
    }

    func testKillSwitchRulesAllowOnlyTypedExceptions() throws {
        let rules = try XCTUnwrap(KillSwitchRules.render(
            physicalInterface: "en0", tunnelInterface: "utun123",
            endpointIPs: ["192.0.2.10", "2001:db8::10"]))
        XCTAssertTrue(rules.contains("pass out quick on utun123 all"))
        XCTAssertTrue(rules.contains("pass out quick on en0 to 192.0.2.10"))
        XCTAssertTrue(rules.contains("pass out quick on en0 to 2001:db8::10"))
        XCTAssertTrue(rules.hasSuffix("block drop out quick all\n"))
        XCTAssertNil(KillSwitchRules.render(
            physicalInterface: "en0\npass out all", tunnelInterface: "utun123",
            endpointIPs: ["192.0.2.10"]))
        XCTAssertNil(KillSwitchRules.render(
            physicalInterface: "en0", tunnelInterface: "utun123",
            endpointIPs: ["192.0.2.10; pass out all"]))
    }

    func testPortRange() {
        XCTAssertTrue(HelperValidation.isPort(10808))
        XCTAssertFalse(HelperValidation.isPort(0))
        XCTAssertFalse(HelperValidation.isPort(70000))
    }

    func testSplitAddress() {
        let parsed = TunManager.splitAddress("127.0.0.1:10808")
        XCTAssertEqual(parsed?.host, "127.0.0.1")
        XCTAssertEqual(parsed?.port, 10808)
        XCTAssertNil(TunManager.splitAddress("127.0.0.1"))
        XCTAssertNil(TunManager.splitAddress("127.0.0.1:0"))
        XCTAssertNil(TunManager.splitAddress(":10808"))
    }
}

/// The HWID is the one identifier a panel sees, so where it comes from on a
/// machine that has never run Veil matters as much as where it is stored.
final class DeviceIdentifierTests: XCTestCase {

    private var wasUpgrade = false

    override func setUp() {
        super.setUp()
        wasUpgrade = DeviceID.isUpgrade
    }

    override func tearDown() {
        DeviceID.isUpgrade = wasUpgrade
        super.tearDown()
    }

    func testFreshInstallDoesNotAdoptTheMachineIdentifier() {
        DeviceID.isUpgrade = false
        XCTAssertNil(DeviceID.legacyIdentifierForTesting(),
                     "a machine with no earlier install has no identity to carry forward")
    }

    func testUpgradeCarriesTheOldIdentifierForward() throws {
        DeviceID.isUpgrade = true
        let carried = DeviceID.legacyIdentifierForTesting()
        #if os(macOS)
        // Every Mac reports an IOPlatformUUID; an upgrade has to reuse it
        // rather than register itself with the panel as a second device.
        let value = try XCTUnwrap(carried)
        XCTAssertFalse(value.isEmpty)
        #else
        _ = carried
        #endif
    }

    // `DeviceID.regenerate()` is deliberately not exercised here: it writes the
    // real Keychain item the installed app reads, and a test that rotates a
    // user's HWID behind their back is worse than an untested one line.
}

/// tun2socks answers a flag it cannot parse by printing its usage and exiting,
/// so a wrong argument never looks like a wrong argument — it looks like a TUN
/// interface that refused to appear. Pin the spelling.
final class Tun2socksArgumentTests: XCTestCase {

    func testLongFlagsUseTwoDashes() {
        let args = Tun2socksArguments.build(device: "utun123",
                                            socksHost: "127.0.0.1",
                                            socksPort: 10808,
                                            interface: "en0")
        for flag in args where flag.hasPrefix("-") {
            XCTAssertTrue(flag.hasPrefix("--"),
                          "\(flag) is parsed as a shorthand cluster, not a long flag")
        }
    }

    func testCarriesDeviceProxyAndInterface() {
        let args = Tun2socksArguments.build(device: "utun123",
                                            socksHost: "127.0.0.1",
                                            socksPort: 10808,
                                            interface: "en0")
        XCTAssertEqual(args, ["--device", "utun123",
                              "--proxy", "socks5://127.0.0.1:10808",
                              "--interface", "en0"])
    }
}

final class TunnelRoutePolicyTests: XCTestCase {
    func testStrictIPv4HasPersistentFallbackAndMoreSpecificActiveRoutes() {
        XCTAssertEqual(TunnelRoutePolicy.strictFallbackIPv4,
                       ["0.0.0.0/1", "128.0.0.0/1"])
        XCTAssertEqual(TunnelRoutePolicy.strictTunnelIPv4.count, 4)
        XCTAssertTrue(TunnelRoutePolicy.strictTunnelIPv4.allSatisfy { $0.hasSuffix("/2") })
    }

    func testIPv6ProtectionCoversBothAddressHalves() {
        XCTAssertEqual(TunnelRoutePolicy.protectedIPv6, ["::/1", "8000::/1"])
    }

    func testLegacySettingsMigrateToSafeTunnelDefaults() throws {
        let settings = try JSONDecoder().decode(AppSettings.self,
                                                from: Data(#"{"mode":"tun"}"#.utf8))
        XCTAssertEqual(settings.killSwitch, .strict)
        XCTAssertTrue(settings.strictIPv6Protection)
    }
}

#if os(macOS)
final class CoreRuntimeSecurityTests: XCTestCase {
    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("veil-security-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testCoreManifestRejectsMalformedAndWrongArchitecture() throws {
        XCTAssertNil(CoreVerifier.Manifest(text: "not-a-hash arm64"))
        let hash = String(repeating: "a", count: 64)
        let wrong = CoreVerifier.currentArchitecture == "arm64" ? "x86_64" : "arm64"
        let manifest = try XCTUnwrap(CoreVerifier.Manifest(text: "\(hash) \(wrong)"))
        XCTAssertFalse(CoreVerifier.verify(URL(fileURLWithPath: "/bin/echo"), manifest: manifest))
    }

    func testCoreHashAcceptsExactBytesAndRejectsChanges() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let binary = dir.appendingPathComponent("core")
        try Data("trusted".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        let hash = SHA256.hash(data: Data("trusted".utf8))
            .map { String(format: "%02x", $0) }.joined()
        let manifest = try XCTUnwrap(CoreVerifier.Manifest(
            text: "\(hash) \(CoreVerifier.currentArchitecture)"))
        XCTAssertTrue(CoreVerifier.verify(binary, manifest: manifest))
        try Data("changed".utf8).write(to: binary)
        XCTAssertFalse(CoreVerifier.verify(binary, manifest: manifest))
    }

    func testBundledCoreWithoutManifestIsRejected() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let binary = dir.appendingPathComponent("xray")
        try Data("unknown".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: binary.path)
        XCTAssertFalse(CoreVerifier.verifyBundled(binary, name: "xray"))
    }

    func testCoreConfigsArePrivateAndStaleFilesAreRemoved() throws {
        let dir = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let stale = dir.appendingPathComponent("core-config-stale")
        try Data("secret".utf8).write(to: stale)
        let created = try SecureCoreConfig.create(Data("credential".utf8), in: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        let attrs = try FileManager.default.attributesOfItem(atPath: created.path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        SecureCoreConfig.remove(created, from: dir)
        XCTAssertFalse(FileManager.default.fileExists(atPath: created.path))
    }
}
#endif

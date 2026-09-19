import XCTest
@testable import XrayClient
import VeilHelperKit

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
        XCTAssertFalse(HelperValidation.isLoopback("10.0.0.1"))
        XCTAssertFalse(HelperValidation.isLoopback("evil.example.com"))
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
    // `setManual` is covered through `normalizedManual`, which is the whole of
    // its decision-making and touches no storage.

    func testManualIdentifierKeepsWhatThePanelIssued() {
        // Panels hand out identifiers that are not UUID-shaped. Whatever the
        // user pastes is what their provider expects to see, so it is taken as
        // written rather than folded into Veil's own 16-hex form.
        XCTAssertEqual(DeviceID.normalizedManual("device-42_abc"), "device-42_abc")
    }

    func testManualIdentifierIsTrimmed() {
        // A pasted value almost always arrives with a newline on the end, and
        // a stray space in an HTTP header is a rejected request.
        XCTAssertEqual(DeviceID.normalizedManual("  E0104A37B8464E6B \n"),
                       "E0104A37B8464E6B")
    }

    func testBlankManualIdentifierIsRefused() {
        // Empty means "I changed my mind", not "register me as nobody".
        XCTAssertNil(DeviceID.normalizedManual(""))
        XCTAssertNil(DeviceID.normalizedManual("   \n "))
    }
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

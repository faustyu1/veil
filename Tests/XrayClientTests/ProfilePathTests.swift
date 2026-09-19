import XCTest
@testable import XrayClient

/// Which of the two connection shapes a given setup gets.
///
/// The full profile is the only one that can express "this domain through that
/// node": the single-server path has one proxy outbound, and
/// `RuleTarget.xrayTag` collapses every node- and group-specific target onto
/// it. A rule that cannot be honoured must not look configured, so the app has
/// to know which shape it is about to build.
final class ProfilePathTests: XCTestCase {

    func testTheProfileIsUsedWhenTheNativeInboundIsOn() {
        XCTAssertTrue(ConnectionManager.usesProfile(mode: .tun, useNativeTun: true))
    }

    func testSystemProxyAlwaysUsesTheProfile() {
        XCTAssertTrue(ConnectionManager.usesProfile(mode: .systemProxy,
                                                    useNativeTun: false),
                      "there is no TUN interface in this mode, so the native "
                      + "inbound setting has nothing to say about it")
    }

    func testTunWithoutTheNativeInboundFallsBackToTheSingleServerPath() {
        XCTAssertFalse(ConnectionManager.usesProfile(mode: .tun, useNativeTun: false))
    }

    // MARK: - What that costs

    func testANodeTargetCannotBeExpressedOnTheSingleServerPath() {
        let target = RuleTarget.server(UUID())

        XCTAssertEqual(target.xrayTag, "proxy",
                       "this is the collapse the warning has to be about")
    }

    func testARuleNamingANodeIsReportedAsUnhonoured() {
        var rule = RoutingRule()
        rule.domains = ["office.example"]
        rule.target = .server(UUID())

        XCTAssertTrue(RoutingRule.needsProfile([rule]))
    }

    func testARuleNamingAGroupIsReportedAsUnhonoured() {
        var rule = RoutingRule()
        rule.domains = ["office.example"]
        rule.target = .group(UUID())

        XCTAssertTrue(RoutingRule.needsProfile([rule]))
    }

    func testPlainTargetsNeedNothingSpecial() {
        var direct = RoutingRule()
        direct.domains = ["lan.example"]
        direct.target = .direct
        var proxied = RoutingRule()
        proxied.domains = ["example.com"]
        proxied.target = .proxy

        XCTAssertFalse(RoutingRule.needsProfile([direct, proxied]))
    }

    func testADisabledRuleIsNotCountedAgainstTheSetup() {
        var rule = RoutingRule()
        rule.domains = ["office.example"]
        rule.target = .server(UUID())
        rule.enabled = false

        XCTAssertFalse(RoutingRule.needsProfile([rule]),
                       "a rule that is switched off routes nothing")
    }
}

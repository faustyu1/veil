import XCTest
@testable import XrayClient

/// A user's own rules used to apply only under the "Custom" preset, which made
/// "send this app through that server" cost the preset's bypasses. These cover
/// the order the rules end up in now.
final class RoutingRuleOrderTests: XCTestCase {

    private func settings(preset: RoutingPreset,
                          blockAds: Bool = false) -> AppSettings {
        var settings = AppSettings()
        settings.routingPreset = preset
        settings.blockAds = blockAds
        settings.customRules = [
            RoutingRule(name: "Work app", target: .direct,
                        processNames: ["Slack"])
        ]
        return settings
    }

    func testUserRulesApplyUnderEveryPreset() {
        for preset in RoutingPreset.allCases {
            let rules = settings(preset: preset).effectiveRoutingRules
            XCTAssertTrue(rules.contains { $0.name == "Work app" },
                          "\(preset.rawValue) dropped the user's rule")
        }
    }

    func testLanBypassStaysAheadOfUserRules() {
        let rules = settings(preset: .bypassLAN).effectiveRoutingRules
        let lan = rules.firstIndex { $0.name == "LAN direct" }
        let user = rules.firstIndex { $0.name == "Work app" }
        // An app rule would otherwise swallow that app's LAN traffic too.
        XCTAssertNotNil(lan)
        XCTAssertNotNil(user)
        XCTAssertLessThan(lan!, user!)
    }

    func testUserRulesOutrankThePresetsCountryRules() {
        let rules = settings(preset: .bypassChina).effectiveRoutingRules
        let user = rules.firstIndex { $0.name == "Work app" }!
        let country = rules.firstIndex { $0.name == "China sites direct" }!
        XCTAssertLessThan(user, country)
    }

    func testAdBlockingComesFirst() {
        let rules = settings(preset: .bypassRussia, blockAds: true).effectiveRoutingRules
        XCTAssertEqual(rules.first?.target, .block)
        XCTAssertEqual(rules.first?.domains, ["geosite:category-ads-all"])
    }

    /// The scenario this ordering exists for: a WireGuard peer for the
    /// office network, one address routed to it, and a subscription carrying
    /// everything else. The LAN bypass would otherwise send that address
    /// straight out of the physical interface and the rule would do nothing.
    func testAnAddressedRuleOutranksTheLanBypass() {
        var settings = AppSettings()
        settings.routingPreset = .bypassLAN
        let peer = UUID()
        settings.customRules = [
            RoutingRule(name: "Office host", target: .server(peer),
                        ips: ["172.16.4.10/32"])
        ]

        let rules = settings.effectiveRoutingRules
        let office = rules.firstIndex { $0.name == "Office host" }!
        let lan = rules.firstIndex { $0.name == "LAN direct" }!
        XCTAssertLessThan(office, lan)
    }

    /// Only rules that name their own destinations move ahead — an
    /// application rule still sits behind the bypass.
    func testAnApplicationRuleStaysBehindTheLanBypass() {
        var settings = AppSettings()
        settings.routingPreset = .bypassLAN
        settings.customRules = [
            RoutingRule(name: "Addressed", target: .direct, domains: ["example.com"]),
            RoutingRule(name: "Work app", target: .direct, processNames: ["Slack"])
        ]

        let names = settings.effectiveRoutingRules.map(\.name)
        XCTAssertEqual(names.firstIndex(of: "Addressed")! < names.firstIndex(of: "LAN direct")!,
                       true)
        XCTAssertLessThan(names.firstIndex(of: "LAN direct")!,
                          names.firstIndex(of: "Work app")!)
    }

    /// A source-side rule is about who is asking, not where the traffic goes,
    /// so it does not get to jump the bypass.
    func testASourceRuleDoesNotJumpTheBypass() {
        var settings = AppSettings()
        settings.routingPreset = .bypassLAN
        var rule = RoutingRule(name: "From the NAS", target: .direct,
                               ips: ["192.168.1.9/32"])
        rule.direction = .source
        settings.customRules = [rule]

        let names = settings.effectiveRoutingRules.map(\.name)
        XCTAssertLessThan(names.firstIndex(of: "LAN direct")!,
                          names.firstIndex(of: "From the NAS")!)
    }

    // MARK: - What counts as an unapplied change

    /// The reconnect notice used to appear whenever the panes were opened
    /// while connected, which said a change was pending when none was.
    func testSettingsThatDidNotChangeHaveTheSameFingerprint() {
        var settings = AppSettings()
        settings.customRules = [RoutingRule(name: "Office", target: .direct,
                                            ips: ["172.16.4.10/32"])]
        var reopened = settings
        // Things the core is not built from.
        reopened.appearance = .dark
        reopened.logPaneHeight = 240
        reopened.lastRoutingTab = "dns"
        reopened.showSourcesTab = false

        XCTAssertEqual(settings.routingFingerprint, reopened.routingFingerprint)
    }

    func testEveryRoutingEditChangesTheFingerprint() {
        let base = AppSettings()
        var edits: [(String, AppSettings)] = []

        var rule = base
        rule.customRules = [RoutingRule(name: "Office", target: .direct,
                                        ips: ["172.16.4.10/32"])]
        edits.append(("a rule", rule))

        var preset = base
        preset.routingPreset = .bypassRussia
        edits.append(("the preset", preset))

        var ads = base
        ads.blockAds = true
        edits.append(("ad blocking", ads))

        var group = base
        group.serverGroups = [ServerGroup(name: "EU", kind: .selector, memberIDs: [UUID()])]
        edits.append(("a group", group))

        var lists = base
        lists.communityLists = ["some-list"]
        edits.append(("a community list", lists))

        var dns = base
        dns.dns.enabled = !dns.dns.enabled
        edits.append(("the resolver", dns))

        for (what, edited) in edits {
            XCTAssertNotEqual(base.routingFingerprint, edited.routingFingerprint,
                              "editing \(what) left the fingerprint alone")
        }
    }

    func testBuiltInRulesAreStillGuardsThenPreset() {
        // The two halves together must equal what the presets used to return,
        // since the profile tests and the Xray path both go through this.
        for preset in RoutingPreset.allCases {
            let combined = preset.guardRules(blockAds: true) + preset.presetRules()
            XCTAssertEqual(combined.map(\.name),
                           preset.builtInRules(blockAds: true).map(\.name))
        }
    }
}

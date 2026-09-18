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

import XCTest
@testable import XrayClient

/// The list is where every arrangement the user asked for shows up: grouping by
/// something other than the subscription, pinning, hiding, manual order, tag
/// filters. All of it is decided here, by a pure function, so the rules can be
/// tested without SwiftUI and the keyboard navigation cannot drift away from
/// what is drawn.
final class ServerListBuilderTests: XCTestCase {

    // MARK: - Grouping

    func testBySubscriptionThereIsOneSectionPerSource() {
        let sections = build(sources: [source("Panel A", ["NL-01"]),
                                       source("Panel B", ["DE-01"])],
                             grouping: .subscription)

        XCTAssertEqual(sections.map(\.title), ["Panel A", "Panel B"])
        XCTAssertEqual(sections[0].servers.map(\.name), ["NL-01"])
    }

    func testACollapsedSourceKeepsItsRowsButSaysItIsCollapsed() {
        var collapsed = source("Panel A", ["NL-01"])
        collapsed.isCollapsed = true
        let sections = build(sources: [collapsed], grouping: .subscription)

        XCTAssertTrue(sections[0].isCollapsed)
        XCTAssertEqual(sections[0].servers.count, 1,
                       "collapse is a display state, not a filter")
    }

    func testByCountryTheSourcesAreMergedIntoOneListPerPlace() {
        let sections = build(sources: [source("Panel A", ["NL-01", "DE-01"]),
                                       source("Panel B", ["🇳🇱 Amsterdam"])],
                             grouping: .country)

        XCTAssertEqual(sections.map(\.title), ["Germany", "Netherlands"])
        XCTAssertEqual(sections.first { $0.title == "Netherlands" }?.servers.count, 2)
    }

    func testANodeWithNoCountryLandsInOtherAtTheEnd() {
        let sections = build(sources: [source("Panel A", ["NL-01", "Fast Server"])],
                             grouping: .country)

        XCTAssertEqual(sections.map(\.title), ["Netherlands", "Other"])
        XCTAssertEqual(sections.last?.servers.map(\.name), ["Fast Server"])
    }

    func testByTagTheSectionsAreTheUsersOwnLabels() {
        let source = source("Panel A", ["NL-01", "DE-01"])
        var annotations: [UUID: NodeAnnotation] = [:]
        annotations[source.servers[0].id] = NodeAnnotation(tags: ["work", "fast"])

        let sections = build(sources: [source], annotations: annotations, grouping: .tag)
        let titles = sections.map(\.title)

        XCTAssertEqual(titles, ["fast", "work", "Other"],
                       "with derived tags off these are only what the user wrote")
        XCTAssertEqual(sections.first { $0.title == "work" }?.servers.map(\.name),
                       ["NL-01"],
                       "a node with several tags appears under each of them")
        XCTAssertEqual(sections.last?.servers.map(\.name), ["DE-01"],
                       "an unlabelled node has to stay reachable")
    }

    func testWithDerivedTagsOnTheSectionsAlsoHoldWhatTheNamesSay() {
        let source = source("Panel A", ["NL-01", "DE-01"])
        var annotations: [UUID: NodeAnnotation] = [:]
        annotations[source.servers[0].id] = NodeAnnotation(tags: ["work"])

        let sections = build(sources: [source], annotations: annotations,
                             grouping: .tag, autoTags: true)
        let titles = sections.map(\.title)

        XCTAssertTrue(titles.contains("work"), "got \(titles)")
        XCTAssertTrue(titles.contains("NL"),
                      "the country read out of the name is a tag like any other")
        XCTAssertFalse(titles.contains("Other"),
                       "every node has at least its protocol, so nothing is untagged")
    }

    func testWithNoGroupingEverythingIsOneList() {
        let sections = build(sources: [source("Panel A", ["NL-01"]),
                                       source("Panel B", ["DE-01"])],
                             grouping: .none)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].servers.map(\.name), ["NL-01", "DE-01"])
    }

    // MARK: - Order

    func testPinnedRowsComeFirst() {
        let source = source("Panel A", ["A", "B", "C"])
        let annotations = [source.servers[2].id: NodeAnnotation(pinned: true)]

        let sections = build(sources: [source], annotations: annotations,
                             grouping: .subscription)

        XCTAssertEqual(sections[0].servers.map(\.name), ["C", "A", "B"])
    }

    func testAManualOrderOverridesTheOrderTheSourceSent() {
        let source = source("Panel A", ["A", "B", "C"])
        let annotations = [source.servers[0].id: NodeAnnotation(sortIndex: 2),
                           source.servers[1].id: NodeAnnotation(sortIndex: 1)]

        let sections = build(sources: [source], annotations: annotations,
                             grouping: .subscription)

        XCTAssertEqual(sections[0].servers.map(\.name), ["B", "A", "C"],
                       "nodes the user never moved keep the source's order, behind those they did")
    }

    func testThePingSortOrdersByLatency() {
        let source = source("Panel A", ["A", "B"])
        let slow = source.servers[0].id
        var filter = ListFilter()
        filter.sortByPing = true
        filter.latency = { $0 == slow ? 300 : 40 }

        let sections = build(sources: [source], grouping: .subscription, filter: filter)

        XCTAssertEqual(sections[0].servers.map(\.name), ["B", "A"])
    }

    func testAnUnreachableNodeSortsLastRatherThanFirst() {
        let source = source("Panel A", ["A", "B"])
        let untested = source.servers[0].id
        var filter = ListFilter()
        filter.sortByPing = true
        filter.latency = { $0 == untested ? nil : 40 }

        let sections = build(sources: [source], grouping: .subscription, filter: filter)

        XCTAssertEqual(sections[0].servers.map(\.name), ["B", "A"])
    }

    // MARK: - Hiding and filtering

    func testAHiddenNodeIsCountedNotDrawn() {
        let source = source("Panel A", ["A", "B"])
        let annotations = [source.servers[0].id: NodeAnnotation(hidden: true)]

        let sections = build(sources: [source], annotations: annotations,
                             grouping: .subscription)

        XCTAssertEqual(sections[0].servers.map(\.name), ["B"])
        XCTAssertEqual(sections[0].hiddenCount, 1)
    }

    func testHiddenNodesComeBackWhenAsked() {
        let source = source("Panel A", ["A", "B"])
        let annotations = [source.servers[0].id: NodeAnnotation(hidden: true)]
        var filter = ListFilter()
        filter.showHidden = true

        let sections = build(sources: [source], annotations: annotations,
                             grouping: .subscription, filter: filter)

        XCTAssertEqual(sections[0].servers.count, 2)
    }

    func testSearchMatchesTheNameAndTheAddress() {
        var source = source("Panel A", ["NL-01", "DE-01"])
        source.servers[1].address = "berlin.example.com"
        var filter = ListFilter()

        filter.search = "nl"
        XCTAssertEqual(build(sources: [source], grouping: .none, filter: filter)
            .first?.servers.map(\.name), ["NL-01"])

        filter.search = "berlin"
        XCTAssertEqual(build(sources: [source], grouping: .none, filter: filter)
            .first?.servers.map(\.name), ["DE-01"])
    }

    func testTagFiltersAreOrWithinAKindAndAndAcrossKinds() {
        let source = source("Panel A", ["NL-01", "DE-01", "US-01"])
        var annotations: [UUID: NodeAnnotation] = [:]
        annotations[source.servers[0].id] = NodeAnnotation(tags: ["work"])
        annotations[source.servers[2].id] = NodeAnnotation(tags: ["work"])

        var filter = ListFilter()
        filter.countries = ["NL", "DE"]
        XCTAssertEqual(names(build(sources: [source], annotations: annotations,
                                   grouping: .none, filter: filter)),
                       ["NL-01", "DE-01"])

        filter.tags = ["work"]
        XCTAssertEqual(names(build(sources: [source], annotations: annotations,
                                   grouping: .none, filter: filter)),
                       ["NL-01"],
                       "a country filter and a tag filter narrow each other")
    }

    func testTheAliveFilterDropsWhatNeverAnswered() {
        let source = source("Panel A", ["A", "B"])
        let dead = source.servers[0].id
        var filter = ListFilter()
        filter.aliveOnly = true
        filter.latency = { $0 == dead ? nil : 40 }

        XCTAssertEqual(names(build(sources: [source], grouping: .none, filter: filter)), ["B"])
    }

    func testASectionEmptiedByAFilterDisappearsButAnEmptySourceDoesNot() {
        let empty = source("Panel B", [])
        var filter = ListFilter()
        filter.search = "nothing matches this"

        let filtered = build(sources: [source("Panel A", ["NL-01"]), empty],
                             grouping: .subscription, filter: filter)
        XCTAssertTrue(filtered.isEmpty)

        let unfiltered = build(sources: [empty], grouping: .subscription)
        XCTAssertEqual(unfiltered.map(\.title), ["Panel B"],
                       "a subscription with nothing in it is still a subscription")
    }

    // MARK: - Annotations on a row

    func testANameOverrideIsWhatTheListShows() {
        let source = source("Panel A", ["NL-01"])
        let id = source.servers[0].id
        let annotations = [id: NodeAnnotation(nameOverride: "Home")]

        let sections = build(sources: [source], annotations: annotations, grouping: .none)

        XCTAssertEqual(sections[0].servers[0].name, "Home")
        XCTAssertEqual(sections[0].servers[0].id, id, "renaming is not a new node")
    }

    func testAGroupRowIsListedAboveTheNodes() {
        var source = source("Panel A", ["NL-01"])
        source.groupRows = [node(named: "auto")]

        let sections = build(sources: [source], grouping: .subscription)

        XCTAssertEqual(sections[0].groups.map(\.name), ["auto"])
        XCTAssertEqual(sections[0].servers.map(\.name), ["NL-01"])
    }

    // MARK: - Helpers

    private func build(sources: [ListSource],
                       annotations: [UUID: NodeAnnotation] = [:],
                       grouping: ListGrouping,
                       filter: ListFilter = ListFilter(),
                       autoTags: Bool = false) -> [ListSection] {
        ServerListBuilder.sections(sources: sources, annotations: annotations,
                                   grouping: grouping, filter: filter,
                                   autoTags: autoTags,
                                   locale: Locale(identifier: "en_US"))
    }

    private func names(_ sections: [ListSection]) -> [String] {
        sections.flatMap { $0.servers.map(\.name) }
    }

    private func source(_ name: String, _ servers: [String]) -> ListSource {
        ListSource(id: UUID(), name: name, isCollapsed: false,
                   groupRows: [], servers: servers.map(node(named:)))
    }

    private func node(named name: String) -> ProxyConfig {
        var node = ProxyConfig(name: name, proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = UUID().uuidString
        return node
    }
}

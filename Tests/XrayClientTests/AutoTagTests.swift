import XCTest
@testable import XrayClient

/// Tags a node earns by what it already says about itself.
///
/// Manual labels are the second half of the feature; on their own they mean a
/// fresh install has no tags at all, so grouping by tag shows one bucket and
/// the tag filter is empty. A provider's names already carry the country, the
/// protocol, the transport and their own conventions — `Premium`, `Trial`,
/// `IPv6`, `Game` — and reading them costs nothing and stores nothing.
final class AutoTagTests: XCTestCase {

    func testACountryInTheNameBecomesATag() {
        let tags = AutoTags.tags(for: node("🇳🇱 Amsterdam 01"))

        XCTAssertTrue(tags.contains("NL"), "got \(tags)")
    }

    func testTheProtocolIsATag() {
        XCTAssertTrue(AutoTags.tags(for: node("NL-01")).contains("vless"))
    }

    func testANonDefaultTransportIsATag() {
        var node = node("NL-01")
        node.network = .ws
        XCTAssertTrue(AutoTags.tags(for: node).contains("ws"))
    }

    func testAPlainTCPTransportIsNotWorthATag() {
        var node = node("NL-01")
        node.network = .tcp
        XCTAssertFalse(AutoTags.tags(for: node).contains("tcp"),
                       "a tag every node has separates nothing")
    }

    func testRealityIsWorthSaying() {
        var node = node("NL-01")
        node.security = .reality
        XCTAssertTrue(AutoTags.tags(for: node).contains("reality"))
    }

    func testAProvidersOwnWordIsPickedUp() {
        let tags = AutoTags.tags(for: node("NL Premium 01"))

        XCTAssertTrue(tags.contains("premium"), "got \(tags)")
    }

    func testSeveralWordsAreAllPickedUp() {
        let tags = AutoTags.tags(for: node("DE Trial IPv6"))

        XCTAssertTrue(tags.contains("trial"))
        XCTAssertTrue(tags.contains("ipv6"))
    }

    func testAWordIsMatchedWhateverItsCase() {
        XCTAssertTrue(AutoTags.tags(for: node("NL PREMIUM")).contains("premium"))
    }

    func testAnArbitraryWordIsNotATag() {
        let tags = AutoTags.tags(for: node("Amsterdam Zwiebelkuchen"))

        XCTAssertFalse(tags.contains("zwiebelkuchen"),
                       "every node name would otherwise become its own tag")
    }

    func testTagsDoNotRepeat() {
        let tags = AutoTags.tags(for: node("NL Premium premium"))

        XCTAssertEqual(tags.filter { $0 == "premium" }.count, 1)
    }

    func testTagsAreStable() {
        let node = node("🇳🇱 NL Premium 01")

        XCTAssertEqual(AutoTags.tags(for: node), AutoTags.tags(for: node),
                       "a reshuffling tag list reshuffles the whole display")
    }

    // MARK: - Combined with the user's own

    func testAManualTagJoinsTheAutomaticOnes() {
        let node = node("🇳🇱 Amsterdam")
        let all = AutoTags.all(for: node, annotation: NodeAnnotation(tags: ["work"]), derived: true)

        XCTAssertTrue(all.contains("work"))
        XCTAssertTrue(all.contains("NL"))
    }

    func testAManualTagComesFirst() {
        let node = node("🇳🇱 Amsterdam")
        let all = AutoTags.all(for: node, annotation: NodeAnnotation(tags: ["work"]), derived: true)

        XCTAssertEqual(all.first, "work",
                       "what the user wrote outranks what was guessed")
    }

    func testAManualTagThatRepeatsAnAutomaticOneIsNotShownTwice() {
        let node = node("🇳🇱 Amsterdam")
        let all = AutoTags.all(for: node, annotation: NodeAnnotation(tags: ["NL"]), derived: true)

        XCTAssertEqual(all.filter { $0 == "NL" }.count, 1)
    }

    func testARenamedNodeIsTaggedByItsNewName() {
        let node = node("🇳🇱 Amsterdam")
        let all = AutoTags.all(for: node,
                               annotation: NodeAnnotation(nameOverride: "🇩🇪 Berlin"),
                               derived: true)

        XCTAssertTrue(all.contains("DE"), "got \(all)")
        XCTAssertFalse(all.contains("NL"))
    }

    // MARK: - Where the tags are used

    func testTheTagFilterMatchesADerivedTag() {
        var source = ListSource(id: UUID(), name: "Panel")
        source.servers = [node("🇳🇱 Amsterdam"), node("🇩🇪 Berlin")]
        var filter = ListFilter()
        filter.tags = ["NL"]

        let sections = ServerListBuilder.sections(sources: [source], annotations: [:],
                                                  grouping: .subscription, filter: filter,
                                                  autoTags: true)

        XCTAssertEqual(sections.first?.servers.map(\.name), ["🇳🇱 Amsterdam"],
                       "a tag you can see has to be a tag you can filter by")
    }

    func testGroupingByTagBucketsOnDerivedTags() {
        var source = ListSource(id: UUID(), name: "Panel")
        source.servers = [node("NL Premium")]

        let sections = ServerListBuilder.sections(sources: [source], annotations: [:],
                                                  grouping: .tag, filter: ListFilter(),
                                                  autoTags: true)

        XCTAssertTrue(sections.contains { $0.title == "premium" },
                      "got \(sections.map(\.title))")
    }

    func testAnAutomaticGroupCanAskForADerivedTag() {
        let premium = GroupResolver.Candidate(server: node("NL Premium"), sourceID: UUID())
        let basic = GroupResolver.Candidate(server: node("NL Basic"), sourceID: UUID())
        var query = GroupQuery()
        query.tags = ["premium"]

        let ids = GroupResolver.members(of: query, in: [premium, basic], annotations: [:],
                                        autoTags: true)

        XCTAssertEqual(ids, [premium.server.id])
    }

    // MARK: - Switched off

    func testDerivedTagsAreOffUntilTheUserAsksForThem() {
        XCTAssertFalse(AppSettings().autoTags,
                       "these are guesses about someone else's naming")
    }

    func testWithThemOffOnlyTheUsersOwnLabelsShow() {
        let node = node("🇳🇱 Amsterdam Premium")

        let all = AutoTags.all(for: node,
                               annotation: NodeAnnotation(tags: ["work"]),
                               derived: false)

        XCTAssertEqual(all, ["work"])
    }

    func testWithThemOffTheListDoesNotBucketByThem() {
        var source = ListSource(id: UUID(), name: "Panel")
        source.servers = [node("NL Premium")]

        let sections = ServerListBuilder.sections(sources: [source], annotations: [:],
                                                  grouping: .tag, filter: ListFilter(),
                                                  autoTags: false)

        XCTAssertFalse(sections.contains { $0.title == "premium" },
                       "got \(sections.map(\.title))")
    }

    func testWithThemOffAGroupQueryMatchesOnlyTheUsersLabels() {
        let premium = GroupResolver.Candidate(server: node("NL Premium"), sourceID: UUID())
        var query = GroupQuery()
        query.tags = ["premium"]

        let ids = GroupResolver.members(of: query, in: [premium], annotations: [:],
                                        autoTags: false)

        XCTAssertTrue(ids.isEmpty)
    }

    // MARK: - Helpers

    private func node(_ name: String) -> ProxyConfig {
        var node = ProxyConfig(name: name, proto: .vless, address: "1.2.3.4", port: 443)
        node.uuid = UUID().uuidString
        return node
    }
}

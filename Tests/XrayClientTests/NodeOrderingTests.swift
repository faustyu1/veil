import XCTest
@testable import XrayClient

/// Dragging a row is the only way a manual order gets written, and it has to
/// leave every other section alone.
final class NodeOrderingTests: XCTestCase {

    func testDroppingARowWritesAnOrderForThatSectionOnly() {
        let section = [UUID(), UUID(), UUID()]
        let elsewhere = UUID()
        var annotations: [UUID: NodeAnnotation] = [elsewhere: NodeAnnotation(sortIndex: 7)]

        NodeOrdering.apply(order: [section[2], section[0], section[1]], to: &annotations)

        XCTAssertEqual(annotations[section[2]]?.sortIndex, 0)
        XCTAssertEqual(annotations[section[0]]?.sortIndex, 1)
        XCTAssertEqual(annotations[section[1]]?.sortIndex, 2)
        XCTAssertEqual(annotations[elsewhere]?.sortIndex, 7,
                       "a node in another section is not renumbered")
    }

    func testReorderingKeepsEverythingElseOnTheNode() {
        let id = UUID()
        var annotations = [id: NodeAnnotation(tags: ["work"], pinned: true)]

        NodeOrdering.apply(order: [id], to: &annotations)

        XCTAssertEqual(annotations[id]?.tags, ["work"])
        XCTAssertTrue(annotations[id]?.pinned == true)
        XCTAssertEqual(annotations[id]?.sortIndex, 0)
    }

    func testClearingTheOrderHandsTheSectionBackToItsSource() {
        let ids = [UUID(), UUID()]
        var annotations = [ids[0]: NodeAnnotation(sortIndex: 1),
                           ids[1]: NodeAnnotation(tags: ["work"], sortIndex: 0)]

        NodeOrdering.clear(ids, in: &annotations)

        XCTAssertNil(annotations[ids[0]], "an annotation with nothing left in it is dropped")
        XCTAssertNil(annotations[ids[1]]?.sortIndex)
        XCTAssertEqual(annotations[ids[1]]?.tags, ["work"])
    }
}

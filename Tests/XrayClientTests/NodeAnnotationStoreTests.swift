import XCTest
@testable import XrayClient

/// Annotations live in `store.json` with the rest of the settings, and that
/// file is read by builds older and newer than the one that wrote it.
final class NodeAnnotationStoreTests: XCTestCase {

    func testAnnotationsSurviveASaveAndLoad() throws {
        let id = UUID()
        var settings = AppSettings()
        settings.nodeAnnotations[id] = NodeAnnotation(tags: ["work"], pinned: true,
                                                      nameOverride: "Home", sortIndex: 3)
        settings.listGrouping = .country

        let data = try JSONEncoder().encode(settings)
        let loaded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(loaded.nodeAnnotations[id]?.tags, ["work"])
        XCTAssertEqual(loaded.nodeAnnotations[id]?.nameOverride, "Home")
        XCTAssertEqual(loaded.nodeAnnotations[id]?.sortIndex, 3)
        XCTAssertEqual(loaded.listGrouping, .country)
    }

    func testAStoreFromAnOlderBuildLoadsWithTodaysBehaviour() throws {
        let data = Data("{}".utf8)
        let loaded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertTrue(loaded.nodeAnnotations.isEmpty)
        XCTAssertEqual(loaded.listGrouping, .subscription)
        XCTAssertFalse(loaded.showHiddenNodes)
    }

    func testAPartiallyWrittenAnnotationStillLoads() throws {
        let data = Data(#"{"tags":["work"]}"#.utf8)
        let annotation = try JSONDecoder().decode(NodeAnnotation.self, from: data)

        XCTAssertEqual(annotation.tags, ["work"])
        XCTAssertFalse(annotation.pinned)
        XCTAssertNil(annotation.sortIndex)
    }
}

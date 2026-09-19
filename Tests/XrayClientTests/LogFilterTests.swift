import XCTest
@testable import XrayClient

/// Reading a log that scrolls past at connect time.
///
/// The pane shows whatever the core wrote, which at debug level is hundreds of
/// lines a minute. Finding the one that matters means narrowing by severity
/// and by text, and both have to be honest about lines the cores format
/// differently — xray writes `[Warning]`, sing-box writes `WARN`.
final class LogFilterTests: XCTestCase {

    func testNoFilterLeavesTheTextAlone() {
        let text = "2026/09/19 [Info] started\n2026/09/19 [Error] boom"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: nil), text)
    }

    func testAQueryKeepsOnlyTheMatchingLines() {
        let text = "[Info] listening on 1080\n[Info] connected to NL-01"

        XCTAssertEqual(LogFilter.apply(text, query: "NL-01", minimum: nil),
                       "[Info] connected to NL-01")
    }

    func testAQueryIgnoresCase() {
        let text = "[Info] Reality handshake done"

        XCTAssertEqual(LogFilter.apply(text, query: "reality", minimum: nil), text)
    }

    func testTheOrderOfTheKeptLinesIsTheOrderTheyArrivedIn() {
        let text = "a hit\nmiss\nb hit"

        XCTAssertEqual(LogFilter.apply(text, query: "hit", minimum: nil),
                       "a hit\nb hit")
    }

    // MARK: - Severity

    func testALevelDropsTheQuieterLines() {
        let text = "[Debug] dialing\n[Info] up\n[Warning] slow\n[Error] boom"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: .warning),
                       "[Warning] slow\n[Error] boom")
    }

    func testTheSingBoxSpellingIsUnderstood() {
        let text = "2026-09-19 21:00:00 INFO inbound started\n"
                 + "2026-09-19 21:00:01 ERROR dial failed"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: .error),
                       "2026-09-19 21:00:01 ERROR dial failed")
    }

    func testAFatalLineIsNeverFilteredOut() {
        let text = "[Debug] dialing\n2026-09-19 FATAL cannot bind"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: .error),
                       "2026-09-19 FATAL cannot bind")
    }

    func testAContinuationLineStaysWithTheLineItBelongsTo() {
        let text = "[Error] config failed:\n  > bad port 0\n[Debug] retrying"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: .warning),
                       "[Error] config failed:\n  > bad port 0",
                       "hiding the detail under an error hides the error's reason")
    }

    func testALineWithNoLevelAndNothingAboveItIsKept() {
        let text = "veil: launching sing-box\n[Info] started"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: .warning),
                       "veil: launching sing-box",
                       "the app's own lines carry no level and must not vanish")
    }

    func testBothFiltersApplyTogether() {
        let text = "[Error] dial NL-01 failed\n[Error] dial DE-02 failed\n[Info] NL-01 up"

        XCTAssertEqual(LogFilter.apply(text, query: "NL-01", minimum: .error),
                       "[Error] dial NL-01 failed")
    }

    func testNoneMeansEveryLevel() {
        let text = "[Debug] dialing\n[Error] boom"

        XCTAssertEqual(LogFilter.apply(text, query: "", minimum: LogLevel.none), text)
    }
}

/// The log pane's height, which the user drags and the app remembers.
final class LogPaneHeightTests: XCTestCase {

    func testTheDefaultIsTheHeightThePaneAlwaysHad() {
        XCTAssertEqual(AppSettings().logPaneHeight, 168)
    }

    func testAHeightSurvivesARoundTrip() throws {
        var settings = AppSettings()
        settings.logPaneHeight = 320

        let back = try JSONDecoder().decode(
            AppSettings.self, from: JSONEncoder().encode(settings))

        XCTAssertEqual(back.logPaneHeight, 320)
    }

    func testSettingsWrittenBeforeTheDragHandleStillLoad() throws {
        let back = try JSONDecoder().decode(AppSettings.self,
                                            from: Data("{}".utf8))

        XCTAssertEqual(back.logPaneHeight, 168)
    }

    func testAPaneCannotBeDraggedShorterThanItsToolbar() {
        XCTAssertEqual(AppSettings.clampedLogHeight(10), 96)
    }

    func testAPaneCannotEatTheWholeWindow() {
        XCTAssertEqual(AppSettings.clampedLogHeight(4000), 520)
    }

    func testAReasonableHeightIsLeftAlone() {
        XCTAssertEqual(AppSettings.clampedLogHeight(240), 240)
    }

    func testAHeightStoredOutOfRangeIsBroughtBackIn() throws {
        let back = try JSONDecoder().decode(
            AppSettings.self, from: Data(#"{"logPaneHeight": 9000}"#.utf8))

        XCTAssertEqual(back.logPaneHeight, 520,
                       "a bad file must not hide the whole server list")
    }
}

import XCTest
@testable import UsageOrb

final class RingStateTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_792_000_000)

    private func window(_ id: String, _ percent: Double, resetsIn: TimeInterval? = 3600, observedAgo: TimeInterval = 0,
                        source: DataSource = .undocumentedAPI) -> QuotaWindow {
        QuotaWindow(id: id, provider: .claudeCode, name: id, usedPercent: percent,
                    resetsAt: resetsIn.map { now.addingTimeInterval($0) }, source: source,
                    observedAt: now.addingTimeInterval(-observedAgo))
    }

    private func compute(_ windows: [QuotaWindow]) -> RingState {
        RingState.compute(windows: windows, thresholds: .init(), refreshInterval: 300, now: now)
    }

    func testEmptyIsUnknown() {
        XCTAssertTrue(compute([]).isUnknown)
        XCTAssertTrue(compute([]).accessibilityDescription(for: .codex).hasPrefix("Codex: usage unknown"))
    }

    func testMostUrgentPicksHighestFreshWindow() {
        let state = compute([window("a", 20), window("b", 75), window("c", 40)])
        guard case .value(let percent, let level, let picked, let stale) = state else { return XCTFail() }
        XCTAssertEqual(percent, 75)
        XCTAssertEqual(level, .warning)
        XCTAssertEqual(picked.id, "b")
        XCTAssertFalse(stale)
    }

    func testFreshWindowsBeatStaleOnes() {
        // The stale 95% is older than the API's 15-minute freshness, so the fresh 30% wins.
        let state = compute([window("stale", 95, observedAgo: 3600), window("fresh", 30)])
        XCTAssertEqual(state.percent, 30)
    }

    func testOnlyStaleWindowsAreShownAsStale() {
        guard case .value(_, _, _, let stale) = compute([window("old", 50, observedAgo: 7200)]) else { return XCTFail() }
        XCTAssertTrue(stale)
    }

    func testLocalLogsStaleAfterAnHour() {
        XCTAssertEqual(compute([window("log", 50, observedAgo: 30 * 60, source: .localLog)]).isStaleValue, false)
        XCTAssertEqual(compute([window("log", 50, observedAgo: 61 * 60, source: .localLog)]).isStaleValue, true)
    }

    func testWindowsPastTheirResetAreIgnored() {
        XCTAssertEqual(compute([window("reset", 99, resetsIn: -60), window("live", 10)]).percent, 10)
        XCTAssertTrue(compute([window("reset", 99, resetsIn: -60)]).isUnknown)
    }

    func testThresholds() {
        let thresholds = RingThresholds(warning: 70, critical: 90)
        XCTAssertEqual(thresholds.level(for: 69.9), .normal)
        XCTAssertEqual(thresholds.level(for: 70), .warning)
        XCTAssertEqual(thresholds.level(for: 90), .critical)
        XCTAssertEqual(thresholds.level(for: 130), .critical)
    }

    func testAccessibilityDescriptionNamesSourceAndFreshness() {
        let text = compute([window("Weekly", 21, observedAgo: 7200)]).accessibilityDescription(for: .claudeCode)
        XCTAssertTrue(text.contains("Claude Code Weekly: 21% used"), text)
        XCTAssertTrue(text.contains("may be out of date"), text)
    }
}

private extension RingState {
    var isUnknown: Bool { if case .unknown = self { true } else { false } }
    var isStaleValue: Bool? { if case .value(_, _, _, let stale) = self { stale } else { nil } }
}

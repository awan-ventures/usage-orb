import XCTest
@testable import UsageOrb

final class HistoryLogTests: XCTestCase {
    let start = Date(timeIntervalSince1970: 1_792_000_000)

    private func snapshot(percent: Double, spend: Double, at date: Date) -> ProviderSnapshot {
        ProviderSnapshot(provider: .openRouter,
                         windows: [QuotaWindow(id: "w", provider: .openRouter, name: "W", usedPercent: percent,
                                               resetsAt: nil, source: .officialAPI, observedAt: date)],
                         money: [MoneyFigure(id: "openRouter.spendDaily", provider: .openRouter, name: "Today", kind: .spend,
                                             amount: spend, currency: "USD", source: .officialAPI, observedAt: date),
                                 MoneyFigure(id: "openRouter.spendTotal", provider: .openRouter, name: "Total", kind: .spend,
                                             amount: spend, currency: "USD", source: .officialAPI, observedAt: date)],
                         fetchedAt: date)
    }

    func testUnchangedValuesAreThrottledButChangesRecorded() {
        var log = HistoryLog()
        log.record(snapshot(percent: 10, spend: 1, at: start), now: start)
        log.record(snapshot(percent: 10, spend: 1, at: start.addingTimeInterval(300)), now: start)
        log.record(snapshot(percent: 25, spend: 1, at: start.addingTimeInterval(600)), now: start)
        log.record(snapshot(percent: 25, spend: 1, at: start.addingTimeInterval(600 + HistoryLog.heartbeat)), now: start)
        XCTAssertEqual(log.samples.filter { $0.series == "w" }.map(\.value), [10, 25, 25])
        XCTAssertFalse(log.samples.contains { $0.series == "openRouter.spendTotal" }, "only daily spend is charted")
    }

    func testDailySpendKeepsLatestReadingPerUTCDay() {
        var log = HistoryLog()
        let midnight = HistoryLog.utc.startOfDay(for: start).addingTimeInterval(86_400)
        log.record(snapshot(percent: 1, spend: 0.5, at: midnight.addingTimeInterval(-7200)), now: start)
        log.record(snapshot(percent: 1, spend: 0.9, at: midnight.addingTimeInterval(-60)), now: start)
        log.record(snapshot(percent: 1, spend: 0.1, at: midnight.addingTimeInterval(60)), now: start)
        XCTAssertEqual(log.samples.filter { $0.kind == .dailySpend }.map(\.value), [0.9, 0.1])
    }

    func testOldSamplesArePruned() {
        var log = HistoryLog()
        log.record(snapshot(percent: 1, spend: 1, at: start), now: start)
        let later = start.addingTimeInterval(HistoryLog.retention + 3600)
        log.record(snapshot(percent: 2, spend: 2, at: later), now: later)
        XCTAssertTrue(log.samples.allSatisfy { $0.date == later })
    }
}

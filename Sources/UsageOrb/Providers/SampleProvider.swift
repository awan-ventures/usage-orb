import Foundation

/// Synthetic figures for UI work and screenshots. Enabled with `USAGE_ORB_SAMPLE=1`; never reads real accounts.
struct SampleProvider: UsageProvider {
    let id: ProviderID
    var method: String { "Sample data (USAGE_ORB_SAMPLE=1). No accounts are read." }

    static var isEnabled: Bool { ProcessInfo.processInfo.environment["USAGE_ORB_SAMPLE"] == "1" }

    func fetch(now: Date) async throws -> ProviderSnapshot {
        try await Task.sleep(for: .milliseconds(300))
        return Self.snapshot(for: id, now: now)
    }

    static func snapshot(for id: ProviderID, now: Date) -> ProviderSnapshot {
        func window(_ key: String, _ name: String, _ percent: Double, resetsIn hours: Double) -> QuotaWindow {
            QuotaWindow(id: "\(id.rawValue).\(key)", provider: id, name: name, usedPercent: percent,
                        resetsAt: now.addingTimeInterval(hours * 3600), source: .sample, observedAt: now)
        }
        func money(_ key: String, _ name: String, _ kind: MoneyFigure.Kind, _ amount: Double, _ currency: String = "USD") -> MoneyFigure {
            MoneyFigure(id: "\(id.rawValue).\(key)", provider: id, name: name, kind: kind, amount: amount,
                        currency: currency, source: .sample, observedAt: now)
        }
        var snapshot = ProviderSnapshot(provider: id, fetchedAt: now)
        switch id {
        case .claudeCode:
            snapshot.windows = [window("session", "Session", 42, resetsIn: 2.6),
                                window("weekly_all", "Weekly", 74, resetsIn: 61)]
        case .codex:
            snapshot.windows = [window("300", "Session", 18, resetsIn: 3.9),
                                window("10080", "Weekly", 93, resetsIn: 98)]
            snapshot.notes = ["Plan: Plus"]
        case .deepSeek:
            snapshot.money = [money("balance.USD", "Balance", .balance, 8.42)]
        case .openRouter:
            var limit = window("keyLimit", "Key limit", 47, resetsIn: 0)
            limit.resetsAt = nil
            limit.detail = "$13.20 of $25.00 left, resets monthly"
            snapshot.windows = [limit]
            snapshot.money = [money("spendDaily", "Spent today", .spend, 0.37),
                              money("spendMonthly", "Spent this month", .spend, 11.80)]
        }
        return snapshot
    }

    /// Two weeks of plausible history so the dashboard has something to draw.
    static func history(now: Date) -> [HistorySample] {
        var samples: [HistorySample] = []
        for hour in stride(from: 14 * 24, through: 0, by: -3) {
            let date = now.addingTimeInterval(Double(-hour) * 3600)
            let wave = sin(Double(hour) / 9) * 0.5 + 0.5
            samples.append(.init(date: date, series: "claudeCode.weekly_all", label: "Claude Code · Weekly",
                                 kind: .quotaPercent, value: Double((14 * 24 - hour) % (7 * 24)) / 1.8, unit: "%"))
            samples.append(.init(date: date, series: "codex.300", label: "Codex · Session",
                                 kind: .quotaPercent, value: wave * 60, unit: "%"))
            if hour % 24 == 0 {
                samples.append(.init(date: date, series: "openRouter.spendDaily", label: "OpenRouter",
                                     kind: .dailySpend, value: 0.2 + wave * 1.4, unit: "USD"))
            }
        }
        return samples
    }
}

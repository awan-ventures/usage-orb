import Charts
import SwiftUI

/// History over time. A supporting surface: everything urgent is already in the menu bar.
struct DashboardView: View {
    @EnvironmentObject private var store: UsageStore

    enum Period: String, CaseIterable, Identifiable {
        case day = "24 hours", week = "7 days", month = "30 days", quarter = "90 days"
        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self {
            case .day: 86_400
            case .week: 7 * 86_400
            case .month: 30 * 86_400
            case .quarter: 90 * 86_400
            }
        }
    }

    @State private var period: Period = .week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Usage history").font(.title2.weight(.semibold))
                    Spacer()
                    Picker("Period", selection: $period) {
                        ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 320)
                }
                if store.usesSampleData {
                    Label("Sample data. No accounts are read.", systemImage: "flask").foregroundStyle(.secondary)
                }
                section("Subscription quota used",
                        note: "As reported by each provider when Usage Orb checked. Gaps mean nothing was measured.") { quotaChart }
                section("Daily API spend",
                        note: "Spend reported by the provider for each UTC day (OpenRouter). Not an estimate from token counts.") { spendChart }
                section("Balances",
                        note: "Prepaid balances as reported. A drop can be spend or an expired grant; it isn't shown as spend.") { balanceChart }
                section("Now", note: nil) { CurrentTable() }
            }
            .padding(24)
        }
        .frame(minWidth: 620, minHeight: 520)
    }

    private func samples(_ kind: HistorySample.Kind) -> [HistorySample] {
        let start = store.now.addingTimeInterval(-period.seconds)
        return store.history.samples.filter { $0.kind == kind && $0.date >= start }
    }

    @ViewBuilder private var quotaChart: some View {
        let quota = samples(.quotaPercent)
        if quota.isEmpty { empty } else {
            Chart(quota, id: \.self) { sample in
                LineMark(x: .value("Time", sample.date), y: .value("Used", sample.value))
                    .foregroundStyle(by: .value("Window", sample.label))
                    .interpolationMethod(.stepEnd)
            }
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(Int(value.as(Double.self) ?? 0))%") }
                }
            }
            .frame(height: 220)
        }
    }

    @ViewBuilder private var spendChart: some View {
        let spend = samples(.dailySpend)
        if spend.isEmpty { empty } else {
            Chart(spend, id: \.self) { sample in
                BarMark(x: .value("Day", sample.date, unit: .day), y: .value("Spend", sample.value))
                    .foregroundStyle(by: .value("Provider", sample.label))
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { Text(Format.money(value.as(Double.self) ?? 0, currency: "USD")) }
                }
            }
            .frame(height: 180)
        }
    }

    @ViewBuilder private var balanceChart: some View {
        let balances = samples(.balance)
        if balances.isEmpty { empty } else {
            Chart(balances, id: \.self) { sample in
                LineMark(x: .value("Time", sample.date), y: .value("Balance", sample.value))
                    .foregroundStyle(by: .value("Balance", "\(sample.label) (\(sample.unit))"))
            }
            .frame(height: 160)
        }
    }

    private var empty: some View {
        Text("Nothing recorded in this period yet.").foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 80)
    }

    private func section<Content: View>(_ title: String, note: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            if let note { Text(note).font(.caption).foregroundStyle(.secondary) }
            content()
        }
    }
}

private struct CurrentTable: View {
    @EnvironmentObject private var store: UsageStore

    struct Row: Identifiable {
        var id: String
        var provider: String
        var name: String
        var value: String
        var source: String
        var observed: Date
    }

    var body: some View {
        let rows = store.enabledSnapshots.flatMap { snapshot in
            snapshot.windows.map { Row(id: $0.id, provider: $0.provider.displayName, name: $0.name,
                                       value: "\(Format.percent($0.usedPercent)) used", source: $0.source.label, observed: $0.observedAt) }
            + snapshot.money.map { Row(id: $0.id, provider: $0.provider.displayName, name: $0.name,
                                       value: Format.money($0.amount, currency: $0.currency), source: $0.source.label, observed: $0.observedAt) }
        }
        Table(rows) {
            TableColumn("Provider", value: \.provider)
            TableColumn("Measure", value: \.name)
            TableColumn("Value", value: \.value)
            TableColumn("Source", value: \.source)
            TableColumn("Measured") { Text(Format.relative($0.observed, now: store.now)) }
        }
        .frame(minHeight: 160)
    }
}

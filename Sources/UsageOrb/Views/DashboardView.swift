import AppKit
import Charts
import SwiftUI

/// History over time. A supporting surface: everything urgent is already in the menu bar.
struct DashboardView: View {
    @EnvironmentObject private var store: UsageStore

    enum Period: String, CaseIterable, Identifiable {
        case day = "Day", week = "Week", month = "Month", quarter = "90 Days"
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
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $period) {
                    ForEach(Period.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden()
                .frame(maxWidth: 320).frame(maxWidth: .infinity)

                card("Quota used", note: "Solid: weekly · Dashed: session") { quotaChart }
                card("Daily spend") { spendChart }
                card("Balance") { balanceChart }
            }
            .padding(20)
        }
        .frame(minWidth: 560, minHeight: 480)
        .background(VisualEffect().ignoresSafeArea())
    }

    private func samples(_ kind: HistorySample.Kind) -> [HistorySample] {
        let start = store.now.addingTimeInterval(-period.seconds)
        return store.history.samples.filter { $0.kind == kind && $0.date >= start }
    }

    private func card<Content: View>(_ title: String, note: String? = nil,
                                     @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Spacer()
                if let note { Text(note).font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.08)))
    }

    private var empty: some View {
        Text("Nothing recorded yet").font(.callout).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 60)
    }

    @ViewBuilder private var quotaChart: some View {
        let quota = samples(.quotaPercent)
        let present = ProviderID.allCases.filter { id in quota.contains { $0.providerName == id.displayName } }
        if quota.isEmpty { empty } else {
            Chart(quota, id: \.self) { sample in
                LineMark(x: .value("Time", sample.date), y: .value("Used", sample.value),
                         series: .value("Series", sample.series))
                    .foregroundStyle(by: .value("Provider", sample.providerName))
                    .lineStyle(sample.series.hasSuffix("session") || sample.series.hasSuffix(".300")
                               ? StrokeStyle(lineWidth: 1.5, dash: [4, 3]) : StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.monotone)
            }
            .chartForegroundStyleScale(domain: present.map(\.displayName), range: present.map(\.tint))
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 50, 100]) { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(Int(value.as(Double.self) ?? 0))%") }
                }
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 200)
        }
    }

    @ViewBuilder private var spendChart: some View {
        let spend = samples(.dailySpend)
        if spend.isEmpty { empty } else {
            Chart(spend, id: \.self) { sample in
                BarMark(x: .value("Day", sample.date, unit: .day), y: .value("Spend", sample.value))
                    .foregroundStyle(ProviderID.openRouter.tint)
                    .cornerRadius(3)
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine()
                    AxisValueLabel { Text(Format.money(value.as(Double.self) ?? 0, currency: "USD")) }
                }
            }
            .chartLegend(.hidden)
            .frame(height: 140)
        }
    }

    @ViewBuilder private var balanceChart: some View {
        let balances = samples(.balance)
        if balances.isEmpty { empty } else {
            Chart(balances, id: \.self) { sample in
                LineMark(x: .value("Time", sample.date), y: .value("Balance", sample.value),
                         series: .value("Series", sample.series))
                    .foregroundStyle(by: .value("Provider", "\(sample.providerName) (\(sample.unit))"))
            }
            .chartLegend(position: .bottom, alignment: .leading)
            .frame(height: 120)
        }
    }
}

extension HistorySample {
    var providerName: String {
        ProviderID(rawValue: String(series.prefix { $0 != "." }))?.displayName ?? label
    }
}

/// The translucent window background.
private struct VisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

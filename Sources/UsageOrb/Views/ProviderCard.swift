import SwiftUI

/// One provider in the menu: name, a bar per quota window, and any money figures. Hosted in an NSMenuItem.
struct ProviderCard: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    let provider: ProviderID

    static let width: CGFloat = 300

    var body: some View {
        let snapshot = store.snapshots[provider]
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                if let logo = provider.logo {
                    Image(nsImage: logo).resizable().aspectRatio(contentMode: .fit).frame(width: 13, height: 13)
                        .foregroundStyle(provider.logoColor).accessibilityHidden(true)
                }
                Text(provider.displayName).font(.system(size: 13, weight: .semibold))
                Spacer()
                if store.refreshing.contains(provider) {
                    ProgressView().controlSize(.mini)
                } else if let snapshot {
                    Text(Format.relative(snapshot.fetchedAt, now: store.now)).foregroundStyle(.secondary)
                }
            }
            .font(.system(size: 11))

            if let snapshot {
                ForEach(snapshot.windows) { WindowRow(window: $0, tint: provider.tint) }
                ForEach(snapshot.money) { figure in
                    HStack {
                        Text(figure.name).foregroundStyle(.secondary)
                        Spacer()
                        Text(Format.money(figure.amount, currency: figure.currency)).monospacedDigit()
                    }
                    .font(.system(size: 12))
                    .help(figure.provider == .openRouter ? "\(figure.source.label). Days and months are UTC." : figure.source.label)
                }
            }
            if let error = store.errors[provider] {
                Text(error.message)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if snapshot == nil {
                Text("Loading…").font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(width: Self.width, alignment: .leading)
    }
}

private struct WindowRow: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    let window: QuotaWindow
    let tint: Color

    var body: some View {
        let reset = (window.resetsAt ?? .distantFuture) <= store.now
        let stale = RingState.isStale(window, refreshInterval: settings.refreshInterval, now: store.now)
        let level = settings.thresholds.level(for: window.usedPercent)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.name)
                Spacer()
                Text(reset ? "—" : Format.percent(window.usedPercent))
                    .monospacedDigit().fontWeight(.medium)
                    .foregroundStyle(level == .critical ? .red : level == .warning ? .orange : .primary)
            }
            .font(.system(size: 12))
            Bar(fraction: reset ? 0 : window.usedPercent / 100,
                color: level == .critical ? .red : level == .warning ? .orange : tint)
            if let footnote = footnote(reset: reset, stale: stale) {
                Text(footnote).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .help("\(window.source.label), measured \(Format.relative(window.observedAt, now: store.now))")
        .accessibilityElement(children: .combine)
    }

    private func footnote(reset: Bool, stale: Bool) -> String? {
        if reset { return "Reset since last seen" }
        var parts: [String] = []
        if let detail = window.detail { parts.append(detail) }
        if let resetsAt = window.resetsAt { parts.append("Resets \(Format.countdown(to: resetsAt, now: store.now))") }
        if stale { parts.append("seen \(Format.relative(window.observedAt, now: store.now))") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct Bar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.1))
                Capsule().fill(color).frame(width: max(proxy.size.width * min(max(fraction, 0), 1), fraction > 0 ? 6 : 0))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

extension ProviderID {
    /// Claude and DeepSeek have coloured marks; OpenAI and OpenRouter are monochrome.
    var logoColor: Color {
        switch self {
        case .claudeCode, .deepSeek: tint
        case .codex, .openRouter: .primary
        }
    }

    /// Bar colour below the warning threshold.
    var tint: Color {
        switch self {
        case .claudeCode: Color(red: 0.85, green: 0.47, blue: 0.34)
        case .codex: Color(red: 0.36, green: 0.62, blue: 0.98)
        case .deepSeek: Color(red: 0.31, green: 0.43, blue: 0.95)
        case .openRouter: Color(red: 0.55, green: 0.5, blue: 0.95)
        }
    }
}

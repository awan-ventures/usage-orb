import SwiftUI

/// The compact list behind the ring. Works on its own; the dashboard is optional.
struct PopoverView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    var openDashboard: () -> Void
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if store.usesSampleData {
                        Label("Sample data. No accounts are read.", systemImage: "flask")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(ProviderID.allCases) { id in
                        if settings.enabled.contains(id) { ProviderSection(provider: id) }
                    }
                    let off = ProviderID.allCases.filter { !settings.enabled.contains($0) }
                    if !off.isEmpty { DisabledProviders(providers: off, openSettings: openSettings) }
                }
                .padding(14)
            }
            .frame(maxHeight: 460)
            Divider()
            footer
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: RingImage.image(for: store.ring))
                .renderingMode(store.ring.percent == nil ? .template : .original)
            VStack(alignment: .leading, spacing: 1) {
                Text(headline).font(.headline)
                Text(subheadline).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(store.ring.accessibilityDescription)
    }

    private var headline: String {
        switch store.ring {
        case .unknown: "Usage unknown"
        case .value(let percent, _, _, let stale): "\(Format.percent(percent)) used" + (stale ? " (stale)" : "")
        }
    }

    private var subheadline: String {
        switch store.ring {
        case .unknown(let reason): reason
        case .value(_, _, let window, _):
            (settings.pinnedWindowID == nil ? "Most used: " : "Pinned: ") + "\(window.provider.displayName) · \(window.name)"
        }
    }

    private var footer: some View {
        HStack {
            Button {
                Task { await store.refreshAll() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .keyboardShortcut("r")
            .disabled(!store.refreshing.isEmpty)
            Spacer()
            Button("Dashboard", action: openDashboard)
            Button("Settings…", action: openSettings).keyboardShortcut(",")
        }
        .controlSize(.small)
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

private struct ProviderSection: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    let provider: ProviderID

    var body: some View {
        let snapshot = store.snapshots[provider]
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(provider.displayName).font(.subheadline.weight(.semibold))
                if store.refreshing.contains(provider) { ProgressView().controlSize(.mini) }
                Spacer()
                if let snapshot { Text(Format.relative(snapshot.fetchedAt, now: store.now)).font(.caption2).foregroundStyle(.secondary) }
            }
            if let error = store.errors[provider] {
                Label(error.message, systemImage: error.kind == .notConfigured ? "info.circle" : "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(error.kind == .notConfigured ? Color.secondary : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                if snapshot != nil { Text("Showing the last good reading.").font(.caption2).foregroundStyle(.secondary) }
            }
            if let snapshot {
                ForEach(snapshot.windows) { WindowRow(window: $0, pinned: settings.pinnedWindowID == $0.id) }
                ForEach(snapshot.money) { MoneyRow(figure: $0) }
                ForEach(snapshot.notes, id: \.self) { Text($0).font(.caption2).foregroundStyle(.secondary) }
            } else if store.errors[provider] == nil {
                Text("Loading…").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct WindowRow: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    let window: QuotaWindow
    let pinned: Bool

    var body: some View {
        let expired = (window.resetsAt ?? .distantFuture) <= store.now
        let stale = store.now.timeIntervalSince(window.observedAt)
            > RingState.staleAfter(window.source, refreshInterval: settings.refreshInterval)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.name).font(.callout)
                if pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.secondary).accessibilityLabel("Pinned") }
                Spacer()
                Text(expired ? "Reset" : "\(Format.percent(window.usedPercent)) used")
                    .font(.callout.monospacedDigit().weight(.medium))
            }
            UsageBar(fraction: expired ? 0 : window.usedPercent / 100, level: settings.thresholds.level(for: window.usedPercent))
            HStack {
                if expired {
                    Text("Reset since last measured; use \(window.provider.displayName) to update")
                } else if let reset = window.resetsAt {
                    Text("Resets \(Format.countdown(to: reset, now: store.now))")
                }
                Spacer()
                Text(stale ? "\(window.source.label), \(Format.relative(window.observedAt, now: store.now))" : window.source.label)
                    .foregroundStyle(stale ? Color.orange : Color.secondary)
            }
            .font(.caption2).foregroundStyle(.secondary)
        }
        .contextMenu {
            Button(pinned ? "Unpin from Menu Bar" : "Pin to Menu Bar") {
                settings.pinnedWindowID = pinned ? nil : window.id
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct UsageBar: View {
    let fraction: Double
    let level: RingLevel

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(color).frame(width: proxy.size.width * min(max(fraction, 0), 1))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }

    private var color: Color {
        switch level {
        case .normal: .primary.opacity(0.75)
        case .warning: .orange
        case .critical: .red
        }
    }
}

private struct MoneyRow: View {
    let figure: MoneyFigure

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(figure.name).font(.callout)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.money(figure.amount, currency: figure.currency)).font(.callout.monospacedDigit().weight(.medium))
                Text(figure.source.label).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DisabledProviders: View {
    @EnvironmentObject private var settings: AppSettings
    let providers: [ProviderID]
    var openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Not connected").font(.caption).foregroundStyle(.secondary)
            ForEach(providers) { id in
                HStack {
                    Text(id.displayName).font(.callout)
                    Spacer()
                    if id.usesAPIKey && Keychain.apiKey(for: id) == nil {
                        Button("Add Key…", action: openSettings)
                    } else {
                        Button("Connect") { settings.setEnabled(id, true) }
                            .help(id == .claudeCode ? "macOS will ask to let Usage Orb read Claude Code's sign-in." : "")
                    }
                }
                .controlSize(.small)
            }
        }
    }
}

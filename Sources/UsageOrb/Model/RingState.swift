import Foundation

enum RingLevel: Sendable { case normal, warning, critical }

struct RingThresholds: Equatable, Sendable {
    var warning: Double = 70
    var critical: Double = 90

    func level(for percent: Double) -> RingLevel {
        if percent >= critical { return .critical }
        if percent >= warning { return .warning }
        return .normal
    }
}

/// What one provider's menu bar ring shows: its most used quota window. Computed, never stored.
enum RingState: Equatable, Sendable {
    case unknown(reason: String)
    case value(percent: Double, level: RingLevel, window: QuotaWindow, isStale: Bool)

    /// How long a value stays fresh. Local logs only update while the CLI is used, so they go stale sooner.
    static func staleAfter(_ source: DataSource, refreshInterval: TimeInterval) -> TimeInterval {
        switch source {
        case .localLog: 60 * 60
        case .officialAPI, .undocumentedAPI, .sample: max(refreshInterval * 3, 10 * 60)
        }
    }

    static func isStale(_ window: QuotaWindow, refreshInterval: TimeInterval, now: Date) -> Bool {
        now.timeIntervalSince(window.observedAt) > staleAfter(window.source, refreshInterval: refreshInterval)
    }

    static func compute(windows: [QuotaWindow], thresholds: RingThresholds,
                        refreshInterval: TimeInterval, now: Date) -> RingState {
        // A window whose reset time has passed no longer describes current usage.
        let current = windows.filter { ($0.resetsAt ?? .distantFuture) > now }
        let fresh = current.filter { !isStale($0, refreshInterval: refreshInterval, now: now) }
        let pool = fresh.isEmpty ? current : fresh
        guard let top = pool.max(by: { $0.usedPercent < $1.usedPercent }) else {
            return .unknown(reason: windows.isEmpty ? "Not measured yet" : "Reset since last measured")
        }
        return .value(percent: top.usedPercent, level: thresholds.level(for: top.usedPercent), window: top,
                      isStale: isStale(top, refreshInterval: refreshInterval, now: now))
    }

    var percent: Double? { if case .value(let percent, _, _, _) = self { percent } else { nil } }

    func accessibilityDescription(for provider: ProviderID) -> String {
        switch self {
        case .unknown(let reason):
            return "\(provider.displayName): usage unknown. \(reason)."
        case .value(let percent, _, let window, let isStale):
            var text = "\(provider.displayName) \(window.name): \(Format.percent(percent)) used"
            if let reset = window.resetsAt { text += ", resets \(Format.countdown(to: reset))" }
            text += isStale ? ". Last measured \(Format.relative(window.observedAt)), may be out of date."
                            : ". Updated \(Format.relative(window.observedAt))."
            return text
        }
    }
}

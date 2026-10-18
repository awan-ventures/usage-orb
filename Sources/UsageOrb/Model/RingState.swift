import Foundation

enum RingMode: Codable, Hashable, Sendable {
    /// The highest percentage among fresh, enabled quota windows.
    case mostUrgent
    /// One chosen window, by `QuotaWindow.id`.
    case pinned(String)
}

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

/// What the menu bar ring shows. Computed from snapshots and never stored.
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

    static func compute(windows: [QuotaWindow], mode: RingMode, thresholds: RingThresholds,
                        refreshInterval: TimeInterval, now: Date) -> RingState {
        // A window whose reset time has passed no longer describes current usage.
        let current = windows.filter { ($0.resetsAt ?? .distantFuture) > now }
        func isStale(_ window: QuotaWindow) -> Bool {
            now.timeIntervalSince(window.observedAt) > staleAfter(window.source, refreshInterval: refreshInterval)
        }
        func state(_ window: QuotaWindow) -> RingState {
            .value(percent: window.usedPercent, level: thresholds.level(for: window.usedPercent),
                   window: window, isStale: isStale(window))
        }

        switch mode {
        case .pinned(let id):
            if let window = current.first(where: { $0.id == id }) { return state(window) }
            if windows.contains(where: { $0.id == id }) {
                return .unknown(reason: "The pinned window has reset since it was last measured")
            }
            return .unknown(reason: "The pinned window isn't available")
        case .mostUrgent:
            let fresh = current.filter { !isStale($0) }
            let pool = fresh.isEmpty ? current : fresh
            guard let top = pool.max(by: { $0.usedPercent < $1.usedPercent }) else {
                return .unknown(reason: windows.isEmpty
                                ? "No subscription quota is measured yet"
                                : "Every measured window has reset since it was last seen")
            }
            return state(top)
        }
    }
}

extension RingState {
    var accessibilityDescription: String {
        switch self {
        case .unknown(let reason):
            return "Usage unknown. \(reason)."
        case .value(let percent, _, let window, let isStale):
            var text = "\(window.provider.displayName) \(window.name): \(Format.percent(percent)) used"
            if let reset = window.resetsAt { text += ", resets \(Format.countdown(to: reset))" }
            text += isStale ? ". Last measured \(Format.relative(window.observedAt)), may be out of date."
                            : ". Updated \(Format.relative(window.observedAt))."
            return text
        }
    }
}

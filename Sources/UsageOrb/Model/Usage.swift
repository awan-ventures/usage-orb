import Foundation

enum ProviderID: String, CaseIterable, Codable, Identifiable, Sendable {
    case claudeCode, codex, deepSeek, openRouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode: "Claude Code"
        case .codex: "Codex"
        case .deepSeek: "DeepSeek"
        case .openRouter: "OpenRouter"
        }
    }

    /// Providers that authenticate with an API key the user pastes into Settings.
    var usesAPIKey: Bool { self == .deepSeek || self == .openRouter }

    /// DeepSeek reports only a balance, which has no ceiling, so it never gets a ring.
    var reportsQuota: Bool { self == .claudeCode || self == .codex }
}

/// Where a figure came from. Shown next to every value so an estimate never passes for a report.
enum DataSource: String, Codable, Sendable {
    case officialAPI, undocumentedAPI, localLog, sample

    var label: String {
        switch self {
        case .officialAPI: "Official API"
        case .undocumentedAPI: "Undocumented endpoint"
        case .localLog: "Local session log"
        case .sample: "Sample data"
        }
    }
}

/// A subscription quota window, such as Claude's five-hour session or Codex's weekly limit.
struct QuotaWindow: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var provider: ProviderID
    var name: String
    /// 0–100. Values above 100 are kept as reported.
    var usedPercent: Double
    var resetsAt: Date?
    /// Extra context shown under the bar, such as "$13.20 of $25 left".
    var detail: String? = nil
    var source: DataSource
    /// When the provider reported this value (a log line's time, or the fetch time).
    var observedAt: Date
}

/// A money figure: a prepaid balance or reported spend. Never shown as a percentage.
struct MoneyFigure: Codable, Hashable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case balance, spend }

    var id: String
    var provider: ProviderID
    var name: String
    var kind: Kind
    var amount: Double
    /// An ISO currency code, or "credits" for provider credits with no currency.
    var currency: String
    var source: DataSource
    var observedAt: Date
}

struct ProviderSnapshot: Codable, Hashable, Sendable {
    var provider: ProviderID
    var windows: [QuotaWindow] = []
    var money: [MoneyFigure] = []
    var notes: [String] = []
    var fetchedAt: Date
}

struct ProviderError: LocalizedError, Equatable, Sendable {
    enum Kind: Sendable { case notConfigured, auth, rateLimited, network, format }

    var kind: Kind
    var message: String

    var errorDescription: String? { message }

    static func notConfigured(_ message: String) -> Self { .init(kind: .notConfigured, message: message) }
    static func auth(_ message: String) -> Self { .init(kind: .auth, message: message) }
    static func format(_ message: String) -> Self { .init(kind: .format, message: message) }
}

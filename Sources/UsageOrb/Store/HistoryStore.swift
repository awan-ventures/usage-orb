import Foundation

struct HistorySample: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable { case quotaPercent, balance, dailySpend }

    var date: Date
    var series: String
    var label: String
    var kind: Kind
    var value: Double
    var unit: String
}

/// Local history for the dashboard: a small JSON file in Application Support, pruned to 90 days.
struct HistoryLog: Sendable {
    static let retention: TimeInterval = 90 * 86_400
    /// An unchanged value is recorded at most this often, so the file stays small.
    static let heartbeat: TimeInterval = 30 * 60

    private(set) var samples: [HistorySample] = []

    init(samples: [HistorySample] = []) { self.samples = samples }

    mutating func record(_ snapshot: ProviderSnapshot, now: Date) {
        let provider = snapshot.provider.displayName
        for window in snapshot.windows {
            add(.init(date: window.observedAt, series: window.id, label: "\(provider) · \(window.name)",
                      kind: .quotaPercent, value: window.usedPercent, unit: "%"))
        }
        for figure in snapshot.money {
            let kind: HistorySample.Kind
            switch figure.kind {
            case .balance: kind = .balance
            case .spend where figure.id.hasSuffix("spendDaily"): kind = .dailySpend
            default: continue
            }
            add(.init(date: figure.observedAt, series: figure.id, label: "\(provider) · \(figure.name)",
                      kind: kind, value: figure.amount, unit: figure.currency))
        }
        samples.removeAll { now.timeIntervalSince($0.date) > Self.retention }
    }

    private mutating func add(_ sample: HistorySample) {
        guard let index = samples.lastIndex(where: { $0.series == sample.series }) else {
            samples.append(sample); return
        }
        let last = samples[index]
        guard sample.date > last.date else { return }
        if sample.kind == .dailySpend {
            // One figure per UTC day: the latest reading of "spend today".
            if Self.utc.isDate(last.date, inSameDayAs: sample.date) { samples[index] = sample } else { samples.append(sample) }
            return
        }
        if abs(sample.value - last.value) < 0.5 && sample.date.timeIntervalSince(last.date) < Self.heartbeat { return }
        samples.append(sample)
    }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

/// Reads and writes the app's local files. Nothing leaves the Mac.
enum LocalFiles {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Usage Orb", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: [.atomic])
    }
}

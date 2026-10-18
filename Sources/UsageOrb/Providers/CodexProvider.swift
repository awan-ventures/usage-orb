import Foundation

/// Reads the newest rate-limit snapshot Codex CLI wrote to its local session logs.
///
/// No network access and no credentials. The figure is as fresh as the last Codex turn on this Mac,
/// so it can lag behind usage on other devices; the ring marks it stale after an hour.
struct CodexProvider: UsageProvider {
    let id = ProviderID.codex
    let method = "Reads the latest rate-limit snapshot from Codex CLI's session logs in ~/.codex/sessions. No network, no credentials."

    var home: URL = {
        if let path = ProcessInfo.processInfo.environment["CODEX_HOME"] { return URL(fileURLWithPath: path) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
    }()

    func fetch(now: Date) async throws -> ProviderSnapshot {
        let sessions = home.appendingPathComponent("sessions")
        guard FileManager.default.fileExists(atPath: sessions.path) else {
            throw ProviderError.notConfigured("No Codex sessions found in \(sessions.path). Use Codex CLI once, then refresh.")
        }
        for file in Self.newestLogs(in: sessions, limit: 8) {
            guard let tail = Self.tail(of: file, bytes: 512 * 1024) else { continue }
            let modified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? now
            if let snapshot = Self.parseLog(tail, fileDate: modified, now: now) { return snapshot }
        }
        throw ProviderError.notConfigured("Codex hasn't logged any rate limits yet. Run a Codex turn while signed in with ChatGPT.")
    }

    static func newestLogs(in directory: URL, limit: Int) -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: keys) else { return [] }
        var files: [(URL, Date)] = []
        for case let url as URL in enumerator where url.pathExtension == "jsonl" {
            let values = try? url.resourceValues(forKeys: Set(keys))
            files.append((url, values?.contentModificationDate ?? .distantPast))
        }
        return files.sorted { $0.1 > $1.1 }.prefix(limit).map(\.0)
    }

    static func tail(of file: URL, bytes: Int) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? handle.close() }
        guard let size = try? handle.seekToEnd() else { return nil }
        try? handle.seek(toOffset: size > UInt64(bytes) ? size - UInt64(bytes) : 0)
        guard let data = try? handle.readToEnd() else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    /// Finds the last line carrying `rate_limits` and turns it into windows.
    static func parseLog(_ text: String, fileDate: Date, now: Date) -> ProviderSnapshot? {
        for line in text.split(separator: "\n").reversed() where line.contains("\"rate_limits\"") {
            guard let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            // Rollout lines wrap the event: {"timestamp", "type": "event_msg", "payload": {"type": "token_count", ...}}.
            let event = (object["payload"] as? [String: Any]) ?? (object["msg"] as? [String: Any]) ?? object
            guard let limits = event["rate_limits"] as? [String: Any] else { continue }
            let observed = JSON.date(object["timestamp"]) ?? fileDate
            let snapshot = parse(limits, observedAt: observed, now: now)
            if !snapshot.windows.isEmpty || !snapshot.money.isEmpty { return snapshot }
        }
        return nil
    }

    static func parse(_ limits: [String: Any], observedAt: Date, now: Date) -> ProviderSnapshot {
        var snapshot = ProviderSnapshot(provider: .codex, fetchedAt: now)
        for slot in ["primary", "secondary"] {
            guard let window = limits[slot] as? [String: Any], let used = JSON.double(window["used_percent"]) else { continue }
            let minutes = JSON.double(window["window_minutes"])
            var resets = JSON.date(window["resets_at"])
            if resets == nil, let seconds = JSON.double(window["resets_in_seconds"]) {
                resets = observedAt.addingTimeInterval(seconds)
            }
            snapshot.windows.append(QuotaWindow(id: "codex.\(minutes.map { String(Int($0)) } ?? slot)",
                                                provider: .codex, name: windowName(minutes: minutes, slot: slot),
                                                usedPercent: used, resetsAt: resets, source: .localLog,
                                                observedAt: observedAt))
        }
        if let credits = limits["credits"] as? [String: Any], credits["has_credits"] as? Bool == true,
           credits["unlimited"] as? Bool != true, let balance = JSON.double(credits["balance"]) {
            snapshot.money.append(MoneyFigure(id: "codex.credits", provider: .codex, name: "Credits",
                                              kind: .balance, amount: balance, currency: "credits",
                                              source: .localLog, observedAt: observedAt))
        }
        if let plan = limits["plan_type"] as? String { snapshot.notes.append("Plan: \(plan.capitalized)") }
        return snapshot
    }

    static func windowName(minutes: Double?, slot: String) -> String {
        switch minutes.map({ Int($0) }) {
        case 300: return "Session"
        case 10_080: return "Weekly"
        case let value? where value % 1440 == 0: return "\(value / 1440)-day window"
        case let value? where value % 60 == 0: return "\(value / 60)-hour window"
        case let value?: return "\(value)-minute window"
        case nil: return slot == "primary" ? "Primary window" : "Secondary window"
        }
    }
}

import Foundation

/// DeepSeek's documented balance endpoint. It reports money, not a quota, so it never drives the ring.
struct DeepSeekProvider: UsageProvider {
    let id = ProviderID.deepSeek
    let method = "Calls DeepSeek's documented GET /user/balance with your API key. Reports balance only; DeepSeek has no quota window."

    func fetch(now: Date) async throws -> ProviderSnapshot {
        guard let key = Keychain.apiKey(for: id) else {
            throw ProviderError.notConfigured("Add a DeepSeek API key in Settings.")
        }
        let object = try await HTTP.getJSON(URL(string: "https://api.deepseek.com/user/balance")!,
                                            headers: ["Authorization": "Bearer \(key)"], service: "DeepSeek")
        return try Self.parse(object, now: now)
    }

    static func parse(_ object: [String: Any], now: Date) throws -> ProviderSnapshot {
        guard let infos = object["balance_infos"] as? [[String: Any]] else {
            throw ProviderError.format("DeepSeek's balance response had no balance_infos.")
        }
        var snapshot = ProviderSnapshot(provider: .deepSeek, fetchedAt: now)
        for info in infos {
            guard let currency = info["currency"] as? String, let total = JSON.double(info["total_balance"]) else { continue }
            snapshot.money.append(MoneyFigure(id: "deepSeek.balance.\(currency)", provider: .deepSeek,
                                              name: "Balance", kind: .balance, amount: total, currency: currency,
                                              source: .officialAPI, observedAt: now))
        }
        if object["is_available"] as? Bool == false {
            snapshot.notes.append("DeepSeek says the balance is too low for API calls.")
        }
        return snapshot
    }
}

/// OpenRouter's documented key endpoint: spend reported by OpenRouter, plus the key's limit if it has one.
struct OpenRouterProvider: UsageProvider {
    let id = ProviderID.openRouter
    let method = "Calls OpenRouter's documented GET /api/v1/key with your API key. Reports spend and any key limit, not a subscription quota."

    func fetch(now: Date) async throws -> ProviderSnapshot {
        guard let key = Keychain.apiKey(for: id) else {
            throw ProviderError.notConfigured("Add an OpenRouter API key in Settings.")
        }
        let object = try await HTTP.getJSON(URL(string: "https://openrouter.ai/api/v1/key")!,
                                            headers: ["Authorization": "Bearer \(key)"], service: "OpenRouter")
        return try Self.parse(object, now: now)
    }

    /// OpenRouter's daily, weekly and monthly usage reset on UTC boundaries.
    static func parse(_ object: [String: Any], now: Date) throws -> ProviderSnapshot {
        guard let data = object["data"] as? [String: Any] else {
            throw ProviderError.format("OpenRouter's key response had no data.")
        }
        var snapshot = ProviderSnapshot(provider: .openRouter, fetchedAt: now)
        func add(_ field: String, _ key: String, _ name: String, _ kind: MoneyFigure.Kind) {
            guard let amount = JSON.double(data[field]) else { return }
            snapshot.money.append(MoneyFigure(id: "openRouter.\(key)", provider: .openRouter, name: name, kind: kind,
                                              amount: amount, currency: "USD", source: .officialAPI, observedAt: now))
        }
        add("usage_daily", "spendDaily", "Spend today (UTC)", .spend)
        add("usage_weekly", "spendWeekly", "Spend this week (UTC)", .spend)
        add("usage_monthly", "spendMonthly", "Spend this month (UTC)", .spend)
        add("usage", "spendTotal", "Spend, all time", .spend)
        if let limit = JSON.double(data["limit"]) {
            let reset = (data["limit_reset"] as? String).map { " (resets \($0))" } ?? ""
            add("limit_remaining", "limitRemaining", "Left of $\(Int(limit)) key limit\(reset)", .remainingLimit)
        }
        if data["is_free_tier"] as? Bool == true { snapshot.notes.append("Free tier") }
        return snapshot
    }
}

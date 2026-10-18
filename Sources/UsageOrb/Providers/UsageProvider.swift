import Foundation

/// One integration. Each adapter states how it measures, so the UI can label every figure honestly.
protocol UsageProvider: Sendable {
    var id: ProviderID { get }
    /// Shown in Settings: what is read, from where, and how reliable it is.
    var method: String { get }
    func fetch(now: Date) async throws -> ProviderSnapshot
}

enum HTTP {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()

    /// GETs JSON. Never logs headers, since they carry secrets.
    static func getJSON(_ url: URL, headers: [String: String], service: String) async throws -> [String: Any] {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("UsageOrb/0.1 (+https://github.com/awan-ventures/usage-orb)", forHTTPHeaderField: "User-Agent")
        for (name, value) in headers { request.setValue(value, forHTTPHeaderField: name) }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw ProviderError(kind: .network, message: "Couldn't reach \(service): \(error.localizedDescription)")
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: break
        case 401, 403: throw ProviderError.auth("\(service) rejected the credentials (HTTP \(status)).")
        case 429: throw ProviderError(kind: .rateLimited, message: "\(service) is rate limiting requests. Will retry later.")
        default: throw ProviderError(kind: .network, message: "\(service) returned HTTP \(status).")
        }
        return try JSON.object(data, service: service)
    }
}

/// Lenient JSON reading: these payloads are partly undocumented, so unknown fields are ignored.
enum JSON {
    static func object(_ data: Data, service: String) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProviderError.format("\(service) sent a response Usage Orb couldn't read.")
        }
        return object
    }

    static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber where !(number === kCFBooleanTrue || number === kCFBooleanFalse):
            return number.doubleValue
        case let string as String: return Double(string)
        default: return nil
        }
    }

    static func date(_ value: Any?) -> Date? {
        switch value {
        case let string as String:
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: string) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: string)
        case let number as NSNumber:
            // Seconds or milliseconds since the epoch.
            let raw = number.doubleValue
            return Date(timeIntervalSince1970: raw > 100_000_000_000 ? raw / 1000 : raw)
        default:
            return nil
        }
    }
}

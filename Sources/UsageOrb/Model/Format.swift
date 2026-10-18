import Foundation

enum Format {
    static func percent(_ value: Double) -> String {
        value < 10 && value.rounded() != value ? String(format: "%.1f%%", value) : "\(Int(value.rounded()))%"
    }

    static func countdown(to date: Date, now: Date = Date()) -> String {
        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else { return "now" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.allowedUnits = seconds >= 86_400 ? [.day, .hour] : [.hour, .minute]
        return "in " + (formatter.string(from: max(seconds, 60)) ?? "")
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        if abs(now.timeIntervalSince(date)) < 60 { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: now)
    }

    static func money(_ amount: Double, currency: String) -> String {
        if currency == "credits" {
            return amount.formatted(.number.precision(.fractionLength(0...2))) + " credits"
        }
        return amount.formatted(.currency(code: currency).precision(.fractionLength(2...4)))
    }
}

import Foundation
import ServiceManagement

/// Preferences in UserDefaults. Secrets are never stored here; see `Keychain`.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var enabled: Set<ProviderID> { didSet { defaults.set(enabled.map(\.rawValue), forKey: "enabledProviders") } }
    @Published var refreshMinutes: Int { didSet { defaults.set(refreshMinutes, forKey: "refreshMinutes") } }
    @Published var warningPercent: Double { didSet { defaults.set(warningPercent, forKey: "warningPercent") } }
    @Published var criticalPercent: Double { didSet { defaults.set(criticalPercent, forKey: "criticalPercent") } }
    @Published var showPercentInMenuBar: Bool { didSet { defaults.set(showPercentInMenuBar, forKey: "showPercentInMenuBar") } }

    static let refreshChoices = [1, 2, 5, 10, 15, 30]

    init(defaults: UserDefaults = .standard, sample: Bool = SampleProvider.isEnabled) {
        // Sample mode keeps its own preferences and shows every provider.
        let defaults = sample ? UserDefaults(suiteName: "com.madebyawan.UsageOrb.sample") ?? defaults : defaults
        self.defaults = defaults
        // Codex is local and asks nothing. Claude Code needs a Keychain prompt, so it waits for the user.
        let fallback = sample ? ProviderID.allCases : [.codex]
        let stored = defaults.stringArray(forKey: "enabledProviders") ?? fallback.map(\.rawValue)
        enabled = Set(stored.compactMap(ProviderID.init(rawValue:)))
        refreshMinutes = defaults.object(forKey: "refreshMinutes") as? Int ?? 5
        warningPercent = defaults.object(forKey: "warningPercent") as? Double ?? 70
        criticalPercent = defaults.object(forKey: "criticalPercent") as? Double ?? 90
        showPercentInMenuBar = defaults.bool(forKey: "showPercentInMenuBar")
    }

    var thresholds: RingThresholds { .init(warning: warningPercent, critical: max(criticalPercent, warningPercent)) }
    var refreshInterval: TimeInterval { TimeInterval(refreshMinutes * 60) }

    func setEnabled(_ provider: ProviderID, _ on: Bool) {
        if on { enabled.insert(provider) } else { enabled.remove(provider) }
    }

    // MARK: Launch at login

    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ on: Bool) throws {
        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        objectWillChange.send()
    }
}

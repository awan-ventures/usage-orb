import Combine
import Foundation

/// Polls enabled providers, keeps the last good snapshot of each, and records history.
@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [ProviderID: ProviderSnapshot] = [:]
    @Published private(set) var errors: [ProviderID: ProviderError] = [:]
    @Published private(set) var refreshing: Set<ProviderID> = []
    @Published private(set) var history = HistoryLog()
    /// Ticks every minute so countdowns, staleness and the ring stay current without refetching.
    @Published private(set) var now = Date()

    let settings: AppSettings
    let providers: [ProviderID: any UsageProvider]
    private var lastAttempt: [ProviderID: Date] = [:]
    private var failures: [ProviderID: Int] = [:]
    private var timer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    let usesSampleData: Bool

    init(settings: AppSettings, sample: Bool = SampleProvider.isEnabled) {
        self.settings = settings
        usesSampleData = sample
        let live: [any UsageProvider] = [ClaudeCodeProvider(), CodexProvider(), DeepSeekProvider(), OpenRouterProvider()]
        providers = Dictionary(uniqueKeysWithValues: (sample ? ProviderID.allCases.map { SampleProvider(id: $0) } : live).map { ($0.id, $0) })

        if sample {
            history = HistoryLog(samples: SampleProvider.history(now: now))
        } else {
            snapshots = LocalFiles.load([ProviderID: ProviderSnapshot].self, from: "last-snapshots.json") ?? [:]
            history = HistoryLog(samples: LocalFiles.load([HistorySample].self, from: "history.json") ?? [])
        }

        // Enabling a provider fetches it straight away; disabling clears its error.
        settings.$enabled.removeDuplicates().dropFirst().sink { [weak self] enabled in
            guard let self else { return }
            for id in ProviderID.allCases where !enabled.contains(id) { errors[id] = nil }
            Task { await self.refreshDue(force: false, only: enabled) }
        }.store(in: &cancellables)
    }

    func start() {
        let timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.now = Date()
                await self?.refreshDue(force: false)
            }
        }
        timer.tolerance = 15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Task { await refreshDue(force: true) }
    }

    var ring: RingState {
        RingState.compute(windows: enabledSnapshots.flatMap(\.windows), mode: settings.ringMode,
                          thresholds: settings.thresholds, refreshInterval: settings.refreshInterval, now: now)
    }

    var enabledSnapshots: [ProviderSnapshot] {
        ProviderID.allCases.filter(settings.enabled.contains).compactMap { snapshots[$0] }
    }

    func refreshAll() async { await refreshDue(force: true) }

    func refreshDue(force: Bool, only: Set<ProviderID>? = nil) async {
        let current = Date()
        now = current
        let targets = ProviderID.allCases.filter { id in
            guard settings.enabled.contains(id), only?.contains(id) ?? true, !refreshing.contains(id) else { return false }
            if force { return true }
            guard let last = lastAttempt[id] else { return true }
            // Back off after failures: 1×, 2×, 4×, then at most 8× the refresh interval.
            let multiplier = Double(1 << min(failures[id] ?? 0, 3))
            return current.timeIntervalSince(last) >= settings.refreshInterval * multiplier - 5
        }
        guard !targets.isEmpty else { return }

        await withTaskGroup(of: (ProviderID, Result<ProviderSnapshot, ProviderError>).self) { group in
            for id in targets {
                guard let provider = providers[id] else { continue }
                refreshing.insert(id)
                lastAttempt[id] = current
                group.addTask {
                    do { return (id, .success(try await provider.fetch(now: current))) }
                    catch let error as ProviderError { return (id, .failure(error)) }
                    catch { return (id, .failure(ProviderError(kind: .network, message: error.localizedDescription))) }
                }
            }
            for await (id, result) in group {
                refreshing.remove(id)
                switch result {
                case .success(let snapshot):
                    snapshots[id] = snapshot
                    errors[id] = nil
                    failures[id] = 0
                    history.record(snapshot, now: current)
                case .failure(let error):
                    errors[id] = error
                    failures[id, default: 0] += 1
                }
            }
        }
        if !usesSampleData {
            LocalFiles.save(snapshots, to: "last-snapshots.json")
            LocalFiles.save(history.samples, to: "history.json")
        }
    }
}

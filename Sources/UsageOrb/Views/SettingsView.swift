import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Providers") {
                ForEach(ProviderID.allCases) { ProviderSettings(provider: $0) }
            }

            Section("Menu bar ring") {
                Picker("Ring shows", selection: $settings.pinnedWindowID) {
                    Text("Most used quota window").tag(String?.none)
                    ForEach(store.enabledSnapshots.flatMap(\.windows)) { window in
                        Text("\(window.provider.displayName) · \(window.name)").tag(String?.some(window.id))
                    }
                    if let pinned = settings.pinnedWindowID,
                       !store.enabledSnapshots.flatMap(\.windows).contains(where: { $0.id == pinned }) {
                        Text("\(pinned) (unavailable)").tag(String?.some(pinned))
                    }
                }
                Text("Only subscription quota windows can drive the ring. Balances and spend have no fixed ceiling, so they stay in the list.")
                    .font(.caption).foregroundStyle(.secondary)
                Stepper("Warning at \(Int(settings.warningPercent))%", value: $settings.warningPercent, in: 10...100, step: 5)
                Stepper("Critical at \(Int(settings.criticalPercent))%", value: $settings.criticalPercent,
                        in: settings.warningPercent...100, step: 5)
                Toggle("Show percentage next to the ring", isOn: $settings.showPercentInMenuBar)
            }

            Section("General") {
                Picker("Check every", selection: $settings.refreshMinutes) {
                    ForEach(AppSettings.refreshChoices, id: \.self) { Text($0 == 1 ? "minute" : "\($0) minutes").tag($0) }
                }
                Toggle("Open at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { on in
                        do { try settings.setLaunchAtLogin(on); launchError = nil }
                        catch { launchError = error.localizedDescription }
                    }))
                if let launchError { Text(launchError).font(.caption).foregroundStyle(.red) }
            }

            Section("Privacy") {
                Text("Usage Orb talks only to the providers you connect, has no server and sends no analytics. API keys are kept in your Keychain. History stays in ~/Library/Application Support/Usage Orb.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .frame(minHeight: 560)
    }
}

private struct ProviderSettings: View {
    @EnvironmentObject private var store: UsageStore
    @EnvironmentObject private var settings: AppSettings
    let provider: ProviderID
    @State private var key = ""
    @State private var hasKey = false
    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(provider.displayName, isOn: Binding(get: { settings.enabled.contains(provider) },
                                                       set: { settings.setEnabled(provider, $0) }))
                .font(.body.weight(.medium))
            Text(store.providers[provider]?.method ?? "").font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if provider.usesAPIKey {
                HStack {
                    SecureField(hasKey ? "Key saved in Keychain" : "API key", text: $key)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(save)
                    Button("Save", action: save).disabled(key.isEmpty)
                    if hasKey { Button("Remove") { Keychain.setAPIKey(nil, for: provider); hasKey = false } }
                }
                if saveFailed { Text("Couldn't save the key to the Keychain.").font(.caption).foregroundStyle(.red) }
            }
        }
        .padding(.vertical, 2)
        .onAppear { hasKey = provider.usesAPIKey && Keychain.apiKey(for: provider) != nil }
    }

    private func save() {
        guard !key.isEmpty else { return }
        saveFailed = !Keychain.setAPIKey(key, for: provider)
        guard !saveFailed else { return }
        key = ""
        hasKey = true
        settings.setEnabled(provider, true)
        Task { await store.refreshDue(force: true, only: [provider]) }
    }
}

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

            Section("Menu bar") {
                Stepper("Warning at \(Int(settings.warningPercent))%", value: $settings.warningPercent, in: 10...100, step: 5)
                Stepper("Critical at \(Int(settings.criticalPercent))%", value: $settings.criticalPercent,
                        in: settings.warningPercent...100, step: 5)
                Toggle("Show percentages", isOn: $settings.showPercentInMenuBar)
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

            Section {
            } footer: {
                Text("No server, no analytics. Keys stay in your Keychain; history stays on this Mac.")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
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

import AppKit
import Combine
import SwiftUI

/// One menu bar ring per provider. Clicking any ring opens the same native menu, so it gets the system's
/// menu material (and Liquid Glass on macOS 26) for free.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private var items: [String: NSStatusItem] = [:]
    private let store: UsageStore
    private let settings: AppSettings
    private let windows: WindowPresenter
    private var cancellables: Set<AnyCancellable> = []

    init(store: UsageStore, settings: AppSettings, windows: WindowPresenter) {
        self.store = store
        self.settings = settings
        self.windows = windows
        super.init()
        // Coalesce bursts of changes into one redraw.
        store.objectWillChange.merge(with: settings.objectWillChange)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
        update()
    }

    private func update() {
        // With no ring providers, one plain ring keeps the app reachable.
        let wanted: [ProviderID?] = store.ringProviders.isEmpty ? [nil] : store.ringProviders
        let keys = wanted.map { $0?.rawValue ?? "app" }
        for (key, item) in items where !keys.contains(key) {
            NSStatusBar.system.removeStatusItem(item)
            items[key] = nil
        }
        // macOS remembers each ring's position; people can ⌘-drag to reorder them.
        for (key, provider) in zip(keys, wanted) {
            let item = items[key] ?? makeItem(key: key)
            items[key] = item
            render(item, provider: provider)
        }
    }

    private func makeItem(key: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "UsageOrb.\(key)"
        item.button?.imagePosition = .imageLeading
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        return item
    }

    private func render(_ item: NSStatusItem, provider: ProviderID?) {
        guard let button = item.button else { return }
        guard let provider else {
            button.image = RingImage.image(for: .unknown(reason: ""), provider: nil)
            button.title = ""
            button.setAccessibilityLabel("Usage Orb")
            button.toolTip = "Usage Orb: connect a provider"
            return
        }
        let ring = store.ring(for: provider)
        button.image = RingImage.image(for: ring, provider: provider)
        button.title = settings.showPercentInMenuBar ? ring.percent.map { " " + Format.percent($0) } ?? "" : ""
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium)
        button.toolTip = ring.accessibilityDescription(for: provider)
        button.setAccessibilityLabel("Usage Orb, \(provider.displayName)")
        button.setAccessibilityValue(ring.accessibilityDescription(for: provider))
    }

    /// For screenshots and UI work (`USAGE_ORB_OPEN=menu`).
    func openMenu() {
        items.values.first?.button?.performClick(nil)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let enabled = ProviderID.allCases.filter(settings.enabled.contains)
        for (index, provider) in enabled.enumerated() {
            if index > 0 { menu.addItem(.separator()) }
            menu.addItem(cardItem(provider))
        }
        if !enabled.isEmpty { menu.addItem(.separator()) }

        let available = ProviderID.allCases.filter { !settings.enabled.contains($0) }
        if !available.isEmpty {
            let add = NSMenu()
            for provider in available {
                let needsKey = provider.usesAPIKey && Keychain.apiKey(for: provider) == nil
                let entry = add.addItem(withTitle: provider.displayName + (needsKey ? "…" : ""),
                                        action: #selector(addProvider(_:)), keyEquivalent: "")
                entry.target = self
                entry.representedObject = provider.rawValue
                if provider == .claudeCode { entry.toolTip = "macOS will ask to let Usage Orb read Claude Code's sign-in." }
            }
            menu.addItem(withTitle: "Add Provider", action: nil, keyEquivalent: "").submenu = add
        }
        add(menu, "Refresh", #selector(refresh), "r")
        add(menu, "Dashboard", #selector(dashboard), "d")
        add(menu, "Settings…", #selector(openSettings), ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Usage Orb", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        Task { await store.refreshDue(force: false) }
    }

    private func cardItem(_ provider: ProviderID) -> NSMenuItem {
        let host = NSHostingView(rootView: ProviderCard(provider: provider)
            .environmentObject(store).environmentObject(settings))
        host.frame.size = NSSize(width: ProviderCard.width, height: host.fittingSize.height)
        let item = NSMenuItem()
        item.view = host
        return item
    }

    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
    }

    @objc private func addProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let provider = ProviderID(rawValue: raw) else { return }
        if provider.usesAPIKey && Keychain.apiKey(for: provider) == nil {
            windows.showSettings()
        } else {
            settings.setEnabled(provider, true)
        }
    }

    @objc private func refresh() { Task { await store.refreshAll() } }
    @objc private func dashboard() { windows.showDashboard() }
    @objc private func openSettings() { windows.showSettings() }
}

/// Plain windows for the dashboard and settings. The app has no Dock icon.
@MainActor
final class WindowPresenter {
    private let store: UsageStore
    private let settings: AppSettings
    private var dashboard: NSWindow?
    private var settingsWindow: NSWindow?

    init(store: UsageStore, settings: AppSettings) {
        self.store = store
        self.settings = settings
    }

    func showDashboard() {
        dashboard = present(dashboard, title: "Usage Orb", autosave: "Dashboard", resizable: true) {
            DashboardView()
        }
    }

    func showSettings() {
        settingsWindow = present(settingsWindow, title: "Settings", autosave: "Settings", resizable: false) {
            SettingsView()
        }
    }

    private func present<V: View>(_ existing: NSWindow?, title: String, autosave: String, resizable: Bool,
                                  content: () -> V) -> NSWindow {
        let window = existing ?? {
            let host = NSHostingController(rootView: content().environmentObject(store).environmentObject(settings))
            let window = NSWindow(contentViewController: host)
            window.title = title
            window.styleMask = resizable ? [.titled, .closable, .miniaturizable, .resizable] : [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName(autosave)
            window.center()
            return window
        }()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

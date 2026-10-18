import AppKit
import Combine
import SwiftUI

/// Owns the menu bar ring: left click opens the popover, right click opens a small menu.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let store: UsageStore
    private let settings: AppSettings
    private let windows: WindowPresenter
    private var cancellables: Set<AnyCancellable> = []

    init(store: UsageStore, settings: AppSettings, windows: WindowPresenter) {
        self.store = store
        self.settings = settings
        self.windows = windows
        super.init()

        let content = PopoverView(openDashboard: { [weak self] in self?.popover.close(); windows.showDashboard() },
                                  openSettings: { [weak self] in self?.popover.close(); windows.showSettings() })
            .environmentObject(store)
            .environmentObject(settings)
        let host = NSHostingController(rootView: content)
        host.sizingOptions = .preferredContentSize
        popover.contentViewController = host
        popover.behavior = .transient

        if let button = item.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }
        // Coalesce bursts of changes into one redraw.
        store.objectWillChange.merge(with: settings.objectWillChange)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.update() }
            .store(in: &cancellables)
        update()
    }

    private func update() {
        guard let button = item.button else { return }
        let ring = store.ring
        button.image = RingImage.image(for: ring)
        button.title = settings.showPercentInMenuBar ? ring.percent.map { " " + Format.percent($0) } ?? "" : ""
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize(for: .small), weight: .medium)
        button.toolTip = ring.accessibilityDescription
        button.setAccessibilityLabel("Usage Orb")
        button.setAccessibilityValue(ring.accessibilityDescription)
    }

    @objc private func clicked() {
        guard item.button != nil else { return }
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func showPopover() {
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        Task { await store.refreshDue(force: false) }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Refresh Now", action: #selector(refresh), keyEquivalent: "r").target = self
        menu.addItem(withTitle: "Dashboard", action: #selector(dashboard), keyEquivalent: "d").target = self
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Usage Orb", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        item.button?.performClick(nil)
        item.menu = nil
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
        settingsWindow = present(settingsWindow, title: "Usage Orb Settings", autosave: "Settings", resizable: false) {
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

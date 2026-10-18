import AppKit

@main
@MainActor
enum UsageOrbApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: UsageStore?
    private var statusItem: StatusItemController?
    private var windows: WindowPresenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests host the app; don't poll real accounts or add a menu bar item there.
        guard NSClassFromString("XCTestCase") == nil else { return }
        NSApp.mainMenu = Self.mainMenu()
        let settings = AppSettings()
        let store = UsageStore(settings: settings)
        let windows = WindowPresenter(store: store, settings: settings)
        statusItem = StatusItemController(store: store, settings: settings, windows: windows)
        self.store = store
        self.windows = windows
        store.start()
        // For UI work and screenshots: USAGE_ORB_OPEN=popover, dashboard or settings.
        switch ProcessInfo.processInfo.environment["USAGE_ORB_OPEN"] {
        case "popover": DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.statusItem?.showPopover() }
        case "dashboard": windows.showDashboard()
        case "settings": windows.showSettings()
        default: break
        }
    }

    /// An accessory app still needs Edit commands so ⌘V works when pasting an API key, and ⌘W closes windows.
    private static func mainMenu() -> NSMenu {
        let main = NSMenu()
        let app = NSMenu()
        app.addItem(withTitle: "Quit Usage Orb", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let window = NSMenu(title: "Window")
        window.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        for submenu in [app, edit, window] {
            let item = NSMenuItem(title: submenu.title, action: nil, keyEquivalent: "")
            item.submenu = submenu
            main.addItem(item)
        }
        return main
    }
}

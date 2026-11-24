import AppKit
import ServiceManagement
import os

/// Native AppKit helper for the Catalyst app: the menu bar item, and hiding the
/// capture window without closing it.
@objc(MacSupport)
final class MacSupport: NSObject, MacSupportProtocol {
    private let log = Logger(subsystem: "com.smudgeface.homewidget", category: "mac")
    private var statusItem: NSStatusItem?
    private var loginItem: NSMenuItem?
    private var shouldHide: () -> Bool = { false }

    required override init() { super.init() }

    /// The app's content window (the menu bar item has a window of its own).
    private var contentWindows: [NSWindow] { NSApp.windows.filter { $0.styleMask.contains(.titled) } }

    func start(shouldHide: @escaping () -> Bool) {
        self.shouldHide = shouldHide
        installMenuBar()
        let center = NotificationCenter.default
        center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.showWindow()
        }
        center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self, self.shouldHide() else { return }
            self.hideWindow()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.contentWindows.forEach { self?.prepare($0) }
        }
    }

    func hideIfInactive() {
        if !NSApp.isActive && shouldHide() { hideWindow() }
    }

    // MARK: Window

    /// Park the window behind the desktop wallpaper. It must stay "on screen" for the
    /// system: an ordered-out window puts the app in the background state, and HomeKit
    /// then refuses snapshot requests; a transparent or off-screen window can't be captured.
    private func hideWindow() {
        log.notice("window: hide")
        for window in contentWindows {
            prepare(window)
            window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 3)
            window.ignoresMouseEvents = true
        }
    }

    @objc private func showWindow() {
        log.notice("window: show")
        for window in contentWindows {
            prepare(window)
            window.level = .normal
            window.ignoresMouseEvents = false
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func prepare(_ window: NSWindow) {
        // Closing or minimising would stop capture; the window hides itself instead.
        window.styleMask.remove([.closable, .miniaturizable])
        // A window that isn't on any display can't be captured.
        if window.screen == nil || !(window.screen!.visibleFrame.intersects(window.frame)) {
            window.center()
            log.notice("window: was off screen; centred")
        }
    }

    // MARK: Menu bar

    private func installMenuBar() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let image = NSImage(systemSymbolName: "web.camera", accessibilityDescription: "HomeWidget") {
            item.button?.image = image
        } else {
            item.button?.title = "HomeWidget"
        }
        let menu = NSMenu()
        menu.addItem(withTitle: "Show HomeWidget Window", action: #selector(activateAndShow), keyEquivalent: "").target = self
        menu.addItem(.separator())
        let login = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        loginItem = login
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit HomeWidget", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu
        statusItem = item
        updateLoginState()
    }

    @objc private func activateAndShow() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow()
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            log.error("open at login failed: \(String(describing: error), privacy: .public)")
        }
        updateLoginState()
    }

    private func updateLoginState() {
        loginItem?.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}

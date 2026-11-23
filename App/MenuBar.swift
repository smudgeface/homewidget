import ServiceManagement
import UIKit

/// The app's menu bar item. HomeWidget runs without a Dock icon (LSUIElement), so this
/// is the way to reach its window or quit. Built with AppKit through the ObjC runtime,
/// because Catalyst doesn't expose NSStatusItem.
final class MenuBar: NSObject {
    static let shared = MenuBar()

    private var statusItem: NSObject?
    private var loginItem: NSObject?

    func install() {
        guard statusItem == nil,
              let bar = (NSClassFromString("NSStatusBar") as? NSObject.Type)?.value(forKey: "systemStatusBar") as? NSObject,
              let menuClass = NSClassFromString("NSMenu") as? NSObject.Type,
              let itemClass = NSClassFromString("NSMenuItem") as? NSObject.Type else { return }

        typealias MakeItem = @convention(c) (AnyObject, Selector, CGFloat) -> AnyObject
        let makeSel = NSSelectorFromString("statusItemWithLength:")
        let item = unsafeBitCast(bar.method(for: makeSel), to: MakeItem.self)(bar, makeSel, -1) as! NSObject   // -1 = variable length
        statusItem = item

        if let button = item.value(forKey: "button") as? NSObject {
            let image = (NSClassFromString("NSImage") as? NSObject.Type)?
                .perform(NSSelectorFromString("imageWithSystemSymbolName:accessibilityDescription:"),
                         with: "web.camera", with: "HomeWidget")?.takeUnretainedValue()
            if let image { button.setValue(image, forKey: "image") } else { button.setValue("HomeWidget", forKey: "title") }
        }

        let menu = menuClass.init()
        typealias AddItem = @convention(c) (AnyObject, Selector, NSString, Selector?, NSString) -> AnyObject
        let addSel = NSSelectorFromString("addItemWithTitle:action:keyEquivalent:")
        let add = unsafeBitCast(menu.method(for: addSel), to: AddItem.self)
        func addItem(_ title: String, _ action: Selector, target: AnyObject?, key: String = "") -> NSObject {
            let menuItem = add(menu, addSel, title as NSString, action, key as NSString) as! NSObject
            menuItem.setValue(target, forKey: "target")
            return menuItem
        }
        func addSeparator() {
            if let sep = itemClass.value(forKey: "separatorItem") { menu.perform(NSSelectorFromString("addItem:"), with: sep) }
        }

        _ = addItem("Show HomeWidget Window", #selector(showWindow), target: self)
        addSeparator()
        loginItem = addItem("Open at Login", #selector(toggleLogin), target: self)
        addSeparator()
        _ = addItem("Quit HomeWidget", NSSelectorFromString("terminate:"), target: nil, key: "q")
        item.setValue(menu, forKey: "menu")
        updateLoginState()
    }

    @objc private func showWindow() {
        // Activating the app triggers the "show while active" behaviour in HomeWidgetApp.
        WindowHider.activateApp()
        WindowHider.show()
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
        loginItem?.setValue(SMAppService.mainApp.status == .enabled ? 1 : 0, forKey: "state")
    }
}

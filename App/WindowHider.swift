import UIKit

/// Hides and shows the app's window without closing it; the window has to keep
/// existing so the camera views stay capturable. Catalyst has no direct NSWindow
/// access, so this reaches AppKit through the ObjC runtime.
enum WindowHider {
    // UIKit's active/inactive notifications don't follow Mac app activation, so use AppKit's.
    static let didBecomeActive = Notification.Name("NSApplicationDidBecomeActiveNotification")
    static let didResignActive = Notification.Name("NSApplicationDidResignActiveNotification")

    private static var app: NSObject? {
        (NSClassFromString("NSApplication") as? NSObject.Type)?.value(forKey: "sharedApplication") as? NSObject
    }

    static func activateApp() {
        typealias Activate = @convention(c) (AnyObject, Selector, Bool) -> Void
        guard let app else { return }
        let sel = NSSelectorFromString("activateIgnoringOtherApps:")
        unsafeBitCast(app.method(for: sel), to: Activate.self)(app, sel, true)
    }

    static var appIsActive: Bool { app?.value(forKey: "isActive") as? Bool ?? false }

    /// Only the Catalyst content window; the menu bar item has an NSWindow of its own.
    private static var windows: [NSObject] {
        (app?.value(forKey: "windows") as? [NSObject] ?? []).filter { NSStringFromClass(type(of: $0)).contains("UINSWindow") }
    }

    /// Park the window behind the desktop wallpaper. It must stay "on screen" for the
    /// system: an ordered-out window puts the app in the background state, and HomeKit
    /// then refuses snapshot requests; a transparent or off-screen window can't be captured.
    static func hide() {
        log.notice("window: hide")
        for w in windows {
            ensureOnScreen(w)
            w.setValue(-2147483626, forKey: "level")   // just below the wallpaper window
            w.setValue(true, forKey: "ignoresMouseEvents")
        }
    }

    static func show() {
        log.notice("window: show")
        for w in windows {
            w.setValue(0, forKey: "level")
            // Closing or minimising would stop capture; the window hides itself instead.
            if let mask = w.value(forKey: "styleMask") as? UInt { w.setValue(mask & ~UInt(2 | 4), forKey: "styleMask") }
            w.setValue(false, forKey: "ignoresMouseEvents")
            ensureOnScreen(w)
            w.perform(NSSelectorFromString("makeKeyAndOrderFront:"), with: nil)
        }
    }

    /// A window that isn't on any display can't be captured; pull it back if it has strayed.
    static func ensureOnScreen(_ w: NSObject) {
        let frame = (w.value(forKey: "frame") as? NSValue)?.cgRectValue ?? .zero
        let screen = w.value(forKey: "screen") as? NSObject
        let visible = (screen?.value(forKey: "visibleFrame") as? NSValue)?.cgRectValue
        if visible == nil || !visible!.intersects(frame) {
            w.perform(NSSelectorFromString("center"))
            log.notice("window: was off screen; centred")
        }
    }

    static func ensureOnScreen() { windows.forEach(ensureOnScreen) }
}

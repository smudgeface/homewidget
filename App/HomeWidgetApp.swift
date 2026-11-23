import SwiftUI

@main
struct HomeWidgetApp: App {
    @StateObject private var store = CameraStore()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                // Once at least one widget is set up, the window is only needed for capture:
                // show it while the app is active (e.g. after a Dock click), hide it otherwise.
                .onAppear {
                    MenuBar.shared.install()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { WindowHider.ensureOnScreen() }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                        if store.hasWidgets && !WindowHider.appIsActive { WindowHider.hide() }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: WindowHider.didBecomeActive)) { _ in
                    WindowHider.show()
                }
                .onReceive(NotificationCenter.default.publisher(for: WindowHider.didResignActive)) { _ in
                    if store.hasWidgets { WindowHider.hide() }
                }
        }
    }
}

import SwiftUI

@main
struct HomeWidgetApp: App {
    @StateObject private var store = CameraStore()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
                // Once at least one widget is set up, the window is only needed for capture:
                // the helper shows it while the app is active and hides it otherwise.
                .onAppear {
                    MacBridge.support?.start { store.hasWidgets }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { MacBridge.support?.hideIfInactive() }
                }
        }
    }
}

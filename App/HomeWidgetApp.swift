import SwiftUI

@main
struct HomeWidgetApp: App {
    @StateObject private var store = CameraStore()

    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(store)
        }
    }
}

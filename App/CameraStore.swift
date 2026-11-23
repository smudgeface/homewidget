import HomeKit
import UIKit
import WidgetKit

/// Finds HomeKit cameras, asks each for a still snapshot on a timer, and writes
/// the result as a JPEG into the App Group container for the widget to display.
///
/// HomeKit never hands over snapshot pixels directly: an `HMCameraSnapshot` can
/// only be shown in an `HMCameraView`. So each camera has an on-screen
/// `HMCameraView` (hosted by ContentView) and we rasterise that view.
final class CameraStore: NSObject, ObservableObject, HMHomeManagerDelegate, HMCameraSnapshotControlDelegate {
    @Published private(set) var cameras: [CameraInfo] = []
    @Published private(set) var lastUpdate: [String: Date] = [:]
    @Published private(set) var status = "Waiting for HomeKit…"

    /// One view per camera ID; ContentView puts these on screen.
    private(set) var views: [String: HMCameraView] = [:]

    private let manager = HMHomeManager()
    private var controls: [String: HMCameraSnapshotControl] = [:]
    private var timer: Timer?
    private var activity: NSObjectProtocol?

    var interval: TimeInterval {
        let v = UserDefaults.standard.double(forKey: "interval")
        return v >= 10 ? v : 60
    }

    override init() {
        super.init()
        manager.delegate = self
        // Keep timers firing while the window is in the background.
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep],
            reason: "Refreshing camera snapshots for widgets")
    }

    func view(for id: String) -> HMCameraView {
        if let v = views[id] { return v }
        let v = HMCameraView()
        views[id] = v
        return v
    }

    // MARK: HomeKit

    func homeManagerDidUpdateHomes(_ manager: HMHomeManager) {
        var found: [CameraInfo] = []
        controls.removeAll()
        for home in manager.homes {
            for accessory in home.accessories {
                guard let control = accessory.cameraProfiles?.first?.snapshotControl else { continue }
                let id = accessory.uniqueIdentifier.uuidString
                control.delegate = self
                controls[id] = control
                found.append(CameraInfo(id: id, name: accessory.name, home: home.name,
                                        room: accessory.room?.name ?? ""))
            }
        }
        cameras = found.sorted { $0.name < $1.name }
        Shared.saveCameras(cameras)
        status = cameras.isEmpty ? "No HomeKit cameras found." : "\(cameras.count) camera(s)"
        restartTimer()
    }

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        if !status.contains(.authorized) {
            self.status = "HomeKit access denied. Enable it in System Settings › Privacy & Security › HomeKit."
        }
    }

    func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refreshAll()
        }
        refreshAll()
    }

    func refreshAll() {
        for control in controls.values { control.takeSnapshot() }
    }

    func cameraSnapshotControl(_ control: HMCameraSnapshotControl,
                               didTake snapshot: HMCameraSnapshot?, error: Error?) {
        guard let id = controls.first(where: { $0.value === control })?.key else { return }
        guard let snapshot else {
            status = "Snapshot failed: \(error?.localizedDescription ?? "unknown error")"
            return
        }
        let view = self.view(for: id)
        view.cameraSource = snapshot
        // Give the view a moment to render the new frame before rasterising it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.capture(view, id: id)
        }
    }

    // MARK: Capture

    private func capture(_ view: HMCameraView, id: String) {
        guard view.window != nil, view.bounds.width > 1, view.bounds.height > 1,
              let url = Shared.snapshotURL(for: id) else {
            status = "Keep the HomeWidget window open so snapshots can be captured."
            return
        }
        let format = UIGraphicsImageRendererFormat()
        format.scale = min(2, 1024 / view.bounds.width)   // keep widget images small
        format.opaque = true
        let image = UIGraphicsImageRenderer(bounds: view.bounds, format: format).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        do {
            try data.write(to: url, options: .atomic)
            lastUpdate[id] = Date()
            WidgetCenter.shared.reloadTimelines(ofKind: Shared.widgetKind)
        } catch {
            status = "Couldn't save snapshot: \(error.localizedDescription)"
        }
    }
}

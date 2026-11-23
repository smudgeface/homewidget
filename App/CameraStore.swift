import HomeKit
import ScreenCaptureKit
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
    private var capturePending = false
    private var activity: NSObjectProtocol?

    /// Camera ID → refresh interval, taken from the widgets on the desktop
    /// (the shortest interval wins if several widgets show the same camera).
    @Published private(set) var schedule: [String: RefreshInterval] = [:]
    private var lastRequested: [String: Date] = [:]
    var hasWidgets: Bool { !schedule.isEmpty }

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
        refreshAll()   // fill every tile once so the window isn't blank
        if timer == nil {
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.tick() }
        }
    }

    func homeManager(_ manager: HMHomeManager, didUpdate status: HMHomeManagerAuthorizationStatus) {
        if !status.contains(.authorized) {
            self.status = "HomeKit access denied. Enable it in System Settings › Privacy & Security › HomeKit."
        }
    }

    /// Every few seconds: re-read what the widgets ask for, then refresh the cameras that are due.
    private func tick() {
        WidgetCenter.shared.getCurrentConfigurations { [weak self] result in
            var wanted: [String: RefreshInterval] = [:]
            for info in (try? result.get()) ?? [] where info.kind == Shared.widgetKind {
                guard let intent = info.widgetConfigurationIntent(of: SelectCameraIntent.self),
                      let id = intent.camera?.id else { continue }
                if let existing = wanted[id], existing.seconds <= intent.interval.seconds { continue }
                wanted[id] = intent.interval
            }
            DispatchQueue.main.async { self?.refreshDue(wanted) }
        }
    }

    private func refreshDue(_ wanted: [String: RefreshInterval]) {
        if wanted != schedule { schedule = wanted }
        let now = Date()
        var due: [String] = []
        for (id, interval) in wanted {
            guard let control = controls[id] else { continue }
            if let last = lastRequested[id], now.timeIntervalSince(last) < interval.seconds - 1 { continue }
            lastRequested[id] = now
            control.takeSnapshot()
            due.append(id)
        }
        if !due.isEmpty { log.notice("tick: requested \(due.count) of \(wanted.count) widget cameras") }
    }

    func refreshAll() {
        log.notice("refreshAll: requesting \(self.controls.count) snapshots")
        let now = Date()
        for (id, control) in controls {
            lastRequested[id] = now
            control.takeSnapshot()
        }
    }

    func cameraSnapshotControl(_ control: HMCameraSnapshotControl,
                               didTake snapshot: HMCameraSnapshot?, error: Error?) {
        guard let id = controls.first(where: { $0.value === control })?.key else { return }
        if let error { log.error("snapshot failed: \(String(describing: error), privacy: .public)") }
        guard let snapshot else {
            status = "Snapshot failed: \(error?.localizedDescription ?? "unknown error")"
            // Cameras occasionally return a bad response; retry in ~15s rather than waiting a full interval.
            if let interval = schedule[id] { lastRequested[id] = Date().addingTimeInterval(15 - interval.seconds) }
            return
        }
        view(for: id).cameraSource = snapshot
        scheduleCapture()
    }

    // MARK: Capture

    /// Snapshots for several cameras arrive close together; capture the window once for all of them.
    private func scheduleCapture() {
        guard !capturePending else { return }
        capturePending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.capturePending = false
            Task { @MainActor in await self?.captureWindow() }
        }
    }

    /// HMCameraView content lives in the system render server, so UIKit drawing
    /// returns black. Instead, screenshot our own window and crop out each tile.
    @MainActor
    private func captureWindow() async {
        var rects: [String: CGRect] = [:]
        var windowSize = CGSize.zero
        for (id, view) in views {
            guard let window = view.window, view.bounds.width > 1, view.bounds.height > 1 else { continue }
            rects[id] = view.convert(view.bounds, to: nil)
            windowSize = window.bounds.size
        }
        guard !rects.isEmpty, windowSize.width > 1 else {
            status = "Keep the HomeWidget window open so snapshots can be captured."
            log.notice("capture: no tiles in a window")
            return
        }
        do {
            let content = try await SCShareableContent.currentProcess
            // The process owns several system windows; ours is the normal-level one whose size matches the UIWindow.
            func mismatch(_ w: SCWindow) -> CGFloat { abs(w.frame.width - windowSize.width) + abs(w.frame.height - windowSize.height) }
            guard let window = content.windows.filter({ $0.frame.height > 100 && $0.title != "Wallpaper" }).min(by: { mismatch($0) < mismatch($1) }) else {
                status = "Couldn't find the HomeWidget window to capture."
                return
            }
            log.notice("capture: \(rects.count) tiles")
            let config = SCStreamConfiguration()
            config.width = Int(window.frame.width * 2)
            config.height = Int(window.frame.height * 2)
            config.showsCursor = false
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: config)
            let sx = CGFloat(image.width) / windowSize.width
            let sy = CGFloat(image.height) / windowSize.height
            for (id, r) in rects {
                let crop = CGRect(x: r.minX * sx, y: r.minY * sy, width: r.width * sx, height: r.height * sy).integral
                guard let cropped = image.cropping(to: crop),
                      let data = UIImage(cgImage: cropped).jpegData(compressionQuality: 0.8),
                      let url = Shared.snapshotURL(for: id) else { continue }
                try data.write(to: url, options: .atomic)
                lastUpdate[id] = Date()
            }
            status = "\(cameras.count) camera(s)"
            WidgetCenter.shared.reloadTimelines(ofKind: Shared.widgetKind)
        } catch {
            status = "Screen capture failed: \(error.localizedDescription)"
            log.error("capture failed: \(String(describing: error), privacy: .public)")
        }
    }
}

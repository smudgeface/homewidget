import Foundation
import os

let log = Logger(subsystem: "com.smudgeface.homewidget", category: "general")

/// Data shared between the app (which talks to HomeKit) and the widget
/// (which can only read files), via the App Group container.
enum Shared {
    /// Team-prefixed (Mac-style) group ID, injected at build time from the signing team.
    /// iOS-style "group." IDs are not readable from the widget's sandbox on macOS.
    static let appGroup = Bundle.main.object(forInfoDictionaryKey: "AppGroupID") as? String ?? ""
    static let widgetKind = "CameraWidget"

    static var container: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    static var camerasURL: URL? { container?.appendingPathComponent("cameras.json") }

    static func snapshotURL(for cameraID: String) -> URL? {
        container?.appendingPathComponent("snapshot-\(cameraID).jpg")
    }

    static func loadCameras() -> [CameraInfo] {
        guard let url = camerasURL, let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([CameraInfo].self, from: data)) ?? []
    }

    static func saveCameras(_ cameras: [CameraInfo]) {
        guard let url = camerasURL, let data = try? JSONEncoder().encode(cameras) else { return }
        try? data.write(to: url, options: .atomic)
    }
}

struct CameraInfo: Codable, Identifiable, Hashable {
    let id: String      // HMAccessory.uniqueIdentifier
    let name: String
    let home: String
    let room: String
}

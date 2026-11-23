import AppIntents
import Foundation

// Widget configuration ("Edit Widget"). Shared so the app can read each widget's settings.

struct CameraEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Camera"
    static var defaultQuery = CameraQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct CameraQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [CameraEntity] {
        all().filter { identifiers.contains($0.id) }
    }
    func suggestedEntities() async throws -> [CameraEntity] { all() }
    func defaultResult() async -> CameraEntity? { all().first }

    private func all() -> [CameraEntity] {
        return Shared.loadCameras().map { CameraEntity(id: $0.id, name: $0.room.isEmpty ? $0.name : "\($0.name) (\($0.room))") }
    }
}

struct SelectCameraIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Camera"
    static var description = IntentDescription("Choose which HomeKit camera this widget shows and how often it refreshes.")

    @Parameter(title: "Camera")
    var camera: CameraEntity?

    @Parameter(title: "Refresh every", default: .oneMinute)
    var interval: RefreshInterval
}

enum RefreshInterval: String, AppEnum {
    case fifteenSeconds, thirtySeconds, oneMinute, fiveMinutes

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Refresh Interval"
    static var caseDisplayRepresentations: [RefreshInterval: DisplayRepresentation] = [
        .fifteenSeconds: "15 seconds", .thirtySeconds: "30 seconds",
        .oneMinute: "1 minute", .fiveMinutes: "5 minutes",
    ]

    var seconds: TimeInterval {
        switch self {
        case .fifteenSeconds: 15
        case .thirtySeconds: 30
        case .oneMinute: 60
        case .fiveMinutes: 300
        }
    }

    var label: String {
        switch self {
        case .fifteenSeconds: "15 seconds"
        case .thirtySeconds: "30 seconds"
        case .oneMinute: "1 minute"
        case .fiveMinutes: "5 minutes"
        }
    }
}


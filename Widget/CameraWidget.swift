import AppIntents
import SwiftUI
import WidgetKit

// MARK: Configuration ("Edit Widget" → choose a camera)

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
        Shared.loadCameras().map { CameraEntity(id: $0.id, name: $0.room.isEmpty ? $0.name : "\($0.name) (\($0.room))") }
    }
}

struct SelectCameraIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Camera"
    static var description = IntentDescription("Choose which HomeKit camera this widget shows.")

    @Parameter(title: "Camera")
    var camera: CameraEntity?
}

// MARK: Timeline

struct CameraEntry: TimelineEntry {
    let date: Date
    let name: String?
    let image: UIImage?
    let taken: Date?
}

struct CameraProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CameraEntry {
        CameraEntry(date: .now, name: "Camera", image: nil, taken: nil)
    }

    func snapshot(for configuration: SelectCameraIntent, in context: Context) async -> CameraEntry {
        entry(for: configuration)
    }

    func timeline(for configuration: SelectCameraIntent, in context: Context) async -> Timeline<CameraEntry> {
        // The app also triggers a reload whenever it writes a new snapshot;
        // this is just a fallback poll.
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(60)))
    }

    private func entry(for configuration: SelectCameraIntent) -> CameraEntry {
        guard let camera = configuration.camera, let url = Shared.snapshotURL(for: camera.id) else {
            return CameraEntry(date: .now, name: nil, image: nil, taken: nil)
        }
        let taken = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return CameraEntry(date: .now, name: camera.name, image: UIImage(contentsOfFile: url.path), taken: taken)
    }
}

// MARK: View

struct CameraWidgetView: View {
    let entry: CameraEntry

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if entry.image == nil {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash").font(.title2)
                    Text(entry.name == nil ? "Edit widget to choose a camera"
                                           : "No snapshot yet — open HomeWidget")
                        .font(.caption).multilineTextAlignment(.center)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if let name = entry.name, entry.image != nil {
                HStack(spacing: 4) {
                    Text(name).fontWeight(.semibold)
                    if let taken = entry.taken { Text(taken, style: .time) }
                }
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
            }
        }
        .containerBackground(for: .widget) {
            if let image = entry.image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color(.secondarySystemBackground)
            }
        }
    }
}

@main
struct CameraWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Shared.widgetKind, intent: SelectCameraIntent.self,
                               provider: CameraProvider()) { entry in
            CameraWidgetView(entry: entry)
        }
        .configurationDisplayName("HomeKit Camera")
        .description("Shows a regularly refreshed snapshot from one HomeKit camera.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

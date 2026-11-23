import AppIntents
import SwiftUI
import WidgetKit

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
        Timeline(entries: [entry(for: configuration)], policy: .after(.now.addingTimeInterval(configuration.interval.seconds)))
    }

    private func entry(for configuration: SelectCameraIntent) -> CameraEntry {
        log.notice("widget entry: camera=\(configuration.camera?.name ?? "none", privacy: .public) image=\(configuration.camera.flatMap { Shared.snapshotURL(for: $0.id) }.flatMap { UIImage(contentsOfFile: $0.path) } != nil)")
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
            if let image = entry.image {
                // In the content, not the container background: macOS strips the
                // background when desktop widgets are dimmed behind other windows.
                Color.clear.overlay {
                    Image(uiImage: image).resizable()
                        .widgetAccentedRenderingMode(.fullColor)
                        .scaledToFill()
                }
                .clipped()
            } else {
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
                    if let taken = entry.taken { Text(taken.formatted(date: .omitted, time: .standard)) }
                }
                .font(.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(.black.opacity(0.45), in: Capsule())
                .padding(8)
            }
        }
        .containerBackground(for: .widget) { Color.black }
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
        .contentMarginsDisabled()
        .containerBackgroundRemovable(false)
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

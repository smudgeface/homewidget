import HomeKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CameraStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.status).foregroundStyle(.secondary)
                Spacer()
                Button("Refresh Now") { store.refreshAll() }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(store.cameras) { camera in
                        VStack(alignment: .leading, spacing: 4) {
                            CameraPreview(view: store.view(for: camera.id))
                                .aspectRatio(16 / 9, contentMode: .fit)
                            Text(camera.name).font(.headline)
                            Text(store.schedule[camera.id].map { "On a widget · every \($0.label)" } ?? "Not on a widget · not refreshing")
                                .font(.caption).foregroundStyle(store.schedule[camera.id] == nil ? .secondary : .primary)
                            Text(store.lastUpdate[camera.id].map { "Updated \($0.formatted(date: .omitted, time: .standard))" }
                                 ?? "No snapshot yet")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text("Leave this window open (it can sit behind other windows). To choose a camera and how often it refreshes, right-click a HomeKit Camera widget and choose Edit.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .padding()
    }
}

/// Hosts the store-owned HMCameraView so the store can rasterise it.
private struct CameraPreview: UIViewRepresentable {
    let view: HMCameraView
    func makeUIView(context: Context) -> HMCameraView { view }
    func updateUIView(_ uiView: HMCameraView, context: Context) {}
}

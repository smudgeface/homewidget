import HomeKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: CameraStore
    @AppStorage("interval") private var interval: Double = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(store.status).foregroundStyle(.secondary)
                Spacer()
                Picker("Refresh every", selection: $interval) {
                    Text("15 seconds").tag(15.0)
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("5 minutes").tag(300.0)
                }
                .fixedSize()
                .onChange(of: interval) { _, _ in store.restartTimer() }
                Button("Refresh Now") { store.refreshAll() }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 320), spacing: 12)], spacing: 12) {
                    ForEach(store.cameras) { camera in
                        VStack(alignment: .leading, spacing: 4) {
                            CameraPreview(view: store.view(for: camera.id))
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text(camera.name).font(.headline)
                            Text(store.lastUpdate[camera.id].map { "Updated \($0.formatted(date: .omitted, time: .standard))" }
                                 ?? "No snapshot yet")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Text("Leave this window open (it can sit behind other windows). Add a HomeWidget widget to your desktop and pick a camera by editing the widget.")
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

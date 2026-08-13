import SwiftUI
import SwiftData

/// All landmarks with their marked/unmarked status, reachable from the map header. Tapping
/// one opens the same detail sheet as tapping its pin, with the full recording history.
struct LandmarksGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let landmark: Landmark
    let landmarkInfo: [LandmarkInfo]
    let videosBaseDirectory: URL?

    @State private var recordingCounts: [Int: Int] = [:]
    @State private var selectedIndex: Int?

    var body: some View {
        NavigationStack {
            List {
                ForEach(landmark.coordinates.indices, id: \.self) { index in
                    let info = landmarkInfo.indices.contains(index) ? landmarkInfo[index] : nil
                    let count = recordingCounts[index, default: 0]

                    Button {
                        selectedIndex = index
                    } label: {
                        HStack {
                            Image(systemName: info?.icon ?? "mappin.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(info?.title ?? "Landmark \(index + 1)")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(count == 0 ? "Not marked yet" : "\(count) marking\(count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if count > 0 {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Landmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            loadCounts()
        }
        .sheet(item: Binding(
            get: { selectedIndex.map(IdentifiableInt.init) },
            set: { selectedIndex = $0?.value }
        )) { wrapped in
            LandmarkDetailView(
                landmarkIndex: wrapped.value,
                landmarkName: "Landmark \(wrapped.value + 1)",
                info: landmarkInfo.indices.contains(wrapped.value) ? landmarkInfo[wrapped.value] : nil,
                videosBaseDirectory: videosBaseDirectory
            )
        }
    }

    private func loadCounts() {
        do {
            let descriptor = FetchDescriptor<LandmarkVideo>()
            let all = try modelContext.fetch(descriptor)
            recordingCounts = Dictionary(grouping: all, by: \.landmarkIndex).mapValues(\.count)
        } catch {
            print("Failed to load landmark recording counts: \(error)")
        }
    }
}

private struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

#Preview {
    LandmarksGalleryView(
        landmark: MapConstants.landmark,
        landmarkInfo: MapConstants.landmarkInfo,
        videosBaseDirectory: nil
    )
}

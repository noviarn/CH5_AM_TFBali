import SwiftUI
import SwiftData

struct LandmarkDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let landmarkIndex: Int
    let landmarkName: String
    let info: LandmarkInfo?
    let videosBaseDirectory: URL?

    @State private var recordings: [LandmarkVideo] = []
    @State private var playback: ClipPlayback?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.red.opacity(0.12))
                        Image(systemName: info?.icon ?? "mappin.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 140)

                    if let info {
                        Text(info.category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(.red, in: Capsule())

                        Text(info.summary)
                            .font(.body)
                            .foregroundStyle(.primary)
                    } else {
                        Text("No information available for this landmark yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider()

                    markingsSection
                }
                .padding()
            }
            .navigationTitle(info?.title ?? landmarkName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task {
            loadRecordings()
        }
        .fullScreenCover(item: $playback) { playback in
            ClipPlayerView(title: playback.title, clips: playback.clips)
        }
    }

    @ViewBuilder
    private var markingsSection: some View {
        HStack {
            Text("Markings")
                .font(.subheadline.weight(.semibold))
            Spacer()
            if !recordings.isEmpty {
                Text("\(recordings.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.green, in: Capsule())
            }
        }

        if recordings.isEmpty {
            Text("Not marked yet — get near this landmark on a route to record one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(recordings) { recording in
                    HStack {
                        Text(recording.recordedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                            .font(.subheadline)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }

            Button("Play Markings (\(recordings.count))") {
                playback = ClipPlayback(title: info?.title ?? landmarkName, clips: clips())
            }
            .buttonStyle(.borderedProminent)
            .disabled(clips().isEmpty)
        }
    }

    /// Oldest first, so playback tells the landmark's story in the order it was marked —
    /// `recordings` itself stays newest-first for the list above.
    private func clips() -> [TripClip] {
        guard let videosBaseDirectory else { return [] }
        let directory = videosBaseDirectory.appendingPathComponent("landmark-\(landmarkIndex)", isDirectory: true)

        return recordings.sorted { $0.recordedAt < $1.recordedAt }.compactMap { recording in
            let url = directory.appendingPathComponent(recording.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return TripClip(name: recording.landmarkName, url: url)
        }
    }

    private func loadRecordings() {
        let index = landmarkIndex
        let descriptor = FetchDescriptor<LandmarkVideo>(
            predicate: #Predicate { $0.landmarkIndex == index },
            sortBy: [SortDescriptor(\.recordedAt, order: .reverse)]
        )
        do {
            recordings = try modelContext.fetch(descriptor)
        } catch {
            print("Failed to load landmark recordings: \(error)")
        }
    }
}

#Preview {
    LandmarkDetailView(
        landmarkIndex: 0,
        landmarkName: "Landmark 1",
        info: LandmarkInfo(
            title: "Beachfront Bend",
            category: "Scenic Stop",
            summary: "The stretch of the loop closest to the Kuta beachfront, where the road curves in from the coast.",
            icon: "beach.umbrella.fill"
        ),
        videosBaseDirectory: nil
    )
}

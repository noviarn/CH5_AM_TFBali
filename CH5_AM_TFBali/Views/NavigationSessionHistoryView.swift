import SwiftUI
import SwiftData

struct NavigationSessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let videosBaseDirectory: URL?

    @State private var sessions: [NavigationSession] = []
    @State private var videosBySessionID: [UUID: [LandmarkVideo]] = [:]
    @State private var selectedClips: [(name: String, url: URL)] = []
    @State private var showTripSummary = false

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "No Navigation History",
                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                        description: Text("Start and stop a route to create a session history entry.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(sessions) { session in
                        let sessionVideos = sortedVideos(for: session)
                        Section {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(session.routeName)
                                            .font(.headline)
                                        Text(session.startedAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text(statusText(for: session))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(statusColor(for: session))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(statusColor(for: session).opacity(0.12), in: Capsule())
                                }

                                HStack(spacing: 16) {
                                    historyMetric(title: "Checkpoints", value: "\(session.checkpointsReached)/\(max(session.totalCheckpoints, session.checkpointsReached))")
                                    historyMetric(title: "Videos", value: "\(sessionVideos.count)")
                                    historyMetric(title: "Duration", value: durationText(for: session))
                                }

                                if sessionVideos.isEmpty {
                                    Text("No videos recorded in this session")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recordings")
                                            .font(.subheadline.weight(.semibold))

                                        ForEach(sessionVideos) { video in
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(video.landmarkName)
                                                        .font(.subheadline)
                                                    Text(video.recordedAt, format: .dateTime.hour().minute().second())
                                                        .font(.caption)
                                                        .foregroundStyle(.secondary)
                                                }

                                                Spacer()
                                            }
                                            .padding(.vertical, 2)
                                        }
                                    }
                                }

                                Button("Play Video Summary") {
                                    selectedClips = clips(for: session)
                                    showTripSummary = !selectedClips.isEmpty
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(clips(for: session).isEmpty)
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        loadHistory()
                    }
                }
            }
        }
        .task {
            loadHistory()
        }
        .fullScreenCover(isPresented: $showTripSummary) {
            TripSummaryPlayerView(clips: selectedClips)
        }
    }

    @ViewBuilder
    private func historyMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private func statusText(for session: NavigationSession) -> String {
        if session.endedAt == nil { return "Active" }
        return session.isCompleted ? "Finished" : "Incomplete"
    }

    private func statusColor(for session: NavigationSession) -> Color {
        if session.endedAt == nil { return .blue }
        return session.isCompleted ? .green : .orange
    }

    private func durationText(for session: NavigationSession) -> String {
        let endDate = session.endedAt ?? .now
        let duration = Int(endDate.timeIntervalSince(session.startedAt))
        let minutes = duration / 60
        let seconds = duration % 60
        return "\(minutes)m \(seconds)s"
    }

    private func sortedVideos(for session: NavigationSession) -> [LandmarkVideo] {
        videosBySessionID[session.id, default: []]
    }

    private func clips(for session: NavigationSession) -> [(name: String, url: URL)] {
        guard let videosBaseDirectory else { return [] }

        let sessionDirectory = videosBaseDirectory.appendingPathComponent(session.id.uuidString, isDirectory: true)
        return sortedVideos(for: session).compactMap { video in
            let url = sessionDirectory.appendingPathComponent(video.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else { return nil }
            return (name: video.landmarkName, url: url)
        }
    }

    private func loadHistory() {
        do {
            let sessionDescriptor = FetchDescriptor<NavigationSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            let videoDescriptor = FetchDescriptor<LandmarkVideo>(
                sortBy: [SortDescriptor(\.recordedAt, order: .forward)]
            )

            let fetchedSessions = try modelContext.fetch(sessionDescriptor)
            let fetchedVideos = try modelContext.fetch(videoDescriptor)

            sessions = fetchedSessions
            videosBySessionID = Dictionary(grouping: fetchedVideos) { video in
                video.session?.id ?? UUID()
            }
        } catch {
            print("Failed to load navigation history: \(error)")
        }
    }
}

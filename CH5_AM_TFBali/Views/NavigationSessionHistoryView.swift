import SwiftUI
import SwiftData
import MapKit

struct NavigationSessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var sessions: [NavigationSession] = []

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
                                    historyMetric(title: "Duration", value: durationText(for: session))
                                }

                                if !session.routeCoordinates.isEmpty {
                                    RoutePolylineShape(coordinates: session.routeCoordinates.map(\.coordinate))
                                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                                        .frame(height: 140)
                                        .padding(16)
                                        .frame(maxWidth: .infinity)
                                        .background(Color(.systemGray6))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
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
                        Haptics.tap()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") {
                        Haptics.selection()
                        loadHistory()
                    }
                }
            }
        }
        .task {
            loadHistory()
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

    private func loadHistory() {
        do {
            let sessionDescriptor = FetchDescriptor<NavigationSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            sessions = try modelContext.fetch(sessionDescriptor)
        } catch {
            print("Failed to load navigation history: \(error)")
        }
    }
}

/// Draws a route as a bare, scaled-to-fit line with no basemap — a Strava-style route card.
private struct RoutePolylineShape: Shape {
    let coordinates: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = coordinates.first else { return path }
        guard coordinates.count > 1 else {
            path.addEllipse(in: CGRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4))
            return path
        }

        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        let minLat = lats.min() ?? first.latitude
        let maxLat = lats.max() ?? first.latitude
        let minLon = lons.min() ?? first.longitude
        let maxLon = lons.max() ?? first.longitude

        // Scale longitude by cos(latitude) so the shape isn't stretched east-west.
        let lonScale = cos((minLat + maxLat) / 2 * .pi / 180)
        let spanWidth = (maxLon - minLon) * lonScale
        let spanHeight = maxLat - minLat

        let inset: CGFloat = 8
        let drawableWidth = max(rect.width - inset * 2, 1)
        let drawableHeight = max(rect.height - inset * 2, 1)

        let scale: Double
        switch (spanWidth > 0, spanHeight > 0) {
        case (true, true):
            scale = min(drawableWidth / (spanWidth), drawableHeight / (spanHeight))
        case (true, false):
            scale = drawableWidth / spanWidth
        case (false, true):
            scale = drawableHeight / spanHeight
        case (false, false):
            path.addEllipse(in: CGRect(x: rect.midX - 2, y: rect.midY - 2, width: 4, height: 4))
            return path
        }

        let drawWidth = spanWidth * scale
        let drawHeight = spanHeight * scale
        let offsetX = (rect.width - drawWidth) / 2
        let offsetY = (rect.height - drawHeight) / 2

        func point(for coordinate: CLLocationCoordinate2D) -> CGPoint {
            let x = (coordinate.longitude - minLon) * lonScale * scale
            let y = (maxLat - coordinate.latitude) * scale // flip so north is up
            return CGPoint(x: offsetX + x, y: offsetY + y)
        }

        path.move(to: point(for: coordinates[0]))
        for coordinate in coordinates.dropFirst() {
            path.addLine(to: point(for: coordinate))
        }
        return path
    }
}

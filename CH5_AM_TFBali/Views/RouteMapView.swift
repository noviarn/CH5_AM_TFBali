import SwiftUI
import MapKit

struct RouteMapView: View {
    @State private var visibleCorridorIDs: Set<String> = ["K1"]
    @State private var visibleDirectionIDs: Set<UUID> = Set(
        corridors.first(where: { $0.id == "K1" })?.directions.map(\.id) ?? []
    )
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]  // keyed by direction.id.uuidString
    @State private var loadingCorridorIDs: Set<String> = []
    @State private var selectedStop: BusStop?

    private let baliRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.66, longitude: 115.21),
        span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45)
    )

    var body: some View {
        Map(initialPosition: .region(baliRegion)) {
            ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                ForEach(Array(corridor.directions.enumerated()), id: \.element.id) { legIndex, direction in
                    if visibleDirectionIDs.contains(direction.id) {
                        if let coords = polylines[direction.id.uuidString], coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(corridor.color, style: strokeStyle(for: corridor, legIndex: legIndex))
                        }
                        ForEach(direction.stops) { busStop in
                            Annotation(busStop.name, coordinate: busStop.coordinate) {
                                Circle()
                                    .fill(corridor.color)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                                    .onTapGesture { selectedStop = busStop }
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
        }
        .task {
            for corridor in corridors where visibleCorridorIDs.contains(corridor.id) {
                await loadPolylines(for: corridor)
            }
        }
        .onChange(of: visibleCorridorIDs) { oldValue, newValue in
            let newlyVisible = newValue.subtracting(oldValue)
            guard !newlyVisible.isEmpty else { return }
            Task {
                for corridor in corridors where newlyVisible.contains(corridor.id) {
                    await loadPolylines(for: corridor)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                CorridorToggleRow(visibleCorridorIDs: $visibleCorridorIDs, visibleDirectionIDs: $visibleDirectionIDs)
                ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                    DirectionToggleRow(corridor: corridor, visibleDirectionIDs: $visibleDirectionIDs)
                }
            }
        }
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
    }

    private func strokeStyle(for corridor: Corridor, legIndex: Int) -> StrokeStyle {
        if corridor.id == "SHUTTLE_SANUR" {
            return StrokeStyle(lineWidth: 2, dash: [1, 5])
        }
        switch legIndex {
        case 0: return StrokeStyle(lineWidth: 4)
        case 1: return StrokeStyle(lineWidth: 4, dash: [8, 6])
        default: return StrokeStyle(lineWidth: 4, dash: [2, 4])
        }
    }

    @MainActor
    private func loadPolylines(for corridor: Corridor) async {
        guard !loadingCorridorIDs.contains(corridor.id) else { return }
        loadingCorridorIDs.insert(corridor.id)
        defer { loadingCorridorIDs.remove(corridor.id) }
        for direction in corridor.directions {
            if Task.isCancelled { return }
            if polylines[direction.id.uuidString] != nil { continue }
            let coords = await RoutePolylineBuilder.polyline(for: direction)
            polylines[direction.id.uuidString] = coords
        }
    }
}

private struct CorridorToggleRow: View {
    @Binding var visibleCorridorIDs: Set<String>
    @Binding var visibleDirectionIDs: Set<UUID>

    private let lightCorridorIDs: Set<String> = ["K5", "K6", "SHUTTLE_SANUR"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(corridors) { corridor in
                    let isOn = visibleCorridorIDs.contains(corridor.id)
                    Button {
                        let directionIDs = corridor.directions.map(\.id)
                        if isOn {
                            visibleCorridorIDs.remove(corridor.id)
                            visibleDirectionIDs.subtract(directionIDs)
                        } else {
                            visibleCorridorIDs.insert(corridor.id)
                            visibleDirectionIDs.formUnion(directionIDs)
                        }
                    } label: {
                        Text(corridor.id)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? corridor.color : Color.gray.opacity(0.25))
                            .foregroundStyle(isOn ? (lightCorridorIDs.contains(corridor.id) ? Color.black : Color.white) : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }
}

private struct DirectionToggleRow: View {
    let corridor: Corridor
    @Binding var visibleDirectionIDs: Set<UUID>

    private func label(for legIndex: Int) -> String {
        if corridor.directions.count == 2 {
            return legIndex == 0 ? "Pergi" : "Pulang"
        }
        return "Leg \(legIndex + 1)"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(corridor.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(Array(corridor.directions.enumerated()), id: \.element.id) { legIndex, direction in
                    let isOn = visibleDirectionIDs.contains(direction.id)
                    Button {
                        if isOn {
                            visibleDirectionIDs.remove(direction.id)
                        } else {
                            visibleDirectionIDs.insert(direction.id)
                        }
                    } label: {
                        Text(label(for: legIndex))
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isOn ? corridor.color.opacity(0.85) : Color.gray.opacity(0.2))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .background(.thinMaterial)
    }
}

private struct StopDetailSheet: View {
    let stop: BusStop

    var body: some View {
        VStack(spacing: 8) {
            Text(stop.name)
                .font(.title3.bold())
            Text("\(stop.coordinate.latitude), \(stop.coordinate.longitude)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .presentationDetents([.height(120)])
    }
}

#Preview {
    RouteMapView()
}

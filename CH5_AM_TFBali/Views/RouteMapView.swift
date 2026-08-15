import SwiftUI
import MapKit

struct RouteMapView: View {
    @State private var visibleCorridorIDs: Set<String> = Set(corridors.map(\.id))
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]  // keyed by direction.id.uuidString
    @State private var selectedStop: BusStop?

    private let baliRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.4095, longitude: 115.1889),
        span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
    )

    var body: some View {
        Map(initialPosition: .region(baliRegion)) {
            ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                ForEach(Array(corridor.directions.enumerated()), id: \.element.id) { legIndex, direction in
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
                                .onTapGesture { selectedStop = busStop }
                        }
                    }
                }
            }
        }
        .task { await loadAllPolylines() }
        .safeAreaInset(edge: .top) {
            CorridorToggleRow(visibleCorridorIDs: $visibleCorridorIDs)
        }
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
    }

    private func strokeStyle(for corridor: Corridor, legIndex: Int) -> StrokeStyle {
        if corridor.id == "SHUTTLE_SANUR" {
            return StrokeStyle(lineWidth: 2, dash: [1, 5])
        }
        return legIndex % 2 == 0
            ? StrokeStyle(lineWidth: 4)
            : StrokeStyle(lineWidth: 4, dash: [8, 6])
    }

    private func loadAllPolylines() async {
        for corridor in corridors {
            for direction in corridor.directions {
                let coords = await RouteGeometry.polyline(for: direction)
                polylines[direction.id.uuidString] = coords
            }
        }
    }
}

private struct CorridorToggleRow: View {
    @Binding var visibleCorridorIDs: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(corridors) { corridor in
                    let isOn = visibleCorridorIDs.contains(corridor.id)
                    Button {
                        if isOn {
                            visibleCorridorIDs.remove(corridor.id)
                        } else {
                            visibleCorridorIDs.insert(corridor.id)
                        }
                    } label: {
                        Text(corridor.id)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? corridor.color : Color.gray.opacity(0.25))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
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

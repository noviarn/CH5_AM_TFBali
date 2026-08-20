import SwiftUI
import MapKit

struct RouteMapView: View {
    /// Height of the sheet when collapsed. Lower it to make the bar sit closer to the
    /// bottom edge, raise it for more room. Pair it with TripPlannerSheet's top padding,
    /// which decides where the search bar sits inside that height.
    static let collapsedSheetHeight: CGFloat = 80

    @State private var visibleCorridorIDs: Set<String> = ["K1"]
    @State private var visibleDirectionIDs: Set<UUID> = Set(
        corridors.first(where: { $0.id == "K1" })?.directions.map(\.id) ?? []
    )
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]
    @State private var loadingCorridorIDs: Set<String> = []
    @State private var selectedStop: BusStop?
    @State private var destinationPin: BusStop?
    @State private var selectedRoute: TripRoute?
    @State private var cameraPosition: MapCameraPosition = .region(baliRegion)
    @State private var sheetDetent: PresentationDetent = .height(RouteMapView.collapsedSheetHeight)
    @State private var routeProgress: Double = 1
    @State private var routeDrawTask: Task<Void, Never>?

    var body: some View {
        Map(position: $cameraPosition) {
            UserAnnotation()

            // One ForEach over stably-identified lines, never a top-level if/else between two
            // different ForEach trees — MapKit leaves the old branch's overlays on the map otherwise.
            ForEach(mapLines) { line in
                if line.coordinates.count > 1 {
                    MapPolyline(coordinates: line.coordinates)
                        .stroke(line.color, style: line.style)
                }
                ForEach(line.stops) { busStop in
                    Annotation(busStop.name, coordinate: busStop.coordinate) {
                        stopDot(color: line.color, emphasized: line.emphasizedStopIDs.contains(busStop.id))
                            .onTapGesture { selectedStop = busStop }
                    }
                }
                .annotationTitles(.hidden)
            }

            if let destinationPin {
                Annotation(destinationPin.name, coordinate: destinationPin.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
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
                if let selectedRoute {
                    ActiveRouteBar(route: selectedRoute, onClear: clearSelectedRoute)
                } else {
                    CorridorToggleRow(visibleCorridorIDs: $visibleCorridorIDs, visibleDirectionIDs: $visibleDirectionIDs)
                    ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                        DirectionToggleRow(corridor: corridor, visibleDirectionIDs: $visibleDirectionIDs)
                    }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let selectedStop {
                StopDetailCard(stop: selectedStop, onDismiss: { self.selectedStop = nil })
                    .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: .constant(true)) {
            TripPlannerSheet(destinationPin: $destinationPin, sheetDetent: $sheetDetent, onRouteSelected: applySelectedRoute)
                .presentationDetents([.height(Self.collapsedSheetHeight), .medium, .large], selection: $sheetDetent)
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }

    /// Everything the map should draw right now: the picked route's ridden legs, or — with no route
    /// picked — whichever corridors the toggles have switched on.
    private var mapLines: [MapLine] {
        if let selectedRoute {
            return selectedRoute.legs.enumerated().map { index, leg in
                let full = riddenPolyline(for: leg)
                // Reveal the line progressively so a picked route draws itself in.
                let shown = Array(full.prefix(Int((Double(full.count) * routeProgress).rounded())))
                return MapLine(
                    id: "route-\(index)-\(leg.directionID.uuidString)",
                    coordinates: shown,
                    color: corridor(for: leg)?.color ?? .blue,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round),
                    stops: riddenStops(for: leg),
                    emphasizedStopIDs: [leg.boardStop.id, leg.alightStop.id]
                )
            }
        }
        return corridors
            .filter { visibleCorridorIDs.contains($0.id) }
            .flatMap { corridor in
                corridor.directions.compactMap { direction -> MapLine? in
                    guard visibleDirectionIDs.contains(direction.id) else { return nil }
                    return MapLine(
                        id: "browse-\(direction.id.uuidString)",
                        coordinates: polylines[direction.id.uuidString] ?? [],
                        color: corridor.color,
                        style: strokeStyle(for: corridor),
                        stops: direction.stops,
                        emphasizedStopIDs: []
                    )
                }
            }
    }

    private func stopDot(color: Color, emphasized: Bool) -> some View {
        Circle()
            .fill(emphasized ? Color.white : color)
            .frame(width: emphasized ? 13 : 10, height: emphasized ? 13 : 10)
            .overlay(Circle().stroke(emphasized ? color : Color.white, lineWidth: emphasized ? 3.5 : 1.5))
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    private func corridor(for leg: TripLeg) -> Corridor? {
        corridors.first { $0.id == leg.corridorID }
    }

    private func direction(for leg: TripLeg) -> RouteDirection? {
        corridor(for: leg)?.directions.first { $0.id == leg.directionID }
    }

    /// Only the stretch actually ridden on this leg — never the rest of the corridor or its return leg.
    private func riddenPolyline(for leg: TripLeg) -> [CLLocationCoordinate2D] {
        guard let full = polylines[leg.directionID.uuidString], full.count > 1 else {
            return [leg.boardStop.coordinate, leg.alightStop.coordinate]
        }
        return RouteGeometry.slice(full, from: leg.boardStop.coordinate, to: leg.alightStop.coordinate)
    }

    private func riddenStops(for leg: TripLeg) -> [BusStop] {
        guard let direction = direction(for: leg),
              let boardIndex = direction.stops.firstIndex(where: { $0.id == leg.boardStop.id }),
              let alightIndex = direction.stops.firstIndex(where: { $0.id == leg.alightStop.id }),
              boardIndex <= alightIndex else {
            return [leg.boardStop, leg.alightStop]
        }
        return Array(direction.stops[boardIndex...alightIndex])
    }

    private func applySelectedRoute(_ route: TripRoute) {
        routeDrawTask?.cancel()
        selectedRoute = route
        routeProgress = 0
        // Drop the sheet out of the way so the route it just produced is actually visible.
        sheetDetent = .height(Self.collapsedSheetHeight)
        let corridorIDs = Set(route.legs.map(\.corridorID))
        routeDrawTask = Task {
            for corridor in corridors where corridorIDs.contains(corridor.id) {
                await loadPolylines(for: corridor)
            }
            if Task.isCancelled { return }
            focusCamera(on: route)
            await drawRouteIn()
        }
    }

    /// Steps the reveal by hand: MapContent isn't animatable, so withAnimation can't interpolate it.
    private func drawRouteIn(steps: Int = 24, frameMilliseconds: Int = 16) async {
        for step in 0...steps {
            if Task.isCancelled { return }
            routeProgress = Double(step) / Double(steps)
            try? await Task.sleep(for: .milliseconds(frameMilliseconds))
        }
        routeProgress = 1
    }

    private func clearSelectedRoute() {
        routeDrawTask?.cancel()
        selectedRoute = nil
        destinationPin = nil
        routeProgress = 1
        withAnimation { cameraPosition = .region(baliRegion) }
    }

    private func focusCamera(on route: TripRoute) {
        var coordinates = route.legs.flatMap { riddenPolyline(for: $0) }
        if let destinationPin {
            coordinates.append(destinationPin.coordinate)
        }
        guard let region = RouteGeometry.region(fitting: coordinates) else { return }
        withAnimation { cameraPosition = .region(region) }
    }

    /// Solid for every corridor. The shuttle stays thinner because it is a minor line.
    /// The dashes used to tell a corridor's outbound direction from its return one. That job
    /// belongs to the direction toggles, which rarely have both on at once, so the two lines
    /// seldom overlap and the pattern was only noise.
    private func strokeStyle(for corridor: Corridor) -> StrokeStyle {
        StrokeStyle(lineWidth: corridor.id == "SHUTTLE_SANUR" ? 2 : 4)
    }

    @MainActor
    private func loadPolylines(for corridor: Corridor) async {
        guard !loadingCorridorIDs.contains(corridor.id) else { return }
        loadingCorridorIDs.insert(corridor.id)
        defer { loadingCorridorIDs.remove(corridor.id) }
        for (index, direction) in corridor.directions.enumerated() {
            if Task.isCancelled { return }
            if polylines[direction.id.uuidString] != nil { continue }
            // Baked geometry first: routing this live burns through the MKDirections burst limit
            // long before the network is drawn, and every refused segment renders as a straight line.
            if let baked = RouteGeometry.bakedPolyline(corridorID: corridor.id, directionIndex: index) {
                polylines[direction.id.uuidString] = baked
                continue
            }
            let coords = await RouteGeometry.polyline(for: direction)
            polylines[direction.id.uuidString] = coords
        }
    }
}

private struct MapLine: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: Color
    let style: StrokeStyle
    let stops: [BusStop]
    let emphasizedStopIDs: Set<UUID>
}

private struct ActiveRouteBar: View {
    let route: TripRoute
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(route.legs.enumerated()), id: \.offset) { index, leg in
                        if index > 0 {
                            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                        }
                        Text(leg.corridorID)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(corridors.first { $0.id == leg.corridorID }?.color ?? Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .glassEffect(in: .rect)
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
        .glassEffect(in: .rect)
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
        .glassEffect(in: .rect)
    }
}

private struct StopDetailCard: View {
    let stop: BusStop
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.name).font(.headline)
                Text("\(stop.coordinate.latitude), \(stop.coordinate.longitude)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
        .padding(.horizontal)
    }
}

import SwiftUI
import MapKit

/// Equatable stand-in for a coordinate, so `onChange` can fire when `centerCoordinate` moves.
private struct CoordinateKey: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees
    
    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

/// One corridor direction's drawn line + its stops, for browsing transit lines on the map
/// alongside (or instead of) an active navigation route.
struct CorridorOverlay: Identifiable {
    let id: UUID
    let color: Color
    let strokeStyle: StrokeStyle
    let coordinates: [CLLocationCoordinate2D]
    let stops: [BusStop]
}

struct MapViewContainer: View {
    @State private var position: MapCameraPosition
    @State private var selectedLocation: LocationPin?
    /// True for the duration of a camera move *we* triggered (animated or not), so the
    /// camera-change callback that move produces isn't mistaken for the rider grabbing the
    /// map. Anything that arrives while this is false is a real gesture.
    @State private var isProgrammaticCameraChange = false
    /// The map's actual on-screen heading, kept in sync from every camera change regardless
    /// of source. Route chevrons are drawn upright by MapKit and need this to counter-rotate
    /// against — otherwise they stop pointing along the road the moment the map itself is
    /// rotated, whether by our nav camera or a two-finger gesture.
    @State private var currentMapHeading: CLLocationDirection = 0
    
    let locations: [LocationPin]
    let userLocation: CLLocationCoordinate2D?
    let isNavigating: Bool
    let navigationHeading: CLLocationDirection?
    let centerCoordinate: CLLocationCoordinate2D?
    let route: MapRoute?
    /// Progress along `route.combinedWaypoints`, computed once by the owner so the drawn
    /// line, the maneuver list and the checkpoints all agree on where the rider is.
    let routeProgress: RouteProgress?
    let directions: [DirectionStep]
    let landmark: Landmark?
    /// Titles for `landmark.coordinates`, index for index. Without these the pins read
    /// "Landmark 1", which tells a visitor nothing about what they are looking at.
    let landmarkNames: [String]
    /// Asset names for `landmark.coordinates`, index for index — the same illustration the
    /// browse-layer POI pins use, so a landmark reads the same whether it's being browsed or
    /// ridden past. Falls back to the generic illustration when a name has no photo yet.
    let landmarkImages: [String]
    let busStops: [BusStop]
    /// Stops served in the direction this trip travels. The rest still draw — they are real
    /// stops and useful for orientation — but faded, so the platform across the road never
    /// reads as somewhere to board.
    let servingStopIDs: Set<UUID>
    /// The stop the rider hasn't reached yet — highlighted on the map so it reads apart
    /// from the rest of the stop clutter.
    let nextStopID: UUID?
    /// A pedestrian connector between two transfer stops, drawn only while that transfer is
    /// the immediate next leg of the trip.
    let walkingConnector: [CLLocationCoordinate2D]
    /// Transit lines drawn for browsing, independent of the active navigation route.
    let corridorOverlays: [CorridorOverlay]
    /// Points of interest along the corridors — always shown, regardless of which corridor
    /// overlays are toggled on or whether a trip is under way. See the note on `LandmarkPOI`.
    let landmarkPOIs: [LandmarkPOI]
    /// A single place pinned as a destination to explore — distinct from `landmark`, which is
    /// the fixed Kuta-loop checkpoint set.
    let destinationPin: Place?
    /// Region span used to frame `centerCoordinate` when there's no route yet to frame
    /// instead — tighter than `MapConstants.defaultSpan` so a single destination isn't lost
    /// in a whole-Bali overview.
    let focusSpan: MKCoordinateSpan
    /// Whether the camera should keep tracking the rider. The owner flips this to `false`
    /// when it detects a manual pan (see `handleCameraChange`) and back to `true` when the
    /// rider taps recenter.
    @Binding var isFollowingUser: Bool
    /// Called with a landmark's index into `landmark.coordinates` when its pin is tapped.
    var onSelectLandmark: (Int) -> Void = { _ in }
    /// Called when a corridor-overlay stop's marker is tapped.
    var onSelectCorridorStop: (BusStop) -> Void = { _ in }
    /// Called when a `landmarkPOIs` pin is tapped.
    var onSelectLandmarkPOI: (LandmarkPOI) -> Void = { _ in }
    
    init(
        locations: [LocationPin],
        userLocation: CLLocationCoordinate2D? = nil,
        isNavigating: Bool = false,
        navigationHeading: CLLocationDirection? = nil,
        centerCoordinate: CLLocationCoordinate2D? = nil,
        route: MapRoute? = nil,
        routeProgress: RouteProgress? = nil,
        directions: [DirectionStep] = [],
        landmark: Landmark? = nil,
        landmarkNames: [String] = [],
        landmarkImages: [String] = [],
        busStops: [BusStop] = [],
        servingStopIDs: Set<UUID> = [],
        nextStopID: UUID? = nil,
        walkingConnector: [CLLocationCoordinate2D] = [],
        corridorOverlays: [CorridorOverlay] = [],
        landmarkPOIs: [LandmarkPOI] = [],
        destinationPin: Place? = nil,
        focusSpan: MKCoordinateSpan = MapConstants.defaultSpan,
        isFollowingUser: Binding<Bool> = .constant(true),
        onSelectLandmark: @escaping (Int) -> Void = { _ in },
        onSelectCorridorStop: @escaping (BusStop) -> Void = { _ in },
        onSelectLandmarkPOI: @escaping (LandmarkPOI) -> Void = { _ in }
    ) {
        self.locations = locations
        self.userLocation = userLocation
        self.isNavigating = isNavigating
        self.navigationHeading = navigationHeading
        self.centerCoordinate = centerCoordinate
        self.route = route
        self.routeProgress = routeProgress
        self.directions = directions
        self.landmark = landmark
        self.landmarkNames = landmarkNames
        self.landmarkImages = landmarkImages
        self.busStops = busStops
        self.servingStopIDs = servingStopIDs
        self.nextStopID = nextStopID
        self.walkingConnector = walkingConnector
        self.corridorOverlays = corridorOverlays
        self.landmarkPOIs = landmarkPOIs
        self.destinationPin = destinationPin
        self.focusSpan = focusSpan
        self._isFollowingUser = isFollowingUser
        self.onSelectLandmark = onSelectLandmark
        self.onSelectCorridorStop = onSelectCorridorStop
        self.onSelectLandmarkPOI = onSelectLandmarkPOI
        
        // A destination to focus on takes priority over the device's own location — opening
        // "Explore Sanur Beach" should show Sanur, not wherever the phone currently is.
        let center = centerCoordinate ?? userLocation ?? MapConstants.baliCenter
        let span = centerCoordinate != nil ? focusSpan : MapConstants.defaultSpan
        _position = State(initialValue: .region(
            MKCoordinateRegion(center: center, span: span)
        ))
    }
    
    private var cameraState: NavigationCameraState {
        NavigationCameraState(
            latitude: userLocation?.latitude,
            longitude: userLocation?.longitude,
            heading: navigationHeading,
            isNavigating: isNavigating
        )
    }
    
    var body: some View {
        Map(position: $position, interactionModes: .all, selection: $selectedLocation) {
            if let route {
                let remaining = remainingLegs(of: route)
                
                // Thicker than any corridor browsing line (see `corridorOverlays` below) —
                // this is the one route the rider is actually meant to follow, and it needs
                // to read as such against every other line still drawn on the map.
                //
                // Painted a leg at a time in each corridor's own colour: one flat blue line
                // told a visitor nothing about which bus they were on or where to get off.
                // Routes with no legs to tell apart fall back to the single line below.
                ForEach(drawnSegments(of: route)) { segment in
                    if case .ride(_, let color) = segment.kind {
                        MapPolyline(MKPolyline(coordinates: segment.coordinates, count: segment.coordinates.count))
                            .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                    } else {
                        MapPolyline(MKPolyline(coordinates: segment.coordinates, count: segment.coordinates.count))
                            .stroke(Color.secondary, style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 10]))
                    }
                }
                
                if route.segments.isEmpty {
                    if remaining.approach.count >= 2 {
                        MapPolyline(MKPolyline(coordinates: remaining.approach, count: remaining.approach.count))
                            .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, dash: [10, 8]))
                    }
                    
                    if remaining.loop.count >= 2 {
                        MapPolyline(MKPolyline(coordinates: remaining.loop, count: remaining.loop.count))
                            .stroke(.blue, lineWidth: 6)
                    }
                }
                
                // A colour change alone doesn't tell a visitor to get off the bus, so every
                // change of line is called out where it happens.
                ForEach(transferMarkers(of: route)) { transfer in
                    Annotation("", coordinate: transfer.coordinate) {
                        TransferMark(from: transfer.from, to: transfer.to, color: transfer.color)
                    }
                    .annotationTitles(.hidden)
                }
                
                if let edge = RouteGeometry.headingArrow(at: remaining.approach)
                    ?? RouteGeometry.headingArrow(at: remaining.loop) {
                    Annotation("", coordinate: edge.coordinate) {
                        RouteArrowMark(heading: currentMapHeading.shortestTurn(to: edge.heading))
                    }
                    .annotationTitles(.hidden)
                }
                
                ForEach(turnMarkers(for: route)) { marker in
                    Annotation("", coordinate: marker.coordinate) {
                        TurnMarker(heading: currentMapHeading.shortestTurn(to: marker.heading))
                    }
                    .annotationTitles(.hidden)
                }
            }
            
            if walkingConnector.count >= 2 {
                MapPolyline(MKPolyline(coordinates: walkingConnector, count: walkingConnector.count))
                    .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [4, 8]))
                
                if let midpoint = walkingConnector.midpointCoordinate {
                    Annotation("", coordinate: midpoint) {
                        Image(systemName: "figure.walk.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white, .green)
                            .shadow(color: .black.opacity(0.35), radius: 2)
                    }
                    .annotationTitles(.hidden)
                }
            }
            
            ForEach(corridorOverlays) { overlay in
                let overlayCoordinates = remainingOverlayCoordinates(overlay)
                if overlayCoordinates.count > 1 {
                    MapPolyline(coordinates: overlayCoordinates)
                        .stroke(overlay.color, style: overlay.strokeStyle)
                }
                ForEach(overlay.stops) { stop in
                    Annotation(stop.name, coordinate: stop.coordinate) {
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(overlay.color, lineWidth: 2))
                            .frame(width: 44, height: 44)
                            .contentShape(Circle())
                            .onTapGesture {
                                Haptics.tap()
                                onSelectCorridorStop(stop)
                            }
                    }
                }
                .annotationTitles(.hidden)
            }
            
            // landmarkPOIs
            ForEach(landmarkPOIs) { poi in
                Annotation(poi.name, coordinate: poi.coordinate) {
                    LandmarkPin(image: poi.illustration, label: poi.name)
                        .onTapGesture {
                            Haptics.tap()
                            onSelectLandmarkPOI(poi)
                        }
                }
                .annotationTitles(.hidden)
            }
            
            if let destinationPin {
                Annotation(
                    destinationPin.name,
                    coordinate: CLLocationCoordinate2D(latitude: destinationPin.latitude, longitude: destinationPin.longitude)
                ) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
            
            // landmark (nav-engine checkpoints)
            if let landmark = landmark {
                ForEach(Array(landmark.coordinates.enumerated()), id: \.offset) { index, coord in
                    let title = landmarkNames.indices.contains(index)
                    ? landmarkNames[index]
                    : "Landmark \(index + 1)"
                    let image = landmarkImages.indices.contains(index) ? landmarkImages[index] : "landmark-placeholder"
                    Annotation(title, coordinate: coord) {
                        LandmarkPin(image: image, label: title)
                            .onTapGesture {
                                Haptics.tap()
                                onSelectLandmark(index)
                            }
                    }
                }
                .annotationTitles(.hidden)
            }
            
            ForEach(busStops) { stop in
                let isNext = stop.id == nextStopID
                let isServing = servingStopIDs.isEmpty || servingStopIDs.contains(stop.id)
                Annotation(stop.name, coordinate: stop.coordinate) {
                    Image(systemName: "bus.fill")
                        .font(isNext ? .body : .caption)
                        .foregroundStyle(.white)
                        .padding(isNext ? 8 : 6)
                        .background(
                            isNext ? Color.purple : (stop.direction == .outbound ? Color.green : Color.orange),
                            in: Circle()
                        )
                        .overlay(
                            Circle().stroke(.white, lineWidth: isNext ? 2 : 0)
                        )
                        .shadow(color: .black.opacity(isNext ? 0.4 : 0), radius: 3)
                        .opacity(isServing ? 1 : 0.35)
                }
            }
            
            if let userLoc = userLocation {
                Annotation("You", coordinate: userLoc) {
                    UserLocationMark(
                        heading: navigationHeading.map { currentMapHeading.shortestTurn(to: $0) }
                    )
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard)
        // Suppresses MapKit's default controls — specifically the compass that pops up
        // whenever the map rotates, which duplicates our own recenter button and heading cue.
        .mapControls {}
        .ignoresSafeArea()
        .onAppear {
            updateCamera(animated: false)
        }
        .onChange(of: cameraState) { previous, current in
            // Outside navigation the camera frames the whole route; re-running it on every
            // GPS tick would fight the user panning around. Only follow while navigating,
            // plus once when the mode flips.
            guard current.isNavigating || previous.isNavigating != current.isNavigating else { return }
            updateCamera()
        }
        .onChange(of: route?.id) { _, _ in
            updateCamera(animated: false)
        }
        .onChange(of: centerCoordinate.map(CoordinateKey.init)) { _, _ in
            // Only relevant outside an active trip — `centerCoordinate` there is the fixed
            // destination and already framed by the route itself.
            guard !isNavigating else { return }
            updateCamera()
        }
        .onChange(of: isNavigating) { _, navigating in
            if navigating {
                isFollowingUser = true
            }
        }
        .onChange(of: isFollowingUser) { _, following in
            guard following, isNavigating else { return }
            updateCamera()
        }
        .onMapCameraChange(frequency: .continuous) { context in
            handleCameraChange(context)
        }
    }
    
    /// Runs on every camera change, ours or the rider's. Heading tracking always applies —
    /// the chevrons need to know what the map looks like right now regardless of who moved
    /// it. Follow-state only reacts to changes we didn't cause ourselves.
    private func handleCameraChange(_ context: MapCameraUpdateContext) {
        currentMapHeading = context.camera.heading
        
        guard isNavigating, isFollowingUser, !isProgrammaticCameraChange else { return }
        isFollowingUser = false
    }
    
    /// Matched to the ~1 Hz location stream. Each fix glides to the next instead of the
    /// camera sitting still and then jumping, which is what read as teleporting. The old
    /// code also *discarded* any fix arriving inside its throttle window rather than
    /// deferring it, so bursts of movement were dropped outright.
    private static let cameraAnimationDuration: TimeInterval = 1.1
    
    /// Splits the combined-path progress back into the two drawn legs, trimming each to
    /// what is still ahead so the line retreats behind the rider — like Google Maps nav.
    /// One painted stretch of the route as it is actually drawn right now.
    private struct DrawnRouteSegment: Identifiable {
        let id: UUID
        let coordinates: [CLLocationCoordinate2D]
        let kind: RouteSegment.Kind
    }
    
    /// Where the rider changes buses.
    private struct TransferPoint: Identifiable {
        let id: UUID
        let coordinate: CLLocationCoordinate2D
        let from: String
        let to: String
        let color: Color
    }
    
    /// Every painted stretch still ahead of the rider, in travel order. Stretches already
    /// ridden drop out, and the one the rider is inside starts at their projected position
    /// so the line meets the marker instead of jumping back to the last vertex — the same
    /// rule `remainingLegs` applies to an uncoloured route.
    private func drawnSegments(of route: MapRoute) -> [DrawnRouteSegment] {
        let path = route.combinedWaypoints
        guard !route.segments.isEmpty, path.count >= 2 else { return [] }
        // -1 while browsing: nothing has been ridden yet, so every segment draws whole.
        let progressIndex = isNavigating ? (routeProgress?.index ?? -1) : -1
        
        return route.segments.compactMap { segment in
            // Reaches one vertex into the next segment so adjacent colours meet instead of
            // leaving a hairline gap at every change of line.
            let upper = min(segment.range.upperBound + 1, path.count)
            guard segment.range.lowerBound < upper else { return nil }
            let whole = Array(path[segment.range.lowerBound..<upper])
            
            let coordinates: [CLLocationCoordinate2D]
            if progressIndex < segment.range.lowerBound {
                coordinates = whole
            } else if segment.range.contains(progressIndex), let projected = routeProgress?.projected {
                coordinates = RouteGeometry.remaining(
                    whole,
                    fromSegment: progressIndex - segment.range.lowerBound,
                    projected: projected
                )
            } else {
                // Entirely behind the rider.
                return nil
            }
            
            guard coordinates.count >= 2 else { return nil }
            return DrawnRouteSegment(id: segment.id, coordinates: coordinates, kind: segment.kind)
        }
    }
    
    /// The junction between one bus and the next, taken from where each ride ends. Derived
    /// from the drawn segments rather than the stop list so the marker always lands exactly
    /// on the line, whatever the planner picked.
    private func transferMarkers(of route: MapRoute) -> [TransferPoint] {
        let path = route.combinedWaypoints
        let rides = route.segments.filter(\.isRide)
        guard rides.count > 1 else { return [] }
        
        return zip(rides, rides.dropFirst()).compactMap { current, next in
            guard case .ride(let from, _) = current.kind,
                  case .ride(let to, let color) = next.kind
            else { return nil }
            let index = min(current.range.upperBound, path.count - 1)
            guard path.indices.contains(index) else { return nil }
            return TransferPoint(id: current.id, coordinate: path[index], from: from, to: to, color: color)
        }
    }
    
    private func remainingLegs(
        of route: MapRoute
    ) -> (approach: [CLLocationCoordinate2D], loop: [CLLocationCoordinate2D]) {
        guard isNavigating, let routeProgress else {
            return (route.approachWaypoints, route.waypoints)
        }
        
        let approachCount = route.approachWaypoints.count
        let segment = routeProgress.index
        
        if segment + 1 < approachCount {
            return (
                approach: RouteGeometry.remaining(
                    route.approachWaypoints,
                    fromSegment: segment,
                    projected: routeProgress.projected
                ),
                loop: route.waypoints
            )
        }
        
        // Past the join, so the approach is done. Clamp for the shared segment that
        // straddles both legs.
        let loopSegment = max(segment - approachCount, 0)
        return (
            approach: [],
            loop: RouteGeometry.remaining(
                route.waypoints,
                fromSegment: loopSegment,
                projected: routeProgress.projected
            )
        )
    }
    
    /// The ridden corridor's own line is drawn separately from the trimmed nav line above
    /// (see `corridorOverlays`), and on its own coordinate space — `routeProgress.index` is
    /// only meaningful against `route.combinedWaypoints`. Without this it stayed full-length
    /// the whole trip, sitting on top of the nav line's trimmed tail and reading as if
    /// progress never cut anything.
    private func remainingOverlayCoordinates(_ overlay: CorridorOverlay) -> [CLLocationCoordinate2D] {
        guard isNavigating, let userLocation,
              let progress = RouteGeometry.progress(of: userLocation, along: overlay.coordinates)
        else {
            return overlay.coordinates
        }
        return RouteGeometry.remaining(overlay.coordinates, fromSegment: progress.index, projected: progress.projected)
    }
    
    /// Turn markers for maneuvers still ahead — everything once the rider starts, all of
    /// them beforehand as a preview of the trip. `directions` includes MapKit's "Continue"
    /// filler steps between actual turns; only the ones with a real maneuver word get a
    /// marker, the way Google Maps only badges intersections, not every straight stretch.
    private func turnMarkers(for route: MapRoute) -> [RouteArrow] {
        let path = route.combinedWaypoints
        let progressIndex = isNavigating ? (routeProgress?.index ?? 0) : -1
        
        return directions.compactMap { step in
            guard isTurnInstruction(step.instruction), step.pathIndex >= progressIndex else { return nil }
            guard let heading = RouteGeometry.outgoingHeading(at: step.pathIndex, along: path) else { return nil }
            return RouteArrow(coordinate: path[step.pathIndex], heading: heading)
        }
    }
    
    private func isTurnInstruction(_ instruction: String) -> Bool {
        let lower = instruction.lowercased()
        return ["turn", "left", "right", "keep", "merge", "exit", "roundabout", "u-turn"]
            .contains { lower.contains($0) }
    }
    
    private func updateCamera(animated: Bool = true) {
        // Once the rider has taken the map during navigation, leave it alone until they
        // tap recenter — otherwise the next fix would yank it straight back.
        if isNavigating && !isFollowingUser { return }
        
        let nextPosition: MapCameraPosition
        if isNavigating, let camera = navigationCamera() {
            nextPosition = .camera(camera)
        } else {
            nextPosition = overviewCameraPosition()
        }
        
        isProgrammaticCameraChange = true
        
        if animated {
            withAnimation(.linear(duration: Self.cameraAnimationDuration)) {
                position = nextPosition
            } completion: {
                isProgrammaticCameraChange = false
            }
        } else {
            position = nextPosition
            // The resulting camera-change callback can land a runloop turn after this
            // assignment, so give it a beat before treating further changes as the rider's.
            Task {
                try? await Task.sleep(for: .milliseconds(50))
                isProgrammaticCameraChange = false
            }
        }
    }
    
    private func overviewCameraPosition() -> MapCameraPosition {
        if let route {
            var rect = route.polyline.boundingMapRect
            if let approachRect = route.approachPolyline?.boundingMapRect, !approachRect.isNull {
                rect = rect.union(approachRect)
            }
            if !rect.isNull && !rect.isEmpty {
                var region = MKCoordinateRegion(rect)
                region.span.latitudeDelta = max(region.span.latitudeDelta * 1.8, 0.01)
                region.span.longitudeDelta = max(region.span.longitudeDelta * 1.8, 0.01)
                return .region(region)
            }
        }
        
        if let centerCoordinate {
            return .region(MKCoordinateRegion(center: centerCoordinate, span: focusSpan))
        }
        
        let center = userLocation ?? MapConstants.baliCenter
        return .region(
            MKCoordinateRegion(
                center: center,
                span: MapConstants.defaultSpan
            )
        )
    }
    
    private func navigationCamera() -> MapCamera? {
        guard let userLocation else { return nil }
        
        let heading = navigationHeading ?? 0
        let center = coordinate(
            from: userLocation,
            distance: 90,
            heading: heading
        )
        
        return MapCamera(
            centerCoordinate: center,
            distance: 550,
            heading: heading,
            pitch: 65
        )
    }
    
    private func coordinate(
        from coordinate: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        heading: CLLocationDirection
    ) -> CLLocationCoordinate2D {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let destination = location.distance(
            from: distance,
            bearingDegrees: heading
        )
        return destination.coordinate
    }
}

/// A landmark pin drawn as its own illustration rather than a generic glyph — the browse
/// layer and the route-landmark markers both draw from `poi.illustration`, so a landmark
/// reads as the same pin whether it's being browsed or ridden past.
private struct LandmarkPin: View {
    let image: String
    var label: String? = nil
    
    var body: some View {
        VStack(spacing: 4) {
            Image(image)
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            
            if let label {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 110)
                //                    .padding(.horizontal, 8)
                //                    .padding(.vertical, 3)
                //                    .background(.black.opacity(0.65), in: Capsule())
            }
        }
        .contentShape(Rectangle())
    }
}
//private struct LandmarkPin: View {
//    let image: String
//
//    var body: some View {
//        Image(image)
//            .resizable()
//            .scaledToFill()
//            .frame(width: 52, height: 52)
//            .clipShape(Circle())
//            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
//            .contentShape(Circle())
//    }
//}

/// Marks the leading edge of the currently drawn route — where the trip starts, or where
/// the trimmed line currently begins once navigating. `arrowtriangle.up.fill` points north
/// by default, so rotating it by the segment's heading turns it to face the way it travels.
/// The point where the rider gets off one bus and onto another: a white node on the line,
/// captioned with the line they leave and the line they board. Named so a visitor who can't
/// read the network by colour alone still knows what is being asked of them.
private struct TransferMark: View {
    let from: String
    let to: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                Text(from)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                Text(to)
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color, in: Capsule())
            .overlay(Capsule().stroke(.white, lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            .fixedSize()
            
            Circle()
                .fill(.white)
                .frame(width: 14, height: 14)
                .overlay(Circle().stroke(color, lineWidth: 3))
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
    }
}

private struct RouteArrowMark: View {
    let heading: CLLocationDirection
    
    var body: some View {
        Image(systemName: "arrowtriangle.up.fill")
            .font(.system(size: 13))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 1.5)
            .rotationEffect(.degrees(heading))
    }
}

/// The rider's own marker. Once a heading is known it becomes a pointer facing the way they
/// are travelling, like the Google Maps puck. `heading` is already relative to the map's own
/// rotation, so the pointer keeps facing down the road when the map turns under it — and
/// sits upright while the nav camera is aligned with the rider. Without a heading (no
/// compass, standing still before the first course fix) it falls back to a plain dot rather
/// than pointing somewhere arbitrary.
private struct UserLocationMark: View {
    let heading: CLLocationDirection?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 26, height: 26)
                .shadow(color: .black.opacity(0.35), radius: 2)
            
            if let heading {
                Image(systemName: "location.north.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.blue)
                    .rotationEffect(.degrees(heading))
            } else {
                Circle()
                    .fill(.blue)
                    .frame(width: 16, height: 16)
            }
        }
    }
}

/// A white badge with a blue arrow at an upcoming turn — the Google Maps convention for
/// marking a maneuver point on the line, distinct from the plain leading-edge chevron.
private struct TurnMarker: View {
    let heading: CLLocationDirection
    
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.35), radius: 2)
            Image(systemName: "arrow.up")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.blue)
                .rotationEffect(.degrees(heading))
        }
    }
}

private extension Array where Element == CLLocationCoordinate2D {
    /// Coordinate at the array's midpoint by element count — good enough for placing a
    /// single icon on a short walking connector, no need for a distance-weighted midpoint.
    var midpointCoordinate: CLLocationCoordinate2D? {
        guard !isEmpty else { return nil }
        return self[count / 2]
    }
}

private struct NavigationCameraState: Equatable {
    let latitude: CLLocationDegrees?
    let longitude: CLLocationDegrees?
    let heading: CLLocationDirection?
    let isNavigating: Bool
}

private extension CLLocation {
    func distance(
        from meters: CLLocationDistance,
        bearingDegrees: CLLocationDirection
    ) -> CLLocation {
        let earthRadius = 6_371_000.0
        let angularDistance = meters / earthRadius
        let bearing = bearingDegrees * .pi / 180
        
        let latitudeRadians = coordinate.latitude * .pi / 180
        let longitudeRadians = coordinate.longitude * .pi / 180
        
        let destinationLatitude = asin(
            sin(latitudeRadians) * cos(angularDistance) +
            cos(latitudeRadians) * sin(angularDistance) * cos(bearing)
        )
        
        let destinationLongitude = longitudeRadians + atan2(
            sin(bearing) * sin(angularDistance) * cos(latitudeRadians),
            cos(angularDistance) - sin(latitudeRadians) * sin(destinationLatitude)
        )
        
        return CLLocation(
            latitude: destinationLatitude * 180 / .pi,
            longitude: destinationLongitude * 180 / .pi
        )
    }
}

#Preview("Landmark Pin") {
    ZStack {
        Color.gray.opacity(0.3) // simulate a map background
        LandmarkPin(image: "landmark-placeholder", label: "Bajra Sandhi Monument")
    }
    .frame(width: 200, height: 200)
}

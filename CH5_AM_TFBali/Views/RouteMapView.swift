import SwiftUI
import MapKit
import SwiftData

private enum ActiveSheet: Identifiable {
    case videoPreview(url: URL, landmarkName: String)
    case sessionHistory
    case landmarkDetail(index: Int)
    case landmarksGallery

    var id: String {
        switch self {
        case .videoPreview(let url, _): "video-\(url.path)"
        case .sessionHistory: "history"
        case .landmarkDetail(let index): "landmark-\(index)"
        case .landmarksGallery: "landmarks-gallery"
        }
    }
}

/// A fetched pedestrian connector for the transfer leg the rider is currently approaching,
/// tagged with the leg it belongs to so a stale fetch from a passed transfer never lingers.
private struct WalkingConnector {
    let legID: UUID
    let coordinates: [CLLocationCoordinate2D]
}

/// Equatable stand-in for a coordinate, so `onChange` can fire on new fixes.
private struct CoordinateKey: Equatable {
    let latitude: CLLocationDegrees
    let longitude: CLLocationDegrees

    init(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
    }
}

/// The map screen: browse transit corridors, and — merged in from the nav-engine prototype —
/// start turn-by-turn navigation and mark landmarks along the way. With no `destinationPlace`
/// (the plain "Explore Bali by Bus" entry point) navigation targets the fixed Kuta-loop trip
/// exactly as before. With a `destinationPlace` (opened from a place's "Explore" button),
/// navigation targets that place instead: the anchor bus stop is drawn from whichever visible
/// corridor direction actually reaches it, and the single "landmark" to mark is the place
/// itself.
struct RouteMapView: View {
    @Environment(\.modelContext) private var modelContext

    let destinationPlace: Place?

    // MARK: Corridor browsing

    @State private var visibleCorridorIDs: Set<String>
    @State private var visibleDirectionIDs: Set<UUID>
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]  // keyed by direction.id.uuidString
    @State private var loadingCorridorIDs: Set<String> = []
    @State private var selectedStop: BusStop?

    // MARK: Navigation engine

    @State private var locationManager = LocationManager()
    @State private var isRouting = false
    @State private var calculatedRoute: MapRoute?
    @State private var routeTask: Task<Void, Never>?
    @State private var hasRequestedRoute = false
    @State private var hasRoutedWithLocation = false
    @State private var directions: [DirectionStep] = []
    @State private var checkpoints: [RouteCheckpoint] = []
    @State private var currentStepIndex = 0
    @State private var routeProgress: RouteProgress?
    @State private var nearbyLandmark: NearbyLandmark?
    @State private var capturedLandmarkIndices: Set<Int> = []
    @State private var showCamera = false
    @State private var pendingLandmark: NearbyLandmark?
    @State private var activeSheet: ActiveSheet?
    @State private var activeSession: NavigationSession?
    @State private var currentCheckpointIndex = 0
    @State private var lastActivityPush: Date = .distantPast
    @State private var isFollowingUser = true
    @State private var transitVisits: [TransitStopVisit] = []
    @State private var transitLegs: [TransitLeg] = []
    @State private var currentStopVisitIndex = 0
    @State private var activeWalkingConnector: WalkingConnector?
    @State private var walkingConnectorTask: Task<Void, Never>?
    /// Where the rider stood when they tapped start — point A for the trip that gets
    /// written to history, regardless of which stop the route itself is anchored to.
    @State private var sessionStartLocation: CLLocationCoordinate2D?

    private let checkpointArrivalThreshold: CLLocationDistance = 50
    private let activityPushInterval: TimeInterval = 1
    private let firstFixTimeout: Duration = .seconds(8)

    init(destinationPlace: Place? = nil) {
        self.destinationPlace = destinationPlace
        guard let destinationPlace else {
            _visibleCorridorIDs = State(initialValue: ["K1"])
            _visibleDirectionIDs = State(initialValue: Set(corridors.first(where: { $0.id == "K1" })?.directions.map(\.id) ?? []))
            return
        }
        // Every corridor with a stop near the destination shows by default, and only the
        // matching direction(s) of it — not, say, K5's unrelated Kuta<->Politeknik leg just
        // because K5 also happens to have a different leg that reaches here. Anything not
        // near the destination stays off by default but is still toggleable manually.
        let matches = Self.matchingCorridors(within: 1000, of: destinationPlace)
        _visibleCorridorIDs = State(initialValue: Set(matches.keys))
        _visibleDirectionIDs = State(initialValue: Set(matches.values.flatMap(\.directionIDs)))
    }

    var routeName: String {
        destinationPlace?.name ?? "Kuta Route"
    }

    /// Fixed point B for the plain Kuta-loop entry point, or the place being explored.
    private var navigationDestination: CLLocationCoordinate2D {
        guard let destinationPlace else { return MapConstants.pointB }
        return CLLocationCoordinate2D(latitude: destinationPlace.latitude, longitude: destinationPlace.longitude)
    }

    /// The fixed 4-point Kuta-loop landmark set, or a single landmark at the place itself.
    private var navigationLandmark: Landmark {
        guard let destinationPlace else { return MapConstants.landmark }
        return Landmark(name: destinationPlace.name, coordinates: [navigationDestination])
    }

    private var navigationLandmarkInfo: [LandmarkInfo] {
        guard let destinationPlace else { return MapConstants.landmarkInfo }
        return [
            LandmarkInfo(
                title: destinationPlace.name,
                category: destinationPlace.category.name,
                summary: destinationPlace.desc,
                icon: "mappin.circle.fill"
            )
        ]
    }

    /// Disambiguates `LandmarkVideo` storage across different places — see the note on
    /// `LandmarkVideo.placeKey`.
    private var placeKey: String? { destinationPlace?.name }

    private var locationKey: CoordinateKey? {
        locationManager.userLocation.map { CoordinateKey($0) }
    }

    /// Which way the trip goes overall, used to tell the stops serving this direction from
    /// the ones across the road serving the return. Straight-line rather than road-following
    /// on purpose: it only has to be right to within the 90° window `BusStop.serves` allows.
    /// Only meaningful for the fixed Kuta loop, whose stops are bidirectional at each platform
    /// — a place's corridor directions are already single-direction by construction.
    private var travelBearing: CLLocationDirection? {
        let origin = isRouting
            ? (sessionStartLocation ?? locationManager.userLocation)
            : locationManager.userLocation
        return origin?.bearing(to: navigationDestination)
    }

    /// The corridor direction actually used to reach the destination, its stops, and its
    /// real road-shape polyline (empty if not fetched yet) — so `RouteCalculator` can have
    /// the trip ride that line rather than asking MapKit for a fresh point-to-point drive
    /// that ignores the corridor entirely. `nil` for the fixed Kuta loop, which has no such
    /// corridor data (see `MapConstants.pointB`).
    ///
    /// Deliberately independent of `visibleDirectionIDs`: every corridor near the destination
    /// is visible by default (see `init`), but a rider can still manually toggle one off —
    /// that's a display preference and shouldn't be able to break routing, so this re-scans
    /// every corridor rather than trusting whatever's currently toggled on.
    private var servingRide: (corridor: Corridor, direction: RouteDirection, stops: [BusStop], polyline: [CLLocationCoordinate2D])? {
        guard let destinationPlace else { return nil }
        guard let best = bestDirectionTowardDestination() else { return nil }
        return (best.corridor, best.direction, best.direction.stops, polylines[best.direction.id.uuidString] ?? [])
    }

    private var servingBusStops: [BusStop] {
        if let servingRide { return servingRide.stops }
        guard let destinationPlace else { return MapConstants.busStops(serving: travelBearing) }
        // No corridor anywhere reaches within range — fall back to a single stop at the
        // destination itself so routing still has an anchor to work from.
        return [stop(destinationPlace.name, navigationDestination.latitude, navigationDestination.longitude)]
    }

    /// Among every corridor direction (not just the ones currently toggled on), the one
    /// whose nearest-to-destination stop sits closest to *the end* of that direction's stop
    /// sequence — i.e. travelling it actually arrives near the destination, rather than
    /// starting there and heading away.
    private func bestDirectionTowardDestination() -> (corridor: Corridor, direction: RouteDirection)? {
        var best: (corridor: Corridor, direction: RouteDirection, ratio: Double, distance: CLLocationDistance)?
        for corridor in corridors {
            for direction in corridor.directions {
                guard let match = Self.nearestStopIndex(to: navigationDestination, in: direction.stops),
                      match.distance <= 1000 else { continue }
                let ratio = direction.stops.count > 1 ? Double(match.index) / Double(direction.stops.count - 1) : 1
                if best == nil || ratio > best!.ratio || (ratio == best!.ratio && match.distance < best!.distance) {
                    best = (corridor, direction, ratio, match.distance)
                }
            }
        }
        return best.map { ($0.corridor, $0.direction) }
    }

    private static func nearestStopIndex(
        to coordinate: CLLocationCoordinate2D,
        in stops: [BusStop]
    ) -> (index: Int, distance: CLLocationDistance)? {
        var best: (index: Int, distance: CLLocationDistance)?
        for (index, busStop) in stops.enumerated() {
            let distance = busStop.coordinate.distance(to: coordinate)
            if best == nil || distance < best!.distance {
                best = (index, distance)
            }
        }
        return best
    }

    var routeHeading: CLLocationDirection? {
        if let userHeading = locationManager.userHeading {
            return userHeading
        }

        guard
            let userLocation = locationManager.userLocation,
            let currentStep
        else {
            return nil
        }

        return userLocation.bearing(to: currentStep.coordinate)
    }

    var cameraHeading: CLLocationDirection? {
        routeHeading?.normalizedCompassHeading
    }

    var currentStep: DirectionStep? {
        guard currentStepIndex < directions.count else { return nil }
        return directions[currentStepIndex]
    }

    var nextStep: DirectionStep? {
        guard currentStepIndex + 1 < directions.count else { return nil }
        return directions[currentStepIndex + 1]
    }

    var distanceToCurrentStep: CLLocationDistance? {
        guard let currentStep, let userLocation = locationManager.userLocation else { return nil }
        return userLocation.distance(to: currentStep.coordinate)
    }

    private var currentCheckpoint: RouteCheckpoint? {
        guard checkpoints.indices.contains(currentCheckpointIndex) else { return nil }
        return checkpoints[currentCheckpointIndex]
    }

    /// The next real bus stop on the trip — distinct from `currentCheckpoint`, which only
    /// tracks landmarks and the finish stop, not every stop the ride passes through.
    private var nextStopVisit: TransitStopVisit? {
        guard transitVisits.indices.contains(currentStopVisitIndex) else { return nil }
        return transitVisits[currentStopVisitIndex]
    }

    /// The leg currently being ridden or walked — connects the stop just left to
    /// `nextStopVisit`. Carries the transfer info (corridor change, walking distance) for
    /// whatever's between those two stops.
    private var currentTransitLeg: TransitLeg? {
        let legIndex = currentStopVisitIndex - 1
        guard transitLegs.indices.contains(legIndex) else { return nil }
        return transitLegs[legIndex]
    }

    /// Corridor lines currently toggled on, resolved to their fetched polyline coordinates —
    /// what `MapViewContainer` actually draws for browsing.
    private var visibleCorridorOverlays: [CorridorOverlay] {
        corridors
            .filter { visibleCorridorIDs.contains($0.id) }
            .flatMap { corridor in
                corridor.directions.enumerated().compactMap { legIndex, direction -> CorridorOverlay? in
                    guard visibleDirectionIDs.contains(direction.id) else { return nil }
                    return CorridorOverlay(
                        id: direction.id,
                        color: corridor.color,
                        strokeStyle: strokeStyle(for: corridor, legIndex: legIndex),
                        coordinates: polylines[direction.id.uuidString] ?? [],
                        stops: direction.stops
                    )
                }
            }
    }

    var body: some View {
        ZStack {
            MapViewContainer(
                locations: MapConstants.defaultLocations,
                userLocation: locationManager.userLocation,
                isNavigating: isRouting,
                navigationHeading: cameraHeading,
                centerCoordinate: destinationPlace.map { _ in navigationDestination },
                route: calculatedRoute ?? (destinationPlace == nil ? MapConstants.previewRoute : nil),
                routeProgress: routeProgress,
                directions: directions,
                landmark: navigationLandmark,
                busStops: destinationPlace == nil ? MapConstants.busStops : [],
                servingStopIDs: Set(servingBusStops.map(\.id)),
                nextStopID: nextStopVisit?.stop.id,
                walkingConnector: activeWalkingConnector?.coordinates ?? [],
                corridorOverlays: visibleCorridorOverlays,
                destinationPin: destinationPlace,
                focusSpan: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08),
                isFollowingUser: $isFollowingUser,
                onSelectLandmark: { index in
                    activeSheet = .landmarkDetail(index: index)
                },
                onSelectCorridorStop: { stop in
                    selectedStop = stop
                }
            )

            VStack(spacing: 0) {
                MapHeader(
                    title: destinationPlace?.name ?? "Bali Map",
                    onOpenHistory: { activeSheet = .sessionHistory },
                    onOpenLandmarks: { activeSheet = .landmarksGallery }
                )

                if !isRouting {
                    VStack(spacing: 0) {
                        CorridorToggleRow(
                            visibleCorridorIDs: $visibleCorridorIDs,
                            visibleDirectionIDs: $visibleDirectionIDs,
                            loadingCorridorIDs: loadingCorridorIDs
                        )
                        ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                            DirectionToggleRow(
                                corridor: corridor,
                                visibleDirectionIDs: $visibleDirectionIDs,
                                polylines: polylines,
                                isCorridorLoading: loadingCorridorIDs.contains(corridor.id)
                            )
                        }
                    }
                    .background(.thinMaterial)
                }

                Spacer()

                if isRouting {
                    DirectionsBox(
                        currentInstruction: currentStep,
                        distanceToCurrent: distanceToCurrentStep,
                        nextInstruction: nextStep,
                        nearbyLandmark: nearbyLandmark,
                        checkpointIndex: currentCheckpointIndex,
                        totalCheckpoints: checkpoints.count,
                        currentCheckpoint: currentCheckpoint,
                        nextStop: nextStopVisit,
                        transitLeg: currentTransitLeg,
                        onOpenCamera: {
                            pendingLandmark = nearbyLandmark
                            showCamera = true
                        }
                    )
                }

                if isRouting && !isFollowingUser {
                    HStack {
                        Spacer()
                        RecenterButton {
                            isFollowingUser = true
                        }
                    }
                    .padding(.trailing)
                    .padding(.bottom, 8)
                }

                RoutingControl(isRouting: $isRouting, routeName: routeName)
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
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
        .fullScreenCover(isPresented: $showCamera) {
            PortraitLocked {
                CameraView { tempURL in
                    handleCapturedVideo(tempURL)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .videoPreview(let url, let landmarkName):
                VideoPreviewView(url: url, landmarkName: landmarkName)
            case .sessionHistory:
                NavigationSessionHistoryView()
            case .landmarkDetail(let index):
                landmarkDetailSheet(for: index)
            case .landmarksGallery:
                LandmarksGalleryView(
                    landmark: MapConstants.landmark,
                    landmarkInfo: MapConstants.landmarkInfo,
                    videosBaseDirectory: baseVideosDirectory
                )
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.userLocation != nil) { _, hasFix in
            // The route is anchored to the bus stop nearest the rider, so it is worthless
            // until there is a fix. Calculating on appear as well used to race this one and
            // whichever finished last won — often the location-less version, which is why
            // the dashed approach line kept vanishing.
            // Tracked separately from `hasRequestedRoute` so a fix arriving after the
            // no-fix fallback already drew the generic loop still re-anchors the route.
            guard hasFix, !hasRoutedWithLocation else { return }
            hasRoutedWithLocation = true
            hasRequestedRoute = true
            calculateRoute()
        }
        .onChange(of: locationKey) { _, _ in
            refreshNavigationState()
        }
        .onChange(of: isRouting) { _, newValue in
            if newValue {
                startNavigationSession()
                calculateRoute()
                refreshNavigationState()
                Task {
                    await RoutingActivityManager.shared.startActivity(routeName: routeName)
                }
            } else {
                endNavigationSession()
                Task {
                    await RoutingActivityManager.shared.endActivity()
                }
            }
        }
        .task {
            // A `Timer.publish` built inline in `body` is a fresh publisher on every render.
            // The view re-renders on each GPS fix, so the subscription was torn down and
            // restarted before its one-second tick ever landed — which is what made landmark
            // detection, step advance and the live activity all lag by up to a minute. A
            // `task` loop is bound to the view's lifetime, not its render count.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                refreshNavigationState()
            }
        }
        .task {
            // Indoors or with location denied the first fix may never arrive; show the
            // generic loop rather than an empty map.
            try? await Task.sleep(for: firstFixTimeout)
            guard !hasRequestedRoute else { return }
            hasRequestedRoute = true
            calculateRoute()
        }
        .onDisappear {
            routeTask?.cancel()
            walkingConnectorTask?.cancel()
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
            // Per-segment caching lives inside RoutePolylineBuilder's router — a direction
            // whose segments are all already cached resolves here with no network calls.
            let result = await RoutePolylineBuilder.polyline(for: direction)
            polylines[direction.id.uuidString] = result.coordinates
        }
    }

    /// Corridors with at least one stop within `meters` of the place, and how many stops
    /// their matching direction(s) carry — the "for now" way of picking which lines are
    /// relevant to a destination, without a per-place lookup table.
    private static func matchingCorridors(within meters: CLLocationDistance, of place: Place) -> [String: DestinationMatch] {
        let target = CLLocation(latitude: place.latitude, longitude: place.longitude)
        var matches: [String: DestinationMatch] = [:]
        for corridor in corridors {
            for direction in corridor.directions {
                let hasNearStop = direction.stops.contains { busStop in
                    CLLocation(latitude: busStop.coordinate.latitude, longitude: busStop.coordinate.longitude)
                        .distance(from: target) <= meters
                }
                guard hasNearStop else { continue }
                var match = matches[corridor.id] ?? DestinationMatch()
                match.directionIDs.insert(direction.id)
                matches[corridor.id] = match
            }
        }
        return matches
    }

    /// Which of a corridor's directions have a stop near a destination.
    private struct DestinationMatch {
        var directionIDs: Set<UUID> = []
    }

    // MARK: - Navigation engine

    /// Single pass over everything that depends on the rider's position. Driven by new
    /// fixes and by a one-second heartbeat so heading-only changes still land.
    private func refreshNavigationState() {
        updateRouteProgress()
        updateLandmarkProximity()

        guard isRouting else { return }
        updateStepProgress()
        updateCheckpointProgress()
        updateTransitProgress()
        fetchWalkingConnectorIfNeeded()
        pushLiveActivityUpdate()
    }

    private func calculateRoute() {
        routeTask?.cancel()
        let userLocation = locationManager.userLocation
        // Resolved before the await so the anchor stop and the stop queue are drawn from
        // the same list, even if a fix lands while directions are in flight.
        let ride = servingRide
        let stops = servingBusStops
        let destination = navigationDestination

        // Routing can pick a corridor that isn't currently toggled on (e.g. K5, left off the
        // default view for load-budget reasons but still a real, often better, way to reach
        // the destination) — reveal it and fetch its polyline so the ride actually has a real
        // line to follow instead of silently falling back to a direct MapKit leg.
        if let ride, !visibleCorridorIDs.contains(ride.corridor.id) {
            visibleCorridorIDs.insert(ride.corridor.id)
            visibleDirectionIDs.formUnion(ride.corridor.directions.map(\.id))
        }

        routeTask = Task {
            var corridorPolyline = ride?.polyline ?? []
            if let direction = ride?.direction, corridorPolyline.isEmpty {
                let fetched = await RoutePolylineBuilder.polyline(for: direction)
                guard !Task.isCancelled else { return }
                corridorPolyline = fetched.coordinates
                polylines[direction.id.uuidString] = corridorPolyline
            }

            let result = await RouteCalculator.shared.calculateRoute(
                destination: destination,
                userLocation: userLocation,
                busStops: stops,
                corridorPolyline: corridorPolyline
            )
            guard !Task.isCancelled else { return }

            calculatedRoute = result.route
            directions = result.steps
            checkpoints = buildCheckpoints(for: result.route)
            transitVisits = TransitPlanner.stopVisits(for: stops, along: result.route.combinedWaypoints)
            transitLegs = TransitPlanner.legs(for: transitVisits)
            currentStopVisitIndex = 0
            activeWalkingConnector = nil
            routeProgress = nil
            currentStepIndex = 0

            if let activeSession {
                activeSession.totalSteps = result.steps.count
                activeSession.totalCheckpoints = checkpoints.count
                activeSession.routeCoordinates = sessionRouteCoordinates(for: result.route)
            }
            try? modelContext.save()

            refreshNavigationState()
        }
    }

    /// The trip as history should remember it: from where the rider set off (point A) to
    /// the destination. The calculated route is anchored to a bus stop, which can sit behind
    /// the rider when they were already on the corridor — recording it raw drew a line
    /// starting somewhere they never went. Trimming to their projected position and
    /// prepending their actual start makes the saved shape match the journey.
    private func sessionRouteCoordinates(for route: MapRoute) -> [RouteCoordinate] {
        let path = route.combinedWaypoints
        guard let start = sessionStartLocation ?? locationManager.userLocation, path.count >= 2 else {
            return path.map { RouteCoordinate($0) }
        }
        guard let progress = RouteGeometry.progress(of: start, along: path) else {
            return path.map { RouteCoordinate($0) }
        }

        let ahead = RouteGeometry.remaining(path, fromSegment: progress.index, projected: progress.projected)
        // With an approach leg the path already begins at the rider, so prepending would
        // only duplicate the first point.
        let prefix = start.distance(to: progress.projected) > 1 ? [start] : []
        return (prefix + ahead).map { RouteCoordinate($0) }
    }

    /// Orders checkpoints by where the road reaches them, not by how they are declared.
    /// The route is anchored to whichever bus stop the rider starts from (point A), so
    /// the first landmark declared is regularly not the first one you pass.
    private func buildCheckpoints(for route: MapRoute) -> [RouteCheckpoint] {
        let path = route.combinedWaypoints
        guard !path.isEmpty else { return [] }

        let landmarkCheckpoints = navigationLandmark.coordinates
            .enumerated()
            .map { index, coordinate in
                RouteCheckpoint(
                    coordinate: coordinate,
                    name: navigationLandmarkInfo.indices.contains(index) ? navigationLandmarkInfo[index].title : "Landmark \(index + 1)",
                    kind: .landmark,
                    pathIndex: RouteGeometry.nearestIndex(to: coordinate, along: path),
                    landmarkIndex: index
                )
            }
            .sorted { $0.pathIndex < $1.pathIndex }

        let finish = RouteCheckpoint(
            coordinate: navigationDestination,
            name: destinationPlace?.name ?? "Destination",
            kind: .destination,
            pathIndex: path.count - 1
        )

        return landmarkCheckpoints + [finish]
    }

    private func updateRouteProgress() {
        guard
            let userLocation = locationManager.userLocation,
            let route = calculatedRoute
        else { return }

        let path = route.combinedWaypoints
        guard let progress = RouteGeometry.progress(
            of: userLocation,
            along: path,
            from: routeProgress?.index ?? 0
        ) else { return }

        // Never walk the index backwards on a jittery fix; re-acquiring after a genuine
        // detour is the projection's job, not a per-tick decision.
        if let existing = routeProgress, progress.index < existing.index,
           progress.offRouteDistance > RouteGeometry.offRouteThreshold {
            return
        }

        routeProgress = progress
    }

    private func updateLandmarkProximity() {
        nearbyLandmark = LandmarkProximityDetector.nearestLandmark(
            userLocation: locationManager.userLocation,
            landmark: navigationLandmark,
            heading: routeHeading,
            active: nearbyLandmark,
            excluding: capturedLandmarkIndices,
            names: navigationLandmarkInfo.map(\.title)
        )
    }

    /// Picks the first maneuver still ahead on the path. The old version needed the rider
    /// to pass within 50 m of every single step in order and advanced at most one per tick,
    /// so a missed radius pinned the box on the first instruction for the whole trip.
    private func updateStepProgress() {
        guard !directions.isEmpty else { return }
        guard let progressIndex = routeProgress?.index else { return }

        let index = directions.firstIndex { $0.pathIndex > progressIndex } ?? directions.count - 1
        currentStepIndex = max(currentStepIndex, index)
    }

    private func updateCheckpointProgress() {
        guard let userLocation = locationManager.userLocation else { return }
        guard currentCheckpointIndex < checkpoints.count else { return }

        let checkpoint = checkpoints[currentCheckpointIndex]
        let arrived = userLocation.distance(to: checkpoint.coordinate) <= checkpointArrivalThreshold
        // Also clear it once the route itself is past the checkpoint, so a wide GPS fix
        // near a landmark does not block every checkpoint behind it.
        let passed = (routeProgress?.index ?? 0) > checkpoint.pathIndex

        guard arrived || passed else { return }

        currentCheckpointIndex += 1
        activeSession?.checkpointsReached = currentCheckpointIndex
        try? modelContext.save()
    }

    /// Same arrived-or-passed pattern as checkpoints. `transitVisits[0]` is the stop the
    /// rider starts at, so it clears almost immediately — the first real "next stop" the
    /// rider sees is index 1.
    private func updateTransitProgress() {
        guard let userLocation = locationManager.userLocation else { return }
        guard currentStopVisitIndex < transitVisits.count else { return }

        let visit = transitVisits[currentStopVisitIndex]
        let arrived = userLocation.distance(to: visit.stop.coordinate) <= checkpointArrivalThreshold
        let passed = (routeProgress?.index ?? 0) > visit.pathIndex

        guard arrived || passed else { return }

        currentStopVisitIndex += 1
        activeWalkingConnector = nil
    }

    /// Fetches walking directions for the transfer leg the rider is currently approaching,
    /// and only that one — skipped entirely for a plain ride or a same-stop transfer, and
    /// cleared once the rider moves past it or the leg it belongs to changes.
    private func fetchWalkingConnectorIfNeeded() {
        guard let leg = currentTransitLeg, case .walkingTransfer = leg.kind else {
            if activeWalkingConnector != nil {
                walkingConnectorTask?.cancel()
                activeWalkingConnector = nil
            }
            return
        }
        guard activeWalkingConnector?.legID != leg.id else { return }

        walkingConnectorTask?.cancel()
        walkingConnectorTask = Task {
            let result = await RouteCalculator.shared.walkingTransferLeg(
                from: leg.from.stop.coordinate,
                to: leg.to.stop.coordinate
            )
            guard !Task.isCancelled else { return }
            activeWalkingConnector = WalkingConnector(legID: leg.id, coordinates: result.coordinates)
        }
    }

    private func pushLiveActivityUpdate() {
        guard Date().timeIntervalSince(lastActivityPush) >= activityPushInterval else { return }
        lastActivityPush = .now

        let step = currentStep
        let distance = distanceToCurrentStep
        let next = nextStep
        let landmark = nearbyLandmark
        let stopName = nextStopVisit?.stop.name
        let transferSummary = currentTransitLeg?.kind.transferSummary

        Task {
            await RoutingActivityManager.shared.updateActivity(
                currentStep: step,
                distanceToCurrentStep: distance,
                nextStep: next,
                nearbyLandmark: landmark,
                nextStopName: stopName,
                transferSummary: transferSummary
            )
        }
    }

    /// Marks the landmark the rider is next to — the recording is owned by the landmark
    /// itself, not the trip, so it stays and stacks up across every future visit.
    private func handleCapturedVideo(_ tempURL: URL) {
        guard let landmark = pendingLandmark else {
            print("Cannot mark a landmark without one nearby")
            return
        }
        let landmarkName = landmark.name

        guard let savedURL = saveVideo(from: tempURL, landmarkIndex: landmark.index, landmarkName: landmarkName) else { return }
        saveLandmarkVideo(
            landmarkIndex: landmark.index,
            landmarkName: landmarkName,
            fileName: savedURL.lastPathComponent
        )

        // Stop re-announcing a landmark the rider has already marked this trip.
        capturedLandmarkIndices.insert(landmark.index)
        nearbyLandmark = nil
        pendingLandmark = nil

        activeSheet = .videoPreview(url: savedURL, landmarkName: landmarkName)
    }

    private func saveLandmarkVideo(
        landmarkIndex: Int,
        landmarkName: String,
        fileName: String
    ) {
        let video = LandmarkVideo(
            landmarkIndex: landmarkIndex,
            placeKey: placeKey,
            landmarkName: landmarkName,
            fileName: fileName,
            recordedAt: .now
        )
        modelContext.insert(video)
        try? modelContext.save()
    }

    private func landmarkDetailSheet(for index: Int) -> LandmarkRecordingsView {
        LandmarkRecordingsView(
            landmarkIndex: index,
            placeKey: placeKey,
            landmarkName: navigationLandmarkInfo.indices.contains(index) ? navigationLandmarkInfo[index].title : "Landmark \(index + 1)",
            info: navigationLandmarkInfo.indices.contains(index) ? navigationLandmarkInfo[index] : nil,
            videosBaseDirectory: baseVideosDirectory
        )
    }

    private var baseVideosDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LandmarkVideos", isDirectory: true)
    }

    private func videosDirectory(forLandmarkIndex index: Int) -> URL? {
        baseVideosDirectory?
            .appendingPathComponent(LandmarkVideo.storageFolder(landmarkIndex: index, placeKey: placeKey), isDirectory: true)
    }

    private func saveVideo(
        from tempURL: URL,
        landmarkIndex: Int,
        landmarkName: String
    ) -> URL? {
        let fileManager = FileManager.default
        guard let videosDirectory = videosDirectory(forLandmarkIndex: landmarkIndex) else { return nil }

        let safeName = landmarkName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let destinationURL = videosDirectory.appendingPathComponent(
            "\(safeName)_\(Int(Date().timeIntervalSince1970))_\(UUID().uuidString.prefix(6)).mov"
        )

        do {
            try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to save video: \(error)")
            return nil
        }
    }

    private func startNavigationSession() {
        currentStepIndex = 0
        currentCheckpointIndex = 0
        currentStopVisitIndex = 0
        activeWalkingConnector = nil
        nearbyLandmark = nil
        capturedLandmarkIndices = []
        routeProgress = nil
        sessionStartLocation = locationManager.userLocation

        let session = NavigationSession(
            routeName: routeName,
            totalSteps: directions.count,
            totalCheckpoints: checkpoints.count,
            routeCoordinates: calculatedRoute.map { sessionRouteCoordinates(for: $0) } ?? []
        )
        modelContext.insert(session)
        activeSession = session
        try? modelContext.save()
    }

    private func endNavigationSession() {
        guard let activeSession else { return }

        activeSession.endedAt = .now
        activeSession.totalSteps = directions.count
        activeSession.completedSteps = directions.isEmpty ? 0 : min(currentStepIndex + 1, directions.count)
        activeSession.checkpointsReached = currentCheckpointIndex
        activeSession.totalCheckpoints = checkpoints.count
        activeSession.isCompleted = currentCheckpointIndex >= checkpoints.count

        try? modelContext.save()
        self.activeSession = nil
        currentCheckpointIndex = 0
        sessionStartLocation = nil
    }
}

private struct CorridorToggleRow: View {
    @Binding var visibleCorridorIDs: Set<String>
    @Binding var visibleDirectionIDs: Set<UUID>
    let loadingCorridorIDs: Set<String>

    private let lightCorridorIDs: Set<String> = ["K5", "K6", "SHUTTLE_SANUR"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(corridors) { corridor in
                    let isOn = visibleCorridorIDs.contains(corridor.id)
                    let isLoading = isOn && loadingCorridorIDs.contains(corridor.id)
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
                        HStack(spacing: 4) {
                            Text(corridor.id)
                                .font(.caption.bold())
                            if isLoading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(lightCorridorIDs.contains(corridor.id) ? Color.black : Color.white)
                            }
                        }
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
    }
}

private struct DirectionToggleRow: View {
    let corridor: Corridor
    @Binding var visibleDirectionIDs: Set<UUID>
    /// Used only to tell a leg that's still being fetched from one that's loaded (or failed)
    /// — otherwise a long leg with no result yet looks identical to a broken one.
    let polylines: [String: [CLLocationCoordinate2D]]
    let isCorridorLoading: Bool

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
                    let isLoading = isOn && isCorridorLoading && polylines[direction.id.uuidString] == nil
                    Button {
                        if isOn {
                            visibleDirectionIDs.remove(direction.id)
                        } else {
                            visibleDirectionIDs.insert(direction.id)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(label(for: legIndex))
                                .font(.caption2.bold())
                            if isLoading {
                                ProgressView()
                                    .controlSize(.mini)
                                    .tint(.white)
                            }
                        }
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

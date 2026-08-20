import SwiftUI
import MapKit
import SwiftData

private enum ActiveSheet: Identifiable {
    case videoPreview(url: URL, landmarkName: String)
    case sessionHistory
    case landmarkDetail(index: Int)
    case poiDetail(LandmarkPOI)
    
    var id: String {
        switch self {
        case .videoPreview(let url, _): "video-\(url.path)"
        case .sessionHistory: "history"
        case .landmarkDetail(let index): "landmark-\(index)"
        case .poiDetail(let poi): "poi-\(poi.id)"
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
/// (the plain "Explore Bali by Bus" entry point) this is browse-only: every corridor is
/// toggleable but there's nothing to route to, so the nav engine (Start Route, checkpoints,
/// landmark marking, live activity) stays inert. With a `destinationPlace` (opened from a
/// place's "Explore" button), navigation targets that place: the anchor bus stop is drawn
/// from whichever visible corridor direction actually reaches it, and the single "landmark"
/// to mark is the place itself.
struct RouteMapView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let destinationPlace: Place?
    
    // MARK: Corridor browsing
    
    @State private var visibleCorridorIDs: Set<String>
    @State private var visibleDirectionIDs: Set<UUID>
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]  // keyed by direction.id.uuidString
    @State private var loadingCorridorIDs: Set<String> = []
    @State private var loadingDirectionIDs: Set<UUID> = []
    /// Set once the rider works the toggle rows themselves, after which the map stops
    /// re-selecting lines for them.
    @State private var hasManualCorridorSelection = false
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
    
    @State private var showTripPreview = false
    @State private var hasShownTripPreview = false
    
    init(destinationPlace: Place? = nil) {
        self.destinationPlace = destinationPlace
        guard let destinationPlace else {
            _visibleCorridorIDs = State(initialValue: ["K1"])
            _visibleDirectionIDs = State(initialValue: Set(corridors.first(where: { $0.id == "K1" })?.directions.map(\.id) ?? []))
            return
        }
        // Only the one corridor direction the trip will actually ride shows by default —
        // the same one `servingRide` hands to `RouteCalculator`, so the line drawn on the
        // map is the line the rider is told to follow. Other corridors that happen to pass
        // near the destination are not part of this trip and stay off, though they remain
        // toggleable for browsing.
        //
        // No GPS fix exists this early, so this is the location-less pick (whichever line
        // alights nearest the place); `syncVisibilityToServingRide` corrects it as soon as a
        // fix arrives and the rider's own position can be weighed in.
        let destination = CLLocationCoordinate2D(latitude: destinationPlace.latitude, longitude: destinationPlace.longitude)
        guard let serving = Self.bestDirectionTowardDestination(to: destination, from: nil) else {
            // Nothing reaches this place; leave the map clean rather than drawing lines that
            // don't go there. Routing falls back to a stop at the destination itself.
            _visibleCorridorIDs = State(initialValue: [])
            _visibleDirectionIDs = State(initialValue: [])
            return
        }
        _visibleCorridorIDs = State(initialValue: [serving.corridor.id])
        _visibleDirectionIDs = State(initialValue: [serving.direction.id])
    }
    
    var routeName: String {
        destinationPlace?.name ?? "Kuta Route"
    }
    
    /// The place being explored, or `nil` in browse-only mode (opened with no destination —
    /// the whole nav engine below is inert without one).
    private var navigationDestination: CLLocationCoordinate2D? {
        guard let destinationPlace else { return nil }
        return CLLocationCoordinate2D(latitude: destinationPlace.latitude, longitude: destinationPlace.longitude)
    }
    
    /// A single landmark at the place being explored, `nil` in browse-only mode.
    private var navigationLandmark: Landmark? {
        guard let destinationPlace, let navigationDestination else { return nil }
        return Landmark(name: destinationPlace.name, coordinates: [navigationDestination])
    }
    
    private var navigationLandmarkInfo: [LandmarkInfo] {
        guard let destinationPlace else { return [] }
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
    
    /// The corridor direction actually used to reach the destination, its stops, and its
    /// real road-shape polyline (empty if not fetched yet) — so `RouteCalculator` can have
    /// the trip ride that line rather than asking MapKit for a fresh point-to-point drive
    /// that ignores the corridor entirely. `nil` in browse-only mode (no destination to
    /// route to).
    ///
    /// Deliberately independent of `visibleDirectionIDs`: this direction is what the map
    /// shows by default (see `init`), but a rider can still manually toggle it off — that's a
    /// display preference and shouldn't be able to break routing, so this re-scans every
    /// corridor rather than trusting whatever's currently toggled on.
    ///
    /// Which line wins depends on where the rider is, so this changes when the first fix
    /// lands — the map follows it via `syncVisibilityToServingRide`.
    private var servingRide: (corridor: Corridor, direction: RouteDirection, stops: [BusStop], polyline: [CLLocationCoordinate2D])? {
        guard let navigationDestination else { return nil }
        // Frozen to where the rider stood at departure once under way, so a pick can't
        // flip mid-trip as they ride past stops on another corridor.
        let origin = isRouting ? (sessionStartLocation ?? locationManager.userLocation) : locationManager.userLocation
        guard let best = Self.bestDirectionTowardDestination(to: navigationDestination, from: origin) else { return nil }
        // Only the stretch actually ridden, boarding stop through alighting stop. Handing over
        // the whole line would let `RouteCalculator` anchor to a stop past the alighting one —
        // its ride slice would come out backwards and it'd fall back to a direct MapKit leg —
        // and would pad the next-stop queue with stops the trip never reaches.
        let ridden = Array(best.direction.stops[best.boardIndex...best.alightIndex])
        return (best.corridor, best.direction, ridden, polylines[best.direction.id.uuidString] ?? [])
    }
    
    private var servingBusStops: [BusStop] {
        if let servingRide { return servingRide.stops }
        guard let destinationPlace, let navigationDestination else { return [] }
        // No corridor anywhere reaches within range — fall back to a single stop at the
        // destination itself so routing still has an anchor to work from.
        return [stop(destinationPlace.name, navigationDestination.latitude, navigationDestination.longitude)]
    }
    
    /// One candidate trip: board `direction` at `boardIndex`, ride to `alightIndex`, walk off.
    private struct RideOption {
        let corridor: Corridor
        let direction: RouteDirection
        let boardIndex: Int
        let alightIndex: Int
        let walkToBoard: CLLocationDistance
        let walkFromAlight: CLLocationDistance
        
        /// What the rider actually pays on foot. Ride length isn't in here on purpose — a
        /// longer ride on a bus that stops nearer both ends still beats a shorter one the
        /// rider has to walk a kilometre to reach.
        var walkCost: CLLocationDistance { walkToBoard + walkFromAlight }
        var rideStopCount: Int { alightIndex - boardIndex }
    }
    
    /// How far off a corridor a stop can be and still count as reaching the destination.
    private static let maxAlightWalk: CLLocationDistance = 1000
    
    /// The best corridor direction to ride from `origin` to `destination`, across every
    /// corridor — not just the ones currently toggled on.
    ///
    /// Ranked by how far the rider walks at each end, boarding only at a stop the bus reaches
    /// *before* the one it alights at, so the ride runs toward the destination rather than
    /// away from it. An earlier version instead scored a direction by how far along its stop
    /// list the destination sat, which handed every trip to whichever short corridor happened
    /// to terminate near the destination — Sanur's 12-stop shuttle ends ~900 m from Sanur
    /// Beach, scoring a perfect 1.0 that no K-corridor passing mid-line could beat, even for a
    /// rider standing in Kuta with every shuttle stop 10 km away.
    ///
    /// With no `origin` yet (no GPS fix on first paint) it falls back to whichever direction
    /// alights nearest the destination; the pick is redone once a fix lands.
    private static func bestDirectionTowardDestination(
        to destination: CLLocationCoordinate2D,
        from origin: CLLocationCoordinate2D?
    ) -> RideOption? {
        var options: [RideOption] = []
        
        for corridor in corridors {
            for direction in corridor.directions {
                guard let alight = nearestStopIndex(to: destination, in: direction.stops),
                      alight.distance <= maxAlightWalk else { continue }
                
                guard let origin else {
                    options.append(RideOption(
                        corridor: corridor,
                        direction: direction,
                        boardIndex: 0,
                        alightIndex: alight.index,
                        walkToBoard: 0,
                        walkFromAlight: alight.distance
                    ))
                    continue
                }
                
                // Boarding at or past the alighting stop means riding away from the
                // destination, so only the stops ahead of it are candidates. A direction that
                // alights at its very first stop starts at the destination and leaves — no
                // valid boarding stop, so it drops out here.
                let boardable = Array(direction.stops[..<alight.index])
                guard let board = nearestStopIndex(to: origin, in: boardable) else { continue }
                
                options.append(RideOption(
                    corridor: corridor,
                    direction: direction,
                    boardIndex: board.index,
                    alightIndex: alight.index,
                    walkToBoard: board.distance,
                    walkFromAlight: alight.distance
                ))
            }
        }
        
        // Shorter ride breaks a tie between two lines that cost the rider the same on foot.
        return options.min {
            $0.walkCost == $1.walkCost ? $0.rideStopCount < $1.rideStopCount : $0.walkCost < $1.walkCost
        }
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
    
    /// Which corridor directions the map draws. Once the trip is under way that's exactly the
    /// one direction being ridden: anything else toggled on for browsing isn't part of this
    /// trip and only competes with the line the rider is meant to follow. Before that it's
    /// whatever's toggled on — which, for a place, already defaults to just that direction.
    private var drawnDirectionIDs: Set<UUID> {
        if isRouting, let servingRide { return [servingRide.direction.id] }
        return visibleDirectionIDs
    }
    
    /// The drawn corridor lines, resolved to their fetched polyline coordinates and stops —
    /// what `MapViewContainer` renders.
    private var visibleCorridorOverlays: [CorridorOverlay] {
        let drawn = drawnDirectionIDs
        return corridors.flatMap { corridor in
            corridor.directions.enumerated().compactMap { legIndex, direction -> CorridorOverlay? in
                guard drawn.contains(direction.id) else { return nil }
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
                centerCoordinate: navigationDestination,
                route: calculatedRoute,
                routeProgress: routeProgress,
                directions: directions,
                landmark: navigationLandmark,
                busStops: [],
                servingStopIDs: Set(servingBusStops.map(\.id)),
                nextStopID: nextStopVisit?.stop.id,
                walkingConnector: activeWalkingConnector?.coordinates ?? [],
                corridorOverlays: visibleCorridorOverlays,
                landmarkPOIs: landmarkPOIs,
                destinationPin: destinationPlace,
                focusSpan: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08),
                isFollowingUser: $isFollowingUser,
                onSelectLandmark: { index in
                    activeSheet = .landmarkDetail(index: index)
                },
                onSelectCorridorStop: { stop in
                    selectedStop = stop
                },
                onSelectLandmarkPOI: { poi in
                    activeSheet = .poiDetail(poi)
                }
            )
            
            VStack(spacing: 0) {
                MapHeader(
                    title: destinationPlace?.name ?? "Bali Map",
                    onOpenHistory: { activeSheet = .sessionHistory }
                )
                
                if !isRouting {
                    VStack(spacing: 0) {
                        CorridorToggleRow(
                            visibleCorridorIDs: $visibleCorridorIDs,
                            visibleDirectionIDs: $visibleDirectionIDs,
                            loadingCorridorIDs: loadingCorridorIDs,
                            onManualChange: { hasManualCorridorSelection = true }
                        )
                        ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                            DirectionToggleRow(
                                corridor: corridor,
                                visibleDirectionIDs: $visibleDirectionIDs,
                                polylines: polylines,
                                isCorridorLoading: loadingCorridorIDs.contains(corridor.id),
                                onManualChange: { hasManualCorridorSelection = true }
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
                
                // Nothing to route to without a destination — browse-only mode stops here.
                if destinationPlace != nil {
                    RoutingControl(isRouting: $isRouting, routeName: routeName)
                }
            }
        }
        .task {
            await loadVisiblePolylines()
        }
        .onChange(of: visibleDirectionIDs) { _, _ in
            Task { await loadVisiblePolylines() }
        }
        .onChange(of: servingRide?.direction.id) { _, _ in
            syncVisibilityToServingRide()
        }
        //        .onChange(of: servingRide?.direction.id) { _, newValue in
        //            syncVisibilityToServingRide()
        //            if newValue != nil, destinationPlace != nil, !hasShownTripPreview {
        //                hasShownTripPreview = true
        //                showTripPreview = true
        //            }
        //        }
        .onAppear {
            hasShownTripPreview = false
            if servingRide?.direction.id != nil, destinationPlace != nil {
                hasShownTripPreview = true
                showTripPreview = true
            }
        }
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
        //        .sheet(isPresented: $showTripPreview) {
        //            if let ride = servingRide, let destinationPlace {
        //                TripPreviewSheet(
        //                    place: destinationPlace,
        //                    corridor: ride.corridor,
        //                    direction: ride.direction,
        //                    rideStops: ride.stops,
        //                    userLocation: locationManager.userLocation,
        //                    onStart: {
        //                        showTripPreview = false
        //                        isRouting = true
        //                    },
        //                    onDismiss: { showTripPreview = false }
        //                )
        //                .presentationDetents([.height(560), .large])
        //                .presentationDragIndicator(.visible)
        //            }
        //        }
//        .sheet(isPresented: $showTripPreview) {
//            if let ride = servingRide, let destinationPlace {
//                TripPreviewSheet(
//                    place: destinationPlace,
//                    corridor: ride.corridor,
//                    direction: ride.direction,
//                    rideStops: ride.stops,
//                    userLocation: locationManager.userLocation,
//                    onStart: {
//                        showTripPreview = false
//                        isRouting = true
//                    },
//                    onDismiss: {
//                        showTripPreview = false
//                        dismiss()   // ← closes RouteMapView, returning to LandmarkDetailView
//                    }
//                )
//                .presentationDetents([.height(560), .large])
//                .presentationDragIndicator(.visible)
//            }
//        }
        .sheet(isPresented: $showTripPreview) {
            if let ride = servingRide, let destinationPlace {
                TripPreviewSheet(
                    place: destinationPlace,
                    corridor: ride.corridor,
                    direction: ride.direction,
                    rideStops: ride.stops,
                    userLocation: locationManager.userLocation,
                    isTripActive: isRouting,
                    onStart: {
                        isRouting = true
                    },
                    onEnd: {
                        isRouting = false
                        showTripPreview = false
                        dismiss() // Returns to LandmarkDetailView
                    },
                    onDismiss: {
                        showTripPreview = false
                        dismiss()
                    }
                )
                .presentationDetents([.height(560), .large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(isRouting) // Disables pull-down dismissal while navigating
            }
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
            case .poiDetail(let poi):
                LandmarkPOIDetailView(poi: poi)
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
    
    /// Points the map at whichever line now serves the trip. `init` had to pick without a GPS
    /// fix, so the first fix usually changes the answer — a rider in Kuta opening Sanur Beach
    /// starts out looking at the Sanur shuttle (nearest to the place) and gets moved onto the
    /// K-corridor that actually picks them up. Left alone once the rider has chosen lines
    /// themselves.
    private func syncVisibilityToServingRide() {
        guard destinationPlace != nil, !hasManualCorridorSelection, let servingRide else { return }
        visibleCorridorIDs = [servingRide.corridor.id]
        visibleDirectionIDs = [servingRide.direction.id]
    }
    
    /// Fetches the road shape of every direction currently shown, and only those — a corridor
    /// being on no longer drags in the leg running the other way, which for a place's trip is
    /// half the directions requests saved.
    ///
    /// In-flight work is tracked per direction rather than per corridor because this runs both
    /// on appear and on every visibility change, so two passes can overlap; without it they'd
    /// both fetch the same line.
    @MainActor
    private func loadVisiblePolylines() async {
        for corridor in corridors {
            for direction in corridor.directions where visibleDirectionIDs.contains(direction.id) {
                if Task.isCancelled { return }
                guard polylines[direction.id.uuidString] == nil,
                      !loadingDirectionIDs.contains(direction.id) else { continue }
                
                loadingDirectionIDs.insert(direction.id)
                loadingCorridorIDs.insert(corridor.id)
                // Per-segment caching lives inside RoutePolylineBuilder's router — a direction
                // whose segments are all already cached resolves here with no network calls.
                let result = await RoutePolylineBuilder.polyline(for: direction)
                polylines[direction.id.uuidString] = result.coordinates
                loadingDirectionIDs.remove(direction.id)
                if loadingDirectionIDs.isDisjoint(with: corridor.directions.map(\.id)) {
                    loadingCorridorIDs.remove(corridor.id)
                }
            }
        }
    }
    
    // MARK: - Navigation engine
    
    /// Single pass over everything that depends on the rider's position. Driven by new
    /// fixes and by a one-second heartbeat so heading-only changes still land. A no-op in
    /// browse-only mode — there's no destination for any of this to track.
    private func refreshNavigationState() {
        guard destinationPlace != nil else { return }
        updateRouteProgress()
        updateLandmarkProximity()
        
        guard isRouting else { return }
        updateStepProgress()
        updateCheckpointProgress()
        updateTransitProgress()
        fetchWalkingConnectorIfNeeded()
        pushLiveActivityUpdate()
    }
    
    /// A no-op in browse-only mode (no `destinationPlace`) — every call site below fires
    /// unconditionally on appear/fix/toggle, so this one guard covers all of them.
    private func calculateRoute() {
        guard let destination = navigationDestination else { return }
        routeTask?.cancel()
        let userLocation = locationManager.userLocation
        // Resolved before the await so the anchor stop and the stop queue are drawn from
        // the same list, even if a fix lands while directions are in flight.
        let ride = servingRide
        let stops = servingBusStops
        
        // Routing can pick a direction the rider has manually toggled off — reveal that one
        // direction (not its corridor's other legs, which the trip doesn't ride) and fetch its
        // polyline, so the ride has a real line to follow instead of silently falling back to
        // a direct MapKit leg.
        if let ride, !visibleDirectionIDs.contains(ride.direction.id) {
            visibleCorridorIDs.insert(ride.corridor.id)
            visibleDirectionIDs.insert(ride.direction.id)
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
            checkpoints = buildCheckpoints(for: result.route, destination: destination)
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
    /// the first landmark declared is regularly not the first one you pass. `destination` is
    /// passed in already resolved by the caller (`calculateRoute`), which is the only place
    /// this runs and has already confirmed it's non-nil.
    private func buildCheckpoints(for route: MapRoute, destination: CLLocationCoordinate2D) -> [RouteCheckpoint] {
        let path = route.combinedWaypoints
        guard !path.isEmpty, let navigationLandmark else { return [] }
        
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
            coordinate: destination,
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
    /// Tells the map the rider is choosing lines now, so it stops choosing for them.
    let onManualChange: () -> Void
    
    private let lightCorridorIDs: Set<String> = ["K5", "K6", "SHUTTLE_SANUR"]
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(corridors) { corridor in
                    let isOn = visibleCorridorIDs.contains(corridor.id)
                    let isLoading = isOn && loadingCorridorIDs.contains(corridor.id)
                    Button {
                        onManualChange()
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
    /// See `CorridorToggleRow.onManualChange`.
    let onManualChange: () -> Void
    
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
                        onManualChange()
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

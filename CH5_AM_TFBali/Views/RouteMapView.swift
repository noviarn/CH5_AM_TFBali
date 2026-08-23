import SwiftUI
import MapKit
import SwiftData

private enum ActiveSheet: Identifiable {
    case videoPreview(url: URL, landmarkName: String)
    case landmarkDetail(index: Int)
    case poiDetail(LandmarkPOI)

    var id: String {
        switch self {
        case .videoPreview(let url, _): "video-\(url.path)"
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
    /// Looked up by name to turn a picked `LandmarkPOI` into the `Place` a trip needs — every
    /// POI is seeded into this store under its own name (see `MainPageView.seedLandmarkPlacesIfNeeded`).
    @Query private var places: [Place]

    let destinationPlace: Place?
    /// A still-active session found on launch (its `endedAt` never got set — the app was
    /// killed mid-trip) — resuming reattaches to it instead of starting a fresh one, so a
    /// force-quit doesn't lose trip progress or let the rider back out of an in-progress trip.
    let resumeSession: NavigationSession?
    /// True when opened directly via a place's "Explore" button — shows the trip sheet
    /// immediately with no back button, just the sheet's own close button. False when
    /// opened from the general "Explore Bali by Bus" entry point — shows corridor
    /// browsing controls (filter/search) and a back button instead.
    let isDirectToPlace: Bool

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
    @State private var showFilterSheet = false
    /// Set when a landmark is picked from search, so the map zooms to it instead of the
    /// wider browse view. `nil` in every other case, letting `navigationDestination` win.
    @State private var searchFocusCoordinate: CLLocationCoordinate2D?
    /// Non-nil pushes a new `RouteMapView` navigating to that place — see `navigate(to:)`.
    @State private var navigateToPlace: Place?
    /// Landmark categories currently switched off. Empty by default — landmarks show all,
    /// unlike corridors which start with none visible.
    @State private var hiddenLandmarkCategories: Set<String> = []

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
    /// Corridor POIs the calculated route goes past. Worked out once per route calculation
    /// rather than per render — it scans every POI against the whole drawn path, which is far
    /// too much to redo on each of the ~1 Hz navigation ticks.
    @State private var passedLandmarkPOIs: [LandmarkPOI] = []
    /// Landmarks already marked on this trip, held by storage key rather than by index — the
    /// markable set is derived from the route, so indices are not stable across a recalculation.
    @State private var capturedLandmarkKeys: Set<String> = []
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

    /// Ranked trip options from `RoutePlanner`, best first. Held as a list rather than a
    /// single winner so a picker can be added later without reworking the planning path.
    @State private var plannedRoutes: [TripRoute] = []
    /// Which of `plannedRoutes` the trip follows. `nil` means "the best one" — the only
    /// behaviour today, since nothing sets this yet.
    @State private var selectedRouteID: UUID?
    @State private var planTask: Task<Void, Never>?


    private let checkpointArrivalThreshold: CLLocationDistance = 50
    private let activityPushInterval: TimeInterval = 1
    private let firstFixTimeout: Duration = .seconds(8)

    @State private var showTripPreview = false
    @State private var hasShownTripPreview = false
    @State private var tripSheetDetent: PresentationDetent = .medium

    init(destinationPlace: Place? = nil, resumeSession: NavigationSession? = nil, isDirectToPlace: Bool = false) {
        self.destinationPlace = destinationPlace
        self.resumeSession = resumeSession
        self.isDirectToPlace = isDirectToPlace
        guard let destinationPlace else {
            // Browse-only entry starts with every corridor off — the rider picks what they
            // want to see via the filter sheet rather than being handed K1 by default.
            _visibleCorridorIDs = State(initialValue: [])
            _visibleDirectionIDs = State(initialValue: [])
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

    /// The distinct category labels landmark POIs group under (Temple/Beach/Market/Statue/Park),
    /// derived from the data rather than hardcoded since new categories may be added.
    private var landmarkCategories: [String] {
        Array(Set(landmarkPOIs.map(Self.primaryCategory))).sorted()
    }

    /// A POI the trip passes is already drawn by the landmark layer, which is the pin that
    /// opens its markings — drawing the browse pin too would stack two annotations on one
    /// coordinate and make the lower one untappable.
    private var visibleLandmarkPOIs: [LandmarkPOI] {
        let markable = Set(passedLandmarkPOIs.map(\.name))
        return landmarkPOIs.filter {
            !hiddenLandmarkCategories.contains(Self.primaryCategory($0)) && !markable.contains($0.name)
        }
    }

    private static func primaryCategory(_ poi: LandmarkPOI) -> String {
        poi.category.split(separator: "/").first.map(String.init) ?? poi.category
    }

    /// The corridor POIs a calculated route goes past, in declaration order — the landmarks
    /// the rider can actually mark on this trip.
    private static func poisPassed(by route: MapRoute) -> [LandmarkPOI] {
        let path = route.combinedWaypoints
        guard path.count >= 2 else { return [] }
        return landmarkPOIs.filter { LandmarkProximityDetector.routePasses($0.coordinate, along: path) }
    }

    /// Starts a trip to a landmark picked from search or a map pin — pushes a fresh
    /// `RouteMapView` the same way a place's own "Explore" button does.
    private func navigate(to poi: LandmarkPOI) {
        guard let place = places.first(where: { $0.name == poi.name }) else { return }
        activeSheet = nil
        navigateToPlace = place
    }

    /// Starts a trip to a place found through general search — not one of the curated
    /// landmarks, so there's no seeded `Place` to look up. Built fresh and never inserted
    /// into `modelContext`: it exists only for this one navigation, not as a discoverable
    /// place in the app, so it can't show up in the discovery tab from a one-off search.
    private func navigate(toMapItem item: MKMapItem) {
        let coordinate = item.placemark.coordinate
        let place = Place(
            name: item.name ?? "Selected Location",
            desc: item.placemark.title ?? "Searched location",
            image: "placeholder-default",
            category: Category(name: "Other", image: "placeholder-default"),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        activeSheet = nil
        navigateToPlace = place
    }

    /// One markable point on this trip.
    private struct TripLandmark {
        let coordinate: CLLocationCoordinate2D
        let info: LandmarkInfo
        /// Where this landmark's recordings are filed. A POI carries its own key on every trip
        /// that passes it, so its markings accumulate in one place instead of being split by
        /// whichever destination the rider happened to be heading for that day.
        let storageKey: String
    }

    /// The destination, plus every corridor POI the route actually goes past.
    ///
    /// It used to be the destination alone, which meant the camera could not unlock until the
    /// rider was within 100 m of the end of the trip — on a real bus, never mid-route, which
    /// is the entire point of marking a landmark. The destination stays at index 0 so
    /// recordings already filed against it keep resolving.
    private func tripLandmarks(passing pois: [LandmarkPOI]) -> [TripLandmark] {
        guard let destinationPlace, let navigationDestination else { return [] }

        let destination = TripLandmark(
            coordinate: navigationDestination,
            info: LandmarkInfo(
                title: destinationPlace.name,
                category: destinationPlace.category.name,
                summary: destinationPlace.desc,
                icon: "mappin.circle.fill"
            ),
            storageKey: destinationPlace.name
        )

        return [destination] + pois.map { poi in
            TripLandmark(
                coordinate: poi.coordinate,
                info: LandmarkInfo(
                    title: poi.name,
                    category: poi.category,
                    summary: poi.summary,
                    icon: poi.icon
                ),
                storageKey: poi.name
            )
        }
    }

    private var tripLandmarks: [TripLandmark] { tripLandmarks(passing: passedLandmarkPOIs) }

    /// A single landmark at the place being explored, `nil` in browse-only mode.
    private var navigationLandmark: Landmark? {
        guard let destinationPlace else { return nil }
        let landmarks = tripLandmarks
        guard !landmarks.isEmpty else { return nil }
        return Landmark(name: destinationPlace.name, coordinates: landmarks.map(\.coordinate))
    }

    private var navigationLandmarkInfo: [LandmarkInfo] {
        tripLandmarks.map(\.info)
    }

    /// Disambiguates `LandmarkVideo` storage across landmarks — see the note on
    /// `LandmarkVideo.placeKey`.
    private func placeKey(forLandmarkIndex index: Int) -> String? {
        let landmarks = tripLandmarks
        guard landmarks.indices.contains(index) else { return destinationPlace?.name }
        return landmarks[index].storageKey
    }
    
    private var locationKey: CoordinateKey? {
        locationManager.userLocation.map { CoordinateKey($0) }
    }
    
    /// The trip the rider is being sent on, whichever of `plannedRoutes` is picked. Only the
    /// top-ranked one is used today; the list is kept whole so a route picker can be added by
    /// setting `selectedRouteID`, without touching any of the planning or drawing below.
    private var selectedTripRoute: TripRoute? {
        guard let selectedRouteID, let match = plannedRoutes.first(where: { $0.id == selectedRouteID }) else {
            return plannedRoutes.first
        }
        return match
    }

    /// The planned trip resolved into drawable legs — one per bus ridden, each carrying only
    /// the stretch actually ridden plus that corridor's road shape (empty until fetched).
    ///
    /// Deliberately independent of `visibleDirectionIDs`: a rider can toggle a line off for
    /// display, and that must not be able to change where the trip goes.
    private var servingLegs: [PlannedLeg] {
        guard let route = selectedTripRoute else { return previewLegs }
        let legs = route.legs.compactMap { leg -> PlannedLeg? in
            guard let corridor = corridors.first(where: { $0.id == leg.corridorID }),
                  let direction = corridor.directions.first(where: { $0.id == leg.directionID }),
                  let boardIndex = direction.stops.firstIndex(where: { $0.id == leg.boardStop.id }),
                  let alightIndex = direction.stops.firstIndex(where: { $0.id == leg.alightStop.id }),
                  boardIndex <= alightIndex
            else { return nil }
            // Only the ridden stretch. Handing over the whole line would pad the next-stop
            // queue with stops this trip never reaches.
            return PlannedLeg(
                corridor: corridor,
                direction: direction,
                stops: Array(direction.stops[boardIndex...alightIndex]),
                polyline: polylines[direction.id.uuidString] ?? []
            )
        }
        return legs.isEmpty ? previewLegs : legs
    }

    /// What the map shows before there's anywhere to plan *from* — no GPS fix yet, or the
    /// planner found nothing. Falls back to whichever single line passes nearest the place,
    /// so the screen isn't blank while the first fix lands. Replaced by the real plan the
    /// moment `plannedRoutes` fills in.
    private var previewLegs: [PlannedLeg] {
        guard let navigationDestination,
              let best = Self.bestDirectionTowardDestination(to: navigationDestination, from: nil)
        else { return [] }
        return [PlannedLeg(
            corridor: best.corridor,
            direction: best.direction,
            stops: Array(best.direction.stops[best.boardIndex...best.alightIndex]),
            polyline: polylines[best.direction.id.uuidString] ?? []
        )]
    }

    private var servingBusStops: [BusStop] {
        let stops = servingLegs.flatMap(\.stops)
        if !stops.isEmpty { return stops }
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
    /// directions being ridden — every leg of it, and nothing else: anything toggled on for
    /// browsing isn't part of this trip and only competes with the lines the rider is meant
    /// to follow. Before that it's whatever's toggled on, which for a place already defaults
    /// to just the serving lines.
    private var drawnDirectionIDs: Set<UUID> {
        if isRouting {
            let ridden = Set(servingLegs.map(\.direction.id))
            if !ridden.isEmpty { return ridden }
        }
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
                centerCoordinate: navigationDestination ?? searchFocusCoordinate,
                route: calculatedRoute,
                routeProgress: routeProgress,
                directions: directions,
                landmark: navigationLandmark,
                busStops: [],
                servingStopIDs: Set(servingBusStops.map(\.id)),
                nextStopID: nextStopVisit?.stop.id,
                walkingConnector: activeWalkingConnector?.coordinates ?? [],
                corridorOverlays: visibleCorridorOverlays,
                landmarkPOIs: visibleLandmarkPOIs,
                destinationPin: destinationPlace,
                focusSpan: navigationDestination != nil
                    ? MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                    : MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01),
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
                if isDirectToPlace, let destinationPlace {
                    OriginDestinationHeader(destinationName: destinationPlace.name)
                        .padding(.horizontal, 25)
                        .navigationBarBackButtonHidden(true)
                        .toolbar(.hidden, for: .navigationBar)
                }

                Spacer()

                if !isRouting && !isDirectToPlace {
                    HStack {
                        MapFilterButton {
                            showFilterSheet = true
                        }
                        Spacer()
                        MapSearchButton(
                            onSelectLandmark: { poi in
                                searchFocusCoordinate = poi.coordinate
                            },
                            onSelectMapItem: { item in
                                navigate(toMapItem: item)
                            }
                        )
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }

                // Nothing to route to without a destination — browse-only mode stops here.
//                if destinationPlace != nil {
//                    RoutingControl(isRouting: $isRouting, routeName: routeName)
//                }
            }
        }
        // Sits above the presenting view, not inside the sheet — a `.sheet` renders above
        // whatever presented it, so this is only visible while the sheet is at its minimized
        // `.height(80)` detent; an expanded sheet covers this corner same as it would cover
        // any other content back here. Bottom padding clears that minimized bar with a gap.
        .overlay(alignment: .bottomTrailing) {
            if isRouting && !isFollowingUser {
                RecenterButton {
                    isFollowingUser = true
                    // Recentring wants the map, not the sheet — get out of the way.
                    withAnimation { tripSheetDetent = .height(80) }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 96)
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            MapFilterSheet(
                visibleCorridorIDs: $visibleCorridorIDs,
                visibleDirectionIDs: $visibleDirectionIDs,
                loadingCorridorIDs: loadingCorridorIDs,
                hiddenLandmarkCategories: $hiddenLandmarkCategories,
                landmarkCategories: landmarkCategories,
                polylines: polylines,
                onManualCorridorChange: { hasManualCorridorSelection = true }
            )
            .presentationDetents([.medium, .large])
        }
        .task {
            await loadVisiblePolylines()
        }
        .onChange(of: visibleDirectionIDs) { _, _ in
            Task { await loadVisiblePolylines() }
        }
        .onChange(of: servingLegs.map(\.direction.id)) { _, _ in
            syncVisibilityToServingRide()
        }
        .onAppear {
            hasShownTripPreview = false
            if !servingLegs.isEmpty, destinationPlace != nil {
                hasShownTripPreview = true
                showTripPreview = true
            }
        }
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
        .sheet(isPresented: $showTripPreview) {
            if let destinationPlace, !servingLegs.isEmpty {
                TripPreviewSheet(
                    place: destinationPlace,
                    legs: servingLegs,
                    userLocation: locationManager.userLocation,
                    nextStopName: nextStopVisit?.stop.name,
                    stopsRemaining: transitVisits.isEmpty ? nil : (transitVisits.count - currentStopVisitIndex),
                    minutesRemaining: estimatedMinutesRemaining,
                    isTripActive: isRouting,
                    nearbyLandmark: nearbyLandmark,
                    currentDetent: $tripSheetDetent,
                    onStart: {
                        isRouting = true
                    },
                    onEnd: {
                        isRouting = false
                        showTripPreview = false
                        dismiss()
                    },
                    onDismiss: {
                        showTripPreview = false
                        dismiss()
                    },
                    onCapture: { tempURL in
                        pendingLandmark = nearbyLandmark
                        handleCapturedVideo(tempURL)
                    }
                )
                .presentationDetents([.height(80), .medium, .large], selection: $tripSheetDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .presentationBackgroundInteraction(.enabled)
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .videoPreview(let url, let landmarkName):
                VideoPreviewView(url: url, landmarkName: landmarkName)
            case .landmarkDetail(let index):
                landmarkDetailSheet(for: index)
            case .poiDetail(let poi):
                // Nil mid-trip — starting a second trip on top of an active one would leave
                // the first still running (live activity, session) with no way back to it.
                LandmarkPOIDetailView(poi: poi, onNavigate: isRouting ? nil : { navigate(to: poi) })
            }
        }
        .navigationDestination(item: $navigateToPlace) { place in
            RouteMapView(destinationPlace: place, isDirectToPlace: true)
        }
        .lockBackNavigation(isRouting)
        .onAppear {
            locationManager.requestLocation()
            // Reattach to a trip that was still running when the app got killed, rather than
            // dropping the rider back on this place's "start trip" screen — `startNavigationSession`
            // no-ops once `activeSession` is already set, so this doesn't create a duplicate row.
            if let resumeSession, activeSession == nil {
                activeSession = resumeSession
                currentCheckpointIndex = resumeSession.checkpointsReached
                currentStepIndex = min(resumeSession.completedSteps, max(resumeSession.totalSteps - 1, 0))
                isRouting = true
            }
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
            // Planning needs an origin, so this is the first moment a real trip (including
            // any bus changes) can be worked out; it calls `calculateRoute` once it lands.
            planTrip()
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
            planTask?.cancel()
            routeTask?.cancel()
            walkingConnectorTask?.cancel()
        }
    }
    
    /// Deliberately thinner than the active navigation route (`MapViewContainer`'s blue
    /// line, 6pt) — these are background browsing chrome, not the line the rider is meant
    /// to follow, and shouldn't compete with it for attention.
    private func strokeStyle(for corridor: Corridor, legIndex: Int) -> StrokeStyle {
        if corridor.id == "SHUTTLE_SANUR" {
            return StrokeStyle(lineWidth: 2, dash: [1, 5])
        }
        switch legIndex {
        case 0: return StrokeStyle(lineWidth: 3)
        case 1: return StrokeStyle(lineWidth: 3, dash: [8, 6])
        default: return StrokeStyle(lineWidth: 3, dash: [2, 4])
        }
    }
    
    /// Points the map at whichever lines now serve the trip — every leg of it, so a trip with
    /// a change shows both buses rather than half the journey. `init` had to pick without a
    /// GPS fix, so the first fix usually changes the answer: a rider in Kuta opening Arjuna
    /// Statue starts out looking at K4 alone (the only line reaching Ubud) and gets moved onto
    /// K5-then-K4, the pair they can actually board. Left alone once the rider has chosen
    /// lines themselves.
    private func syncVisibilityToServingRide() {
        guard destinationPlace != nil, !hasManualCorridorSelection else { return }
        let legs = servingLegs
        guard !legs.isEmpty else { return }
        visibleCorridorIDs = Set(legs.map(\.corridor.id))
        visibleDirectionIDs = Set(legs.map(\.direction.id))
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
    
    /// Works out which buses to take, across the whole network — including changing lines.
    ///
    /// The old picker only ever considered a single corridor, so a place served by one line
    /// far from the rider produced "walk 10 km to the first stop" rather than "ride out on a
    /// line you can reach, then change." `RoutePlanner` searches direct, one-change and
    /// two-change trips and ranks them; this just takes the winner.
    ///
    /// Runs off the main actor: ~0.4 s of pure geometry, nearly all of it the two-change tier
    /// of the search (measured: 2 ms direct, 23 ms with one change, 347 ms with two). That
    /// would visibly stall the map if it ran during a view update.
    private func planTrip() {
        guard let destination = navigationDestination else { return }
        // Frozen to where the rider stood at departure once under way, so the plan can't
        // change out from under them as they ride past other lines' stops.
        let origin = isRouting ? (sessionStartLocation ?? locationManager.userLocation) : locationManager.userLocation
        guard let origin else { return }

        planTask?.cancel()
        planTask = Task {
            let routes = await Task.detached(priority: .userInitiated) {
                let originCandidates = NearestStopFinder.rankedByStraightLine(
                    candidates: NearestStopFinder.nearestByStraightLine(to: origin),
                    to: origin
                )
                let destinationCandidates = NearestStopFinder.rankedByStraightLine(
                    candidates: NearestStopFinder.nearestByStraightLine(to: destination),
                    to: destination
                )
                return RoutePlanner.findRoutes(
                    originCandidates: originCandidates,
                    destinationCandidates: destinationCandidates,
                    transferIndex: .standard
                )
            }.value
            guard !Task.isCancelled else { return }

            plannedRoutes = routes
            selectedRouteID = routes.first?.id
            calculateRoute()
        }
    }

    /// A no-op in browse-only mode (no `destinationPlace`) — every call site below fires
    /// unconditionally on appear/fix/toggle, so this one guard covers all of them.
    private func calculateRoute() {
        guard let destination = navigationDestination else { return }
        routeTask?.cancel()
        let userLocation = locationManager.userLocation
        // Resolved before the await so the drawn line and the stop queue are built from the
        // same legs, even if a fix lands while directions are in flight.
        let legs = servingLegs

        // Routing can pick lines the rider has manually toggled off — reveal exactly the
        // directions this trip rides (not their corridors' other legs, which it doesn't), so
        // the ride has real lines to follow instead of silently falling back to straight ones.
        for leg in legs where !visibleDirectionIDs.contains(leg.direction.id) {
            visibleCorridorIDs.insert(leg.corridor.id)
            visibleDirectionIDs.insert(leg.direction.id)
        }

        routeTask = Task {
            var resolvedLegs = legs
            for index in resolvedLegs.indices where resolvedLegs[index].polyline.isEmpty {
                let direction = resolvedLegs[index].direction
                let fetched = await RoutePolylineBuilder.polyline(for: direction)
                guard !Task.isCancelled else { return }
                resolvedLegs[index].polyline = fetched.coordinates
                polylines[direction.id.uuidString] = fetched.coordinates
            }

            let result = await RouteCalculator.shared.calculateRoute(
                destination: destination,
                userLocation: userLocation,
                legs: resolvedLegs
            )
            guard !Task.isCancelled else { return }

            calculatedRoute = result.route
            directions = result.steps
            // Passed straight to `buildCheckpoints` as well as being stored, so the checkpoint
            // list is built from exactly the landmark set the rest of the trip will see.
            let passedPOIs = Self.poisPassed(by: result.route)
            passedLandmarkPOIs = passedPOIs
            checkpoints = buildCheckpoints(for: result.route, destination: destination, passing: passedPOIs)
            transitVisits = TransitPlanner.stopVisits(for: resolvedLegs, along: result.route.combinedWaypoints)
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
    private func buildCheckpoints(
        for route: MapRoute,
        destination: CLLocationCoordinate2D,
        passing pois: [LandmarkPOI]
    ) -> [RouteCheckpoint] {
        let path = route.combinedWaypoints
        let landmarks = tripLandmarks(passing: pois)
        guard !path.isEmpty, !landmarks.isEmpty else { return [] }

        let landmarkCheckpoints = landmarks
            .enumerated()
            .map { index, landmark in
                RouteCheckpoint(
                    coordinate: landmark.coordinate,
                    name: landmark.info.title,
                    kind: .landmark,
                    pathIndex: RouteGeometry.nearestIndex(to: landmark.coordinate, along: path),
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
        // Resolved fresh each time rather than stored as indices: a route recalculated
        // mid-trip can change which POIs it passes, and a stale index would then suppress
        // whichever landmark happened to inherit that slot.
        let capturedIndices = tripLandmarks.enumerated().compactMap { index, landmark in
            capturedLandmarkKeys.contains(landmark.storageKey) ? index : nil
        }

        let previous = nearbyLandmark
        nearbyLandmark = LandmarkProximityDetector.nearestLandmark(
            userLocation: locationManager.userLocation,
            landmark: navigationLandmark,
            heading: routeHeading,
            active: nearbyLandmark,
            excluding: Set(capturedIndices),
            names: navigationLandmarkInfo.map(\.title)
        )

        // Buzz once as a landmark comes into range, so the camera button is noticed without
        // the rider watching the screen. Keyed on the landmark changing rather than on there
        // being one, since this runs every second for as long as it stays in range. Silent
        // outside an active trip — that's the only place the camera button exists to point at.
        if isRouting, let current = nearbyLandmark, current.index != previous?.index {
            Haptics.attention()
        }
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
        let card = activityCard

        Task {
            await RoutingActivityManager.shared.updateActivity(
                currentStep: step,
                distanceToCurrentStep: distance,
                nextStep: next,
                nearbyLandmark: landmark,
                nextStopName: stopName,
                transferSummary: transferSummary,
                phase: card?.phase ?? .walking,
                placeName: card?.placeName ?? (destinationPlace?.name ?? routeName),
                minutesRemaining: card?.minutes ?? 0,
                metersRemaining: card?.meters ?? 0,
                stopsRemaining: card?.stops
            )
        }
    }

    /// The stops still to ride on the bus the rider is currently on, ending at the one they
    /// get off at. Empty whenever they're on foot.
    ///
    /// A leg is a run of consecutive visits sharing one corridor — the first visit whose
    /// corridor differs is the next bus, not this one.
    private var remainingVisitsOnThisBus: [TransitStopVisit] {
        guard transitVisits.indices.contains(currentStopVisitIndex) else { return [] }
        let corridorID = transitVisits[currentStopVisitIndex].corridorID
        return Array(transitVisits[currentStopVisitIndex...].prefix { $0.corridorID == corridorID })
    }

    /// Everything the Live Activity card needs: which of the five states the rider is in,
    /// the one name that state is about, and what's left to run.
    ///
    /// The design's two bus-waiting states ("Waiting for K5B", "K5B has arrived") are absent
    /// on purpose — see `ContentState.Phase`.
    private var activityCard: (
        phase: RoutingActivityAttributes.ContentState.Phase,
        placeName: String,
        meters: CLLocationDistance,
        minutes: Int,
        stops: Int?
    )? {
        guard let route = calculatedRoute, routeProgress != nil else { return nil }
        let destinationName = destinationPlace?.name ?? "your destination"

        // Everything cleared means the destination checkpoint is behind them too.
        if currentCheckpointIndex >= checkpoints.count, !checkpoints.isEmpty {
            return (.arrived, destinationName, 0, 0, nil)
        }

        // A landmark alongside outranks the rest: it's the one thing that's only true for a
        // moment, and the only one the rider has to act on before it's behind them.
        if let landmark = nearbyLandmark {
            return (.landmark, landmark.name, landmark.distance, 0, nil)
        }

        // On foot before boarding the first bus, across a walking transfer, and on the last
        // stretch after the final stop.
        var isWalking = currentStopVisitIndex == 0 || nextStopVisit == nil
        if let kind = currentTransitLeg?.kind, case .walkingTransfer = kind { isWalking = true }

        if isWalking {
            // No stop left to reach means this is the final walk, which the island names
            // differently from a walk to a stop.
            guard let visit = nextStopVisit else {
                return finalWalk(to: destinationName, along: route)
            }
            let meters = metersRemaining(to: visit.pathIndex)
            return (.walking, visit.stop.name, meters, minutes(forWalking: true, meters: meters), nil)
        }

        // On the bus: the card counts down to the stop the rider gets off at, not the next
        // one out the window — that's the only one they have to act on.
        let ride = remainingVisitsOnThisBus
        guard let alight = ride.last else {
            return finalWalk(to: destinationName, along: route)
        }

        let meters = metersRemaining(to: alight.pathIndex)
        let stops = ride.count
        // Their stop is the next one — time to get to the door.
        let phase: RoutingActivityAttributes.ContentState.Phase = stops <= 1 ? .gettingOff : .riding
        return (phase, alight.stop.name, meters, minutes(forWalking: false, meters: meters), stops)
    }

    private func finalWalk(to destinationName: String, along route: MapRoute) -> (
        phase: RoutingActivityAttributes.ContentState.Phase,
        placeName: String,
        meters: CLLocationDistance,
        minutes: Int,
        stops: Int?
    ) {
        let meters = metersRemaining(to: route.combinedWaypoints.count - 1)
        return (.walkingToDestination, destinationName, meters, minutes(forWalking: true, meters: meters), nil)
    }

    /// Same timing model the planner and the preview sheet use, so the card can't contradict
    /// the numbers the rider was shown before they set off.
    private func minutes(forWalking isWalking: Bool, meters: CLLocationDistance) -> Int {
        let seconds = isWalking
            ? TripTiming.walk(meters: meters)
            : TripTiming.ride(meters: meters, stops: 0, departingAt: .now)
        return Int((seconds / 60).rounded())
    }

    /// How far along the route the rider still has to travel to reach `pathIndex`.
    private func metersRemaining(to pathIndex: Int) -> CLLocationDistance {
        guard let route = calculatedRoute, let progress = routeProgress else { return 0 }
        let ahead = RouteGeometry.remaining(
            route.combinedWaypoints,
            fromSegment: progress.index,
            projected: progress.projected
        )
        // `ahead` starts at the rider's projected position, so a path index maps onto it by
        // subtracting the segment they're standing on.
        let offset = pathIndex - progress.index
        guard offset >= 1 else { return 0 }
        return RouteGeometry.length(of: Array(ahead.prefix(offset + 1)))
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
        capturedLandmarkKeys.insert(placeKey(forLandmarkIndex: landmark.index) ?? landmarkName)
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
            placeKey: placeKey(forLandmarkIndex: landmarkIndex),
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
            placeKey: placeKey(forLandmarkIndex: index),
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
            .appendingPathComponent(
                LandmarkVideo.storageFolder(landmarkIndex: index, placeKey: placeKey(forLandmarkIndex: index)),
                isDirectory: true
            )
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
        // Resuming a trip that's already active (see `onAppear`) sets `activeSession` before
        // this runs — skip re-creating it, since `isRouting`'s onChange calls this unconditionally.
        guard activeSession == nil else { return }

        currentStepIndex = 0
        currentCheckpointIndex = 0
        currentStopVisitIndex = 0
        activeWalkingConnector = nil
        nearbyLandmark = nil
        capturedLandmarkKeys = []
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
    
    private var estimatedMinutesRemaining: Double? {
        guard let route = calculatedRoute, let progress = routeProgress else { return nil }
        let path = route.combinedWaypoints
        let remaining = RouteGeometry.remaining(path, fromSegment: progress.index, projected: progress.projected)
        guard remaining.count > 1 else { return 0 }

        let averageSpeedKmh = 20.0 // rough bus+walk blended estimate
        return (RouteGeometry.length(of: remaining) / 1000 / averageSpeedKmh) * 60
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

private struct MapFilterButton: View {
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .padding(14)
                .background(.blue, in: Circle())
                .shadow(radius: 4)
        }
    }
}

private struct MapFilterSheet: View {
    @Binding var visibleCorridorIDs: Set<String>
    @Binding var visibleDirectionIDs: Set<UUID>
    let loadingCorridorIDs: Set<String>
    @Binding var hiddenLandmarkCategories: Set<String>
    let landmarkCategories: [String]
    let polylines: [String: [CLLocationCoordinate2D]]
    let onManualCorridorChange: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Bus Corridors") {
                    CorridorToggleRow(
                        visibleCorridorIDs: $visibleCorridorIDs,
                        visibleDirectionIDs: $visibleDirectionIDs,
                        loadingCorridorIDs: loadingCorridorIDs,
                        onManualChange: onManualCorridorChange
                    )
                    .listRowInsets(EdgeInsets())
                    ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                        DirectionToggleRow(
                            corridor: corridor,
                            visibleDirectionIDs: $visibleDirectionIDs,
                            polylines: polylines,
                            isCorridorLoading: loadingCorridorIDs.contains(corridor.id),
                            onManualChange: onManualCorridorChange
                        )
                        .listRowInsets(EdgeInsets())
                    }
                }

                Section("Landmarks") {
                    LandmarkCategoryToggleRow(
                        categories: landmarkCategories,
                        hiddenCategories: $hiddenLandmarkCategories
                    )
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Filter Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        Haptics.tap()
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct LandmarkCategoryToggleRow: View {
    let categories: [String]
    @Binding var hiddenCategories: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    let isOn = !hiddenCategories.contains(category)
                    Button {
                        Haptics.toggle()
                        if isOn {
                            hiddenCategories.insert(category)
                        } else {
                            hiddenCategories.remove(category)
                        }
                    } label: {
                        Text(category)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? Color.blue : Color.gray.opacity(0.25))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
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
                        Haptics.toggle()
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
                            Image(systemName: "bus")
                                .font(.caption)
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
        "Leg \(legIndex + 1)"
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
                        Haptics.toggle()
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

//
//  ContentView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI
import MapKit
import Combine
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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    private let routeName = "Kuta Route"

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

    private var locationKey: CoordinateKey? {
        locationManager.userLocation.map { CoordinateKey($0) }
    }

    /// Which way the trip goes overall, used to tell the stops serving this direction from
    /// the ones across the road serving the return. Straight-line rather than road-following
    /// on purpose: it only has to be right to within the 90° window `BusStop.serves` allows.
    ///
    /// Measured from where the rider set off once under way — a trip's direction is decided
    /// at departure. Reading it from the live position instead would leave it degenerating
    /// into noise over the last few metres, flipping the whole stop set on arrival.
    private var travelBearing: CLLocationDirection? {
        let origin = isRouting
            ? (sessionStartLocation ?? locationManager.userLocation)
            : locationManager.userLocation
        return origin?.bearing(to: MapConstants.pointB)
    }

    /// The stops this trip can actually use. Everything downstream — the anchor the route
    /// starts from, the next-stop queue, the transfer legs — reads from this rather than the
    /// full stop list, so none of them ever offer a stop going the wrong way.
    private var servingBusStops: [BusStop] {
        MapConstants.busStops(serving: travelBearing)
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

    var body: some View {
        MainPageView()
        ZStack {
            MapViewContainer(
                locations: MapConstants.defaultLocations,
                userLocation: locationManager.userLocation,
                isNavigating: isRouting,
                navigationHeading: cameraHeading,
                route: calculatedRoute ?? MapConstants.previewRoute,
                routeProgress: routeProgress,
                directions: directions,
                landmark: MapConstants.landmark,
                busStops: MapConstants.busStops,
                servingStopIDs: Set(servingBusStops.map(\.id)),
                nextStopID: nextStopVisit?.stop.id,
                walkingConnector: activeWalkingConnector?.coordinates ?? [],
                isFollowingUser: $isFollowingUser,
                onSelectLandmark: { index in
                    activeSheet = .landmarkDetail(index: index)
                }
            )

            VStack(spacing: 0) {
                MapHeader(
                    onOpenHistory: { activeSheet = .sessionHistory },
                    onOpenLandmarks: { activeSheet = .landmarksGallery }
                )
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
        let stops = servingBusStops

        routeTask = Task {
            let result = await RouteCalculator.shared.calculateRoute(
                destination: MapConstants.pointB,
                userLocation: userLocation,
                busStops: stops
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
    /// point B. The calculated route is anchored to a bus stop, which can sit behind the
    /// rider when they were already on the corridor — recording it raw drew a line starting
    /// somewhere they never went. Trimming to their projected position and prepending their
    /// actual start makes the saved shape match the journey.
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
    /// landmark 1 is regularly not the first one you pass.
    private func buildCheckpoints(for route: MapRoute) -> [RouteCheckpoint] {
        let path = route.combinedWaypoints
        guard !path.isEmpty else { return [] }

        let landmarkCheckpoints = MapConstants.landmark.coordinates
            .enumerated()
            .map { index, coordinate in
                RouteCheckpoint(
                    coordinate: coordinate,
                    name: "Landmark \(index + 1)",
                    kind: .landmark,
                    pathIndex: RouteGeometry.nearestIndex(to: coordinate, along: path),
                    landmarkIndex: index
                )
            }
            .sorted { $0.pathIndex < $1.pathIndex }

        let finish = RouteCheckpoint(
            coordinate: MapConstants.pointB,
            name: "Destination",
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
            landmark: MapConstants.landmark,
            heading: routeHeading,
            active: nearbyLandmark,
            excluding: capturedLandmarkIndices
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
            landmarkName: "Landmark \(index + 1)",
            info: MapConstants.landmarkInfo.indices.contains(index) ? MapConstants.landmarkInfo[index] : nil,
            videosBaseDirectory: baseVideosDirectory
        )
    }

    private var baseVideosDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LandmarkVideos", isDirectory: true)
    }

    private func videosDirectory(forLandmarkIndex index: Int) -> URL? {
        baseVideosDirectory?
            .appendingPathComponent("landmark-\(index)", isDirectory: true)
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

#Preview {
    ContentView()
}

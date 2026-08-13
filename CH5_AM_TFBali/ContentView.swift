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

    var id: String {
        switch self {
        case .videoPreview(let url, _): "video-\(url.path)"
        case .sessionHistory: "history"
        case .landmarkDetail(let index): "landmark-\(index)"
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
    private let routeName = "Kuta Loop"

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
    @State private var tripSummary: TripSummary?
    @State private var activeSession: NavigationSession?
    @State private var currentCheckpointIndex = 0
    @State private var startStop: BusStop?
    @State private var lastActivityPush: Date = .distantPast
    @State private var isFollowingUser = true
    @State private var transitVisits: [TransitStopVisit] = []
    @State private var transitLegs: [TransitLeg] = []
    @State private var currentStopVisitIndex = 0
    @State private var activeWalkingConnector: WalkingConnector?
    @State private var walkingConnectorTask: Task<Void, Never>?

    private let checkpointArrivalThreshold: CLLocationDistance = 50
    private let activityPushInterval: TimeInterval = 1
    private let firstFixTimeout: Duration = .seconds(8)

    private var locationKey: CoordinateKey? {
        locationManager.userLocation.map { CoordinateKey($0) }
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
        ZStack {
            MapViewContainer(
                locations: MapConstants.defaultLocations,
                userLocation: locationManager.userLocation,
                isNavigating: isRouting,
                navigationHeading: cameraHeading,
                route: calculatedRoute ?? MapConstants.kutaLoop,
                routeProgress: routeProgress,
                directions: directions,
                landmark: MapConstants.landmark,
                busStops: MapConstants.busStops,
                nextStopID: nextStopVisit?.stop.id,
                walkingConnector: activeWalkingConnector?.coordinates ?? [],
                isFollowingUser: $isFollowingUser,
                onSelectLandmark: { index in
                    activeSheet = .landmarkDetail(index: index)
                }
            )

            VStack(spacing: 0) {
                MapHeader {
                    activeSheet = .sessionHistory
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
                NavigationSessionHistoryView(videosBaseDirectory: baseVideosDirectory)
            case .landmarkDetail(let index):
                landmarkDetailSheet(for: index)
            }
        }
        .fullScreenCover(item: $tripSummary) { summary in
            TripSummaryPlayerView(clips: summary.clips)
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
                let completedSession = endNavigationSession()
                Task {
                    await RoutingActivityManager.shared.endActivity()
                }
                presentTripSummaryIfAvailable(for: completedSession)
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

        routeTask = Task {
            let result = await RouteCalculator.shared.calculateRoute(
                waypoints: MapConstants.kutaLoop.waypoints,
                userLocation: userLocation,
                busStops: MapConstants.busStops
            )
            guard !Task.isCancelled else { return }

            calculatedRoute = result.route
            directions = result.steps
            startStop = result.startStop
            checkpoints = buildCheckpoints(for: result.route)
            transitVisits = TransitPlanner.stopVisits(for: MapConstants.busStops, along: result.route.combinedWaypoints)
            transitLegs = TransitPlanner.legs(for: transitVisits)
            currentStopVisitIndex = 0
            activeWalkingConnector = nil
            routeProgress = nil
            currentStepIndex = 0

            if let activeSession {
                activeSession.totalSteps = result.steps.count
                activeSession.totalCheckpoints = checkpoints.count
                activeSession.routeCoordinates = result.route.combinedWaypoints.map { RouteCoordinate($0) }
            }
            try? modelContext.save()

            refreshNavigationState()
        }
    }

    /// Orders checkpoints by where the road reaches them, not by how they are declared.
    /// The loop is anchored to whichever stop the rider starts from, so landmark 1 is
    /// regularly not the first one you pass.
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
            coordinate: startStop?.coordinate ?? path[path.count - 1],
            name: startStop?.name ?? "Bus Stop",
            kind: .busStop,
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

    private func handleCapturedVideo(_ tempURL: URL) {
        let landmark = pendingLandmark
        let landmarkName = landmark?.name ?? "Landmark"
        guard let activeSession else {
            print("Cannot save landmark video without an active navigation session")
            return
        }
        guard let savedURL = saveVideo(from: tempURL, landmarkName: landmarkName, session: activeSession) else { return }
        saveLandmarkVideo(
            landmarkName: landmarkName,
            fileName: savedURL.lastPathComponent,
            session: activeSession
        )

        // Stop re-announcing a landmark the rider has already filmed.
        if let index = landmark?.index {
            capturedLandmarkIndices.insert(index)
        }
        nearbyLandmark = nil
        pendingLandmark = nil

        activeSheet = .videoPreview(url: savedURL, landmarkName: landmarkName)
    }

    private func saveLandmarkVideo(
        landmarkName: String,
        fileName: String,
        session: NavigationSession
    ) {
        let video = LandmarkVideo(
            landmarkName: landmarkName,
            fileName: fileName,
            recordedAt: .now,
            session: session
        )
        modelContext.insert(video)
        session.videos.append(video)
        try? modelContext.save()
    }

    private func landmarkDetailSheet(for index: Int) -> LandmarkDetailView {
        LandmarkDetailView(
            landmarkName: "Landmark \(index + 1)",
            info: MapConstants.landmarkInfo.indices.contains(index) ? MapConstants.landmarkInfo[index] : nil
        )
    }

    private var baseVideosDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LandmarkVideos", isDirectory: true)
    }

    private func videosDirectory(for session: NavigationSession) -> URL? {
        baseVideosDirectory?
            .appendingPathComponent(session.id.uuidString, isDirectory: true)
    }

    private func saveVideo(
        from tempURL: URL,
        landmarkName: String,
        session: NavigationSession
    ) -> URL? {
        let fileManager = FileManager.default
        guard let videosDirectory = videosDirectory(for: session) else { return nil }

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

    private func presentTripSummaryIfAvailable(for session: NavigationSession?) {
        guard
            let session,
            let videosDirectory = videosDirectory(for: session)
        else { return }

        let records = session.videos.sorted { $0.recordedAt < $1.recordedAt }
        guard !records.isEmpty else { return }

        let clips = records.compactMap { record -> TripClip? in
            let url = videosDirectory.appendingPathComponent(record.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Trip summary: skipping \(record.landmarkName), file missing at \(url.path)")
                return nil
            }
            return TripClip(name: record.landmarkName, url: url)
        }

        guard !clips.isEmpty else {
            print("Trip summary: \(records.count) record(s) in SwiftData but no video files on disk")
            return
        }

        tripSummary = TripSummary(clips: clips)
    }

    private func startNavigationSession() {
        currentStepIndex = 0
        currentCheckpointIndex = 0
        currentStopVisitIndex = 0
        activeWalkingConnector = nil
        nearbyLandmark = nil
        capturedLandmarkIndices = []
        routeProgress = nil
        tripSummary = nil

        let session = NavigationSession(
            routeName: routeName,
            totalSteps: directions.count,
            totalCheckpoints: checkpoints.count,
            routeCoordinates: (calculatedRoute?.combinedWaypoints ?? []).map { RouteCoordinate($0) }
        )
        modelContext.insert(session)
        activeSession = session
        try? modelContext.save()
    }

    private func endNavigationSession() -> NavigationSession? {
        guard let activeSession else { return nil }

        let completedSession = activeSession
        completedSession.endedAt = .now
        completedSession.totalSteps = directions.count
        completedSession.completedSteps = directions.isEmpty ? 0 : min(currentStepIndex + 1, directions.count)
        completedSession.checkpointsReached = currentCheckpointIndex
        completedSession.totalCheckpoints = checkpoints.count
        completedSession.isCompleted = currentCheckpointIndex >= checkpoints.count

        try? modelContext.save()
        self.activeSession = nil
        currentCheckpointIndex = 0
        return completedSession
    }
}

#Preview {
    ContentView()
}

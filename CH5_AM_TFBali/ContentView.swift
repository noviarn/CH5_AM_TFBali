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

private enum ActiveSheet: String, Identifiable {
    case videoPreview
    case sessionHistory

    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    private let routeName = "Kuta Loop"

    @State private var locationManager = LocationManager()
    @State private var isRouting = false
    @State private var calculatedRoute: MapRoute?
    @State private var isCalculatingRoute = false
    @State private var directions: [DirectionStep] = []
    @State private var currentStepIndex = 0
    @State private var nearbyLandmark: (distance: CLLocationDistance, side: String, name: String)?
    @State private var showCamera = false
    @State private var pendingLandmarkName: String?
    @State private var videoPreviewURL: URL?
    @State private var videoPreviewLandmarkName: String?
    @State private var showTripSummary = false
    @State private var activeSheet: ActiveSheet?
    @State private var tripSummaryClips: [(name: String, url: URL)] = []
    @State private var activeSession: NavigationSession?
    @State private var currentCheckpointIndex = 0
    @State private var hasCalculatedApproachRoute = false
    @State private var startStop: BusStop?

    private let checkpointArrivalThreshold: CLLocationDistance = 50

    private var checkpoints: [RouteCheckpoint] {
        let landmarkCheckpoints = MapConstants.landmark.coordinates.enumerated().map { index, coordinate in
            RouteCheckpoint(coordinate: coordinate, name: "Landmark \(index + 1)", kind: .landmark)
        }
        let loopEndCoordinate = startStop?.coordinate ?? MapConstants.kutaLoop.waypoints[0]
        let loopEndName = startStop?.name ?? "Bus Stop"
        return landmarkCheckpoints + [RouteCheckpoint(coordinate: loopEndCoordinate, name: loopEndName, kind: .busStop)]
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

    var body: some View {
        ZStack {
            MapViewContainer(
                locations: MapConstants.defaultLocations,
                userLocation: locationManager.userLocation,
                isNavigating: isRouting,
                navigationHeading: cameraHeading,
                route: calculatedRoute ?? MapConstants.kutaLoop,
                landmark: MapConstants.landmark,
                busStops: MapConstants.busStops
            )

            VStack(spacing: 0) {
                MapHeader {
                    activeSheet = .sessionHistory
                }
                Spacer()

                if isRouting {
                    DirectionsBox(
                        currentInstruction: currentStep,
                        nextInstruction: nextStep,
                        nearbyLandmark: nearbyLandmark,
                        checkpointIndex: currentCheckpointIndex,
                        totalCheckpoints: checkpoints.count,
                        currentCheckpoint: checkpoints.indices.contains(currentCheckpointIndex) ? checkpoints[currentCheckpointIndex] : nil,
                        onOpenCamera: {
                            pendingLandmarkName = nearbyLandmark?.name
                            showCamera = true
                        }
                    )
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
            case .videoPreview:
                if let url = videoPreviewURL {
                    VideoPreviewView(url: url, landmarkName: videoPreviewLandmarkName ?? "Landmark")
                }
            case .sessionHistory:
                NavigationSessionHistoryView(videosBaseDirectory: baseVideosDirectory)
            }
        }
        .fullScreenCover(isPresented: $showTripSummary) {
            TripSummaryPlayerView(clips: tripSummaryClips)
        }
        .onAppear {
            locationManager.requestLocation()
            calculateRoute()
        }
        .onChange(of: locationManager.userLocation == nil) { _, isNil in
            guard !isNil, !hasCalculatedApproachRoute, !isRouting else { return }
            hasCalculatedApproachRoute = true
            calculateRoute()
        }
        .onChange(of: isRouting) { oldValue, newValue in
            if newValue {
                startNavigationSession()
                updateLandmarkProximity()
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
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isRouting {
                updateRouteProgress()
                updateLandmarkProximity()
                updateCheckpointProgress()
                updateLiveActivity()
            }
        }
    }

    private func calculateRoute() {
        isCalculatingRoute = true
        Task {
            do {
                let result = try await RouteCalculator.shared.calculateRoute(
                    waypoints: MapConstants.kutaLoop.waypoints,
                    userLocation: locationManager.userLocation,
                    busStops: MapConstants.busStops
                )
                calculatedRoute = result.route
                directions = result.steps
                startStop = result.startStop
                activeSession?.totalSteps = result.steps.count
                try? modelContext.save()
            } catch {
                print("Failed to calculate route: \(error)")
            }
            isCalculatingRoute = false
        }
    }

    private func updateLandmarkProximity() {
        Task {
            let proximity = await LandmarkProximityDetector.shared.detectNearbyLandmarks(
                userLocation: locationManager.userLocation,
                landmark: MapConstants.landmark,
                routeDirection: routeHeading
            )
            nearbyLandmark = proximity
        }
    }

    private func updateLiveActivity() {
        Task {
            await RoutingActivityManager.shared.updateActivity(
                currentStep: currentStep,
                nextStep: nextStep,
                nearbyLandmark: nearbyLandmark
            )
        }
    }

    private func handleCapturedVideo(_ tempURL: URL) {
        let landmarkName = pendingLandmarkName ?? "Landmark"
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
        videoPreviewURL = savedURL
        videoPreviewLandmarkName = landmarkName
        activeSheet = .videoPreview
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

        let clips = records.compactMap { record -> (name: String, url: URL)? in
            let url = videosDirectory.appendingPathComponent(record.fileName)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("Trip summary: skipping \(record.landmarkName), file missing at \(url.path)")
                return nil
            }
            return (name: record.landmarkName, url: url)
        }

        guard !clips.isEmpty else {
            print("Trip summary: \(records.count) record(s) in SwiftData but no video files on disk")
            return
        }

        tripSummaryClips = clips
        showTripSummary = true
    }

    private func startNavigationSession() {
        currentStepIndex = 0
        currentCheckpointIndex = 0
        nearbyLandmark = nil
        tripSummaryClips = []

        let session = NavigationSession(
            routeName: routeName,
            totalSteps: directions.count,
            totalCheckpoints: checkpoints.count,
            routeCoordinates: (calculatedRoute?.waypoints ?? []).map(RouteCoordinate.init)
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
        completedSession.isCompleted = currentCheckpointIndex >= checkpoints.count

        try? modelContext.save()
        self.activeSession = nil
        currentCheckpointIndex = 0
        return completedSession
    }

    private func updateCheckpointProgress() {
        guard let userLocation = locationManager.userLocation else { return }
        guard currentCheckpointIndex < checkpoints.count else { return }

        let target = checkpoints[currentCheckpointIndex].coordinate
        if userLocation.distance(to: target) <= checkpointArrivalThreshold {
            currentCheckpointIndex += 1
            activeSession?.checkpointsReached = currentCheckpointIndex
            try? modelContext.save()
        }
    }

    private func updateRouteProgress() {
        guard let userLocation = locationManager.userLocation else { return }

        if currentStepIndex < directions.count {
            let currentStepCoord = directions[currentStepIndex].coordinate
            let distanceToStep = userLocation.distance(to: currentStepCoord)

            if distanceToStep < 50 && currentStepIndex + 1 < directions.count {
                currentStepIndex += 1
            }
        }
    }
}

#Preview {
    ContentView()
}

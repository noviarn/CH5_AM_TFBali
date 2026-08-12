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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var locationManager = LocationManager()
    @State private var isRouting = false
    @State private var calculatedRoute: MapRoute?
    @State private var isCalculatingRoute = false
    @State private var directions: [DirectionStep] = []
    @State private var currentStepIndex = 0
    @State private var nearbyLandmark: (distance: CLLocationDistance, side: String, name: String)?
    @State private var showCamera = false
    @State private var pendingLandmarkName: String?
    @State private var showVideoPreview = false
    @State private var videoPreviewURL: URL?
    @State private var videoPreviewLandmarkName: String?
    @State private var showTripSummary = false
    @State private var tripSummaryClips: [(name: String, url: URL)] = []

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
                route: calculatedRoute ?? MapConstants.kutaLoop,
                landmark: MapConstants.landmark
            )

            VStack(spacing: 0) {
                MapHeader()
                Spacer()

                if isRouting {
                    DirectionsBox(
                        currentInstruction: currentStep,
                        nextInstruction: nextStep,
                        nearbyLandmark: nearbyLandmark,
                        onOpenCamera: {
                            pendingLandmarkName = nearbyLandmark?.name
                            showCamera = true
                        }
                    )
                }

                RoutingControl(isRouting: $isRouting, routeName: "Kuta Loop")
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
        .sheet(isPresented: $showVideoPreview) {
            if let url = videoPreviewURL {
                VideoPreviewView(url: url, landmarkName: videoPreviewLandmarkName ?? "Landmark")
            }
        }
        .fullScreenCover(isPresented: $showTripSummary) {
            TripSummaryPlayerView(clips: tripSummaryClips)
        }
        .onAppear {
            locationManager.requestLocation()
            calculateRoute()
        }
        .onChange(of: isRouting) { oldValue, newValue in
            if newValue {
                updateLandmarkProximity()
                Task {
                    await RoutingActivityManager.shared.startActivity(routeName: "Kuta Loop")
                }
            } else {
                Task {
                    await RoutingActivityManager.shared.endActivity()
                }
                presentTripSummaryIfAvailable()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isRouting {
                updateRouteProgress()
                updateLandmarkProximity()
                updateLiveActivity()
            }
        }
    }

    private func calculateRoute() {
        isCalculatingRoute = true
        Task {
            do {
                let result = try await RouteCalculator.shared.calculateRoute(
                    waypoints: MapConstants.kutaLoop.waypoints
                )
                calculatedRoute = result.route
                directions = result.steps
            } catch {
                print("Failed to calculate route: \(error)")
            }
            isCalculatingRoute = false
        }
    }

    private func updateLandmarkProximity() {
        Task {
            let heading: CLLocationDirection? = nil
            let proximity = await LandmarkProximityDetector.shared.detectNearbyLandmarks(
                userLocation: locationManager.userLocation,
                landmark: MapConstants.landmark,
                routeDirection: heading
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
        guard let savedURL = saveVideo(from: tempURL, landmarkName: landmarkName) else { return }
        upsertLandmarkVideo(landmarkName: landmarkName, fileName: savedURL.lastPathComponent)
        videoPreviewURL = savedURL
        videoPreviewLandmarkName = landmarkName
        showVideoPreview = true
    }

    private func upsertLandmarkVideo(landmarkName: String, fileName: String) {
        let descriptor = FetchDescriptor<LandmarkVideo>(
            predicate: #Predicate { $0.landmarkName == landmarkName }
        )

        if let existing = try? modelContext.fetch(descriptor).first {
            existing.fileName = fileName
            existing.recordedAt = .now
        } else {
            modelContext.insert(LandmarkVideo(landmarkName: landmarkName, fileName: fileName))
        }

        try? modelContext.save()
    }

    private var videosDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("LandmarkVideos", isDirectory: true)
    }

    private func saveVideo(from tempURL: URL, landmarkName: String) -> URL? {
        let fileManager = FileManager.default
        guard let videosDirectory else { return nil }

        let safeName = landmarkName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let destinationURL = videosDirectory.appendingPathComponent("\(safeName).mov")

        do {
            try fileManager.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to save video: \(error)")
            return nil
        }
    }

    private func presentTripSummaryIfAvailable() {
        guard let videosDirectory else { return }
        let descriptor = FetchDescriptor<LandmarkVideo>(sortBy: [SortDescriptor(\.recordedAt)])
        guard let records = try? modelContext.fetch(descriptor), !records.isEmpty else { return }

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

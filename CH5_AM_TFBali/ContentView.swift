//
//  ContentView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI
import MapKit
import Combine

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var isRouting = false
    @State private var calculatedRoute: MapRoute?
    @State private var isCalculatingRoute = false
    @State private var directions: [DirectionStep] = []
    @State private var currentStepIndex = 0
    @State private var nearbyLandmark: (distance: CLLocationDistance, side: String, name: String)?

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
                        nearbyLandmark: nearbyLandmark
                    )
                }

                RoutingControl(isRouting: $isRouting, routeName: "Kuta Loop")
            }
        }
        .onAppear {
            locationManager.requestLocation()
            calculateRoute()
        }
        .onChange(of: isRouting) { oldValue, newValue in
            if newValue {
                updateLandmarkProximity()
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
            if isRouting {
                updateLandmarkProximity()
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
}

#Preview {
    ContentView()
}

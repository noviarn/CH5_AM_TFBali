//
//  ContentView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI
import MapKit

struct ContentView: View {
    @State private var locationManager = LocationManager()
    @State private var isRouting = false
    @State private var calculatedRoute: MapRoute?
    @State private var isCalculatingRoute = false

    var body: some View {
        ZStack {
            MapViewContainer(
                locations: MapConstants.defaultLocations,
                userLocation: locationManager.userLocation,
                route: calculatedRoute ?? MapConstants.kutaLoop
            )

            VStack(spacing: 0) {
                MapHeader()
                Spacer()
                RoutingControl(isRouting: $isRouting, routeName: "Kuta Loop")
            }
        }
        .onAppear {
            locationManager.requestLocation()
            calculateRoute()
        }
    }

    private func calculateRoute() {
        isCalculatingRoute = true
        Task {
            do {
                let route = try await RouteCalculator.shared.calculateRoute(
                    waypoints: MapConstants.kutaLoop.waypoints
                )
                calculatedRoute = route
            } catch {
                print("Failed to calculate route: \(error)")
            }
            isCalculatingRoute = false
        }
    }
}

#Preview {
    ContentView()
}

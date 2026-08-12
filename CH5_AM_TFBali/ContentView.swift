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

    var body: some View {
        ZStack {
            MapViewContainer(
                locations: MapConstants.defaultLocations,
                userLocation: locationManager.userLocation
            )

            VStack {
                MapHeader()
                Spacer()
            }
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }
}

#Preview {
    ContentView()
}

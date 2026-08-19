//
//  LocationDisplayView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 18/08/26.
//

import SwiftUI

struct LocationDisplay: View {
    @State private var locationManager = LocationManager()
    
    var body: some View {
        NavigationLink {
            // user's location selection screen tba
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16))
                Text(locationManager.cityName)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
            .foregroundStyle(.white)
            .background(Color.primaryPurple)
            .clipShape(Capsule())
        }
        .onAppear {
            locationManager.requestLocation()
        }
    }
}

#Preview {
    LocationDisplay()
}

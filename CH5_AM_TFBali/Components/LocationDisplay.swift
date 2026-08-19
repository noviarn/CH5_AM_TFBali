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
        HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(.body))
            Text(locationManager.cityName)
                .font(.system(.footnote, design: .rounded))
                .fontWeight(.semibold)
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 8)
        .foregroundStyle(.white)
        .background(Color.primaryPurple)
        .clipShape(Capsule())
    }
}

#Preview {
    LocationDisplay()
}

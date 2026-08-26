//
//  NoInternetBanner.swift
//  Jelaja
//
//  Created by Novia Rahman Nisa on 25/08/26.
//

import SwiftUI

struct NoInternetBanner: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "wifi.slash")
            Text("Offline Mode")
        }
        .font(.system(.caption, weight: .semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.black.opacity(0.75), in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }
}

#Preview {
    NoInternetBanner()
}

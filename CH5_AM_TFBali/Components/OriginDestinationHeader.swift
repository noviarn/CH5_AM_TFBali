//
//  OriginDestinationHeader.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 20/08/26.
//

import SwiftUI

struct OriginDestinationHeader: View {
    let destinationName: String
    @State private var originName = "Your Location"
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Origin
            HStack(spacing: 18) {
                Image(systemName: "circle.circle.fill")
                    .font(.system(.body))
                    .foregroundStyle(Color.primaryPurple)
                    .frame(width: 24)
                
                TextField(
                    "Your location",
                    text: $originName
                )
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Color.primaryPurple)
                .textFieldStyle(.plain)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 50)
            
            
            // MARK: - Divider
            Rectangle()
                .fill(Color.gray.opacity(0.35))
                .frame(height: 1)
                .padding(.leading, 60)
                .padding(.trailing, 24)
            
            
            // MARK: - Destination
            HStack(spacing: 18) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(.body))
                    .foregroundStyle(Color.primaryPurple)
                    .frame(width: 24)
                
                Text(destinationName)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(Color.primaryPurple)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(height: 50)
        }
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 15))
        .shadow(
            color: Color.black.opacity(0.12),
            radius: 8,
            x: 0,
            y: 3
        )
    }
}

#Preview {
    OriginDestinationHeader(destinationName: "Sanur Beach")
}

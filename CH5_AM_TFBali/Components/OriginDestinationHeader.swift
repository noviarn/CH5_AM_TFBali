//
//  OriginDestinationHeader.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 20/08/26.
//

import SwiftUI

struct OriginDestinationHeader: View {
    /// What the trip is planned to start from — the rider's own position unless they picked
    /// somewhere else. Owned by the caller: this used to be local `@State` on a `TextField`,
    /// which meant typing here changed nothing the planner ever saw.
    let originName: String
    let destinationName: String
    var onTapOrigin: () -> Void = {}
    /// Non-nil only once a first mile has been picked, so choosing one isn't a one-way door.
    var onClearOrigin: (() -> Void)?
    var onTapDestination: () -> Void = {}
    /// The same escape hatch for the last mile.
    var onClearDestination: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Origin
            HStack(spacing: 18) {
                Image(systemName: "circle.circle.fill")
                    .font(.system(.body))
                    .foregroundStyle(Color.primaryPurple)
                    .frame(width: 24)
                
                Button(action: onTapOrigin) {
                    HStack {
                        Text(originName)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Color.primaryPurple)
                            .lineLimit(1)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if let onClearOrigin {
                    Button(action: onClearOrigin) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(.body))
                            .foregroundStyle(Color.gray.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
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
                
                Button(action: onTapDestination) {
                    HStack {
                        Text(destinationName)
                            .font(.system(.body, design: .rounded))
                            .foregroundStyle(Color.primaryPurple)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                if let onClearDestination {
                    Button(action: onClearDestination) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(.body))
                            .foregroundStyle(Color.gray.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
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
    OriginDestinationHeader(originName: "Your Location", destinationName: "Sanur Beach")
}

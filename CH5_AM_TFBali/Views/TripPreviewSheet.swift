//
//  TripPreviewSheet.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 20/08/26.
//

import SwiftUI
import CoreLocation

struct TripPreviewSheet: View {
    let place: Place
    let corridor: Corridor
    let direction: RouteDirection
    /// Already sliced to just the boarded-through-alighted stops (see `RouteMapView.servingRide`).
    let rideStops: [BusStop]
    let userLocation: CLLocationCoordinate2D?
    let nextStopName: String?
    let stopsRemaining: Int?
    let minutesRemaining: Double?
    let isTripActive: Bool // Track active route state
    let nearbyLandmark: NearbyLandmark?
    @Binding var currentDetent: PresentationDetent
    let onStart: () -> Void
    let onEnd: () -> Void
    let onDismiss: () -> Void
    
    @State private var isStopsExpanded = false
    
    private let walkingSpeedKmh: Double = 4.5
    private let busSpeedKmh: Double = 20
    private let minimizedDetent: PresentationDetent = .height(80)
    
    private var isMinimized: Bool { currentDetent == minimizedDetent }
    
    // Check if user is within 50 meters of the destination
    private var hasReachedDestination: Bool {
        guard let userLocation else { return false }
        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let destLoc = CLLocation(latitude: place.latitude, longitude: place.longitude)
        return userLoc.distance(from: destLoc) <= 50
    }
    
    private var boardStop: BusStop? { rideStops.first }
    private var alightStop: BusStop? { rideStops.last }
    private var intermediateStops: [BusStop] {
        guard rideStops.count > 2 else { return [] }
        return Array(rideStops.dropFirst().dropLast())
    }
    
    private var walkToBoardKm: Double {
        guard let userLocation, let boardStop else { return 0 }
        return userLocation.distance(to: boardStop.coordinate) / 1000
    }
    
    private var walkFromAlightKm: Double {
        guard let alightStop else { return 0 }
        let destination = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        return alightStop.coordinate.distance(to: destination) / 1000
    }
    
    private var rideDistanceKm: Double {
        guard rideStops.count > 1 else { return 0 }
        var total = 0.0
        for i in 0..<(rideStops.count - 1) {
            total += rideStops[i].coordinate.distance(to: rideStops[i + 1].coordinate) / 1000
        }
        return total
    }
    
    private var walkToBoardMinutes: Double { (walkToBoardKm / walkingSpeedKmh) * 60 }
    private var rideMinutes: Double { (rideDistanceKm / busSpeedKmh) * 60 }
    private var walkFromAlightMinutes: Double { (walkFromAlightKm / walkingSpeedKmh) * 60 }
    private var totalMinutes: Double { walkToBoardMinutes + rideMinutes + walkFromAlightMinutes }
    
    private var boardTime: Date { Date().addingTimeInterval(walkToBoardMinutes * 60) }
    private var alightTime: Date { boardTime.addingTimeInterval(rideMinutes * 60) }
    private var arrivalTime: Date { alightTime.addingTimeInterval(walkFromAlightMinutes * 60) }
    
    // MARK: - Dynamic Banner Helpers
    private var landmarkDirectionText: String {
        guard let nearbyLandmark else { return "Look around!" }
        return "Look \(nearbyLandmark.sideDescription)!"
    }
    
    private var bannerTitle: String {
        if isTripActive {
            return nearbyLandmark != nil ? landmarkDirectionText : "Enjoy the ride!"
        }
        return place.name
    }
    
    private var bannerIconName: String {
        nearbyLandmark != nil ? "eyes.inverse" : "bell.fill"
    }
    
    var body: some View {
        if isMinimized {
            minimizedContent
        } else {
            fullContent
        }
    }
    
    // MARK: - Minimized state
    
    private var minimizedContent: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.deepPrimaryPurple)
                    .lineLimit(2)
                Text(place.desc)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.deepPrimaryPurple.opacity(0.7))
                    .lineLimit(1)
            }
            .onTapGesture {
                withAnimation { currentDetent = .medium }
            }
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 36, height: 36)
                    .background(Color.gray.opacity(0.15))
                    .clipShape(Circle())
            }
        }
        .padding()
        .frame(maxHeight: .infinity)
    }
    
    // MARK: - Full state (existing content, unchanged)
    
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Header Area
            HStack(alignment: .top, spacing: 12) {
                if isTripActive {
                    // Active Trip State
                    HStack(alignment: .center, spacing: 12) {
                        // Left Status Icon
                        Circle()
                            .foregroundStyle(Color.deepPrimaryPurple)
                            .frame(width: 50, height: 50)
                            .overlay {
                                Image(systemName: bannerIconName)
                                    .font(.system(size: 24))
                                    .foregroundStyle(Color.white)
                            }
                        
                        // Middle Information Content
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bannerTitle)
                                .font(.system(.headline, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundStyle(Color.deepPrimaryPurple)
                            
                            if let nearbyLandmark {
                                Text(nearbyLandmark.name)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.deepPrimaryPurple)
                                
                                let distanceText = "\(nearbyLandmark.formattedDistance) away"
                                let badgeText = if let minutesRemaining {
                                    "\(distanceText) • \(formattedDuration(minutes: minutesRemaining)) remaining"
                                } else {
                                    distanceText
                                }
                                
                                Text(badgeText)
                                    .font(.system(.caption, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundStyle(Color.white)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(Color.secondaryPurple)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                if let nextStopName {
                                    Text("Next Stop: \(nextStopName)")
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.deepPrimaryPurple)
                                }
                                
                                if let stopsRemaining, let minutesRemaining {
                                    Text("\(stopsRemaining) stop\(stopsRemaining == 1 ? "" : "s") left • \(formattedDuration(minutes: minutesRemaining)) remaining")
                                        .font(.system(.caption, design: .rounded))
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color.white)
                                        .padding(.vertical, 5)
                                        .padding(.horizontal, 10)
                                        .background(Color.secondaryPurple)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        
                        Spacer(minLength: 0)
                        
                        // Right Action Icon (Camera badge when landmark is present)
                        if nearbyLandmark != nil {
                            Circle()
                                .foregroundStyle(Color.primaryOrange)
                                .frame(width: 50, height: 50)
                                .overlay {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(Color.white)
                                }
                        }
                    }
                } else {
                    // Inactive Trip State: Display Title/Landmark Name & Dismiss Button
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.deepPrimaryPurple)
                        
                        Text(place.desc)
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundStyle(Color.deepPrimaryPurple.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.gray.opacity(0.15))
                            .clipShape(Circle())
                    }
                }
            }
            
            // MARK: - Inactive Trip Summary Badges
            if !isTripActive {
                HStack(spacing: 5) {
                    Image(systemName: "clock.fill")
                        .font(.system(.body))
                    Text(formattedDuration(minutes: totalMinutes))
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.regular)
                }
                .font(.system(.body, design: .rounded))
                
                HStack(spacing: 6) {
                    Image(systemName: "figure.walk")
                    Text("\(Int(walkToBoardMinutes))min")
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                    Image(systemName: "bus")
                    Text(corridor.id)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(corridor.color)
                        .clipShape(Capsule())
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                    Image(systemName: "figure.walk")
                    Text("\(Int(walkFromAlightMinutes))min")
                }
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Color.deepPrimaryPurple)
                
                Divider()
            }
            
            // MARK: - Timeline Route Details
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    timelineRow(
                        dotStyle: .filled(Color.blue),
                        label: "Your location",
                        labelColor: .blue,
                        time: nil,
                        showLine: true
                    )
                    
                    timelineRow(
                        dotStyle: .none,
                        label: "Walk \(Int(walkToBoardMinutes)) min (\(formattedDistance(walkToBoardKm)))",
                        labelColor: .secondary,
                        icon: "figure.walk",
                        time: nil,
                        showLine: true
                    )
                    
                    if let boardStop {
                        timelineRow(
                            dotStyle: .none,
                            label: boardStop.name,
                            labelColor: Color.deepPrimaryPurple,
                            bold: true,
                            time: boardTime,
                            showLine: true
                        )
                        
                        HStack {
                            Image(systemName: "bus")
                            Text(corridor.id)
                                .fontWeight(.bold)
                            Text(direction.label)
                                .lineLimit(1)
                        }
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(corridor.color)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.leading, 28)
                        .padding(.bottom, 8)
                        
                        if !intermediateStops.isEmpty {
                            Button {
                                withAnimation { isStopsExpanded.toggle() }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: isStopsExpanded ? "chevron.up" : "chevron.down")
                                    Text("\(intermediateStops.count) Stops (\(formattedDuration(minutes: rideMinutes)))")
                                        .fontWeight(.semibold)
                                }
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.primaryPurple)
                                .clipShape(Capsule())
                            }
                            .padding(.leading, 28)
                            .padding(.bottom, 8)
                            
                            if isStopsExpanded {
                                ForEach(intermediateStops) { intermediateStop in
                                    timelineRow(
                                        dotStyle: .small,
                                        label: intermediateStop.name,
                                        labelColor: .secondary,
                                        time: nil,
                                        showLine: true
                                    )
                                }
                            }
                        }
                    }
                    
                    if let alightStop {
                        timelineRow(
                            dotStyle: .filledOutline(Color.black),
                            label: alightStop.name,
                            labelColor: Color.deepPrimaryPurple,
                            bold: true,
                            time: alightTime,
                            showLine: true
                        )
                    }
                    
                    timelineRow(
                        dotStyle: .none,
                        label: "Walk \(Int(walkFromAlightMinutes)) min (\(formattedDistance(walkFromAlightKm)))",
                        labelColor: .secondary,
                        icon: "figure.walk",
                        time: nil,
                        showLine: true
                    )
                    
                    timelineRow(
                        dotStyle: .pin,
                        label: place.name,
                        labelColor: Color.deepPrimaryPurple,
                        bold: true,
                        time: arrivalTime,
                        showLine: false
                    )
                }
            }
            
            // MARK: - Primary Action Button
            Button(action: {
                if isTripActive {
                    onEnd()
                } else {
                    onStart()
                }
            }) {
                Text(isTripActive ? "End Trip" : "Start")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        isTripActive
                        ? (hasReachedDestination ? Color.blue : Color.primaryPurple)
                        : Color.primaryOrange
                    )
                    .clipShape(Capsule())
            }
        }
        .padding()
    }
    
    private enum DotStyle {
        case filled(Color)
        case filledOutline(Color)
        case small
        case pin
        case none
    }
    
    @ViewBuilder
    private func timelineRow(
        dotStyle: DotStyle,
        label: String,
        labelColor: Color,
        bold: Bool = false,
        icon: String? = nil,
        time: Date?,
        showLine: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Group {
                    switch dotStyle {
                    case .filled(let color):
                        Circle().fill(color).frame(width: 12, height: 12)
                    case .filledOutline(let color):
                        Circle().fill(.white).frame(width: 12, height: 12)
                            .overlay(Circle().stroke(color, lineWidth: 2))
                    case .small:
                        Circle().fill(Color.gray.opacity(0.4)).frame(width: 6, height: 6)
                    case .pin:
                        Image(systemName: "mappin")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.deepPrimaryPurple)
                    case .none:
                        Circle().fill(Color.gray.opacity(0.3)).frame(width: 6, height: 6)
                    }
                }
                .frame(height: 12)
                if showLine {
                    Rectangle()
                        .fill(Color.gray.opacity(0.25))
                        .frame(width: 2)
                        .frame(minHeight: 24)
                }
            }
            .frame(width: 16)
            
            HStack {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(labelColor)
                }
                Text(label)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(bold ? .semibold : .regular)
                    .foregroundStyle(labelColor)
                
                Spacer()
                
                if let time {
                    Text(time, format: .dateTime.hour().minute())
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 12)
        }
    }
    
    private func formattedDuration(minutes: Double) -> String {
        let total = Int(minutes.rounded())
        let hours = total / 60
        let mins = total % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
    }
    
    private func formattedDistance(_ km: Double) -> String {
        km < 1 ? "\(Int(km * 1000))m" : String(format: "%.1fkm", km)
    }
}

#Preview {
    let userLoc = CLLocationCoordinate2D(latitude: -8.7183, longitude: 115.1686)
    
    let stops = [
        stop("Tuban Murni Teguh 2", -8.7280, 115.1670, corridor: 1, direction: .outbound, serviceBearing: 90),
        stop("Kuta Center", -8.7205, 115.1720, corridor: 1, direction: .outbound, serviceBearing: 90),
        stop("Legian Junction", -8.7050, 115.1730, corridor: 1, direction: .outbound, serviceBearing: 90),
        stop("Mertasari", -8.6950, 115.2500, corridor: 1, direction: .outbound, serviceBearing: 90)
    ]
    
    let direction = RouteDirection(
        label: "Sentral Parkir Kuta - Politeknik Negeri Bali",
        stops: stops
    )
    
    let corridor = Corridor(
        id: "K5B",
        name: "Kuta - Politeknik",
        color: Color.yellow,
        directions: [direction]
    )
    
    let place = Place(
        name: "Sanur Beach",
        desc: "Explore beach, forest, and waterfall. yagitulah lorem ipsum",
        image: "placeholder-default",
        category: Category(name: "Beach", image: "placeholder-default"),
        latitude: -8.6905,
        longitude: 115.2624
    )
    
    //    TripPreviewSheet(
    //        place: place,
    //        corridor: corridor,
    //        direction: direction,
    //        rideStops: stops,
    //        userLocation: userLoc,
    //        nextStopName: nil,
    //        stopsRemaining: nil,
    //        minutesRemaining: nil,
    //        isTripActive: false,
    //        nearbyLandmark: NearbyLandmark(
    //            index: 0,
    //            distance: 50,
    //            side: .left,
    //            name: "Garuda Wisnu Kencana"
    //        ),
    //        currentDetent: .constant(.medium),
    //        //        currentDetent: .constant(.height(80)),
    //        onStart: {},
    //        onEnd: {},
    //        onDismiss: {}
    //    )
    
//    TripPreviewSheet(
//        place: place,
//        corridor: corridor,
//        direction: direction,
//        rideStops: stops,
//        userLocation: userLoc,
//        nextStopName: "Kuta Center",
//        stopsRemaining: 3,
//        minutesRemaining: 12,
//        isTripActive: true,
//        nearbyLandmark: nil,
//        currentDetent: .constant(.medium),
//        onStart: {},
//        onEnd: {},
//        onDismiss: {}
//    )
    
    TripPreviewSheet(
        place: place,
        corridor: corridor,
        direction: direction,
        rideStops: stops,
        userLocation: userLoc,
        nextStopName: "Kuta Center",
        stopsRemaining: 1,
        minutesRemaining: 3,
        isTripActive: true,
        nearbyLandmark: NearbyLandmark(
            index: 1,
            distance: 30,
            side: .right,
            name: "Waterbom Bali"
        ),
        currentDetent: .constant(.medium),
        onStart: {},
        onEnd: {},
        onDismiss: {}
    )
}

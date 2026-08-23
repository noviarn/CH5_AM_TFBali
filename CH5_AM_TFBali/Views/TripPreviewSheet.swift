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
    /// One entry per bus ridden, in order — two or more when the trip involves changing
    /// lines. Each already sliced to just its boarded-through-alighted stops (see
    /// `RouteMapView.servingLegs`).
    let legs: [PlannedLeg]
    /// The rider's live position — what "have I arrived" is measured against.
    let userLocation: CLLocationCoordinate2D?
    /// Where the trip is planned to start from, which is only the same as `userLocation`
    /// until the rider picks a first mile of their own. The two are separate because the
    /// walk to the first stop follows the chosen origin while arrival follows real GPS.
    var planningOrigin: CLLocationCoordinate2D?
    let nextStopName: String?
    let stopsRemaining: Int?
    let minutesRemaining: Double?
    let isTripActive: Bool // Track active route state
    let nearbyLandmark: NearbyLandmark?
    @Binding var currentDetent: PresentationDetent
    let onStart: () -> Void
    let onEnd: () -> Void
    let onDismiss: () -> Void
    let onCapture: (URL) -> Void
    
    /// Expanded state per leg, keyed by leg id — one shared flag would open every leg's stop
    /// list at once on a trip with a change.
    @State private var expandedLegIDs: Set<UUID> = []
    @State private var isShowingCamera = false
    
    private let minimizedDetent: PresentationDetent = .height(80)
    
    private var isMinimized: Bool { currentDetent == minimizedDetent }
    
    // Check if user is within 50 meters of the destination
    private var hasReachedDestination: Bool {
        guard let userLocation else { return false }
        let userLoc = CLLocation(latitude: userLocation.latitude, longitude: userLocation.longitude)
        let destLoc = CLLocation(latitude: place.latitude, longitude: place.longitude)
        return userLoc.distance(from: destLoc) <= 50
    }
    
    private var boardStop: BusStop? { legs.first?.boardStop }
    private var alightStop: BusStop? { legs.last?.alightStop }

    private var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }

    private func intermediateStops(of leg: PlannedLeg) -> [BusStop] {
        guard leg.stops.count > 2 else { return [] }
        return Array(leg.stops.dropFirst().dropLast())
    }

    private func rideMeters(of leg: PlannedLeg) -> CLLocationDistance {
        guard leg.stops.count > 1 else { return 0 }
        return (0..<(leg.stops.count - 1)).reduce(0.0) { total, i in
            total + leg.stops[i].coordinate.distance(to: leg.stops[i + 1].coordinate)
        }
    }

    /// Walking from the previous leg's alight stop to this one's board stop. Zero for the
    /// first leg, which is reached from the rider's own location instead.
    private func transferMeters(before index: Int) -> CLLocationDistance {
        guard index > 0,
              let previousAlight = legs[index - 1].alightStop,
              let board = legs[index].boardStop
        else { return 0 }
        return previousAlight.coordinate.distance(to: board.coordinate)
    }

    private var walkToBoardMeters: CLLocationDistance {
        guard let origin = planningOrigin ?? userLocation, let boardStop else { return 0 }
        return origin.distance(to: boardStop.coordinate)
    }

    private var walkFromAlightMeters: CLLocationDistance {
        guard let alightStop else { return 0 }
        return alightStop.coordinate.distance(to: destinationCoordinate)
    }

    /// Every time on this sheet comes from here, so what the rider reads is exactly what the
    /// planner ranked — including the wait for each bus and the traffic it will be sitting in.
    /// See `TripTiming`.
    private var schedule: TripTiming.Schedule {
        TripTiming.schedule(
            legs: legs.enumerated().map { index, leg in
                TripTiming.TimedLeg(
                    corridorID: leg.corridor.id,
                    rideMeters: rideMeters(of: leg),
                    stopCount: max(leg.stops.count - 1, 0),
                    transferMeters: transferMeters(before: index)
                )
            },
            walkToFirstStop: walkToBoardMeters,
            walkFromLastStop: walkFromAlightMeters,
            departingAt: Date()
        )
    }

    private func minutes(_ seconds: TimeInterval) -> Double { seconds / 60 }

    private var walkToBoardMinutes: Double { minutes(schedule.legs.first?.approach ?? 0) }
    private func transferMinutes(before index: Int) -> Double {
        minutes(index > 0 ? (schedule.legs[safe: index]?.approach ?? 0) : 0)
    }
    private func rideMinutes(of index: Int) -> Double { minutes(schedule.legs[safe: index]?.ride ?? 0) }
    private func waitMinutes(of index: Int) -> Double { minutes(schedule.legs[safe: index]?.wait ?? 0) }
    private var walkFromAlightMinutes: Double { minutes(schedule.finalWalk) }
    private var totalMinutes: Double { minutes(schedule.total) }

    private func boardTime(of index: Int) -> Date { schedule.legs[safe: index]?.boardAt ?? Date() }
    private func alightTime(of index: Int) -> Date { schedule.legs[safe: index]?.alightAt ?? Date() }
    private var arrivalTime: Date { schedule.arriveAt }
    
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

            if !isTripActive {
                Button {
                    Haptics.tap()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(Color.gray.opacity(0.15))
                        .clipShape(Circle())
                }
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
                        
                        // Right Action Icon (Camera button when landmark is present)
                        if nearbyLandmark != nil {
                            Button {
                                Haptics.tap()
                                isShowingCamera = true
                            } label: {
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
                    
                    Button {
                        Haptics.tap()
                        onDismiss()
                    } label: {
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
                
                // Walk → bus → (walk → bus)… → walk, one badge per line ridden, so a trip
                // with a change reads as two buses rather than one.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Image(systemName: "figure.walk")
                        Text("\(Int(walkToBoardMinutes))min")

                        ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                            if index > 0 {
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                Image(systemName: "figure.walk")
                                Text("\(Int(transferMinutes(before: index)))min")
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                            Image(systemName: "bus")
                            Text(leg.corridor.id)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(leg.corridor.color)
                                .clipShape(Capsule())
                        }

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                        Image(systemName: "figure.walk")
                        Text("\(Int(walkFromAlightMinutes))min")
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.deepPrimaryPurple)
                }

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
                        label: "Walk \(Int(walkToBoardMinutes)) min (\(DirectionStep.formatted(walkToBoardMeters)))",
                        labelColor: .secondary,
                        icon: "figure.walk",
                        time: nil,
                        showLine: true
                    )
                    
                    ForEach(Array(legs.enumerated()), id: \.element.id) { index, leg in
                        legRows(for: leg, at: index)
                    }

                    timelineRow(
                        dotStyle: .none,
                        label: "Walk \(Int(walkFromAlightMinutes)) min (\(DirectionStep.formatted(walkFromAlightMeters)))",
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
                    Haptics.success()
                    onEnd()
                } else {
                    Haptics.success()
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
        .fullScreenCover(isPresented: $isShowingCamera) {
            PortraitLocked {
                CameraView { videoURL in
                    onCapture(videoURL)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    /// One bus leg's rows: the walk over from the previous bus (when there is one), the
    /// boarding stop, the line badge, the collapsible middle stops, and the alighting stop.
    @ViewBuilder
    private func legRows(for leg: PlannedLeg, at index: Int) -> some View {
        let middle = intermediateStops(of: leg)
        let isExpanded = expandedLegIDs.contains(leg.id)

        if index > 0, transferMeters(before: index) > 0 {
            timelineRow(
                dotStyle: .none,
                label: "Change buses — walk \(Int(transferMinutes(before: index))) min (\(DirectionStep.formatted(transferMeters(before: index))))",
                labelColor: Color.primaryOrange,
                bold: true,
                icon: "figure.walk",
                time: nil,
                showLine: true
            )
        }

        if let board = leg.boardStop {
            timelineRow(
                dotStyle: .none,
                label: board.name,
                labelColor: Color.deepPrimaryPurple,
                bold: true,
                time: boardTime(of: index),
                showLine: true
            )

            // The wait is often the largest single slice of a trip — S1 every 45 minutes
            // averages 22 of them — so it is shown rather than buried in the total.
            timelineRow(
                dotStyle: .none,
                label: "Wait ~\(Int(waitMinutes(of: index).rounded())) min for \(leg.corridor.id) (every \(Int(leg.corridor.headwayMinutes)) min)",
                labelColor: .secondary,
                icon: "clock",
                time: nil,
                showLine: true
            )

            HStack {
                Image(systemName: "bus")
                Text(leg.corridor.id)
                    .fontWeight(.bold)
                Text(leg.direction.label)
                    .lineLimit(1)
            }
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(leg.corridor.color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.leading, 28)
            .padding(.bottom, 8)

            if !middle.isEmpty {
                Button {
                    Haptics.toggle()
                    withAnimation {
                        if isExpanded {
                            expandedLegIDs.remove(leg.id)
                        } else {
                            expandedLegIDs.insert(leg.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        Text("\(middle.count) Stops (\(formattedDuration(minutes: rideMinutes(of: index))))")
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

                if isExpanded {
                    ForEach(middle) { intermediateStop in
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

        if let alight = leg.alightStop {
            timelineRow(
                dotStyle: .filledOutline(Color.black),
                label: alight.name,
                labelColor: Color.deepPrimaryPurple,
                bold: true,
                time: alightTime(of: index),
                showLine: true
            )
        }
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
    
}

private extension Array {
    /// Timeline rows are built from `schedule.legs`, which is derived from `legs` and so
    /// always the same length — but reading it by index in a view builder is worth guarding
    /// rather than risking a crash mid-render.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview("Trip with a change") {
    let userLoc = CLLocationCoordinate2D(latitude: -8.7183, longitude: 115.1686)

    let firstStops = [
        stop("Tuban Murni Teguh 2", -8.7280, 115.1670),
        stop("Kuta Center", -8.7205, 115.1720),
        stop("Legian Junction", -8.7050, 115.1730),
        stop("Titi Banda", -8.6490, 115.2550)
    ]
    let firstDirection = RouteDirection(label: "Sentral Parkir Kuta - Titi Banda", stops: firstStops)
    let firstLeg = PlannedLeg(
        corridor: Corridor(id: "K5", name: "Kuta - Politeknik", color: .yellow, headwayMinutes: 22, directions: [firstDirection]),
        direction: firstDirection,
        stops: firstStops,
        polyline: []
    )

    let secondStops = [
        stop("Titi Banda", -8.6489, 115.2551),
        stop("Batubulan", -8.6180, 115.2760),
        stop("Puri Dalem Peliatan Ubud", -8.5100, 115.2690)
    ]
    let secondDirection = RouteDirection(label: "Terminal UBUNG - Monkey Forest Ubud", stops: secondStops)
    let secondLeg = PlannedLeg(
        corridor: Corridor(id: "K4", name: "Ubung - Ubud", color: .green, headwayMinutes: 22, directions: [secondDirection]),
        direction: secondDirection,
        stops: secondStops,
        polyline: []
    )

    let place = Place(
        name: "Arjuna Statue",
        desc: "A prominent Ubud roadside sculpture.",
        image: "placeholder-default",
        category: Category(name: "Statue", image: "placeholder-default"),
        latitude: -8.5090,
        longitude: 115.2711
    )

    TripPreviewSheet(
        place: place,
        legs: [firstLeg, secondLeg],
        userLocation: userLoc,
        nextStopName: nil,
        stopsRemaining: nil,
        minutesRemaining: nil,
        isTripActive: false,
        nearbyLandmark: nil,
        currentDetent: .constant(.medium),
        onStart: {},
        onEnd: {},
        onDismiss: {},
        onCapture: { _ in }
    )
}

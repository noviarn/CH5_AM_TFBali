//
//  TripPreviewSheet.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 20/08/26.
//

import SwiftUI
import CoreLocation

/// A walk the rider is on right now — to their first bus, or across a transfer — plus the
/// bus waiting at the far end of it.
struct WalkStep {
    let name: String
    let meters: CLLocationDistance
    let minutes: Int
    /// Nil on the final walk to the destination, where no bus follows.
    let thenRide: (corridor: String, stops: Int)?
    /// Full name of the line being caught, e.g. "Central Parkir Kuta - Politeknik Negeri Bali".
    var routeName: String?
    /// This walk is a change between two buses rather than the trip's first approach.
    var isTransfer = false
    /// Average wait for the bus at the end of this walk. Shown flat rather than counted down,
    /// because the rider hasn't reached the stop yet.
    var busWaitMinutes: Int?
    /// The rider is standing at the stop already, so the row stops being about the walk and
    /// starts being about the bus they are waiting for.
    var isWaitingAtStop = false
    /// When the bus is expected, one headway-average after the rider reached the stop. There
    /// is no live arrival feed, so once this passes all the sheet can say is that the bus is
    /// late — not how late.
    var waitEndsAt: Date?
}

/// The bus the rider is on, counted down to the stop they get off at rather than to the end
/// of the line.
struct RideStep {
    let stopName: String
    let stops: Int
    let minutes: Int
}

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
    let isTripActive: Bool // Track active route state
    let nearbyLandmark: NearbyLandmark?
    /// The full entry for `nearbyLandmark` — its photo, summary, activities and fun fact.
    var nearbyPOI: LandmarkPOI?
    /// The rider is at the destination — the last thing the bar says before the trip ends.
    var hasArrived = false
    /// Set only while the rider is on foot towards a stop — the walk to the first bus, or
    /// across a transfer. The collapsed bar shows that walk instead of the two stop columns,
    /// which have nothing to say until the rider is actually on a bus.
    var walkTarget: WalkStep?
    /// Set while the rider is on a bus — nil whenever `walkTarget` is set.
    var rideTarget: RideStep?
    @Binding var currentDetent: PresentationDetent
    let onStart: () -> Void
    let onEnd: () -> Void
    let onDismiss: () -> Void
    let onCapture: (URL) -> Void
    /// Opens the landmark's own page — the collapsed bar is the only place a passing landmark
    /// is offered now that the floating card is gone.
    var onLandmarkTap: () -> Void = {}
    
    /// Expanded state per leg, keyed by leg id — one shared flag would open every leg's stop
    /// list at once on a trip with a change.
    @State private var expandedLegIDs: Set<String> = []
    @State private var isShowingCamera = false
    /// The landmark card starts open — it only appears at all while a landmark is alongside,
    /// which is exactly when the rider wants to read it.
    @State private var isLandmarkCardExpanded = true
    
    /// The collapsed bar. Taller than the 80pt it used to be: the content here changes as the
    /// trip runs — current stop, next stop, time left — and at 80pt only one line of that
    /// survived. Shared with `RouteMapView`, which stacks its map overlays clear of this.
    static let minimizedHeight: CGFloat = 150
    private let minimizedDetent: PresentationDetent = .height(TripPreviewSheet.minimizedHeight)
    
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

    /// Both approach walks carry `NearestStopFinder.detourFactor`, the same allowance the
    /// planner made when it costed this trip — without it the sheet quoted a shorter journey
    /// than the card that led the rider here.
    private var walkToBoardMeters: CLLocationDistance {
        guard let origin = planningOrigin ?? userLocation, let boardStop else { return 0 }
        return origin.distance(to: boardStop.coordinate) * NearestStopFinder.detourFactor
    }

    private var walkFromAlightMeters: CLLocationDistance {
        guard let alightStop else { return 0 }
        return alightStop.coordinate.distance(to: destinationCoordinate) * NearestStopFinder.detourFactor
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
        return nearbyLandmark.prompt
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
        Group {
            if isMinimized {
                minimizedContent
            } else {
                fullContent
            }
        }
        .fullScreenCover(isPresented: $isShowingCamera) {
            PortraitLocked {
                CameraView { videoURL in
                    onCapture(videoURL)
                }
            }
            .ignoresSafeArea()
        }
    }
    
    // MARK: - Minimized state
    
    private var minimizedContent: some View {
        Group {
            if isTripActive {
                ridingSummary
            } else {
                destinationSummary
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            if isTripActive, nearbyLandmark != nil {
                onLandmarkTap()
            } else {
                withAnimation { currentDetent = .medium }
            }
        }
    }

    /// What the collapsed bar shows while riding: where the bus just was and where it stops
    /// next. This used to repeat the destination's name and description, which never changed
    /// for the whole journey and told the rider nothing about their progress.
    @ViewBuilder
    private var ridingSummary: some View {
        if hasArrived {
            summaryRow(
                icon: "mappin.and.ellipse",
                eyebrow: "You've arrived!",
                title: "Welcome to \(place.name)"
            )
        } else if let rideTarget, rideTarget.stops <= 1 {
            // One stop to go is the moment the rider has to act, so it stops being a progress
            // count and becomes an instruction — and it outranks a landmark, which would
            // otherwise send them looking out of the window as their stop goes past.
            summaryRow(
                icon: "bell.fill",
                eyebrow: "Get Ready!",
                title: "Get off at \(rideTarget.stopName)",
                pill: "Last stop · \(rideTarget.minutes) min"
            )
        } else if let nearbyLandmark {
            // Only true for a moment, and the one thing the rider has to act on before it is
            // behind them — so it takes the row over from whatever it was showing.
            summaryRow(
                icon: "eyes.inverse",
                eyebrow: nearbyLandmark.prompt,
                title: nearbyLandmark.name,
                showsCamera: true
            )
        } else if let walkTarget {
            walkSummary(walkTarget)
        } else if let rideTarget {
            summaryRow(
                icon: "bell.fill",
                title: "Your Stop: \(rideTarget.stopName)",
                pill: "\(rideTarget.stops) stops left · \(rideTarget.minutes) min"
            )
        }
        // Nothing at all until the route is computed: every row above needs numbers that do
        // not exist yet, and the two-column bar that used to fill this gap was the last of
        // the old design left on screen.
    }

    private let walkIconSize: CGFloat = 56
    private let walkRowSpacing: CGFloat = 12

    /// On foot towards a stop: one line saying which stop, and how far and how long it is.
    private func walkSummary(_ target: WalkStep) -> some View {
        // Re-renders every half minute so the wait actually counts down.
        TimelineView(.periodic(from: .now, by: 30)) { context in
            summaryRow(
                icon: walkIcon(target),
                eyebrow: walkEyebrow(target),
                title: walkTitle(target),
                pill: walkPill(target, now: context.date),
                footnote: walkFootnote(target, now: context.date)
            )
        }
    }

    /// Every state of the collapsed bar is this row: one round icon, a title, a pill of
    /// numbers, and sometimes a line under a divider saying what comes next.
    private func summaryRow(
        icon: String,
        eyebrow: String? = nil,
        title: String,
        pill: String? = nil,
        footnote: String? = nil,
        showsCamera: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: walkRowSpacing) {
                Circle()
                    .fill(Color.primaryPurple)
                    .frame(width: walkIconSize, height: walkIconSize)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    if let eyebrow {
                        Text(eyebrow)
                            .font(.system(size: 14, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryPurple)
                            .lineLimit(1)
                    }

                    Text(title)
                        .font(.system(size: 16, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryPurple)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let pill {
                        Text(pill)
                            .font(.system(size: 12, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentPurple, in: Capsule())
                    }
                }

                Spacer(minLength: 0)

                if showsCamera {
                    Button {
                        Haptics.tap()
                        isShowingCamera = true
                    } label: {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.white)
                            .frame(width: walkIconSize, height: walkIconSize)
                            .background(Color.primaryOrange, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            // The divider stays put whether or not there is a footnote, so the bar keeps the
            // same shape as the trip moves from one state to the next.
            VStack(alignment: .leading, spacing: 10) {
                Rectangle()
                    .fill(Color.primaryPurple.opacity(0.12))
                    .frame(height: 1)

                if let footnote {
                    Text(footnote)
                        .font(.system(size: 13, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.primaryPurple.opacity(0.7))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Line up under the headline's text, not under its icon.
            .padding(.leading, walkIconSize + walkRowSpacing)
        }
    }

    /// The line under the divider: what happens after this walk, or — once a bus is overdue —
    /// why it hasn't come.
    private func walkFootnote(_ target: WalkStep, now: Date) -> String? {
        if target.isWaitingAtStop {
            guard let waitEndsAt = target.waitEndsAt, now >= waitEndsAt else { return nil }
            return "Bus expected to be delayed due to traffic"
        }
        // The transfer row spends its pill on the next bus, so the walk the rider is actually
        // on has to be said here or it is never said at all.
        if target.isTransfer {
            return "Walk \(DirectionStep.formatted(target.meters)) · \(target.minutes) min to \(target.name)"
        }
        guard let ride = target.thenRide else { return nil }
        return "Then ride \(ride.corridor) · \(ride.stops) stop\(ride.stops == 1 ? "" : "s")"
    }

    private func walkEyebrow(_ target: WalkStep) -> String? {
        if target.isWaitingAtStop { return nil }
        if target.isTransfer { return "Transfer corridor!" }
        if target.thenRide == nil { return "Last little walk!" }
        return nil
    }

    private func walkTitle(_ target: WalkStep) -> String {
        // No bus at the end of this walk means it is the last stretch, to the place itself.
        guard let ride = target.thenRide else { return "Head to \(target.name)" }

        let line = target.routeName.map { "\(ride.corridor) \(Self.shortRouteName($0))" } ?? ride.corridor
        if target.isTransfer { return line }
        if target.isWaitingAtStop { return "Wait for \(line)" }
        return "Walk to \(target.name)"
    }

    private func walkIcon(_ target: WalkStep) -> String {
        if target.isWaitingAtStop { return "bus.fill" }
        // The last walk is an alert to act on, not a route to follow — the rider is being
        // told to leave the bus network behind.
        if target.thenRide == nil { return "bell.fill" }
        return "figure.walk"
    }

    /// Line names run to both ends of the route and every via — "Central Parkir Kuta -
    /// Politeknik Negeri Bali - Titi Banda (via Bandara)" is three lines in this row. The
    /// first two legs of the name are enough to recognise the bus.
    static func shortRouteName(_ name: String) -> String {
        name.components(separatedBy: " - ").prefix(2).joined(separator: " - ")
    }

    private func walkPill(_ target: WalkStep, now: Date) -> String {
        if let ride = target.thenRide, target.isTransfer, let wait = target.busWaitMinutes {
            return "\(ride.corridor) · Arrive in \(wait) min"
        }

        guard target.isWaitingAtStop, let ride = target.thenRide else {
            let walk = target.thenRide == nil ? " walk" : ""
            return "\(DirectionStep.formatted(target.meters))\(walk) · \(target.minutes) min"
        }

        guard let waitEndsAt = target.waitEndsAt else { return ride.corridor }
        let minutes = Int((waitEndsAt.timeIntervalSince(now) / 60).rounded(.up))
        guard minutes > 0 else { return "\(ride.corridor) · Arriving any minute" }
        return "\(ride.corridor) · Est. arrive in \(minutes) min"
    }

    // MARK: - Landmark card

    /// What used to float over the map as `LandmarkProximityCard`, now part of the sheet so
    /// there is one place a passing landmark is read about rather than two.
    private func landmarkCard(_ poi: LandmarkPOI) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NEXT LANDMARK")
                .font(.system(size: 14, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(Color.primaryPurple)

            HStack(spacing: 12) {
                Image(poi.primaryImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(poi.name)
                        .font(.system(size: 18, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryPurple)
                        .lineLimit(2)

                    if let landmarkPill {
                        Text(landmarkPill)
                            .font(.system(size: 12, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.accentPurple, in: Capsule())
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Haptics.tap()
                    withAnimation { isLandmarkCardExpanded.toggle() }
                } label: {
                    Image(systemName: isLandmarkCardExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.primaryPurple)
                }
                .buttonStyle(.plain)
            }

            if isLandmarkCardExpanded {
                Text(poi.summary)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Color.primaryPurple.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)

                if !poi.activities.isEmpty {
                    Text("WHAT TO DO")
                        .font(.system(size: 16, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryPurple)

                    ForEach(poi.activities, id: \.self) { activity in
                        HStack(spacing: 10) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.primaryPurple)
                                .frame(width: 32, height: 32)
                                .background(.white, in: Circle())

                            Text(activity.text)
                                .font(.system(size: 14, design: .rounded))
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(8)
                        .background(Color.accentPurple, in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                if let funFact = poi.funFact {
                    funFactCard(title: poi.funFactTitle, body: funFact)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondaryPurple.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
    }

    private func funFactCard(title: String?, body: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FUNFACT")
                .font(.system(size: 16, design: .rounded))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primaryOrange, in: RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 6) {
                if let title {
                    Text(title)
                        .font(.system(size: 14, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color.primaryPurple)
                }

                Text(body)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Color.primaryPurple.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    /// How far the landmark still is, and how long that is at bus speed.
    private var landmarkPill: String? {
        guard let nearbyLandmark else { return nil }
        let minutes = Int((TripTiming.ride(meters: nearbyLandmark.distance, stops: 0, departingAt: .now) / 60).rounded())
        return "\(DirectionStep.formatted(nearbyLandmark.distance)) · \(minutes) min"
    }

    /// Before the trip starts there are no stops to report yet, so the bar still introduces
    /// the place being explored.
    private var destinationSummary: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundStyle(Color.primaryPurple)
                    .lineLimit(2)
                Text(place.desc)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Color.primaryPurple.opacity(0.7))
                    .lineLimit(1)
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

    // MARK: - Full state (existing content, unchanged)
    
    private var fullContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // MARK: - Header Area
            HStack(alignment: .top, spacing: 12) {
                if isTripActive {
                    // The same row the collapsed bar shows, so pulling the sheet up changes
                    // how much is on screen rather than what the rider is being told.
                    ridingSummary
                } else {
                    // Inactive Trip State: Display Title/Landmark Name & Dismiss Button
                    VStack(alignment: .leading, spacing: 4) {
                        Text(place.name)
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryPurple)
                        
                        Text(place.desc)
                                                .font(.system(.caption, design: .rounded))
                                                .foregroundStyle(Color.primaryPurple.opacity(0.7))
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
                                .foregroundStyle(leg.corridor.labelColor)
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
                    .foregroundStyle(Color.primaryPurple)
                }

                Divider()
            }
            
            // No divider above the card: the header row draws its own.
            if isTripActive, let nearbyPOI {
                landmarkCard(nearbyPOI)
                Divider()
            }

            // MARK: - Timeline Route Details
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if isTripActive {
                        Text("Your Journey")
                            .font(.system(size: 20, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(Color.primaryPurple)
                            .padding(.bottom, 12)
                    }

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
                        labelColor: Color.primaryPurple,
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
                labelColor: Color.primaryPurple,
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
            .foregroundStyle(leg.corridor.labelColor)
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
                labelColor: Color.primaryPurple,
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
                            .foregroundStyle(Color.primaryPurple)
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
        images: ["placeholder-default"],
        category: Category(name: "Statue", image: "placeholder-default"),
        latitude: -8.5090,
        longitude: 115.2711
    )

    TripPreviewSheet(
        place: place,
        legs: [firstLeg, secondLeg],
        userLocation: userLoc,
        isTripActive: false,
        nearbyLandmark: nil,
        currentDetent: .constant(.medium),
        onStart: {},
        onEnd: {},
        onDismiss: {},
        onCapture: { _ in }
    )
}

/// The collapsed bar in each of the states it takes on while the rider is on foot. Set to the
/// same height the map uses so the preview shows what the rider actually gets.
private struct WalkStatePreview: View {
    let title: String
    var walkTarget: WalkStep?
    var rideTarget: RideStep?
    var nearbyLandmark: NearbyLandmark?
    var hasArrived = false

    var body: some View {
        let place = Place(
            name: "Arjuna Statue",
            desc: "A prominent Ubud roadside sculpture.",
            images: ["placeholder-default"],
            category: Category(name: "Statue", image: "placeholder-default"),
            latitude: -8.5090,
            longitude: 115.2711
        )

        VStack(alignment: .leading) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TripPreviewSheet(
                place: place,
                legs: [],
                userLocation: nil,
                isTripActive: true,
                nearbyLandmark: nearbyLandmark,
                hasArrived: hasArrived,
                walkTarget: walkTarget,
                rideTarget: rideTarget,
                currentDetent: .constant(.height(TripPreviewSheet.minimizedHeight)),
                onStart: {},
                onEnd: {},
                onDismiss: {},
                onCapture: { _ in }
            )
            .frame(height: TripPreviewSheet.minimizedHeight)
            .background(.background, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

#Preview("Expanded sheet — landmark alongside") {
    let place = Place(
        name: "Arjuna Statue",
        desc: "A prominent Ubud roadside sculpture.",
        images: ["placeholder-default"],
        category: Category(name: "Statue", image: "placeholder-default"),
        latitude: -8.5090,
        longitude: 115.2711
    )

    TripPreviewSheet(
        place: place,
        legs: [],
        userLocation: nil,
        isTripActive: true,
        nearbyLandmark: NearbyLandmark(index: 1, distance: 1400, side: .right, name: landmarkPOIs[1].name),
        nearbyPOI: landmarkPOIs[1],
        rideTarget: RideStep(stopName: "RS Siloam", stops: 7, minutes: 31),
        currentDetent: .constant(.medium),
        onStart: {},
        onEnd: {},
        onDismiss: {},
        onCapture: { _ in }
    )
}

#Preview("Collapsed bar — walking states") {
    let stopName = "Bypass Ngurah Rai 4 (Carwash)"
    let routeName = "Central Parkir Kuta - Politeknik Negeri Bali - Titi Banda (via Bandara)"

    ScrollView {
        VStack(spacing: 24) {
            WalkStatePreview(
                title: "Walking to the stop",
                walkTarget: WalkStep(
                    name: stopName,
                    meters: 197,
                    minutes: 3,
                    thenRide: (corridor: "K6", stops: 5)
                )
            )

            WalkStatePreview(
                title: "Waiting at the stop",
                walkTarget: WalkStep(
                    name: stopName,
                    meters: 12,
                    minutes: 1,
                    thenRide: (corridor: "K5", stops: 10),
                    routeName: routeName,
                    isWaitingAtStop: true,
                    waitEndsAt: .now.addingTimeInterval(15 * 60)
                )
            )

            WalkStatePreview(
                title: "Waiting, bus overdue",
                walkTarget: WalkStep(
                    name: stopName,
                    meters: 12,
                    minutes: 1,
                    thenRide: (corridor: "K5", stops: 10),
                    routeName: routeName,
                    isWaitingAtStop: true,
                    waitEndsAt: .now.addingTimeInterval(-60)
                )
            )

            WalkStatePreview(
                title: "On the bus",
                rideTarget: RideStep(stopName: "RS Siloam", stops: 7, minutes: 31)
            )

            WalkStatePreview(
                title: "On the bus, stop coming up",
                rideTarget: RideStep(stopName: "RS Siloam", stops: 1, minutes: 4)
            )

            WalkStatePreview(
                title: "Get ready to get off",
                rideTarget: RideStep(stopName: "RS Siloam", stops: 1, minutes: 2)
            )

            WalkStatePreview(
                title: "Transfer between buses",
                walkTarget: WalkStep(
                    name: "Pantai Sindhu",
                    meters: 180,
                    minutes: 3,
                    thenRide: (corridor: "K3B", stops: 6),
                    routeName: "Terminal Ubung - Sanur",
                    isTransfer: true,
                    busWaitMinutes: 12
                )
            )

            WalkStatePreview(
                title: "Last walk to the destination",
                walkTarget: WalkStep(name: "Bajra Shandi Monument", meters: 500, minutes: 6, thenRide: nil)
            )

            WalkStatePreview(title: "Arrived", hasArrived: true)

            WalkStatePreview(
                title: "Landmark alongside",
                rideTarget: RideStep(stopName: "RS Siloam", stops: 7, minutes: 31),
                nearbyLandmark: NearbyLandmark(index: 0, distance: 120, side: .right, name: "Dewa Ruci Statue")
            )
        }
        .padding()
    }
    .background(Color.gray.opacity(0.15))
}

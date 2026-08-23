import MapKit

struct NearbyLandmark: Equatable {
    let index: Int
    let distance: CLLocationDistance
    let side: Side
    let name: String

    enum Side: String {
        case left
        case right
        case ahead
    }

    var sideDescription: String {
        switch side {
        case .left: "on your left"
        case .right: "on your right"
        case .ahead: "ahead"
        }
    }

    /// How the announcement should read, which changes as the bus closes in. Landmarks are
    /// called a kilometre out so there is time to read what the place is; being told to look
    /// left that early only sends the rider staring at the wrong buildings. The instruction
    /// arrives once the thing is actually out there to see.
    enum Stage {
        /// Far enough that the card is something to read, not something to act on.
        case ahead
        /// Close enough to be worth putting the phone down for.
        case approaching
        /// In view now.
        case inSight
    }

    var stage: Stage {
        if distance <= LandmarkProximityDetector.inSightDistance { return .inSight }
        if distance <= LandmarkProximityDetector.approachingDistance { return .approaching }
        return .ahead
    }

    var prompt: String {
        switch stage {
        case .ahead: "Coming up"
        case .approaching: "Almost there"
        case .inSight: "Look \(sideDescription)!"
        }
    }

    var formattedDistance: String {
        String(format: "%.0f m", distance)
    }
}

/// Plain synchronous proximity math.
///
/// This was an actor, which meant every check hopped off the main actor and the result
/// landed a tick or more later — combined with the stale ticker in `ContentView` a landmark
/// could take a minute to light up, and then stayed lit long after the bus had passed it.
/// There is nothing to serialize here: it is a handful of distance calculations.
enum LandmarkProximityDetector {
    /// How close you must get before a landmark is announced. A kilometre out, which is far
    /// more than is needed to spot the place: the point is to give the rider time to read
    /// what it is before it goes past, not to point at it.
    static let enterThreshold: CLLocationDistance = 1000
    /// How far you must get before it is dropped. Must stay above `enterThreshold` — this is
    /// the hysteresis band for an already-active landmark, and setting it lower would make
    /// one announced near the outer edge blink off on the very next fix.
    ///
    /// In practice a landmark is normally cleared by having been ridden past rather than by
    /// this; see `passedLandmarkIndices` in `RouteMapView`.
    static let exitThreshold: CLLocationDistance = 1100
    /// Within this, the rider can actually see the place, so the wording switches to which
    /// window to look out of and the card stops offering something to read.
    static let inSightDistance: CLLocationDistance = 150
    /// The middle stretch: no longer just a heads-up, not yet in view.
    static let approachingDistance: CLLocationDistance = 500

    static func nearestLandmark(
        userLocation: CLLocationCoordinate2D?,
        landmark: Landmark?,
        heading: CLLocationDirection?,
        active: NearbyLandmark?,
        excluding excludedIndices: Set<Int> = [],
        names: [String] = []
    ) -> NearbyLandmark? {
        guard let userLocation, let landmark else { return nil }

        var nearest: (index: Int, distance: CLLocationDistance)?
        for (index, coordinate) in landmark.coordinates.enumerated() {
            guard !excludedIndices.contains(index) else { continue }
            let distance = userLocation.distance(to: coordinate)
            if let current = nearest, distance >= current.distance { continue }
            nearest = (index, distance)
        }

        guard let nearest else { return nil }

        let threshold = active?.index == nearest.index ? exitThreshold : enterThreshold
        guard nearest.distance <= threshold else { return nil }

        return NearbyLandmark(
            index: nearest.index,
            distance: nearest.distance,
            side: side(
                from: userLocation,
                to: landmark.coordinates[nearest.index],
                heading: heading
            ),
            name: names.indices.contains(nearest.index) ? names[nearest.index] : "Landmark \(nearest.index + 1)"
        )
    }

    /// Relative bearing decides the side: a landmark clockwise of where you are pointed is
    /// on your right, counter-clockwise is on your left. The old version compared raw
    /// unnormalized degrees, which flipped the answer whenever the difference went negative.
    private static func side(
        from userLocation: CLLocationCoordinate2D,
        to landmarkLocation: CLLocationCoordinate2D,
        heading: CLLocationDirection?
    ) -> NearbyLandmark.Side {
        guard let heading else { return .ahead }
        let relativeBearing = heading.shortestTurn(to: userLocation.bearing(to: landmarkLocation))
        return relativeBearing >= 0 ? .right : .left
    }
}

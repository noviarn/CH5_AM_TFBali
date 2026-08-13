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
    /// How close you must get before a landmark is announced.
    static let enterThreshold: CLLocationDistance = 100
    /// How far you must get before it is dropped. Wider than the enter threshold so a
    /// landmark sitting near the boundary does not blink on and off as GPS jitters.
    static let exitThreshold: CLLocationDistance = 140

    static func nearestLandmark(
        userLocation: CLLocationCoordinate2D?,
        landmark: Landmark?,
        heading: CLLocationDirection?,
        active: NearbyLandmark?,
        excluding excludedIndices: Set<Int> = []
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
            name: "Landmark \(nearest.index + 1)"
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

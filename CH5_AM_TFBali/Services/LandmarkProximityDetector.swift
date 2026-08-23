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
    ///
    /// Sized for a rider on a moving bus, not on foot. At 100 m — the on-foot value this
    /// started at — a bus doing 30-40 km/h is inside the radius for about ten seconds, which
    /// is not long enough to notice the banner and hit the camera; and measured against the
    /// real corridor data, most POIs sit further than that from the road the bus takes, so
    /// they could never fire at all. See `routePassRadius` for the matching route-side filter.
    static let enterThreshold: CLLocationDistance = 250
    /// How far you must get before it is dropped. Wider than the enter threshold so a
    /// landmark sitting near the boundary does not blink on and off as GPS jitters.
    static let exitThreshold: CLLocationDistance = 350
    /// How far off the drawn route a landmark can sit and still count as one the trip goes
    /// past. Kept a little wider than `enterThreshold`: the rider has to come within that to
    /// mark it, and the bus lane, the GPS fix and the drawn corridor shape all differ by tens
    /// of metres in practice, so a landmark marginally outside can still come into range.
    ///
    /// These three are the tuning knobs for this feature — raise them if field tests show
    /// landmarks going unannounced, lower them if landmarks are offered for roads the bus
    /// never actually takes.
    static let routePassRadius: CLLocationDistance = 300

    /// Whether a route actually goes past `coordinate` — measured to the route *line*, not to
    /// its vertices, which sit far enough apart on a straight stretch to put a roadside
    /// landmark hundreds of metres from the nearest one.
    static func routePasses(
        _ coordinate: CLLocationCoordinate2D,
        along path: [CLLocationCoordinate2D]
    ) -> Bool {
        guard let progress = RouteGeometry.progress(of: coordinate, along: path) else { return false }
        return progress.offRouteDistance <= routePassRadius
    }

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

#if DEBUG
extension LandmarkProximityDetector {
    static func runSelfCheck() {
        // A straight north-south path ~1.1 km long, vertices ~111 m apart so the gaps between
        // them are wider than the pass radius — a vertex-distance check would fail these.
        let path = (0...10).map { CLLocationCoordinate2D(latitude: -8.700 + Double($0) * 0.001, longitude: 115.200) }

        func offset(latitude: Double, metresEast: Double) -> CLLocationCoordinate2D {
            let metresPerLongitude = 111_320.0 * cos(latitude * .pi / 180)
            return CLLocationCoordinate2D(latitude: latitude, longitude: 115.200 + metresEast / metresPerLongitude)
        }

        // 1. Right on the line, and midway between two vertices — the case a nearest-vertex
        //    check gets wrong.
        assert(routePasses(CLLocationCoordinate2D(latitude: -8.6955, longitude: 115.200), along: path))

        // 2. Just inside and just outside the pass radius, measured perpendicular to the line.
        assert(routePasses(offset(latitude: -8.6955, metresEast: routePassRadius - 20), along: path))
        assert(!routePasses(offset(latitude: -8.6955, metresEast: routePassRadius + 200), along: path))

        // 3. Beyond the far end of the route, not merely off to one side: a landmark further
        //    along the same road the bus never reaches must not count as passed.
        assert(!routePasses(CLLocationCoordinate2D(latitude: -8.680, longitude: 115.200), along: path))

        // 4. No route at all — nothing is passed, rather than everything.
        assert(!routePasses(path[0], along: []))

        // 5. Hysteresis: a landmark drifting past `enterThreshold` stays active until it
        //    passes the wider `exitThreshold`, so it doesn't blink on and off.
        let landmark = Landmark(name: "L", coordinates: [path[5]])
        let justOutsideEnter = offset(latitude: path[5].latitude, metresEast: (enterThreshold + exitThreshold) / 2)
        assert(
            nearestLandmark(userLocation: justOutsideEnter, landmark: landmark, heading: nil, active: nil) == nil,
            "expected no landmark before the rider is within the enter threshold"
        )
        let active = NearbyLandmark(index: 0, distance: 10, side: .ahead, name: "L")
        assert(
            nearestLandmark(userLocation: justOutsideEnter, landmark: landmark, heading: nil, active: active) != nil,
            "expected an already-active landmark to survive out to the exit threshold"
        )

        // 6. A landmark already marked this trip is not offered again.
        assert(
            nearestLandmark(userLocation: path[5], landmark: landmark, heading: nil, active: nil, excluding: [0]) == nil,
            "expected an already-marked landmark to stay excluded"
        )

        print("✅ LandmarkProximityDetector.runSelfCheck passed")
    }
}
#endif

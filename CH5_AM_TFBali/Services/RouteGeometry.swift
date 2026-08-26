import MapKit

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        let loc1 = CLLocation(latitude: latitude, longitude: longitude)
        let loc2 = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return loc1.distance(from: loc2)
    }

    /// Initial great-circle bearing, normalized to 0..<360.
    func bearing(to other: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = latitude * .pi / 180
        let lon1 = longitude * .pi / 180
        let lat2 = other.latitude * .pi / 180
        let lon2 = other.longitude * .pi / 180

        let dlon = lon2 - lon1
        let y = sin(dlon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dlon)

        return (atan2(y, x) * 180 / .pi).normalizedCompassHeading
    }
}

extension CLLocationDirection {
    var normalizedCompassHeading: CLLocationDirection {
        let normalized = truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }

    /// Signed turn from self to `other`, in -180...180. Positive is clockwise.
    /// Interpolating or comparing raw headings without this spins the long way round
    /// when crossing north.
    func shortestTurn(to other: CLLocationDirection) -> CLLocationDirection {
        let delta = (other - self).truncatingRemainder(dividingBy: 360)
        if delta > 180 { return delta - 360 }
        if delta < -180 { return delta + 360 }
        return delta
    }
}

/// A direction chevron placed along a route leg, pointing the way that leg travels.
struct RouteArrow: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let heading: CLLocationDirection
}

/// Where the user sits along a route polyline.
struct RouteProgress: Equatable {
    /// Index of the vertex that starts the segment the user is on.
    let index: Int
    /// The user's position projected onto that segment.
    let projected: CLLocationCoordinate2D
    /// Distance from the user to the line itself.
    let offRouteDistance: CLLocationDistance

    static func == (lhs: RouteProgress, rhs: RouteProgress) -> Bool {
        lhs.index == rhs.index
            && lhs.offRouteDistance == rhs.offRouteDistance
            && lhs.projected.latitude == rhs.projected.latitude
            && lhs.projected.longitude == rhs.projected.longitude
    }
}

enum RouteGeometry {
    static let offRouteThreshold: CLLocationDistance = 120
    static let defaultSearchWindow = 120

    /// Projects `location` onto `coordinates`, searching forward from `searchStart` first.
    ///
    /// A global nearest-point search is wrong for this route: it is a loop that ends where
    /// it starts and doubles back on itself, so the globally nearest vertex is regularly on
    /// a stretch the rider has not reached yet — or already finished. Scanning a forward
    /// window keeps progress monotonic. The full scan only runs when the windowed match is
    /// far enough off the line that the rider genuinely needs re-acquiring.
    static func progress(
        of location: CLLocationCoordinate2D,
        along coordinates: [CLLocationCoordinate2D],
        from searchStart: Int = 0,
        window: Int = defaultSearchWindow
    ) -> RouteProgress? {
        guard coordinates.count >= 2 else { return nil }

        let lastSegment = coordinates.count - 2
        let start = min(max(searchStart, 0), lastSegment)
        let end = min(start + window, lastSegment)

        if let windowed = bestProjection(of: location, along: coordinates, in: start...end),
           windowed.offRouteDistance <= offRouteThreshold {
            return windowed
        }

        return bestProjection(of: location, along: coordinates, in: 0...lastSegment)
    }

    /// Index of the path vertex nearest `coordinate`. Used to place landmarks, bus stops
    /// and maneuver points in the order the route actually reaches them.
    static func nearestIndex(
        to coordinate: CLLocationCoordinate2D,
        along coordinates: [CLLocationCoordinate2D]
    ) -> Int {
        guard !coordinates.isEmpty else { return 0 }
        var bestIndex = 0
        var bestDistance = CLLocationDistance.infinity
        for (index, candidate) in coordinates.enumerated() {
            let distance = coordinate.distance(to: candidate)
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// A single chevron at the very start of `coordinates`, pointing the way that leg
    /// travels. Marks the leading edge of whatever's currently drawn rather than papering
    /// the whole line with them.
    /// The stretch of `path` between two points that sit on it. Falls back to a straight
    /// line when the shape hasn't loaded or the slice comes out backwards — better a rough
    /// line than none. Shared so the corridor drawn under a trip and the route drawn on top
    /// of it are trimmed by the same rule and can't disagree.
    static func slice(
        _ path: [CLLocationCoordinate2D],
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard path.count >= 2 else { return [start, end] }
        let startIndex = nearestIndex(to: start, along: path)
        let endIndex = nearestIndex(to: end, along: path)
        guard startIndex < endIndex else { return [start, end] }
        return Array(path[startIndex...endIndex])
    }

    /// How far apart two vertices are measured along the path itself. Straight-line distance
    /// understates this wherever the road bends, which matters when the question is "how far
    /// has the rider travelled since passing that", not "how far away is it".
    static func distance(
        along coordinates: [CLLocationCoordinate2D],
        from start: Int,
        to end: Int
    ) -> CLLocationDistance {
        guard start < end, coordinates.indices.contains(start), coordinates.indices.contains(end)
        else { return 0 }
        return (start..<end).reduce(0) { total, index in
            total + coordinates[index].distance(to: coordinates[index + 1])
        }
    }

    /// The stretch of `coordinates` still ahead of the user, starting exactly at their
    /// projected position so the drawn line meets the marker instead of jumping to the
    /// next vertex.
    static func remaining(
        _ coordinates: [CLLocationCoordinate2D],
        fromSegment segmentIndex: Int,
        projected: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard !coordinates.isEmpty else { return [] }
        let nextVertex = segmentIndex + 1
        guard nextVertex < coordinates.count else { return [] }
        return [projected] + Array(coordinates[nextVertex...])
    }

    /// Total length of a run of coordinates, in metres.
    static func length(of coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
        guard coordinates.count > 1 else { return 0 }
        return (0..<(coordinates.count - 1)).reduce(0) { total, i in
            total + coordinates[i].distance(to: coordinates[i + 1])
        }
    }

    private static func bestProjection(
        of location: CLLocationCoordinate2D,
        along coordinates: [CLLocationCoordinate2D],
        in range: ClosedRange<Int>
    ) -> RouteProgress? {
        guard range.lowerBound <= range.upperBound else { return nil }

        var best: RouteProgress?
        for index in range {
            let projected = closestPoint(
                to: location,
                onSegmentFrom: coordinates[index],
                to: coordinates[index + 1]
            )
            let distance = location.distance(to: projected)
            if let current = best, distance >= current.offRouteDistance { continue }
            best = RouteProgress(index: index, projected: projected, offRouteDistance: distance)
        }
        return best
    }

    /// Closest point on a segment, worked out in a local metres-per-degree plane — exact
    /// enough over the tens of metres between route vertices, and far cheaper than a
    /// proper geodesic projection at 1 Hz.
    private static func closestPoint(
        to location: CLLocationCoordinate2D,
        onSegmentFrom start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        let metersPerLatitude = 111_320.0
        let metersPerLongitude = 111_320.0 * cos(start.latitude * .pi / 180)

        let segmentX = (end.longitude - start.longitude) * metersPerLongitude
        let segmentY = (end.latitude - start.latitude) * metersPerLatitude
        let pointX = (location.longitude - start.longitude) * metersPerLongitude
        let pointY = (location.latitude - start.latitude) * metersPerLatitude

        let lengthSquared = segmentX * segmentX + segmentY * segmentY
        guard lengthSquared > 0 else { return start }

        let t = min(max((pointX * segmentX + pointY * segmentY) / lengthSquared, 0), 1)
        return CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * t,
            longitude: start.longitude + (end.longitude - start.longitude) * t
        )
    }
}

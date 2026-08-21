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

    struct Segment {
        let index: Int
        let waypoints: [CLLocationCoordinate2D]       // >= 2: stop_i, (via...), stop_i+1 — used for routing
        let overrideCoordinates: [CLLocationCoordinate2D]?  // if set, skip routing and use this polyline directly
    }

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
    static func headingArrow(at coordinates: [CLLocationCoordinate2D]) -> RouteArrow? {
        guard coordinates.count >= 2, coordinates[0].distance(to: coordinates[1]) > 0 else { return nil }
        return RouteArrow(coordinate: coordinates[0], heading: coordinates[0].bearing(to: coordinates[1]))
    }

    /// The heading leaving vertex `index`, for placing a turn marker at a maneuver point.
    static func outgoingHeading(
        at index: Int,
        along coordinates: [CLLocationCoordinate2D]
    ) -> CLLocationDirection? {
        guard coordinates.indices.contains(index) else { return nil }
        let nextIndex = min(index + 1, coordinates.count - 1)
        guard nextIndex != index else { return nil }
        return coordinates[index].bearing(to: coordinates[nextIndex])
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

    // MARK: - Static corridor polyline building (trip planner search)

    /// Pure: no network, no async. Turns a direction's stops + viaPoints + manualOverride
    /// into an ordered list of segments to route (or not route).
    static func segments(for direction: RouteDirection) -> [Segment] {
        guard direction.stops.count >= 2 else { return [] }
        var result: [Segment] = []
        for i in 0..<(direction.stops.count - 1) {
            let a = direction.stops[i].coordinate
            let b = direction.stops[i + 1].coordinate
            if let override = direction.manualOverride[i] {
                result.append(Segment(index: i, waypoints: [a, b], overrideCoordinates: override))
            } else {
                let via = direction.viaPoints[i] ?? []
                result.append(Segment(index: i, waypoints: [a] + via + [b], overrideCoordinates: nil))
            }
        }
        return result
    }

    /// Builds the full road-following polyline for a direction. Falls back to a straight
    /// line for any leg whose MKDirections request fails, so the map never shows a gap.
    static func polyline(
        for direction: RouteDirection,
        router: (@MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]?)? = nil
    ) async -> [CLLocationCoordinate2D] {
        let router = router ?? Self.router
        var full: [CLLocationCoordinate2D] = []
        for segment in segments(for: direction) {
            if let override = segment.overrideCoordinates {
                full.append(contentsOf: override)
                continue
            }
            for i in 0..<(segment.waypoints.count - 1) {
                let from = segment.waypoints[i]
                let to = segment.waypoints[i + 1]
                if let coords = await router(from, to) {
                    full.append(contentsOf: coords)
                } else {
                    full.append(contentsOf: [from, to])
                }
            }
        }
        return full
    }

    /// Pure: narrows a full-direction polyline down to just the stretch actually ridden between
    /// two stops, by snapping each stop to its closest point on the line and slicing between them.
    static func slice(
        _ polyline: [CLLocationCoordinate2D],
        from board: CLLocationCoordinate2D,
        to alight: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        guard polyline.count > 1 else { return polyline }
        let boardIndex = nearestIndex(in: polyline, to: board)
        let alightIndex = nearestIndex(in: polyline, to: alight)
        let lower = min(boardIndex, alightIndex)
        let upper = max(boardIndex, alightIndex)
        return Array(polyline[lower...upper])
    }

    static func nearestIndex(in polyline: [CLLocationCoordinate2D], to point: CLLocationCoordinate2D) -> Int {
        var bestIndex = 0
        var bestDistance = Double.greatestFiniteMagnitude
        for (index, coordinate) in polyline.enumerated() {
            let d = coordinate.distance(to: point)
            if d < bestDistance {
                bestDistance = d
                bestIndex = index
            }
        }
        return bestIndex
    }

    /// Pure: the map region that frames every given coordinate, so a picked route can be zoomed
    /// to instead of leaving the camera on the whole island.
    static func region(
        fitting coordinates: [CLLocationCoordinate2D],
        paddingFactor: Double = 1.4,
        minimumSpan: CLLocationDegrees = 0.005
    ) -> MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return nil }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * paddingFactor, minimumSpan),
            longitudeDelta: max((maxLon - minLon) * paddingFactor, minimumSpan)
        )
        return MKCoordinateRegion(center: center, span: span)
    }

    /// Road geometry baked ahead of time into Resources/RoutePolylines.json.
    ///
    /// MKDirections refuses everything after a burst of roughly 50 requests, and drawing the
    /// whole network needs 461 — measured, not guessed. Fetching at runtime therefore leaves
    /// most segments falling back to `[from, to]`, which is the straight lines on the map.
    /// Corridor data is static, so this is computed once by scripts/bake and shipped.
    private static let bakedPolylines: [String: [[Double]]] = {
        guard let url = Bundle.main.url(forResource: "RoutePolylines", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([String: [[Double]]].self, from: data)
        else { return [:] }
        return decoded
    }()

    static func bakedKey(corridorID: String, directionIndex: Int) -> String { "\(corridorID)|\(directionIndex)" }

    /// Direction IDs are fresh UUIDs on every launch, so the bake is keyed by corridor +
    /// direction index instead.
    static func bakedPolyline(corridorID: String, directionIndex: Int) -> [CLLocationCoordinate2D]? {
        decodeBaked(bakedPolylines[bakedKey(corridorID: corridorID, directionIndex: directionIndex)])
    }

    /// Split out so the self-check can exercise the decoding without a bundle.
    static func decodeBaked(_ pairs: [[Double]]?) -> [CLLocationCoordinate2D]? {
        guard let pairs, pairs.count > 1 else { return nil }
        let coordinates = pairs.compactMap { pair -> CLLocationCoordinate2D? in
            guard pair.count == 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
        return coordinates.count > 1 ? coordinates : nil
    }

    /// Injectable seam so tests/self-checks can stub out network routing.
    static var router: @MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? = drivingRoute

    private static func drivingRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        request.transportType = .automobile
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else {
                #if DEBUG
                print("⚠️ MKDirections returned no route \(from.latitude),\(from.longitude) → \(to.latitude),\(to.longitude)")
                #endif
                return nil
            }
            return route.polyline.coordinates()
        } catch {
            #if DEBUG
            print("⚠️ MKDirections failed \(from.latitude),\(from.longitude) → \(to.latitude),\(to.longitude): \(error)")
            #endif
            return nil
        }
    }
}

#if DEBUG
extension RouteGeometry {
    static func runSelfCheck() {
        let a = stop("A", 0, 0)
        let b = stop("B", 1, 1)
        let c = stop("C", 2, 2)
        let via = CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5)
        let override = [CLLocationCoordinate2D(latitude: 9, longitude: 9), CLLocationCoordinate2D(latitude: 9.5, longitude: 9.5)]

        let direction = RouteDirection(
            label: "self-check",
            stops: [a, b, c],
            viaPoints: [0: [via]],
            manualOverride: [1: override]
        )

        let segments = RouteGeometry.segments(for: direction)
        assert(segments.count == 2, "expected 2 segments for 3 stops, got \(segments.count)")
        assert(segments[0].waypoints.count == 3, "segment 0 should chain through 1 via point, got \(segments[0].waypoints.count) waypoints")
        assert(segments[0].overrideCoordinates == nil, "segment 0 should not have an override")
        assert(segments[1].overrideCoordinates?.count == 2, "segment 1 should use the 2-point manual override")
        assert(segments[1].overrideCoordinates?[0].latitude == 9, "segment 1 override should start at lat 9")

        // Slicing: a full corridor line must narrow to only the ridden stretch, so the map
        // doesn't draw the whole corridor (and its return leg) for a short trip.
        let line = (0...10).map { CLLocationCoordinate2D(latitude: 0, longitude: Double($0) * 0.001) }
        let ridden = RouteGeometry.slice(line, from: line[3], to: line[6])
        assert(ridden.count == 4, "expected 4 points for a 3-segment ride, got \(ridden.count)")
        assert(ridden.first!.longitude == line[3].longitude, "slice should start at the board stop")
        assert(ridden.last!.longitude == line[6].longitude, "slice should end at the alight stop")

        // Stops that don't sit exactly on a vertex still snap to the nearest one.
        let offset = CLLocationCoordinate2D(latitude: 0.00002, longitude: 0.00205)
        let snapped = RouteGeometry.slice(line, from: line[0], to: offset)
        assert(snapped.count == 3, "expected slice to snap an off-line stop to its nearest vertex, got \(snapped.count)")

        // Framing: the camera region must cover every coordinate of the picked route.
        assert(RouteGeometry.region(fitting: []) == nil, "an empty coordinate list has no region")
        let framed = RouteGeometry.region(fitting: [
            CLLocationCoordinate2D(latitude: -8.70, longitude: 115.20),
            CLLocationCoordinate2D(latitude: -8.60, longitude: 115.30)
        ])!
        assert(abs(framed.center.latitude - (-8.65)) < 0.0001, "region should centre between the extremes, got \(framed.center.latitude)")
        assert(framed.span.latitudeDelta > 0.1, "region should pad beyond the raw extent, got \(framed.span.latitudeDelta)")
        let tight = RouteGeometry.region(fitting: [CLLocationCoordinate2D(latitude: -8.7, longitude: 115.2)])!
        assert(tight.span.latitudeDelta >= 0.005, "a single point should still get a usable minimum span")

        // Baked geometry: malformed rows are dropped rather than crashing on pair[0], and a
        // direction that decodes to fewer than 2 usable points is treated as absent so the
        // caller falls back to routing instead of drawing a degenerate line.
        assert(RouteGeometry.decodeBaked(nil) == nil, "missing bake should read as absent")
        assert(RouteGeometry.decodeBaked([[1, 2]]) == nil, "a single point is not a polyline")
        assert(RouteGeometry.decodeBaked([[1, 2], [3]]) == nil, "a dropped malformed row must not leave a 1-point line")
        let decoded = RouteGeometry.decodeBaked([[1, 2], [3, 4], [5, 6]])
        assert(decoded?.count == 3, "expected 3 decoded coordinates, got \(decoded?.count ?? -1)")
        assert(decoded?[1].longitude == 4, "expected [lat, lon] ordering, got \(String(describing: decoded?[1]))")
        assert(RouteGeometry.bakedKey(corridorID: "K5", directionIndex: 1) == "K5|1", "bake key format changed")

        print("✅ RouteGeometry.runSelfCheck passed")
    }

    static func runAsyncSelfCheck() async {
        let stubRouter: @MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? = { _, _ in nil }

        let a = stop("A", 0, 0)
        let b = stop("B", 1, 1)
        let c = stop("C", 2, 2)
        let direction = RouteDirection(label: "async self-check", stops: [a, b, c])

        let result = await polyline(for: direction, router: stubRouter)
        let expected: [CLLocationCoordinate2D] = [a.coordinate, b.coordinate, b.coordinate, c.coordinate]
        assert(result.count == expected.count, "expected \(expected.count) coordinates on full fallback, got \(result.count)")
        for (r, e) in zip(result, expected) {
            assert(r.latitude == e.latitude && r.longitude == e.longitude, "fallback coordinate mismatch")
        }

        print("✅ RouteGeometry.runAsyncSelfCheck passed")
    }
}
#endif

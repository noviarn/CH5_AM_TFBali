import Foundation
import CoreLocation
import MapKit

enum RouteGeometry {
    struct Segment {
        let index: Int
        let waypoints: [CLLocationCoordinate2D]       // >= 2: stop_i, (via...), stop_i+1 — used for routing
        let overrideCoordinates: [CLLocationCoordinate2D]?  // if set, skip routing and use this polyline directly
    }

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
            return route.polyline.coordinates
        } catch {
            #if DEBUG
            print("⚠️ MKDirections failed \(from.latitude),\(from.longitude) → \(to.latitude),\(to.longitude): \(error)")
            #endif
            return nil
        }
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
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

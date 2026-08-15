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
    static func polyline(for direction: RouteDirection) async -> [CLLocationCoordinate2D] {
        var full: [CLLocationCoordinate2D] = []
        for segment in segments(for: direction) {
            if let override = segment.overrideCoordinates {
                full.append(contentsOf: override)
                continue
            }
            for i in 0..<(segment.waypoints.count - 1) {
                let from = segment.waypoints[i]
                let to = segment.waypoints[i + 1]
                if let coords = await drivingRoute(from: from, to: to) {
                    full.append(contentsOf: coords)
                } else {
                    full.append(contentsOf: [from, to])
                }
            }
        }
        return full
    }

    private static func drivingRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }
            return route.polyline.coordinates
        } catch {
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

        print("✅ RouteGeometry.runSelfCheck passed")
    }
}
#endif

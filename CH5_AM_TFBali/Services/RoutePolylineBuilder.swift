import Foundation
import CoreLocation
import MapKit

enum RoutePolylineBuilder {
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
    /// `hadFallback` tells the caller whether that happened anywhere in this direction — a
    /// result with a fallback shouldn't be cached to disk, or the degraded stretch would be
    /// served forever instead of getting a clean retry next time.
    static func polyline(
        for direction: RouteDirection,
        router: (@MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]?)? = nil
    ) async -> (coordinates: [CLLocationCoordinate2D], hadFallback: Bool) {
        let router = router ?? Self.router
        var full: [CLLocationCoordinate2D] = []
        var hadFallback = false
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
                    hadFallback = true
                }
            }
        }
        return (full, hadFallback)
    }
    
    /// Injectable seam so tests/self-checks can stub out network routing.
    static var router: @MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? = cachedDrivingRoute

    /// Checks the on-disk segment cache before ever hitting MapKit, and saves a fresh result
    /// there the moment it succeeds — independently of whether neighboring segments in the
    /// same leg succeed or not. See `RouteSegmentCache` for why per-segment (not per-leg).
    private static func cachedDrivingRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        let key = RouteSegmentCache.key(from: from, to: to)
        if let cached = await RouteSegmentCache.shared.coordinates(for: key) {
            return cached
        }
        guard let fetched = await drivingRoute(from: from, to: to) else { return nil }
        await RouteSegmentCache.shared.store(key: key, coordinates: fetched)
        return fetched
    }

    /// A throttled/failed request throws rather than returning an empty route list, and is
    /// often transient — a short backoff and retry regularly succeeds where firing straight
    /// back-to-back wouldn't. A genuine "no route between these points" (empty `routes`)
    /// isn't retried since trying again won't change that answer.
    private static let maxAttempts = 3

    private static func drivingRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        for attempt in 1...maxAttempts {
            await DirectionsThrottle.shared.waitIfNeeded()

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
                await DirectionsThrottle.shared.reportSuccess()
                return route.polyline.coordinates()
            } catch {
                await DirectionsThrottle.shared.reportFailure()
                guard attempt < maxAttempts else {
#if DEBUG
                    print("⚠️ MKDirections failed after \(maxAttempts) attempts \(from.latitude),\(from.longitude) → \(to.latitude),\(to.longitude): \(error)")
#endif
                    return nil
                }
                try? await Task.sleep(for: .milliseconds(400 * attempt))
            }
        }
        return nil
    }
}

/// Backpressure shared across every in-flight corridor/leg fetch, not just retries of one
/// failed segment. A single fixed delay per request was either too slow when things were
/// fine or not enough once the limit actually tripped (a 40+ stop leg queued right behind
/// another one keeps failing through its own retries since the underlying throttle window
/// hadn't cleared yet). This instead ramps a shared delay up on failure and eases it back
/// down on success, so whatever's queued next — the rest of this leg, or the next one —
/// automatically backs off while the limit is hot and speeds back up once it isn't.
private actor DirectionsThrottle {
    static let shared = DirectionsThrottle()

    private var delay: Duration = .zero
    private let maxDelay: Duration = .seconds(3)
    private let increment: Duration = .milliseconds(350)
    private let decrement: Duration = .milliseconds(60)

    func waitIfNeeded() async {
        guard delay > .zero else { return }
        try? await Task.sleep(for: delay)
    }

    func reportSuccess() {
        delay = max(.zero, delay - decrement)
    }

    func reportFailure() {
        delay = min(maxDelay, delay + increment)
    }
}

//private extension MKPolyline {
//    var coordinates: [CLLocationCoordinate2D] {
//        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
//        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
//        return coords
//    }
//}

#if DEBUG
extension RoutePolylineBuilder {
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
        
        let segments = RoutePolylineBuilder.segments(for: direction)
        assert(segments.count == 2, "expected 2 segments for 3 stops, got \(segments.count)")
        assert(segments[0].waypoints.count == 3, "segment 0 should chain through 1 via point, got \(segments[0].waypoints.count) waypoints")
        assert(segments[0].overrideCoordinates == nil, "segment 0 should not have an override")
        assert(segments[1].overrideCoordinates?.count == 2, "segment 1 should use the 2-point manual override")
        assert(segments[1].overrideCoordinates?[0].latitude == 9, "segment 1 override should start at lat 9")
        
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
        assert(result.coordinates.count == expected.count, "expected \(expected.count) coordinates on full fallback, got \(result.coordinates.count)")
        assert(result.hadFallback, "expected hadFallback to be true when every segment falls back")
        for (r, e) in zip(result.coordinates, expected) {
            assert(r.latitude == e.latitude && r.longitude == e.longitude, "fallback coordinate mismatch")
        }
        
        print("✅ RouteGeometry.runAsyncSelfCheck passed")
    }
}
#endif


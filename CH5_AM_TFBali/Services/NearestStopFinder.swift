import Foundation
import CoreLocation
import MapKit

enum NearestStopFinder {
    struct RankedStop {
        let stop: BusStop
        let walkingDistance: CLLocationDistance
    }

    /// Pure: every stop within `withinMeters` straight-line, nearest first, capped at `limit`,
    /// deduped by identical name+coordinate. No network.
    ///
    /// A fixed top-5 used to hide corridors here: if a corridor's stop was the 6th nearest it
    /// never entered the planner, so a direct route on it could not be found at all.
    static func nearestByStraightLine(
        to point: CLLocationCoordinate2D,
        withinMeters: CLLocationDistance = 1500,
        limit: Int = 12,
        stopReferences: [StopReference] = CorridorGraph.allStopReferences
    ) -> [BusStop] {
        var seenKeys = Set<String>()
        var uniqueStops: [BusStop] = []
        for ref in stopReferences {
            let key = "\(ref.stop.name)_\(ref.stop.coordinate.latitude)_\(ref.stop.coordinate.longitude)"
            if seenKeys.insert(key).inserted, ref.stop.coordinate.distance(to: point) <= withinMeters {
                uniqueStops.append(ref.stop)
            }
        }
        return Array(
            uniqueStops
                .sorted { $0.coordinate.distance(to: point) < $1.coordinate.distance(to: point) }
                .prefix(limit)
        )
    }

    /// Straight-line distance with a 1.3x detour factor. No network.
    ///
    /// ponytail: one MKDirections call per candidate per endpoint is ~24 calls a search once
    /// the candidate list is this wide, which is the rate limit the current design exists to
    /// avoid. Planning runs on this estimate; only the routes actually shown get refined by
    /// `walkingDistance`.
    static func rankedByStraightLine(candidates: [BusStop], to point: CLLocationCoordinate2D) -> [RankedStop] {
        candidates
            .map { RankedStop(stop: $0, walkingDistance: $0.coordinate.distance(to: point) * 1.3) }
            .sorted { $0.walkingDistance < $1.walkingDistance }
    }

    /// Refines straight-line candidates using real walking distance. Injectable router seam
    /// so self-checks can stub network calls, same pattern as RouteGeometry's `router`.
    static func rankedByWalkingDistance(
        candidates: [BusStop],
        to point: CLLocationCoordinate2D,
        router: (@MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> CLLocationDistance?)? = nil
    ) async -> [RankedStop] {
        let router = router ?? Self.walkingDistance
        var ranked: [RankedStop] = []
        for candidate in candidates {
            let distance = await router(candidate.coordinate, point) ?? candidate.coordinate.distance(to: point)
            ranked.append(RankedStop(stop: candidate, walkingDistance: distance))
        }
        return ranked.sorted { $0.walkingDistance < $1.walkingDistance }
    }

    @MainActor
    static func walkingDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> CLLocationDistance? {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: from.latitude, longitude: from.longitude), address: nil)
        request.destination = MKMapItem(location: CLLocation(latitude: to.latitude, longitude: to.longitude), address: nil)
        request.transportType = .walking
        do {
            let response = try await MKDirections(request: request).calculate()
            return response.routes.first?.distance
        } catch {
            return nil
        }
    }
}

#if DEBUG
extension NearestStopFinder {
    static func runSelfCheck() {
        let point = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let s1 = stop("S1", 0, 0.001)
        let s2 = stop("S2", 0, 0.002)
        let s3 = stop("S3", 0, 0.003)
        let s4 = stop("S4", 0, 0.004)
        let s5 = stop("S5", 0, 0.005)
        let s1Duplicate = stop("S1", 0, 0.001) // same name+coordinate as s1 -> must not count as a 6th candidate

        let direction = RouteDirection(label: "fake", stops: [s1, s2, s3, s4, s5, s1Duplicate])
        let refs = direction.stops.enumerated().map { index, s in
            StopReference(corridorID: "FAKE", directionID: direction.id, stopIndex: index, stop: s)
        }

        let nearest = nearestByStraightLine(to: point, withinMeters: 1500, limit: 12, stopReferences: refs)
        assert(nearest.count == 5, "expected 5 unique candidates, got \(nearest.count)")
        assert(nearest.map(\.name) == ["S1", "S2", "S3", "S4", "S5"], "expected straight-line order S1...S5, got \(nearest.map(\.name))")

        // Stops beyond the radius are dropped, not merely ranked last — S5 sits ~556m out.
        let nearby = nearestByStraightLine(to: point, withinMeters: 400, limit: 12, stopReferences: refs)
        assert(nearby.map(\.name) == ["S1", "S2", "S3"], "expected radius to cut at 400m, got \(nearby.map(\.name))")

        print("✅ NearestStopFinder.runSelfCheck passed")
    }

    static func runAsyncSelfCheck() async {
        let point = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        let s1 = stop("S1", 0, 0.001)
        let s2 = stop("S2", 0, 0.002)
        let s3 = stop("S3", 0, 0.003)
        let s4 = stop("S4", 0, 0.004)
        let s5 = stop("S5", 0, 0.005)

        // Stub walking distances that deliberately invert the straight-line order,
        // proving the final ranking follows walking distance, not straight-line distance.
        let stubDistances: [String: CLLocationDistance] = [
            "S1": 500, "S2": 100, "S3": 300, "S4": 50, "S5": 400
        ]
        let stubRouter: @MainActor (CLLocationCoordinate2D, CLLocationCoordinate2D) async -> CLLocationDistance? = { from, _ in
            let match = [s1, s2, s3, s4, s5].first { $0.coordinate.latitude == from.latitude && $0.coordinate.longitude == from.longitude }
            return match.flatMap { stubDistances[$0.name] }
        }

        let ranked = await rankedByWalkingDistance(candidates: [s1, s2, s3, s4, s5], to: point, router: stubRouter)
        let expectedOrder = ["S4", "S2", "S3", "S5", "S1"]
        assert(ranked.map(\.stop.name) == expectedOrder, "expected walking-distance order \(expectedOrder), got \(ranked.map(\.stop.name))")

        print("✅ NearestStopFinder.runAsyncSelfCheck passed")
    }
}
#endif

import Foundation
import CoreLocation
import MapKit

enum NearestStopFinder {
    struct RankedStop {
        let stop: BusStop
        let walkingDistance: CLLocationDistance
    }

    /// Pure: top `count` stops by straight-line distance, deduped by identical name+coordinate. No network.
    static func nearestByStraightLine(
        to point: CLLocationCoordinate2D,
        count: Int = 5,
        stopReferences: [StopReference] = CorridorGraph.allStopReferences
    ) -> [BusStop] {
        var seenKeys = Set<String>()
        var uniqueStops: [BusStop] = []
        for ref in stopReferences {
            let key = "\(ref.stop.name)_\(ref.stop.coordinate.latitude)_\(ref.stop.coordinate.longitude)"
            if seenKeys.insert(key).inserted {
                uniqueStops.append(ref.stop)
            }
        }
        return Array(
            uniqueStops
                .sorted { $0.coordinate.distance(to: point) < $1.coordinate.distance(to: point) }
                .prefix(count)
        )
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
    private static func walkingDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> CLLocationDistance? {
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

        let nearest = nearestByStraightLine(to: point, count: 5, stopReferences: refs)
        assert(nearest.count == 5, "expected 5 unique candidates, got \(nearest.count)")
        assert(nearest.map(\.name) == ["S1", "S2", "S3", "S4", "S5"], "expected straight-line order S1...S5, got \(nearest.map(\.name))")

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

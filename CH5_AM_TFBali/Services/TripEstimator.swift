//
//  TripEstimator.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 15/08/26.
//
import Foundation
import CoreLocation

// MARK: - Result type

struct PlaceTripEstimate {
    let duration: String        // formatted, e.g. "3h 20m"
    let busRideCount: Int       // number of distinct route legs taken
    let distanceKm: Double      // distance from user to their nearest boarding stop
    /// Whole-trip distance: the walk to the boarding stop plus every ride leg, measured
    /// stop-to-stop along the route. Follows the route rather than a straight user->landmark
    /// line, so it doesn't under-report the way crow-flies distance would.
    let totalDistanceKm: Double
    /// True when no bus path was found and these numbers are a straight-line fallback rather
    /// than a real transit estimate. The UI marks these with a "~" so they read as rough.
    let isApproximate: Bool
}

// MARK: - Estimator

/// Works estimates out one at a time and remembers them.
///
/// Both halves matter. A lazy grid rebuilds its cards constantly while scrolling, so every
/// card asked for an estimate again each time it reappeared — and the search is heavy enough
/// that a screenful of them at once saturated the CPU. Being an actor serialises the work;
/// the cache means a card that comes back into view costs nothing at all.
actor TripEstimateCache {
    static let shared = TripEstimateCache()

    private var entries: [Key: PlaceTripEstimate] = [:]

    private struct Key: Hashable {
        let place: Int
        let user: Int
    }

    /// ~11 m buckets, so a jittering fix doesn't invalidate every entry.
    private static func bucket(_ coordinate: CLLocationCoordinate2D) -> Int {
        let latitude = Int(((coordinate.latitude + 90) * 10_000).rounded())
        let longitude = Int(((coordinate.longitude + 180) * 10_000).rounded())
        return latitude &* 4_000_000 &+ longitude
    }

    func estimate(
        to placeLocation: CLLocationCoordinate2D,
        from userLocation: CLLocationCoordinate2D
    ) -> PlaceTripEstimate {
        let key = Key(place: Self.bucket(placeLocation), user: Self.bucket(userLocation))
        if let cached = entries[key] { return cached }

        let estimate = TripEstimator.estimateTrip(to: placeLocation, from: userLocation)
        entries[key] = estimate
        return estimate
    }
}

enum TripEstimator {
    /// Only used by the straight-line fallback, for a place no bus reaches.
    private static let averageBusSpeedKmh: Double = 20

    /// The trip a card promises is the trip the map will plan: same `RoutePlanner` search,
    /// same winner, same `TripTiming` clock. It used to be a second estimator of its own —
    /// its own nearest-stop lookup, its own path search, flat average speeds and a fixed
    /// transfer penalty — so a card could advertise "1h 24m" for a journey the trip sheet
    /// then costed at 2h 52m.
    ///
    /// ponytail: the whole two-change search runs per place (~0.35 s). It is off the main
    /// actor and cached per place/location bucket, so a card pays it once. If a screenful of
    /// new places ever feels slow to fill in, capping `maxTransfers` at 1 here is the knob —
    /// at the cost of under-reporting trips that really do need two changes.
    static func estimateTrip(
        to placeLocation: CLLocationCoordinate2D,
        from userLocation: CLLocationCoordinate2D
    ) -> PlaceTripEstimate {
        let originCandidates = NearestStopFinder.rankedByStraightLine(
            candidates: NearestStopFinder.nearestByStraightLine(to: userLocation),
            to: userLocation
        )
        let destinationCandidates = NearestStopFinder.rankedByStraightLine(
            candidates: NearestStopFinder.nearestByStraightLine(to: placeLocation),
            to: placeLocation
        )
        let routes = RoutePlanner.findRoutes(
            originCandidates: originCandidates,
            destinationCandidates: destinationCandidates,
            transferIndex: .standard
        )
        // `findRoutes` returns its picks fastest-first, and the map takes the same first one.
        guard let route = routes.first else {
            return straightLineEstimate(to: placeLocation, from: userLocation)
        }

        let rideMeters = route.legs.reduce(0.0) { $0 + $1.rideDistance }
        return PlaceTripEstimate(
            duration: formattedDuration(minutes: route.estimatedDuration / 60),
            busRideCount: route.legs.count,
            distanceKm: route.walkToFirstStop / 1000,
            totalDistanceKm: (route.totalWalk + rideMeters) / 1000,
            isApproximate: false
        )
    }

    /// Crow-flies distance user -> place with a rough time from the average bus speed. Used
    /// only when no bus path is found; flagged approximate so the UI can mark it.
    private static func straightLineEstimate(
        to placeLocation: CLLocationCoordinate2D,
        from userLocation: CLLocationCoordinate2D
    ) -> PlaceTripEstimate {
        let km = userLocation.distance(to: placeLocation) / 1000
        let minutes = (km / averageBusSpeedKmh) * 60
        return PlaceTripEstimate(
            duration: formattedDuration(minutes: minutes),
            busRideCount: 0,
            distanceKm: km,
            totalDistanceKm: km,
            isApproximate: true
        )
    }

    private static func formattedDuration(minutes: Double) -> String {
        let totalMinutes = Int(minutes.rounded())
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
        }
        return "\(mins)m"
    }
}

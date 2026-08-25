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

// MARK: - Internal path representation

/// One leg of a multi-leg trip: ride this direction from boardIndex to alightIndex.
private struct RouteLeg {
    let direction: RouteDirection
    let boardIndex: Int
    let alightIndex: Int
}

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

        let estimate = TripEstimator.estimateTrip(
            to: placeLocation,
            from: userLocation,
            corridors: corridors
        )
        entries[key] = estimate
        return estimate
    }
}

// MARK: - Estimator

enum TripEstimator {
    
    /// Average speed assumptions used to convert distance into a time estimate,
    /// since Corridor/RouteDirection data has no built-in travel-time field.
    private static let averageBusSpeedKmh: Double = 20
    private static let averageWalkingSpeedKmh: Double = 4.5
    private static let transferPenaltyMinutes: Double = 5 // wait time per transfer
    
    /// Always returns a figure: a real transit estimate when a bus path exists, otherwise a
    /// straight-line fallback (marked `isApproximate`) so a card is never left blank for a
    /// place the network doesn't reach.
    static func estimateTrip(
        to placeLocation: CLLocationCoordinate2D,
        from userLocation: CLLocationCoordinate2D,
        corridors: [Corridor]
    ) -> PlaceTripEstimate {
        transitEstimate(to: placeLocation, from: userLocation, corridors: corridors)
            ?? straightLineEstimate(to: placeLocation, from: userLocation)
    }

    private static func transitEstimate(
        to placeLocation: CLLocationCoordinate2D,
        from userLocation: CLLocationCoordinate2D,
        corridors: [Corridor]
    ) -> PlaceTripEstimate? {

        // 1. Find nearest boarding stop to the user, across all directions in all corridors.
        guard let (startStop, startDistance) = nearestStop(to: userLocation, corridors: corridors) else {
            return nil
        }

        // 2. Find nearest alighting stop to the place.
        guard let (endStop, _) = nearestStop(to: placeLocation, corridors: corridors) else {
            return nil
        }

        // 3. Search for a path of legs connecting startStop -> endStop,
        //    allowing transfers at stops that share the same coordinate across directions.
        guard let legs = findPath(from: startStop, to: endStop, corridors: corridors) else {
            return nil
        }

        // 4. Sum ride distance + estimated time across all legs + transfer penalties.
        let rideDistanceKm = legs.reduce(0.0) { $0 + legDistanceKm(for: $1) }
        let totalMinutes = (rideDistanceKm / averageBusSpeedKmh) * 60
            + Double(max(legs.count - 1, 0)) * transferPenaltyMinutes

        return PlaceTripEstimate(
            duration: formattedDuration(minutes: totalMinutes),
            busRideCount: legs.count,
            distanceKm: startDistance,
            totalDistanceKm: startDistance + rideDistanceKm,
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
    
    // MARK: - Nearest stop lookup
    
    private static func nearestStop(
        to coordinate: CLLocationCoordinate2D,
        corridors: [Corridor]
    ) -> (stop: BusStop, distanceKm: Double)? {
        // Measured through the coordinate extension rather than by building a CLLocation per
        // stop: this runs over all 478 stops, twice per estimate.
        var best: (BusStop, Double)?
        for corridor in corridors {
            for direction in corridor.directions {
                for stop in direction.stops {
                    let distanceKm = coordinate.distance(to: stop.coordinate) / 1000
                    if best == nil || distanceKm < best!.1 {
                        best = (stop, distanceKm)
                    }
                }
            }
        }
        return best
    }
    
    // MARK: - Path search (BFS across directions, transferring at shared-coordinate stops)
    
    private static func findPath(
        from start: BusStop,
        to end: BusStop,
        corridors: [Corridor]
    ) -> [RouteLeg]? {
        // Flatten all directions for easy lookup.
        let allDirections = corridors.flatMap { $0.directions }
        
        // BFS queue: each entry is (current stop, legs taken so far, visited direction IDs to avoid loops)
        var queue: [(stop: BusStop, legs: [RouteLeg])] = [(start, [])]
        var visitedStopKeys: Set<Int> = [key(for: start.coordinate)]
        let endKey = key(for: end.coordinate)

        // Every direction's stop keys, worked out once. Recomputing them inside the search
        // meant hashing the same coordinates again at every node visited.
        let directionKeys = allDirections.map { $0.stops.map { key(for: $0.coordinate) } }

        while !queue.isEmpty {
            let (currentStop, legs) = queue.removeFirst()

            if legs.count > 3 { continue } // cap transfers to keep search bounded

            let currentKey = key(for: currentStop.coordinate)
            if currentKey == endKey {
                return legs
            }

            // Try every direction that contains a stop matching currentStop's coordinate.
            for (directionIndex, direction) in allDirections.enumerated() {
                let stopKeys = directionKeys[directionIndex]
                guard let boardIndex = stopKeys.firstIndex(of: currentKey) else { continue }
                
                // Ride forward to every subsequent stop on this direction — each is a possible alight point.
                for alightIndex in (boardIndex + 1)..<direction.stops.count {
                    let alightKey = stopKeys[alightIndex]
                    if visitedStopKeys.contains(alightKey) { continue }
                    let alightStop = direction.stops[alightIndex]
                    
                    let leg = RouteLeg(direction: direction, boardIndex: boardIndex, alightIndex: alightIndex)
                    visitedStopKeys.insert(alightKey)
                    queue.append((alightStop, legs + [leg]))
                }
            }
        }
        
        return nil // no path found within the transfer cap
    }
    
    /// Rounds to ~11 m precision so nearly-identical coordinates are treated as the same stop.
    ///
    /// Packed into an Int rather than formatted into a String: the path search calls this for
    /// every stop of every direction at every node it visits — around 160,000 times for a
    /// single estimate — and `String(format:)` at that volume is most of the cost.
    private static func key(for coordinate: CLLocationCoordinate2D) -> Int {
        let latitude = Int(((coordinate.latitude + 90) * 10_000).rounded())
        let longitude = Int(((coordinate.longitude + 180) * 10_000).rounded())
        return latitude &* 4_000_000 &+ longitude
    }
    
    // MARK: - Time + formatting helpers
    
    private static func legDistanceKm(for leg: RouteLeg) -> Double {
        let stops = Array(leg.direction.stops[leg.boardIndex...leg.alightIndex])
        var distanceKm = 0.0
        for i in 0..<(stops.count - 1) {
            distanceKm += stops[i].coordinate.distance(to: stops[i + 1].coordinate) / 1000
        }
        return distanceKm
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

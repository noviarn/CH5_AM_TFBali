import Foundation
import CoreLocation

struct TripLeg: Identifiable {
    let id = UUID()
    let corridorID: String
    let directionID: UUID
    let boardStop: BusStop
    let alightStop: BusStop
    /// Chained stop-to-stop distance from board to alight (straight line per hop).
    let rideDistance: CLLocationDistance
    /// Hops ridden: alight index - board index.
    let stopCount: Int
}

struct TripRoute: Identifiable {
    let id = UUID()
    let legs: [TripLeg]
    /// Straight-line estimate while planning; refined with a real walking route for the
    /// handful of options actually shown.
    var walkToFirstStop: CLLocationDistance
    var walkFromLastStop: CLLocationDistance
    /// Why this route is on screen ("Tercepat", ...). Set by `RoutePlanner.rank`.
    var tags: [String] = []

    /// Rp 4.400 flat, charged per boarding — a transfer means paying again. Confirmed by Pafras
    /// 2026-08-19. Fare therefore only ever tracks the boarding count, which is why "Termurah"
    /// and "fewest transfers" are one criterion and not two.
    static let farePerBoarding = 4_400

    var transferCount: Int { legs.count - 1 }
    var fare: Int { legs.count * Self.farePerBoarding }

    /// Walking between an alight stop and the next leg's board stop. Transfer stops are matched
    /// by proximity, not identity, so this is real walking the rider does — leaving it out of
    /// `totalWalk` made every extra transfer look free and skewed the least-walking pick.
    var transferWalk: CLLocationDistance {
        zip(legs, legs.dropFirst()).reduce(0) { total, pair in
            total + pair.0.alightStop.coordinate.distance(to: pair.1.boardStop.coordinate)
        }
    }

    var totalWalk: CLLocationDistance { walkToFirstStop + transferWalk + walkFromLastStop }

    // ponytail: no timetable or traffic data exists, so this is a heuristic — bus at
    // 18 km/h along the stop chain, 20s dwell per stop, 4 min wait per boarding, walk at
    // 1.3 m/s. Ceiling: it ignores traffic and real headways. Upgrade path is
    // MKDirections `expectedTravelTime` per leg, but that is one network call per leg.
    var estimatedDuration: TimeInterval {
        let walk = totalWalk / 1.3
        let ride = legs.reduce(0.0) { $0 + $1.rideDistance / 5 + Double($1.stopCount) * 20 }
        return walk + ride + Double(legs.count) * 240
    }
}

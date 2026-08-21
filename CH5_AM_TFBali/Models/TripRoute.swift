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

    /// The legs reduced to what timing depends on, so `TripTiming` can cost this trip the
    /// same way `TripPreviewSheet` costs the one it draws.
    private var timedLegs: [TripTiming.TimedLeg] {
        legs.enumerated().map { index, leg in
            TripTiming.TimedLeg(
                corridorID: leg.corridorID,
                rideMeters: leg.rideDistance,
                stopCount: leg.stopCount,
                transferMeters: index == 0
                    ? 0
                    : legs[index - 1].alightStop.coordinate.distance(to: leg.boardStop.coordinate)
            )
        }
    }

    /// Door to door, including the wait for each bus and the traffic it will be sitting in.
    /// See `TripTiming` for the model and what it deliberately doesn't know.
    func estimatedDuration(departingAt departure: Date) -> TimeInterval {
        TripTiming.schedule(
            legs: timedLegs,
            walkToFirstStop: walkToFirstStop,
            walkFromLastStop: walkFromLastStop,
            departingAt: departure
        ).total
    }

    var estimatedDuration: TimeInterval { estimatedDuration(departingAt: Date()) }
}

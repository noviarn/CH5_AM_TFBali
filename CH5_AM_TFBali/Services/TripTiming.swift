import Foundation
import CoreLocation

/// How long a trip takes, in one place.
///
/// This used to live in two: `TripRoute.estimatedDuration` ranked routes at 18 km/h with a
/// flat 4-minute allowance per boarding, while `TripPreviewSheet` drew its timeline at
/// 20 km/h and counted no waiting at all. So the rider was shown a number that neither
/// matched the one used to pick "Tercepat" nor included the ten-plus minutes they would
/// actually spend at a bus stop. Both now go through `schedule(...)`.
enum TripTiming {
    /// Brisk-but-not-rushed pavement pace.
    static let walkingSpeed: CLLocationSpeed = 1.3          // m/s ≈ 4.7 km/h
    /// Bus speed with the road to itself, before `trafficMultiplier` is applied.
    static let freeFlowBusSpeed: CLLocationSpeed = 5.0      // m/s = 18 km/h
    /// Time lost at each stop letting riders on and off — unaffected by traffic.
    static let dwellPerStop: TimeInterval = 20

    /// Used when a corridor ID isn't in the network data, which in practice means a
    /// self-check's invented line. Real corridors all declare `headwayMinutes`.
    static let fallbackHeadwayMinutes: Double = 20

    private static let headwayMinutesByCorridorID: [String: Double] = Dictionary(
        corridors.map { ($0.id, $0.headwayMinutes) },
        uniquingKeysWith: { first, _ in first }
    )

    /// How long a rider turning up at a stop without a timetable waits on average: half the
    /// gap between buses. That is the standard result for arrivals spread evenly across the
    /// headway, and it is what makes frequency matter — S1 every 45 minutes costs a rider
    /// 22½ minutes to board, against 10 for a K1 every 20.
    ///
    /// ponytail: assumes buses actually keep their headway. Real ones bunch, which pushes the
    /// average wait above H/2. Upgrade path is published departure times per stop, if the
    /// operator ever provides them.
    static func expectedWait(corridorID: String) -> TimeInterval {
        (headwayMinutesByCorridorID[corridorID] ?? fallbackHeadwayMinutes) * 60 / 2
    }

    /// How much slower than free-flow the roads are at a given time of day.
    ///
    /// ponytail: a fixed curve, not live traffic — deliberately, because planning scores many
    /// candidate routes and asking MapKit for each would blow the MKDirections burst limit the
    /// rest of this app already works around. Ceiling: it knows nothing about today, only the
    /// hour; a holiday, a ceremony closing a road, or a wet afternoon all read as normal.
    /// Upgrade path is `MKDirections` with `departureDate` set, for the one route the rider
    /// actually picks rather than every candidate.
    static func trafficMultiplier(at date: Date, calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = Double(components.hour ?? 12) + Double(components.minute ?? 0) / 60

        switch hour {
        case 7..<9:    return 1.6   // school and office run
        case 16..<19:  return 1.7   // worst of the day, everyone heading home at once
        case 6..<7, 9..<11, 15..<16, 19..<20: return 1.25
        case 22...24, 0..<5: return 0.9   // empty roads
        default:       return 1.0
        }
    }

    static func walk(meters: CLLocationDistance) -> TimeInterval {
        meters / walkingSpeed
    }

    /// Time on the bus: the moving part stretches with traffic, the time spent sitting at
    /// stops does not.
    static func ride(
        meters: CLLocationDistance,
        stops: Int,
        departingAt date: Date
    ) -> TimeInterval {
        (meters / freeFlowBusSpeed) * trafficMultiplier(at: date) + Double(stops) * dwellPerStop
    }

    /// One bus of a trip, reduced to just what the timing depends on. Both `TripRoute` (which
    /// ranks candidates) and `TripPreviewSheet` (which draws the chosen one) can produce these,
    /// which is what keeps their numbers identical.
    struct TimedLeg {
        let corridorID: String
        let rideMeters: CLLocationDistance
        let stopCount: Int
        /// Walk from the previous leg's alighting stop to this one's boarding stop. Zero for
        /// the first leg, which is reached from wherever the rider is standing instead.
        let transferMeters: CLLocationDistance
    }

    struct Schedule {
        struct Leg {
            /// Walking to this leg's boarding stop — from the rider's start for the first leg,
            /// from the previous bus for the rest.
            let approach: TimeInterval
            let wait: TimeInterval
            let ride: TimeInterval
            let boardAt: Date
            let alightAt: Date
        }

        let departAt: Date
        let legs: [Leg]
        let finalWalk: TimeInterval
        let arriveAt: Date

        var total: TimeInterval { arriveAt.timeIntervalSince(departAt) }
        var totalWait: TimeInterval { legs.reduce(0) { $0 + $1.wait } }
    }

    /// Walks the trip through in order — walk, wait, ride, walk, wait, ride, walk — carrying
    /// the clock forward so each leg is costed at the time the rider actually reaches it. On a
    /// two-hour trip that matters: leaving before the evening peak is not the same as riding
    /// through it.
    static func schedule(
        legs: [TimedLeg],
        walkToFirstStop: CLLocationDistance,
        walkFromLastStop: CLLocationDistance,
        departingAt departure: Date
    ) -> Schedule {
        var clock = departure
        var timedLegs: [Schedule.Leg] = []

        for (index, leg) in legs.enumerated() {
            let approach = index == 0 ? walk(meters: walkToFirstStop) : walk(meters: leg.transferMeters)
            clock += approach

            let wait = expectedWait(corridorID: leg.corridorID)
            clock += wait
            let boardAt = clock

            let ride = ride(meters: leg.rideMeters, stops: leg.stopCount, departingAt: boardAt)
            clock += ride

            timedLegs.append(Schedule.Leg(
                approach: approach,
                wait: wait,
                ride: ride,
                boardAt: boardAt,
                alightAt: clock
            ))
        }

        // With no bus at all the whole trip is the walk — `walkToFirstStop` is the rider's
        // distance to the destination in that case.
        let finalWalk = walk(meters: legs.isEmpty ? 0 : walkFromLastStop)
        clock += finalWalk

        return Schedule(departAt: departure, legs: timedLegs, finalWalk: finalWalk, arriveAt: clock)
    }
}

#if DEBUG
extension TripTiming {
    static func runSelfCheck() {
        // 1. Frequency drives the wait: half the headway, per the corridor's own data.
        assert(expectedWait(corridorID: "K1") == 10 * 60, "K1 runs every 20 min, so expect a 10 min wait")
        assert(expectedWait(corridorID: "S1") == 22.5 * 60, "S1 runs every 45 min, so expect a 22.5 min wait")
        assert(
            expectedWait(corridorID: "S1") > expectedWait(corridorID: "K1"),
            "a rarer line must cost more to board, or frequency can't affect ranking"
        )
        assert(
            expectedWait(corridorID: "no such corridor") == fallbackHeadwayMinutes * 60 / 2,
            "an unknown line should fall back rather than crash or wait forever"
        )

        // 2. Traffic stretches the moving part of a ride, and only the moving part.
        var midnight = DateComponents(); midnight.year = 2026; midnight.month = 8; midnight.day = 21; midnight.hour = 2
        var rushHour = midnight; rushHour.hour = 17
        var quiet = midnight; quiet.hour = 13
        let calendar = Calendar(identifier: .gregorian)
        let quietDate = calendar.date(from: quiet)!
        let rushDate = calendar.date(from: rushHour)!

        assert(trafficMultiplier(at: quietDate, calendar: calendar) == 1.0, "early afternoon should be free-flow")
        assert(
            trafficMultiplier(at: rushDate, calendar: calendar) > trafficMultiplier(at: quietDate, calendar: calendar),
            "the evening peak must be slower than midday, or traffic isn't being modelled at all"
        )

        let quietRide = ride(meters: 10_000, stops: 10, departingAt: quietDate)
        let rushRide = ride(meters: 10_000, stops: 10, departingAt: rushDate)
        assert(rushRide > quietRide, "the same ride must take longer in the peak, got \(rushRide) vs \(quietRide)")
        // Dwell is boarding time, not road time: both rides sit at 10 stops for 20s each.
        assert(
            abs((rushRide - 200) / (quietRide - 200) - 1.7) < 0.001,
            "traffic should scale road time only, leaving dwell untouched"
        )

        // 3. A whole trip adds up, and waiting is part of it — the bug that made the sheet
        //    promise arrival times no rider could hit.
        let direct = schedule(
            legs: [TimedLeg(corridorID: "K1", rideMeters: 5_000, stopCount: 10, transferMeters: 0)],
            walkToFirstStop: 260,
            walkFromLastStop: 130,
            departingAt: quietDate
        )
        assert(direct.legs.count == 1, "expected 1 leg, got \(direct.legs.count)")
        assert(direct.totalWait == 10 * 60, "a single K1 boarding should cost one 10 min wait")
        assert(
            abs(direct.total - (200 + 600 + 1_000 + 200 + 100)) < 0.001,
            "walk 200s + wait 600s + ride (1000s road + 200s dwell) + walk 100s, got \(direct.total)"
        )
        assert(direct.arriveAt == quietDate.addingTimeInterval(direct.total), "arrival must be departure plus the total")

        // 4. Changing buses costs a second wait — which is what stops the planner treating
        //    transfers as free and chaining them endlessly.
        let withChange = schedule(
            legs: [
                TimedLeg(corridorID: "K1", rideMeters: 5_000, stopCount: 10, transferMeters: 0),
                TimedLeg(corridorID: "S1", rideMeters: 1_000, stopCount: 2, transferMeters: 130)
            ],
            walkToFirstStop: 260,
            walkFromLastStop: 130,
            departingAt: quietDate
        )
        assert(
            withChange.totalWait == (10 + 22.5) * 60,
            "expected a 10 min then a 22.5 min wait, got \(withChange.totalWait / 60) min"
        )
        assert(withChange.total > direct.total, "adding a change and a rarer bus can't make a trip shorter")
        assert(withChange.legs[1].boardAt > withChange.legs[0].alightAt, "the second bus is boarded after the first is left")

        print("✅ TripTiming.runSelfCheck passed")
    }
}
#endif

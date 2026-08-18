import MapKit

/// Works out which real bus stops a calculated route actually passes, in order, and what
/// happens between each — a straight ride, a same-stop corridor change, or a walk to a
/// different corridor's stop. Pure geometry, no networking, so it's cheap to recompute
/// whenever the route changes.
enum TransitPlanner {
    /// How far a stop can sit from the route path and still count as "on this trip." Wide
    /// enough that a stop platform set back from the road doesn't get dropped.
    static let stopMembershipThreshold: CLLocationDistance = 150
    /// Within this, two stops are the same physical spot — either the outbound/inbound pair
    /// at a two-way stop, or an interchange serving two corridors from one platform.
    static let samePlaceThreshold: CLLocationDistance = 25

    static func stopVisits(
        for busStops: [BusStop],
        along path: [CLLocationCoordinate2D]
    ) -> [TransitStopVisit] {
        guard !path.isEmpty else { return [] }

        let onRoute = busStops
            .compactMap { stop -> TransitStopVisit? in
                let index = RouteGeometry.nearestIndex(to: stop.coordinate, along: path)
                guard stop.coordinate.distance(to: path[index]) <= stopMembershipThreshold else { return nil }
                return TransitStopVisit(stop: stop, pathIndex: index)
            }
            .sorted { $0.pathIndex < $1.pathIndex }

        // Drop the outbound/inbound duplicate at the same physical stop — the rider passes
        // that spot once, not twice.
        var visits: [TransitStopVisit] = []
        for visit in onRoute {
            if let last = visits.last, last.stop.coordinate.distance(to: visit.stop.coordinate) <= samePlaceThreshold {
                continue
            }
            visits.append(visit)
        }
        return visits
    }

    static func legs(for visits: [TransitStopVisit]) -> [TransitLeg] {
        guard visits.count >= 2 else { return [] }

        return (0..<(visits.count - 1)).map { index in
            let from = visits[index]
            let to = visits[index + 1]

            let kind: TransitLegKind
            if from.stop.corridor == to.stop.corridor {
                kind = .ride(corridor: to.stop.corridor)
            } else {
                let distance = from.stop.coordinate.distance(to: to.stop.coordinate)
                kind = distance <= samePlaceThreshold
                    ? .sameStopTransfer(from: from.stop.corridor, to: to.stop.corridor)
                    : .walkingTransfer(from: from.stop.corridor, to: to.stop.corridor, distance: distance)
            }
            return TransitLeg(from: from, to: to, kind: kind)
        }
    }
}

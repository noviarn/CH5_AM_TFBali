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

    /// Takes the planned legs rather than a flat stop list so each visit keeps the corridor
    /// it belongs to — that's what makes a transfer detectable.
    static func stopVisits(
        for legs: [PlannedLeg],
        along path: [CLLocationCoordinate2D]
    ) -> [TransitStopVisit] {
        guard !path.isEmpty else { return [] }

        let onRoute = legs
            .flatMap { leg in
                leg.stops.compactMap { stop -> TransitStopVisit? in
                    let index = RouteGeometry.nearestIndex(to: stop.coordinate, along: path)
                    guard stop.coordinate.distance(to: path[index]) <= stopMembershipThreshold else { return nil }
                    return TransitStopVisit(stop: stop, corridorID: leg.corridor.id, pathIndex: index)
                }
            }
            .sorted { $0.pathIndex < $1.pathIndex }

        // Drop the outbound/inbound duplicate at the same physical stop — the rider passes
        // that spot once, not twice. Only within one corridor, though: at an interchange the
        // two co-located stops belong to different lines and collapsing them would erase the
        // very transfer the rider needs to be told about.
        var visits: [TransitStopVisit] = []
        for visit in onRoute {
            if let last = visits.last,
               last.corridorID == visit.corridorID,
               last.stop.coordinate.distance(to: visit.stop.coordinate) <= samePlaceThreshold {
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
            if from.corridorID == to.corridorID {
                kind = .ride(corridor: to.corridorID)
            } else {
                let distance = from.stop.coordinate.distance(to: to.stop.coordinate)
                kind = distance <= samePlaceThreshold
                    ? .sameStopTransfer(from: from.corridorID, to: to.corridorID)
                    : .walkingTransfer(from: from.corridorID, to: to.corridorID, distance: distance)
            }
            return TransitLeg(from: from, to: to, kind: kind)
        }
    }
}

#if DEBUG
extension TransitPlanner {
    static func runSelfCheck() {
        // A straight west-to-east path; 0.001° of longitude is ~111 m here.
        let path = (0...15).map { CLLocationCoordinate2D(latitude: 0, longitude: Double($0) * 0.0002) }

        func leg(_ corridorID: String, _ stops: [BusStop]) -> PlannedLeg {
            let direction = RouteDirection(label: "\(corridorID)-line", stops: stops)
            return PlannedLeg(
                corridor: Corridor(id: corridorID, name: corridorID, color: .blue, headwayMinutes: 20, directions: [direction]),
                direction: direction,
                stops: stops,
                polyline: []
            )
        }

        let a0 = stop("A0", 0, 0.000)
        let a1 = stop("A1", 0, 0.001)
        let a2 = stop("A2", 0, 0.002)

        // 1. One corridor end to end: every leg is a plain ride, nothing to announce.
        let directVisits = stopVisits(for: [leg("A", [a0, a1, a2])], along: path)
        assert(directVisits.count == 3, "expected 3 visits on a direct trip, got \(directVisits.count)")
        assert(directVisits.allSatisfy { $0.corridorID == "A" }, "every visit on a one-bus trip belongs to that bus")
        assert(legs(for: directVisits).allSatisfy { !$0.isTransfer }, "a one-bus trip must report no transfers")

        // 2. Changing buses at a shared platform. This is the case that used to vanish: both
        //    stops carry BusStop.corridor == 0, so comparing that field saw one continuous
        //    ride and the rider was never told to get off.
        let sharedPlatform = stop("B0", 0, 0.002)
        let sameStopVisits = stopVisits(for: [leg("A", [a0, a1, a2]), leg("B", [sharedPlatform, stop("B1", 0, 0.003)])], along: path)
        // All 5 stops survive: the two sharing a platform belong to different lines, so
        // neither is collapsed away.
        assert(sameStopVisits.count == 5, "co-located stops on different lines must both survive, got \(sameStopVisits.count)")
        let sameStopTransfers = legs(for: sameStopVisits).filter(\.isTransfer)
        assert(sameStopTransfers.count == 1, "expected exactly 1 transfer, got \(sameStopTransfers.count)")
        if case .sameStopTransfer(let from, let to) = sameStopTransfers[0].kind {
            assert(from == "A" && to == "B", "expected A → B, got \(from) → \(to)")
        } else {
            assertionFailure("stops sharing a platform should be a same-stop change, got \(sameStopTransfers[0].kind)")
        }

        // 3. Changing buses across the road: far enough apart that the rider has to walk it.
        let acrossTheRoad = stop("C0", 0, 0.0025) // ~55 m from A2, past samePlaceThreshold
        let walkVisits = stopVisits(for: [leg("A", [a0, a1, a2]), leg("C", [acrossTheRoad, stop("C1", 0, 0.003)])], along: path)
        let walkTransfers = legs(for: walkVisits).filter(\.isTransfer)
        assert(walkTransfers.count == 1, "expected exactly 1 transfer, got \(walkTransfers.count)")
        if case .walkingTransfer(_, _, let distance) = walkTransfers[0].kind {
            assert(distance > samePlaceThreshold, "a walked change must carry the real gap, got \(distance)")
        } else {
            assertionFailure("stops across the road should be a walking change, got \(walkTransfers[0].kind)")
        }

        // 4. The outbound/inbound pair at one physical stop is still one visit — that
        //    collapsing must stay scoped to a single corridor so it can't eat a transfer.
        let duplicateVisits = stopVisits(for: [leg("A", [a0, a1, stop("A1 (other side)", 0, 0.001), a2])], along: path)
        assert(duplicateVisits.count == 3, "same-corridor duplicate at one stop should collapse, got \(duplicateVisits.count)")

        print("✅ TransitPlanner.runSelfCheck passed")
    }
}
#endif

import Foundation
import CoreLocation

enum RoutePlanner {
    static func findRoutes(
        originCandidates: [NearestStopFinder.RankedStop],
        destinationCandidates: [NearestStopFinder.RankedStop],
        maxTransfers: Int = 2,
        stopReferences: [StopReference] = CorridorGraph.allStopReferences,
        transferThresholdMeters: CLLocationDistance = 150
    ) -> [TripRoute] {
        let stopsByDirection = Dictionary(grouping: stopReferences, by: \.directionID)
            .mapValues { $0.sorted { $0.stopIndex < $1.stopIndex } }

        struct StopKey: Hashable {
            let directionID: UUID
            let stopIndex: Int
        }

        // Precomputed once: for each stop, the other-CORRIDOR stops within the transfer threshold.
        // Same-corridor stops are excluded — riding a different direction of the same corridor
        // isn't a transfer, it's just riding the same bus line differently.
        var transferIndex: [StopKey: [StopReference]] = [:]
        for i in 0..<stopReferences.count {
            let a = stopReferences[i]
            for j in (i + 1)..<stopReferences.count {
                let b = stopReferences[j]
                guard a.corridorID != b.corridorID, a.directionID != b.directionID else { continue }
                guard a.stop.coordinate.distance(to: b.stop.coordinate) < transferThresholdMeters else { continue }
                transferIndex[StopKey(directionID: a.directionID, stopIndex: a.stopIndex), default: []].append(b)
                transferIndex[StopKey(directionID: b.directionID, stopIndex: b.stopIndex), default: []].append(a)
            }
        }
        func transferCandidates(near ref: StopReference) -> [StopReference] {
            transferIndex[StopKey(directionID: ref.directionID, stopIndex: ref.stopIndex)] ?? []
        }

        func destinationWalk(for ref: StopReference) -> CLLocationDistance? {
            destinationCandidates.first { $0.stop.coordinate.distance(to: ref.stop.coordinate) < 1 }?.walkingDistance
        }

        struct PartialRoute {
            let legs: [TripLeg]
            let walkToFirstStop: CLLocationDistance
            let lastRef: StopReference // board point for the next leg
        }

        // Riding rule: boarding at stop index i, a later stop index j > i on the SAME
        // direction is a valid alight point — RouteDirection.stops is already ordered
        // in the direction of travel, so there's no riding backward.
        var frontier: [PartialRoute] = originCandidates.flatMap { origin in
            stopReferences
                .filter { $0.stop.coordinate.distance(to: origin.stop.coordinate) < 1 }
                .map { ref in PartialRoute(legs: [], walkToFirstStop: origin.walkingDistance, lastRef: ref) }
        }

        var results: [TripRoute] = []

        for tier in 0...maxTransfers {
            var nextFrontier: [PartialRoute] = []
            var bestAtTier: TripRoute?

            for partial in frontier {
                guard let stopsInDirection = stopsByDirection[partial.lastRef.directionID] else { continue }
                let boardIndex = partial.lastRef.stopIndex

                for alightRef in stopsInDirection where alightRef.stopIndex > boardIndex {
                    let leg = TripLeg(
                        corridorID: alightRef.corridorID,
                        directionID: alightRef.directionID,
                        boardStop: partial.lastRef.stop,
                        alightStop: alightRef.stop
                    )
                    let legs = partial.legs + [leg]

                    if let walkFrom = destinationWalk(for: alightRef) {
                        let candidate = TripRoute(legs: legs, walkToFirstStop: partial.walkToFirstStop, walkFromLastStop: walkFrom)
                        let candidateCost = candidate.walkToFirstStop + candidate.walkFromLastStop
                        let bestCost = bestAtTier.map { $0.walkToFirstStop + $0.walkFromLastStop }
                        if bestCost == nil || candidateCost < bestCost! {
                            bestAtTier = candidate
                        }
                    }

                    if tier < maxTransfers {
                        // Never board a corridor this route already rode — that doubles back along
                        // the same line (its return leg), which is not a trip anyone would take.
                        let usedCorridors = Set(legs.map(\.corridorID))
                        for transferRef in transferCandidates(near: alightRef) where !usedCorridors.contains(transferRef.corridorID) {
                            nextFrontier.append(PartialRoute(legs: legs, walkToFirstStop: partial.walkToFirstStop, lastRef: transferRef))
                        }
                    }
                }
            }

            if let best = bestAtTier {
                results.append(best)
            }
            frontier = nextFrontier
        }

        return results
    }
}

#if DEBUG
extension RoutePlanner {
    static func runSelfCheck() {
        // Direction A (corridor "A"): A0 -- A1 -- A2, ~111m apart.
        let a0 = stop("A0", 0, 0.000)
        let a1 = stop("A1", 0, 0.001)
        let a2 = stop("A2", 0, 0.002)
        let directionA = RouteDirection(label: "A-line", stops: [a0, a1, a2])

        // Direction B (corridor "B"): B0 -- B1 -- B2. B0 sits ~11m from A2 (proximity transfer, not exact match).
        let b0 = stop("B0", 0, 0.0021)
        let b1 = stop("B1", 0, 0.003)
        let b2 = stop("B2", 0, 0.004)
        let directionB = RouteDirection(label: "B-line", stops: [b0, b1, b2])

        // Direction C (corridor "C"): far away, no proximity link to A or B (nearest gap is ~668m).
        let c0 = stop("C0", 0, 0.010)
        let c1 = stop("C1", 0, 0.011)
        let directionC = RouteDirection(label: "C-line", stops: [c0, c1])

        // Second direction on corridor "A" (A-line-return): AR0 sits ~111m from A1 (same corridor
        // as A-line) but ~165m from B0 (no indirect link via B). Must NOT be reachable as a transfer
        // target from A1 — same-corridor legs aren't transfers.
        let ar0 = stop("AR0", -0.001, 0.001)
        let ar1 = stop("AR1", -0.001, 0.006)
        let directionAReturn = RouteDirection(label: "A-line-return", stops: [ar0, ar1])

        // A third direction on corridor "A", starting ~5m from B1. Without the corridor-revisit rule
        // the planner would happily route A -> B -> A, i.e. send the rider back onto the line they
        // already rode. Reaching AL1 requires corridor A twice, so it must be unreachable.
        let al0 = stop("AL0", 0, 0.00305)
        let al1 = stop("AL1", 0.002, 0.00305)
        let directionALoop = RouteDirection(label: "A-line-loop", stops: [al0, al1])

        func refs(_ corridorID: String, _ direction: RouteDirection) -> [StopReference] {
            direction.stops.enumerated().map { index, s in
                StopReference(corridorID: corridorID, directionID: direction.id, stopIndex: index, stop: s)
            }
        }
        let fakeRefs = refs("A", directionA) + refs("B", directionB) + refs("C", directionC)
            + refs("A", directionAReturn) + refs("A", directionALoop)

        // 1. Direct route: A0 -> A1, same direction, 0 transfers.
        let directResults = findRoutes(
            originCandidates: [.init(stop: a0, walkingDistance: 10)],
            destinationCandidates: [.init(stop: a1, walkingDistance: 20)],
            stopReferences: fakeRefs
        )
        assert(directResults.count == 1, "expected 1 direct route, got \(directResults.count)")
        assert(directResults[0].transferCount == 0, "expected 0 transfers")
        assert(directResults[0].legs[0].alightStop.name == "A1", "expected alight at A1")

        // 2. 1-transfer route: A0 -> (transfer near A2) -> B1.
        let transferResults = findRoutes(
            originCandidates: [.init(stop: a0, walkingDistance: 10)],
            destinationCandidates: [.init(stop: b1, walkingDistance: 15)],
            stopReferences: fakeRefs
        )
        assert(transferResults.count == 1, "expected 1 route via transfer, got \(transferResults.count)")
        assert(transferResults[0].transferCount == 1, "expected 1 transfer")
        assert(transferResults[0].legs.map(\.corridorID) == ["A", "B"], "expected corridor sequence A -> B")
        assert(transferResults[0].legs.last?.alightStop.name == "B1", "expected final alight at B1")
        assert(transferResults[0].walkToFirstStop + transferResults[0].walkFromLastStop == 25, "expected total walk 25m")

        // 3. No route: C-line has no proximity link to A/B within maxTransfers.
        let noRouteResults = findRoutes(
            originCandidates: [.init(stop: a0, walkingDistance: 10)],
            destinationCandidates: [.init(stop: c1, walkingDistance: 5)],
            stopReferences: fakeRefs
        )
        assert(noRouteResults.isEmpty, "expected no route to unreachable C-line, got \(noRouteResults.count)")

        // 4. Same-corridor "transfer" must be rejected: AR0 sits ~11m from A2, same corridor "A"
        // as A-line, so it must NOT be treated as a transfer point even though it's a different direction.
        let sameCorridorResults = findRoutes(
            originCandidates: [.init(stop: a0, walkingDistance: 10)],
            destinationCandidates: [.init(stop: ar1, walkingDistance: 5)],
            stopReferences: fakeRefs
        )
        assert(sameCorridorResults.isEmpty, "expected no route via same-corridor pseudo-transfer, got \(sameCorridorResults.count)")

        // 5. A route must never ride the same corridor twice (A -> B -> A), which is what surfaced
        // as the corridor's return leg being drawn on the map.
        let revisitResults = findRoutes(
            originCandidates: [.init(stop: a0, walkingDistance: 10)],
            destinationCandidates: [.init(stop: al1, walkingDistance: 5)],
            stopReferences: fakeRefs
        )
        assert(revisitResults.isEmpty, "expected no route that rides corridor A twice, got \(revisitResults.map { $0.legs.map(\.corridorID) })")

        print("✅ RoutePlanner.runSelfCheck passed")
    }
}
#endif

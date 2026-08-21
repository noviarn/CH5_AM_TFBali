import Foundation
import CoreLocation

/// For each stop, the other-CORRIDOR stops close enough to change buses at.
///
/// An all-pairs scan over every stop in the network (~478 of them, so ~114k distance
/// checks, ~25 ms measured). The corridor network is static, so `standard` builds it lazily
/// on first use and every later plan reuses it rather than redoing the scan.
struct StopTransferIndex {
    static let standard = StopTransferIndex(stopReferences: CorridorGraph.allStopReferences)

    private struct StopKey: Hashable {
        let directionID: UUID
        let stopIndex: Int
    }

    private let index: [StopKey: [StopReference]]

    init(stopReferences: [StopReference], transferThresholdMeters: CLLocationDistance = 150) {
        var index: [StopKey: [StopReference]] = [:]
        for i in 0..<stopReferences.count {
            let a = stopReferences[i]
            for j in (i + 1)..<stopReferences.count {
                let b = stopReferences[j]
                // Same-corridor stops are excluded — riding a different direction of the same
                // corridor isn't a transfer, it's just riding the same bus line differently.
                guard a.corridorID != b.corridorID, a.directionID != b.directionID else { continue }
                guard a.stop.coordinate.distance(to: b.stop.coordinate) < transferThresholdMeters else { continue }
                index[StopKey(directionID: a.directionID, stopIndex: a.stopIndex), default: []].append(b)
                index[StopKey(directionID: b.directionID, stopIndex: b.stopIndex), default: []].append(a)
            }
        }
        self.index = index
    }

    func candidates(near ref: StopReference) -> [StopReference] {
        index[StopKey(directionID: ref.directionID, stopIndex: ref.stopIndex)] ?? []
    }
}

enum RoutePlanner {
    static func findRoutes(
        originCandidates: [NearestStopFinder.RankedStop],
        destinationCandidates: [NearestStopFinder.RankedStop],
        maxTransfers: Int = 2,
        stopReferences: [StopReference] = CorridorGraph.allStopReferences,
        transferThresholdMeters: CLLocationDistance = 150,
        transferIndex: StopTransferIndex? = nil,
        departingAt departure: Date = Date()
    ) -> [TripRoute] {
        let stopsByDirection = Dictionary(grouping: stopReferences, by: \.directionID)
            .mapValues { $0.sorted { $0.stopIndex < $1.stopIndex } }

        // Callers working with the real network pass the shared prebuilt index; self-checks
        // pass their own stop list and get a matching one built here.
        let transferIndex = transferIndex ?? StopTransferIndex(
            stopReferences: stopReferences,
            transferThresholdMeters: transferThresholdMeters
        )
        func transferCandidates(near ref: StopReference) -> [StopReference] {
            transferIndex.candidates(near: ref)
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

        // Best route per corridor sequence (e.g. "K5", "K2>K3"), keyed so the search keeps every
        // genuinely different way of making the trip instead of one winner per transfer tier —
        // a direct route and a two-corridor route are now ranked against each other, not siloed.
        var bestBySignature: [String: TripRoute] = [:]

        for tier in 0...maxTransfers {
            var nextFrontier: [PartialRoute] = []

            for partial in frontier {
                guard let stopsInDirection = stopsByDirection[partial.lastRef.directionID] else { continue }
                let boardIndex = partial.lastRef.stopIndex

                // Ride distance accumulates hop by hop: stopsInDirection is index-ordered, so each
                // further alight point is one more hop past the previous one.
                var rideDistance: CLLocationDistance = 0
                var previousStop = partial.lastRef.stop

                for alightRef in stopsInDirection where alightRef.stopIndex > boardIndex {
                    rideDistance += previousStop.coordinate.distance(to: alightRef.stop.coordinate)
                    previousStop = alightRef.stop

                    let leg = TripLeg(
                        corridorID: alightRef.corridorID,
                        directionID: alightRef.directionID,
                        boardStop: partial.lastRef.stop,
                        alightStop: alightRef.stop,
                        rideDistance: rideDistance,
                        stopCount: alightRef.stopIndex - boardIndex
                    )
                    let legs = partial.legs + [leg]

                    if let walkFrom = destinationWalk(for: alightRef) {
                        let candidate = TripRoute(legs: legs, walkToFirstStop: partial.walkToFirstStop, walkFromLastStop: walkFrom)
                        let signature = legs.map(\.corridorID).joined(separator: ">")
                        let incumbent = bestBySignature[signature]?.estimatedDuration(departingAt: departure) ?? .infinity
                        if incumbent > candidate.estimatedDuration(departingAt: departure) {
                            bestBySignature[signature] = candidate
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

            frontier = nextFrontier
        }

        return rank(Array(bestBySignature.values), departingAt: departure)
    }

    /// At most three options: fastest, cheapest, least walking. Cheapest is the fewest-boardings
    /// route, since the fare is flat per boarding. A route that wins more
    /// than one criterion carries both tags rather than appearing twice.
    ///
    /// Every candidate is costed from one pinned `departure` rather than each asking the clock
    /// itself — durations now depend on the time of day (traffic), so comparing routes measured
    /// moments apart would be comparing them against slightly different roads.
    static func rank(_ routes: [TripRoute], departingAt departure: Date = Date()) -> [TripRoute] {
        func duration(_ route: TripRoute) -> TimeInterval { route.estimatedDuration(departingAt: departure) }

        func winner(_ label: String, _ isBetter: (TripRoute, TripRoute) -> Bool) -> (String, UUID)? {
            routes.min(by: isBetter).map { (label, $0.id) }
        }
        let picks = [
            winner("Tercepat") { duration($0) < duration($1) },
            winner("Termurah") { ($0.transferCount, duration($0)) < ($1.transferCount, duration($1)) },
            winner("Jalan kaki paling sedikit") { ($0.totalWalk, duration($0)) < ($1.totalWalk, duration($1)) },
        ].compactMap { $0 }

        var tagsByID: [UUID: [String]] = [:]
        for (label, id) in picks { tagsByID[id, default: []].append(label) }

        return routes
            .compactMap { route -> TripRoute? in
                guard let tags = tagsByID[route.id] else { return nil }
                var tagged = route
                tagged.tags = tags
                return tagged
            }
            .sorted { duration($0) < duration($1) }
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

        // 6. Ranking: fastest and fewest-transfer can be different routes. Both must come back,
        //    each carrying only the tag it actually won.
        func fakeLeg(_ corridorID: String, _ direction: RouteDirection, _ board: BusStop, _ alight: BusStop, _ meters: CLLocationDistance, _ hops: Int) -> TripLeg {
            TripLeg(corridorID: corridorID, directionID: direction.id, boardStop: board, alightStop: alight, rideDistance: meters, stopCount: hops)
        }
        let quickWithTransfer = TripRoute(
            legs: [fakeLeg("A", directionA, a0, a1, 500, 1), fakeLeg("B", directionB, b0, b1, 500, 1)],
            walkToFirstStop: 10, walkFromLastStop: 10
        )
        let slowButDirect = TripRoute(
            legs: [fakeLeg("C", directionC, c0, c1, 20_000, 20)],
            walkToFirstStop: 10, walkFromLastStop: 10
        )
        let ranked = rank([quickWithTransfer, slowButDirect])
        assert(ranked.count == 2, "expected both options ranked, got \(ranked.count)")
        assert(ranked[0].tags.contains("Tercepat"), "expected the transfer route to win on time, got \(ranked[0].tags)")
        // The direct route wins on walking too, now that the 122m transfer hop counts against
        // the other one — that hop used to be invisible.
        assert(
            ranked[1].tags == ["Termurah", "Jalan kaki paling sedikit"],
            "expected the direct route to win transfers and walking, got \(ranked[1].tags)"
        )

        // 6b. Transfer walking counts. b0 sits ~11m from a1's neighbour a2, so the A>B route walks
        //     between the two stops and that distance must land in totalWalk.
        assert(quickWithTransfer.transferWalk > 0, "expected transfer walking to be counted, got \(quickWithTransfer.transferWalk)")
        assert(slowButDirect.transferWalk == 0, "expected no transfer walk on a direct route, got \(slowButDirect.transferWalk)")
        assert(
            abs(quickWithTransfer.totalWalk - (20 + a1.coordinate.distance(to: b0.coordinate))) < 0.001,
            "expected totalWalk to include the transfer hop, got \(quickWithTransfer.totalWalk)"
        )

        // 6c. Fare is per boarding, so a transfer doubles it.
        assert(quickWithTransfer.fare == 8_800, "expected Rp8.800 for two boardings, got \(quickWithTransfer.fare)")
        assert(slowButDirect.fare == 4_400, "expected Rp4.400 for one boarding, got \(slowButDirect.fare)")

        // 7. One route winning every criterion is listed once with every tag, not three times.
        let onlyOption = rank([slowButDirect])
        assert(onlyOption.count == 1, "expected a single option, got \(onlyOption.count)")
        assert(onlyOption[0].tags.count == 3, "expected all three tags on the sole option, got \(onlyOption[0].tags)")

        print("✅ RoutePlanner.runSelfCheck passed")
    }
}
#endif

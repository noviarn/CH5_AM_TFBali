# Trip Planner Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user search any destination and get back trip options showing which halte to walk to (first-mile), which corridor(s)/transfers to ride, and which halte to walk from (last-mile).

**Architecture:** Pure-logic services (`CorridorGraph`, `NearestStopFinder`, `RoutePlanner`) compute candidate stops and tiered BFS routes with no network beyond a bounded set of `MKDirections` walking calls; a `LocationManager`/`DestinationSearchService` pair wraps CoreLocation and `MKLocalSearchCompleter`; an Apple-Maps-style bottom sheet (`TripPlannerSheet`) drives the search and hands a chosen `TripRoute` back to `RouteMapView`, which reuses its existing corridor-toggle state to highlight it.

**Tech Stack:** Swift 5, SwiftUI, MapKit (`MKLocalSearchCompleter`, `MKLocalSearch`, `MKDirections`), CoreLocation. No new dependencies, no XCTest target (project has none — see Global Constraints).

**Spec:** `docs/superpowers/specs/2026-08-18-trip-planner-search-design.md`

## Global Constraints
- No XCTest target exists in this project. Follow the established convention in `Services/RouteGeometry.swift`: `#if DEBUG`-guarded `static func runSelfCheck()` / `runAsyncSelfCheck()` functions using `assert()` + `print("✅ ...")`, invoked from `CH5_AM_TFBaliApp.swift`'s `init()`. Do not add XCTest.
- Deployment target is iOS 26.5 (`IPHONEOS_DEPLOYMENT_TARGET` in `project.pbxproj`) — no API-availability concerns for anything used in this plan.
- Avoid deprecated MapKit APIs (the codebase already fixed one such case — commit `188537e`). Use `MKMapItem.location` (non-optional `CLLocation`), not the deprecated `.placemark`.
- `xcodebuild` requires the active developer directory to point at Xcode, not just Command Line Tools. Before any `xcodebuild` step, confirm with `xcode-select -p` — if it prints a Command Line Tools path instead of `/Applications/Xcode.app`, tell the user to run `sudo xcode-select -s /Applications/Xcode.app` once (this needs their password, so do not run it yourself).
- Scheme/target name: `CH5_AM_TFBali`.
- Match existing code style: no doc comments, terse one-line comments only where a WHY isn't obvious (see `RouteGeometry.swift` for the bar).

---

## Task 1: Foundation — TripRoute model, shared BaliRegion, CorridorGraph

**Files:**
- Create: `CH5_AM_TFBali/Models/TripRoute.swift`
- Create: `CH5_AM_TFBali/Constants/BaliRegion.swift`
- Create: `CH5_AM_TFBali/Services/CorridorGraph.swift`
- Modify: `CH5_AM_TFBali/Views/RouteMapView.swift:13-16` (remove now-duplicate private `baliRegion`)

**Interfaces:**
- Produces: `TripLeg` (corridorID: String, directionID: UUID, boardStop: BusStop, alightStop: BusStop), `TripRoute` (legs: [TripLeg], walkToFirstStop: CLLocationDistance, walkFromLastStop: CLLocationDistance, computed transferCount: Int), global `let baliRegion: MKCoordinateRegion`, `StopReference` (corridorID: String, directionID: UUID, stopIndex: Int, stop: BusStop), `CorridorGraph.allStopReferences: [StopReference]`, `CLLocationCoordinate2D.distance(to:) -> CLLocationDistance`.

This task is pure data/plumbing (flatMap + a native `CLLocation.distance(from:)` wrapper) — no branching logic, so no self-check, matching the bar set by the existing codebase (trivial one-liners in `RouteGeometry.swift`, like the `stop()` helper, don't get self-checks either; only `segments(for:)`'s branching logic does).

- [ ] **Step 1: Create the TripRoute model**

`CH5_AM_TFBali/Models/TripRoute.swift`:

```swift
import Foundation
import CoreLocation

struct TripLeg: Identifiable {
    let id = UUID()
    let corridorID: String
    let directionID: UUID
    let boardStop: BusStop
    let alightStop: BusStop
}

struct TripRoute: Identifiable {
    let id = UUID()
    let legs: [TripLeg]
    let walkToFirstStop: CLLocationDistance
    let walkFromLastStop: CLLocationDistance

    var transferCount: Int { legs.count - 1 }
}
```

- [ ] **Step 2: Extract the shared Bali region constant**

`CH5_AM_TFBali/Constants/BaliRegion.swift`:

```swift
import MapKit

let baliRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: -8.66, longitude: 115.21),
    span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45)
)
```

Then in `CH5_AM_TFBali/Views/RouteMapView.swift`, remove this now-duplicate private property (it currently sits right after the `@State` declarations, lines 13-16):

```swift
    private let baliRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.66, longitude: 115.21),
        span: MKCoordinateSpan(latitudeDelta: 0.45, longitudeDelta: 0.45)
    )
```

Delete it entirely. `Map(initialPosition: .region(baliRegion))` further down keeps working unchanged since it now resolves to the new global constant (`DestinationSearchService` will reuse the same constant in Task 5 — one source of truth instead of two copies of the same magic numbers).

- [ ] **Step 3: Create CorridorGraph**

`CH5_AM_TFBali/Services/CorridorGraph.swift`:

```swift
import Foundation
import CoreLocation

struct StopReference {
    let corridorID: String
    let directionID: UUID
    let stopIndex: Int
    let stop: BusStop
}

enum CorridorGraph {
    /// Every (corridor, direction, stop) tuple across all corridors, flattened once.
    static let allStopReferences: [StopReference] = corridors.flatMap { corridor in
        corridor.directions.flatMap { direction in
            direction.stops.enumerated().map { index, stop in
                StopReference(corridorID: corridor.id, directionID: direction.id, stopIndex: index, stop: stop)
            }
        }
    }
}

extension CLLocationCoordinate2D {
    /// Great-circle distance in meters, via CoreLocation (no manual haversine math needed).
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}
```

- [ ] **Step 4: Compile-check**

This is data/plumbing with no XCTest target, so the verification is a scratch compile against the real project files (catches type errors without touching the Xcode project or needing a simulator):

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
print("stop count:", CorridorGraph.allStopReferences.count)
print("bali region center lat:", baliRegion.center.latitude)
EOF
swiftc \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Models/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/Corridors/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/CorridorGraph.swift \
  main.swift -o task1bin && ./task1bin
```

Expected output: `stop count: 478` and `bali region center lat: -8.66`. Then `cd -` back and `rm -rf /tmp/tp-verify`.

- [ ] **Step 5: Commit**

```bash
git add CH5_AM_TFBali/Models/TripRoute.swift CH5_AM_TFBali/Constants/BaliRegion.swift CH5_AM_TFBali/Services/CorridorGraph.swift CH5_AM_TFBali/Views/RouteMapView.swift
git commit -m "feat: add TripRoute model, shared BaliRegion, and CorridorGraph"
```

---

## Task 2: NearestStopFinder

**Files:**
- Create: `CH5_AM_TFBali/Services/NearestStopFinder.swift`
- Modify: `CH5_AM_TFBali/CH5_AM_TFBaliApp.swift` (wire self-checks into the existing `#if DEBUG` init block)

**Interfaces:**
- Consumes: `StopReference`, `CorridorGraph.allStopReferences` (Task 1), `BusStop` (existing `Models/Corridor.swift`).
- Produces: `NearestStopFinder.RankedStop` (stop: BusStop, walkingDistance: CLLocationDistance), `NearestStopFinder.nearestByStraightLine(to:count:stopReferences:) -> [BusStop]`, `NearestStopFinder.rankedByWalkingDistance(candidates:to:router:) async -> [RankedStop]`.

- [ ] **Step 1: Write NearestStopFinder with an injectable router (mirrors RouteGeometry's pattern)**

`CH5_AM_TFBali/Services/NearestStopFinder.swift`:

```swift
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
```

- [ ] **Step 2: Add the self-checks (append to the same file)**

```swift
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
```

- [ ] **Step 3: Verify via scratch compile + run (real red/green cycle, no Xcode/simulator needed)**

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
NearestStopFinder.runSelfCheck()
await NearestStopFinder.runAsyncSelfCheck()
EOF
swiftc -DDEBUG \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Models/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/Corridors/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/CorridorGraph.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/NearestStopFinder.swift \
  main.swift -o task2bin && ./task2bin
```

Expected output:
```
✅ NearestStopFinder.runSelfCheck passed
✅ NearestStopFinder.runAsyncSelfCheck passed
```

If it fails first (e.g. before Step 2's asserts are correct), that's the red state — fix until both lines print. Then `cd -` and `rm -rf /tmp/tp-verify`.

- [ ] **Step 4: Wire the self-checks into the app's DEBUG init block**

In `CH5_AM_TFBali/CH5_AM_TFBaliApp.swift`, the current `init()` is:

```swift
    init() {
        #if DEBUG
        RouteGeometry.runSelfCheck()
        CorridorDataCheck.run()
        Task { await RouteGeometry.runAsyncSelfCheck() }
        #endif
    }
```

Change it to:

```swift
    init() {
        #if DEBUG
        RouteGeometry.runSelfCheck()
        CorridorDataCheck.run()
        NearestStopFinder.runSelfCheck()
        Task {
            await RouteGeometry.runAsyncSelfCheck()
            await NearestStopFinder.runAsyncSelfCheck()
        }
        #endif
    }
```

- [ ] **Step 5: Commit**

```bash
git add CH5_AM_TFBali/Services/NearestStopFinder.swift CH5_AM_TFBali/CH5_AM_TFBaliApp.swift
git commit -m "feat: add NearestStopFinder (straight-line prefilter + walking-distance ranking)"
```

---

## Task 3: RoutePlanner

**Files:**
- Create: `CH5_AM_TFBali/Services/RoutePlanner.swift`
- Modify: `CH5_AM_TFBali/CH5_AM_TFBaliApp.swift` (wire self-check into the `#if DEBUG` init block)

**Interfaces:**
- Consumes: `StopReference`, `CorridorGraph.allStopReferences` (Task 1), `NearestStopFinder.RankedStop` (Task 2), `TripLeg`/`TripRoute` (Task 1).
- Produces: `RoutePlanner.findRoutes(originCandidates:destinationCandidates:maxTransfers:stopReferences:transferThresholdMeters:) -> [TripRoute]`.

- [ ] **Step 1: Write RoutePlanner's tiered BFS**

`CH5_AM_TFBali/Services/RoutePlanner.swift`:

```swift
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

        func transferCandidates(near ref: StopReference) -> [StopReference] {
            stopReferences.filter {
                $0.directionID != ref.directionID &&
                $0.stop.coordinate.distance(to: ref.stop.coordinate) < transferThresholdMeters
            }
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
                        for transferRef in transferCandidates(near: alightRef) {
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
```

- [ ] **Step 2: Add the self-check (append to the same file)**

```swift
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

        func refs(_ corridorID: String, _ direction: RouteDirection) -> [StopReference] {
            direction.stops.enumerated().map { index, s in
                StopReference(corridorID: corridorID, directionID: direction.id, stopIndex: index, stop: s)
            }
        }
        let fakeRefs = refs("A", directionA) + refs("B", directionB) + refs("C", directionC)

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

        print("✅ RoutePlanner.runSelfCheck passed")
    }
}
#endif
```

- [ ] **Step 3: Verify via scratch compile + run**

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
RoutePlanner.runSelfCheck()
EOF
swiftc -DDEBUG \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Models/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/Corridors/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/CorridorGraph.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/NearestStopFinder.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/RoutePlanner.swift \
  main.swift -o task3bin && ./task3bin
```

Expected output: `✅ RoutePlanner.runSelfCheck passed`. Then `cd -` and `rm -rf /tmp/tp-verify`.

- [ ] **Step 4: Wire into App.init()**

In `CH5_AM_TFBali/CH5_AM_TFBaliApp.swift`, add `RoutePlanner.runSelfCheck()` next to the `NearestStopFinder.runSelfCheck()` call added in Task 2:

```swift
    init() {
        #if DEBUG
        RouteGeometry.runSelfCheck()
        CorridorDataCheck.run()
        NearestStopFinder.runSelfCheck()
        RoutePlanner.runSelfCheck()
        Task {
            await RouteGeometry.runAsyncSelfCheck()
            await NearestStopFinder.runAsyncSelfCheck()
        }
        #endif
    }
```

- [ ] **Step 5: Commit**

```bash
git add CH5_AM_TFBali/Services/RoutePlanner.swift CH5_AM_TFBali/CH5_AM_TFBaliApp.swift
git commit -m "feat: add RoutePlanner tiered BFS (direct, 1-transfer, 2-transfer routing)"
```

---

## Task 4: LocationManager + location permission string

**Files:**
- Create: `CH5_AM_TFBali/Services/LocationManager.swift`
- Modify: `CH5_AM_TFBali.xcodeproj/project.pbxproj` (add `NSLocationWhenInUseUsageDescription`)

**Interfaces:**
- Produces: `LocationManager` (ObservableObject, `@MainActor`) with `authorizationStatus: LocationManager.Status` (`.notDetermined`/`.denied`/`.authorized`), `requestAuthorization()`, `currentLocation() async -> CLLocationCoordinate2D?`.

No self-check — this is a thin CoreLocation delegate wrapper with no branching logic of its own to verify beyond what `CLLocationManager` itself guarantees (matches the same bar as Task 1: framework-wrapping code isn't tested in this codebase, only composed/branching logic is — see `RouteGeometry`'s untested `drivingRoute` vs. its tested `segments(for:)`).

- [ ] **Step 1: Write LocationManager**

`CH5_AM_TFBali/Services/LocationManager.swift`:

```swift
import Combine
import CoreLocation

@MainActor
final class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    enum Status {
        case notDetermined, denied, authorized
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D?, Never>?

    override init() {
        super.init()
        manager.delegate = self
    }

    var authorizationStatus: Status {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .denied, .restricted:
            return .denied
        default:
            return .notDetermined
        }
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    func currentLocation() async -> CLLocationCoordinate2D? {
        if let loc = manager.location {
            return loc.coordinate
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            continuation?.resume(returning: locations.first?.coordinate)
            continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            continuation?.resume(returning: nil)
            continuation = nil
        }
    }
}
```

- [ ] **Step 2: Add the location permission string to both build configs**

The app has no manual `Info.plist` — it uses `GENERATE_INFOPLIST_FILE = YES` with `INFOPLIST_KEY_*` build settings (see the existing `INFOPLIST_KEY_UIApplicationSceneManifest_Generation` etc.). Origin is now GPS-based, so this key is required or location requests silently fail at runtime.

In `CH5_AM_TFBali.xcodeproj/project.pbxproj`, this exact line appears twice (once in the Debug config, once in the Release config):

```
				GENERATE_INFOPLIST_FILE = YES;
```

Replace **both** occurrences with:

```
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Butuh akses lokasi untuk mencari halte terdekat dari posisi kamu.";
```

(Use the Edit tool with `replace_all: true` on the single-line match — both occurrences are byte-identical and both need the same new line appended, so one `replace_all` edit handles both configs in one call.)

- [ ] **Step 3: Verify the Info.plist edit landed in both configs**

```bash
grep -c "INFOPLIST_KEY_NSLocationWhenInUseUsageDescription" CH5_AM_TFBali.xcodeproj/project.pbxproj
```

Expected output: `2`.

- [ ] **Step 4: Compile-check LocationManager**

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
print("ok")
EOF
swiftc /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/LocationManager.swift main.swift -o task4bin && ./task4bin
```

Expected output: `ok`. Then `cd -` and `rm -rf /tmp/tp-verify`.

- [ ] **Step 5: Commit**

```bash
git add CH5_AM_TFBali/Services/LocationManager.swift CH5_AM_TFBali.xcodeproj/project.pbxproj
git commit -m "feat: add LocationManager and location permission string"
```

---

## Task 5: DestinationSearchService

**Files:**
- Create: `CH5_AM_TFBali/Services/DestinationSearchService.swift`

**Interfaces:**
- Consumes: `baliRegion` (Task 1).
- Produces: `DestinationSearchService` (ObservableObject, `@MainActor`) with `@Published var suggestions: [MKLocalSearchCompletion]`, `updateQuery(_ text: String)`, `resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem?`.

No self-check — thin `MKLocalSearchCompleter`/`MKLocalSearch` wrapper, same reasoning as Task 4.

- [ ] **Step 1: Write DestinationSearchService**

`CH5_AM_TFBali/Services/DestinationSearchService.swift`:

```swift
import Combine
import MapKit

@MainActor
final class DestinationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var suggestions: [MKLocalSearchCompletion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.region = baliRegion
    }

    func updateQuery(_ text: String) {
        completer.queryFragment = text
    }

    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try? await search.start()
        return response?.mapItems.first
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.suggestions = []
        }
    }
}
```

Note: the async resolve method is `MKLocalSearch.start()`, not `.search()` — double-check this against the SDK if autocomplete suggests otherwise.

- [ ] **Step 2: Compile-check**

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
print("ok")
EOF
swiftc \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/BaliRegion.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/DestinationSearchService.swift \
  main.swift -o task5bin && ./task5bin
```

Expected output: `ok`. Then `cd -` and `rm -rf /tmp/tp-verify`.

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Services/DestinationSearchService.swift
git commit -m "feat: add DestinationSearchService wrapping MKLocalSearchCompleter"
```

---

## Task 6: TripPlannerSheet view

**Files:**
- Create: `CH5_AM_TFBali/Views/TripPlannerSheet.swift`

**Interfaces:**
- Consumes: `TripRoute`/`TripLeg` (Task 1), `NearestStopFinder` (Task 2), `RoutePlanner` (Task 3), `LocationManager` (Task 4), `DestinationSearchService` (Task 5), `BusStop` (existing `Models/Corridor.swift`).
- Produces: `TripPlannerSheet: View` with `init(destinationPin: Binding<BusStop?>, onRouteSelected: @escaping (TripRoute) -> Void)`.

- [ ] **Step 1: Write TripPlannerSheet**

`CH5_AM_TFBali/Views/TripPlannerSheet.swift`:

```swift
import SwiftUI
import MapKit
import CoreLocation

struct TripPlannerSheet: View {
    @Binding var destinationPin: BusStop?
    let onRouteSelected: (TripRoute) -> Void

    @StateObject private var searchService = DestinationSearchService()
    @StateObject private var locationManager = LocationManager()

    @State private var query = ""
    @State private var phase: Phase = .idle
    @State private var routes: [TripRoute] = []

    enum Phase: Equatable {
        case idle, searching, locationDenied, noResults, noRoute, results
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Cari tujuan...", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .onChange(of: query) { _, newValue in
                    searchService.updateQuery(newValue)
                }

            switch phase {
            case .idle:
                if !searchService.suggestions.isEmpty {
                    suggestionList
                }
            case .searching:
                ProgressView().frame(maxWidth: .infinity)
            case .locationDenied:
                Text("Aktifkan akses lokasi di Pengaturan untuk pakai fitur pencarian rute.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            case .noResults:
                Text("Gak ada hasil untuk \"\(query)\".")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            case .noRoute:
                Text("Rute belum ditemukan dari sini.")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            case .results:
                routeList
            }

            Spacer()
        }
        .padding(.top, 12)
    }

    private var suggestionList: some View {
        List(searchService.suggestions, id: \.self) { suggestion in
            Button {
                Task { await selectDestination(suggestion) }
            } label: {
                VStack(alignment: .leading) {
                    Text(suggestion.title)
                    Text(suggestion.subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }

    private var routeList: some View {
        List(routes) { route in
            Button {
                onRouteSelected(route)
            } label: {
                RouteCard(route: route)
            }
        }
        .listStyle(.plain)
    }

    private func selectDestination(_ suggestion: MKLocalSearchCompletion) async {
        phase = .searching
        guard let mapItem = await searchService.resolve(suggestion) else {
            phase = .noResults
            return
        }
        let destinationCoordinate = mapItem.location.coordinate
        destinationPin = BusStop(name: mapItem.name ?? suggestion.title, coordinate: destinationCoordinate)

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestAuthorization()
        }
        guard locationManager.authorizationStatus != .denied,
              let userCoordinate = await locationManager.currentLocation() else {
            phase = .locationDenied
            return
        }

        let originStraightLine = NearestStopFinder.nearestByStraightLine(to: userCoordinate)
        let destinationStraightLine = NearestStopFinder.nearestByStraightLine(to: destinationCoordinate)
        let originRanked = await NearestStopFinder.rankedByWalkingDistance(candidates: originStraightLine, to: userCoordinate)
        let destinationRanked = await NearestStopFinder.rankedByWalkingDistance(candidates: destinationStraightLine, to: destinationCoordinate)

        let found = RoutePlanner.findRoutes(originCandidates: originRanked, destinationCandidates: destinationRanked)
        routes = found
        phase = found.isEmpty ? .noRoute : .results
    }
}

private struct RouteCard: View {
    let route: TripRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                ForEach(Array(route.legs.enumerated()), id: \.offset) { index, leg in
                    if index > 0 {
                        Image(systemName: "arrow.right").font(.caption2)
                    }
                    Text(leg.corridorID)
                        .font(.caption.bold())
                        .padding(.horizontal, 8).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            Text("\(Int(route.walkToFirstStop))m jalan → naik → \(Int(route.walkFromLastStop))m jalan ke tujuan")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(route.transferCount == 0 ? "Langsung" : "\(route.transferCount)x transfer")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

- [ ] **Step 2: Compile-check together with everything it depends on**

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
print("ok")
EOF
swiftc \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Models/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/Corridors/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Views/TripPlannerSheet.swift \
  main.swift -o task6bin && ./task6bin
```

Expected output: `ok` with no warnings. Then `cd -` and `rm -rf /tmp/tp-verify`.

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Views/TripPlannerSheet.swift
git commit -m "feat: add TripPlannerSheet (Apple Maps-style bottom sheet search UI)"
```

---

## Task 7: Wire TripPlannerSheet into RouteMapView

**Files:**
- Modify: `CH5_AM_TFBali/Views/RouteMapView.swift`

**Interfaces:**
- Consumes: `TripPlannerSheet` (Task 6), `TripRoute` (Task 1).

**Important interaction note:** the trip-planner sheet is always presented (Apple Maps style), so the existing stop-tap `.sheet(item: $selectedStop) { StopDetailSheet(...) }` can no longer be a second `.sheet` — SwiftUI does not reliably support two independently-driven sheets active on the same view at once. This task converts the stop-detail popup from a `.sheet` to a lightweight `.overlay` card instead (`StopDetailCard`, replacing `StopDetailSheet`), which coexists fine with the always-on bottom sheet.

- [ ] **Step 1: Replace the full contents of RouteMapView.swift**

`CH5_AM_TFBali/Views/RouteMapView.swift` (full file):

```swift
import SwiftUI
import MapKit

struct RouteMapView: View {
    @State private var visibleCorridorIDs: Set<String> = ["K1"]
    @State private var visibleDirectionIDs: Set<UUID> = Set(
        corridors.first(where: { $0.id == "K1" })?.directions.map(\.id) ?? []
    )
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]
    @State private var loadingCorridorIDs: Set<String> = []
    @State private var selectedStop: BusStop?
    @State private var destinationPin: BusStop?

    var body: some View {
        Map(initialPosition: .region(baliRegion)) {
            ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                ForEach(Array(corridor.directions.enumerated()), id: \.element.id) { legIndex, direction in
                    if visibleDirectionIDs.contains(direction.id) {
                        if let coords = polylines[direction.id.uuidString], coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(corridor.color, style: strokeStyle(for: corridor, legIndex: legIndex))
                        }
                        ForEach(direction.stops) { busStop in
                            Annotation(busStop.name, coordinate: busStop.coordinate) {
                                Circle()
                                    .fill(corridor.color)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                    .frame(width: 44, height: 44)
                                    .contentShape(Circle())
                                    .onTapGesture { selectedStop = busStop }
                            }
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            if let destinationPin {
                Annotation(destinationPin.name, coordinate: destinationPin.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                }
            }
        }
        .task {
            for corridor in corridors where visibleCorridorIDs.contains(corridor.id) {
                await loadPolylines(for: corridor)
            }
        }
        .onChange(of: visibleCorridorIDs) { oldValue, newValue in
            let newlyVisible = newValue.subtracting(oldValue)
            guard !newlyVisible.isEmpty else { return }
            Task {
                for corridor in corridors where newlyVisible.contains(corridor.id) {
                    await loadPolylines(for: corridor)
                }
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                CorridorToggleRow(visibleCorridorIDs: $visibleCorridorIDs, visibleDirectionIDs: $visibleDirectionIDs)
                ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                    DirectionToggleRow(corridor: corridor, visibleDirectionIDs: $visibleDirectionIDs)
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let selectedStop {
                StopDetailCard(stop: selectedStop, onDismiss: { self.selectedStop = nil })
                    .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: .constant(true)) {
            TripPlannerSheet(destinationPin: $destinationPin, onRouteSelected: applySelectedRoute)
                .presentationDetents([.height(80), .medium, .large])
                .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }

    private func applySelectedRoute(_ route: TripRoute) {
        let corridorIDs = Set(route.legs.map(\.corridorID))
        let directionIDs = Set(route.legs.map(\.directionID))
        visibleCorridorIDs = corridorIDs
        visibleDirectionIDs = directionIDs
        Task {
            for corridor in corridors where corridorIDs.contains(corridor.id) {
                await loadPolylines(for: corridor)
            }
        }
    }

    private func strokeStyle(for corridor: Corridor, legIndex: Int) -> StrokeStyle {
        if corridor.id == "SHUTTLE_SANUR" {
            return StrokeStyle(lineWidth: 2, dash: [1, 5])
        }
        switch legIndex {
        case 0: return StrokeStyle(lineWidth: 4)
        case 1: return StrokeStyle(lineWidth: 4, dash: [8, 6])
        default: return StrokeStyle(lineWidth: 4, dash: [2, 4])
        }
    }

    @MainActor
    private func loadPolylines(for corridor: Corridor) async {
        guard !loadingCorridorIDs.contains(corridor.id) else { return }
        loadingCorridorIDs.insert(corridor.id)
        defer { loadingCorridorIDs.remove(corridor.id) }
        for direction in corridor.directions {
            if Task.isCancelled { return }
            if polylines[direction.id.uuidString] != nil { continue }
            let coords = await RouteGeometry.polyline(for: direction)
            polylines[direction.id.uuidString] = coords
        }
    }
}

private struct CorridorToggleRow: View {
    @Binding var visibleCorridorIDs: Set<String>
    @Binding var visibleDirectionIDs: Set<UUID>

    private let lightCorridorIDs: Set<String> = ["K5", "K6", "SHUTTLE_SANUR"]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(corridors) { corridor in
                    let isOn = visibleCorridorIDs.contains(corridor.id)
                    Button {
                        let directionIDs = corridor.directions.map(\.id)
                        if isOn {
                            visibleCorridorIDs.remove(corridor.id)
                            visibleDirectionIDs.subtract(directionIDs)
                        } else {
                            visibleCorridorIDs.insert(corridor.id)
                            visibleDirectionIDs.formUnion(directionIDs)
                        }
                    } label: {
                        Text(corridor.id)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? corridor.color : Color.gray.opacity(0.25))
                            .foregroundStyle(isOn ? (lightCorridorIDs.contains(corridor.id) ? Color.black : Color.white) : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.thinMaterial)
    }
}

private struct DirectionToggleRow: View {
    let corridor: Corridor
    @Binding var visibleDirectionIDs: Set<UUID>

    private func label(for legIndex: Int) -> String {
        if corridor.directions.count == 2 {
            return legIndex == 0 ? "Pergi" : "Pulang"
        }
        return "Leg \(legIndex + 1)"
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(corridor.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(Array(corridor.directions.enumerated()), id: \.element.id) { legIndex, direction in
                    let isOn = visibleDirectionIDs.contains(direction.id)
                    Button {
                        if isOn {
                            visibleDirectionIDs.remove(direction.id)
                        } else {
                            visibleDirectionIDs.insert(direction.id)
                        }
                    } label: {
                        Text(label(for: legIndex))
                            .font(.caption2.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(isOn ? corridor.color.opacity(0.85) : Color.gray.opacity(0.2))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
        .background(.thinMaterial)
    }
}

private struct StopDetailCard: View {
    let stop: BusStop
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(stop.name).font(.headline)
                Text("\(stop.coordinate.latitude), \(stop.coordinate.longitude)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
```

- [ ] **Step 2: Compile-check the whole feature together**

```bash
mkdir -p /tmp/tp-verify && cd /tmp/tp-verify
cat > main.swift <<'EOF'
print("ok")
EOF
swiftc \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Models/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Constants/Corridors/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Services/*.swift \
  /Users/pafrasv/Documents/CH5-TransportForBali/CH5_AM_TFBali/Views/*.swift \
  main.swift -o task7bin && ./task7bin
```

Expected output: `ok` with no warnings. Then `cd -` and `rm -rf /tmp/tp-verify`.

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Views/RouteMapView.swift
git commit -m "feat: wire TripPlannerSheet into RouteMapView with route highlighting"
```

---

## Task 8: End-to-end verification in the iOS Simulator

**Files:** none (verification only).

- [ ] **Step 1: Confirm the full Xcode toolchain is active**

```bash
xcode-select -p
```

If this prints a Command Line Tools path (not `/Applications/Xcode.app/Contents/Developer`), stop and tell the user to run `sudo xcode-select -s /Applications/Xcode.app` themselves (needs their password), then continue.

- [ ] **Step 2: Build for the simulator**

```bash
xcodebuild -project CH5_AM_TFBali.xcodeproj -scheme CH5_AM_TFBali -destination 'platform=iOS Simulator,name=iPhone 16' build
```

Expected: `** BUILD SUCCEEDED **`. If it fails, read the error, fix the relevant task's file, and rebuild — do not proceed until this passes (this is the first point where the DEBUG self-checks added in Tasks 2-3 actually run, since they execute on app launch, not at build time).

- [ ] **Step 3: Launch in the simulator and confirm self-checks pass on launch**

Use the iOS Simulator tool: `attach` to open the panel, then `launch` the built `.app` (path reported by the build in Step 2, typically under `~/Library/Developer/Xcode/DerivedData/.../Build/Products/Debug-iphonesimulator/CH5_AM_TFBali.app`). A crash on launch (SIGABRT) means one of the `assert()`s in a self-check fired — check the simulator's console output for which one and fix it.

- [ ] **Step 4: Manually verify the search flow**

With the app running:
1. Confirm the bottom sheet appears collapsed at launch, showing just the "Cari tujuan..." field, with the existing K1-only map and corridor toggle row still visible above it.
2. Tap the search field, type a real Bali place name (e.g. "Pantai Kuta" or "Bandara Ngurah Rai"). Confirm suggestions appear and the sheet expands.
3. Tap a suggestion. Confirm: a location-permission prompt appears (first run only) — grant it. Confirm the sheet shows a loading state, then either a list of route cards or a "Rute belum ditemukan" message.
4. If route cards appear, tap one. Confirm the map's corridor toggle row updates to reflect the selected route's corridor(s), the map highlights only those, and a red destination pin appears at the searched place.
5. Tap a bus-stop dot on the map. Confirm the `StopDetailCard` overlay appears near the bottom (not a second sheet) and can be dismissed via its X button without disturbing the trip-planner sheet underneath.

Take a screenshot at each key step (collapsed sheet, expanded suggestions, route list, highlighted route) to confirm visually rather than assuming from logs alone.

- [ ] **Step 5: Report results**

Summarize what worked and what didn't (if anything) — do not claim the feature complete without having actually walked through Step 4 in the simulator.

# Trip Planner Search (First-Mile / Last-Mile) — Design

## Purpose
Let user search a destination (any place, not just a bus stop) and get back one or more trip options: which halte to walk to and board (first-mile), which corridor(s) to ride (including transfers if needed), and which halte to get off at and walk from (last-mile) to reach that destination.

## Scope
- In: destination search (free text, any place), origin fixed to user's current GPS location, nearest-stop matching by real walking distance, automatic corridor/transfer route-finding (up to 2 transfers), bottom-sheet UI (Apple Maps style) showing route options, selecting a route highlights it on the existing map.
- Out: turn-by-turn walking navigation, live vehicle tracking, real-time schedules, manual origin entry (origin is always current location), fare/cost estimation.

## Data Model (`Models/`)
Builds on the existing `BusStop` / `RouteDirection` / `Corridor` (see `2026-08-15-route-visualisation-design.md`). New additions:

```swift
struct TripLeg {
    let corridorID: String
    let directionID: UUID       // which RouteDirection (arah/leg) is ridden
    let boardStop: BusStop
    let alightStop: BusStop
}

struct TripRoute: Identifiable {
    let id = UUID()
    let legs: [TripLeg]                        // ordered, 1-3 legs (0-2 transfers)
    let walkToFirstStop: CLLocationDistance     // meters, origin -> legs.first.boardStop
    let walkFromLastStop: CLLocationDistance    // meters, legs.last.alightStop -> destination
    var transferCount: Int { legs.count - 1 }
}
```

`Destination` doesn't need a new struct — `MKMapItem` from `MKLocalSearch` already carries name + coordinate.

## Services (`Services/`)

### `LocationManager`
Wraps `CLLocationManager`. Async `currentLocation() -> CLLocationCoordinate2D?`, requests when-in-use authorization on first use. Requires adding `NSLocationWhenInUseUsageDescription` to the Xcode project's Info.plist build settings (not present today — the existing map feature never needed user location).

### `DestinationSearchService`
Wraps `MKLocalSearchCompleter` (live autocomplete as user types) and `MKLocalSearch` (resolve a chosen suggestion into a full `MKMapItem` with coordinate). Region-biased to the Bali `baliRegion` already defined in `RouteMapView`. No custom destination data — Apple's local Maps database is the source, so there's nothing to maintain.

### `NearestStopFinder`
Given one coordinate (origin or destination):
1. Compute straight-line (haversine) distance to every `BusStop` across all corridors/directions — cheap, no network, runs on ~478 stop entries instantly.
2. Take the top 5 closest by straight-line distance.
3. Call `MKDirections` (walking) for only those 5 candidates to get real walking distance/duration, then re-rank by that.
4. If a walking-directions call fails for a candidate, fall back to its straight-line distance for ranking purposes only (that candidate isn't dropped).

Capping refinement at 5 candidates per search (max 10 walking calls total: 5 origin + 5 destination) avoids repeating the `MKDirections` rate-limit problem noted in the route-visualisation spec (~460 calls caused throttling).

### `RoutePlanner`
Builds a static graph once from `corridors` (no network, pure geometry):
- Flattens every `(corridorID, directionID, stopIndex, stop)` tuple across all directions.
- Precomputes "transfer-compatible" stop pairs: any two stops from *different* directions whose straight-line distance is under a 150m threshold. This catches near-duplicate interchange points (e.g. "Central Parkir Kuta" vs "Central Parkir Kuta Luar", ~40m apart) without requiring exact name/coordinate match.

`findRoutes(originCandidates: [BusStop], destinationCandidates: [BusStop], maxTransfers: 2) -> [TripRoute]`:
- Riding rule: within one `RouteDirection`, boarding at stop index `i` and alighting at index `j` is only valid when `j > i` (stops are already ordered in the direction of travel — no riding backward).
- BFS by transfer tier, 0 through `maxTransfers`:
  - **Tier 0 (direct):** any direction containing both an origin-candidate stop (index `i`) and a destination-candidate stop (index `j > i`) → 1-leg route.
  - **Tier 1:** from possible alight points (index `≥ i`) on a tier-0-style first leg, look up transfer-compatible stops on other directions, start leg 2 there, check if it reaches a destination candidate.
  - **Tier 2:** repeat once more from leg 2's alight points.
- Per tier, if multiple candidate routes exist (different origin/destination candidate combos), keep only the one minimizing `walkToFirstStop + walkFromLastStop`.
- Return up to one `TripRoute` per tier found (max 3 results total) — a tier is only included if a route exists for it.

## UI (`Views/RouteMapView.swift`)
Apple Maps-style bottom sheet, layered on top of the existing map + corridor toggle row (which stays untouched and keeps working independently):

- `.sheet` with `.presentationDetents([.height(80), .medium, .large])` and `.presentationBackgroundInteraction(.enabled(upThrough: .medium))` so the map stays pannable/zoomable while the sheet is up.
- **Collapsed:** just a search field ("Cari tujuan..."). Typing drives `MKLocalSearchCompleter` suggestions shown as a list; sheet auto-expands to `.medium`.
- **Selecting a suggestion:** resolves the destination via `MKLocalSearch`, requests current location via `LocationManager`, runs `NearestStopFinder` for origin and destination in parallel, then `RoutePlanner.findRoutes`. Sheet shows a loading state, then a list of `TripRoute` cards.
- **Each card** shows: corridor chips per leg with transfer arrows (e.g. `K1 → K4`), direction label (Pergi/Pulang) per leg, walk distance to the first stop and from the last stop, transfer count.
- **Tapping a card:** sets `visibleCorridorIDs` / `visibleDirectionIDs` (existing `@State` in `RouteMapView`) to exactly the corridors/directions used by that route — the existing toggle row updates automatically since it's bound to the same state. Sheet collapses to a small summary bar with a clear/reset button. Destination gets a pin `Annotation` on the map.

## Error Handling
- Location permission denied/restricted: inline message in the sheet ("Aktifkan akses lokasi..."), no fallback — origin is GPS-only by design.
- Destination search returns no results: empty state under the search field.
- No route found within 2 transfers: "Rute belum ditemukan" message in place of the card list.
- Failed `MKDirections` walking call for a candidate stop: falls back to straight-line distance for that candidate only (mirrors the existing `RouteGeometry` fallback pattern) — never blocks the search.

## Testing
Non-trivial logic here is `RoutePlanner`'s tiered BFS and `NearestStopFinder`'s ranking — both covered without hitting the network:
- `RoutePlanner`: unit test against a small fake/stubbed corridor graph, asserting a direct route is found when one exists, a 1-transfer route is found via a proximity-compatible stop on a different direction, and no route is returned when reaching the destination requires more than `maxTransfers`.
- `NearestStopFinder`: unit test with stubbed walking-distance results, asserting the straight-line prefilter picks the right top-5 and the final ranking follows the stubbed walking distances.

## Out of scope for this pass
- Manual/searchable origin (always current GPS location).
- Persisted search history or favorite destinations.
- Fare or travel-time estimates.
- More than 2 transfers.

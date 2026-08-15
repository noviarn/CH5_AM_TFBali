# Route Visualisation — Design

## Purpose
Show bus corridor routes (koridor) and their stops (halte) on a real MapKit map, scoped to Bali. First corridor to ship: K1 (Central Parkir Kuta ↔ Terminal Pesiapan Tabanan). Built to extend to more corridors later without restructuring.

## Scope
- In: map screen showing corridor polylines + stop pins, corridor selection toggle, tap-stop detail, road-following route lines.
- Out: turn-by-turn navigation, live vehicle tracking, real-time schedules — not part of this feature.

## Data Model (`Models/`)
```swift
struct BusStop: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct RouteDirection: Identifiable {
    let id = UUID()
    let label: String                     // "Central Parkir Kuta → Terminal Tabanan"
    let stops: [BusStop]                  // ordered
    let viaPoints: [Int: [CLLocationCoordinate2D]]  // segment index (between stop i, i+1) -> manual shaping points, default [:]
    let manualOverride: [Int: [CLLocationCoordinate2D]]  // segment index -> full hardcoded polyline, skips routing entirely, default [:]
}

struct Corridor: Identifiable {
    let id: String        // "K1"
    let name: String
    let color: Color       // .orange for K1
    let directions: [RouteDirection]  // berangkat & pulang
}
```

## Data Storage (`Constants/CorridorData.swift`)
Corridors hardcoded as static Swift data (`let corridors: [Corridor]`), not JSON — no bundle/parsing needed, compile-time checked, easy to append a new corridor entry later. K1 data (both directions, from user's notes) goes here first.

## Route Geometry (`Services/RouteGeometry.swift`)
For each `RouteDirection`, build the full road-following polyline:
1. For each consecutive stop pair (segment i → i+1):
   - If `manualOverride[i]` exists, use those coordinates directly (no routing call).
   - Else build the waypoint chain: `[stop_i] + (viaPoints[i] ?? []) + [stop_i+1]`, call `MKDirections` between each consecutive pair in that chain, concatenate the resulting route polylines in order.
2. Concatenate all segment polylines into one `[CLLocationCoordinate2D]` for the direction.
3. Requests run async (`MKDirections.calculate()` via async/await), computed once per app session when the map appears — no persistent caching for now (add later if relaunch cost/rate-limits become a real problem).
4. If a segment's directions request fails (no route found / network error), fall back to a straight line between the two stops for that segment only, so the map never shows a gap.

**Revision workflow** (for when a road-followed segment looks wrong): look up a road point in Maps, add its coordinate to `viaPoints` for that segment, rerun. If still wrong, hardcode the segment via `manualOverride`.

## Map View (`Views/RouteMapView.swift`)
- SwiftUI `Map` (iOS 17+ API), camera scoped to Bali on load.
- One `MapPolyline` per direction per visible corridor — `.stroke(corridor.color, style: solid for berangkat, dashed for pulang)`.
- One `Marker`/`Annotation` per stop (deduplicated by coordinate isn't needed — all stops from both directions shown as-is).
- Tapping a stop annotation opens a small sheet with the stop name.
- Corridor toggle row (chips) above/below the map to show/hide each corridor; all corridors visible by default.

## Error Handling
- Failed `MKDirections` segment → straight-line fallback (see above), not a blocking error — map should always render something.
- No location/network permission edge cases beyond what MapKit needs by default; no user-location features in this pass.

## Testing
Non-trivial logic here is the segment-chaining in `RouteGeometry` (viaPoints/manualOverride precedence, concatenation order, fallback behavior). Cover it with a small unit test using a fake/stubbed directions result rather than hitting the network, asserting:
- override segment skips routing and returns exact override coordinates
- viaPoints segment produces `n+1` chained calls for `n` via points
- failed segment falls back to straight line between its two stops

## Out of scope for this pass
- Persisted/cached route geometry across launches.
- More corridors beyond K1 (data model supports it, just not populated yet).

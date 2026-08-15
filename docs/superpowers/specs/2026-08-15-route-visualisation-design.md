# Route Visualisation — Design

## Purpose
Show bus corridor routes (koridor) and their stops (halte) on a real MapKit map, scoped to Bali.

## Corridors (all data collected, ship together)
| ID | Name | Color | Legs |
|---|---|---|---|
| K1 | Central Parkir Kuta ↔ Terminal Pesiapan Tabanan | orange | 2 (round trip) |
| K2 | Terminal Ubung ↔ Bandara I Gusti Ngurah Rai | light blue | 2 (round trip) |
| K3 | Terminal Ubung ↔ ICON Mall Sanur (via Dalung) | navy | 2 (round trip) |
| K4 | Terminal Ubung ↔ Monkey Forest Ubud | green (mid) | 2 (round trip) |
| K5 | Central Parkir Kuta → Politeknik Negeri Bali → Titi Banda → Central Parkir Kuta | yellow | 3 (loop, not a simple round trip — one bus runs all 3 legs in sequence) |
| K6 | Central Parkir Kuta ↔ ITDC Nusa Dua | very light blue | 2 (round trip) |
| S1 | Gor Ngurah Rai ↔ GWK (Trans Sarbagita network, distinct from K1–K6's Trans Metro Dewata) | teal/tosca | 2 (round trip) |
| Shuttle Sanur | Mertasari ↔ Jl. Wira (Segara Ayu) | same hue as K6, dotted line style to distinguish from K6's solid/dashed | 2 (round trip) |

`RouteDirection` is not fixed at 2 per corridor — K5 has 3, modeled as 3 sequential legs on the same `Corridor`.

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
Corridors hardcoded as static Swift data (`let corridors: [Corridor]`), not JSON — no bundle/parsing needed, compile-time checked, easy to append a new corridor entry later. All 8 corridors above (from user's notes) go here.

Two K4 stop coordinates were supplied in DMS and converted to decimal for storage: Hanoman 1 (Ceremony) → `-8.509167, 115.265083`, Simpang Sakah (Mata) → `-8.564639, 115.274083` — confirmed against Google Maps by the user.

## Route Geometry (`Services/RouteGeometry.swift`)
For each `RouteDirection`, build the full road-following polyline:
1. For each consecutive stop pair (segment i → i+1):
   - If `manualOverride[i]` exists, use those coordinates directly (no routing call).
   - Else build the waypoint chain: `[stop_i] + (viaPoints[i] ?? []) + [stop_i+1]`, call `MKDirections` between each consecutive pair in that chain, concatenate the resulting route polylines in order.
2. Concatenate all segment polylines into one `[CLLocationCoordinate2D]` for the direction.
3. Requests run async (`MKDirections.calculate()` via async/await), computed lazily per corridor — only for corridors currently visible, not all 8 upfront. Loading all 8 corridors' full route geometry on launch means ~460 sequential `MKDirections` calls, which hits Apple's rate limit and silently degrades to straight lines; lazy loading avoids that. No persistent caching for now (add later if relaunch cost becomes a problem even with lazy loading).
4. If a segment's directions request fails (no route found / network error), fall back to a straight line between the two stops for that segment only, so the map never shows a gap.

**Revision workflow** (for when a road-followed segment looks wrong): look up a road point in Maps, add its coordinate to `viaPoints` for that segment, rerun. If still wrong, hardcode the segment via `manualOverride`.

## Map View (`Views/RouteMapView.swift`)
- SwiftUI `Map` (iOS 17+ API), camera scoped to Bali on load.
- One `MapPolyline` per direction/leg per visible corridor — `.stroke(corridor.color, style:)`: solid for the first leg, dashed for the second, alternating for any further legs (covers K5's 3 legs). Shuttle Sanur additionally uses a dotted style instead of solid/dashed, to stay visually distinct from K6 despite sharing its hue.
- One `Marker`/`Annotation` per stop (deduplicated by coordinate isn't needed — all stops from both directions shown as-is).
- Tapping a stop annotation opens a small sheet with the stop name.
- Corridor toggle row (chips) above/below the map to show/hide each corridor. Default: only **K1** visible on launch (not all 8), to keep the initial `MKDirections` request volume low — toggling a corridor on loads its polylines on demand and caches the result so toggling off/on doesn't re-fetch.

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

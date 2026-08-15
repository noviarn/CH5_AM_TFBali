# Route Visualisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show all 8 Bali bus corridors (K1–K6, S1, Shuttle Sanur) as road-following polylines with stop pins on a SwiftUI MapKit map, with per-corridor toggle and tap-to-see-stop-name.

**Architecture:** Static Swift data (one file per corridor) feeds a pure, testable segment-chaining function, which an async `MKDirections`-based service turns into road-following coordinate arrays at runtime; a SwiftUI `Map` renders them as `MapPolyline`s and `Annotation`s.

**Tech Stack:** SwiftUI, MapKit (`Map`, `MapPolyline`, `Annotation`, `MKDirections`), CoreLocation. No new dependencies, no new Xcode targets.

## Global Constraints
- iOS deployment target: 26.5 (already set in the project — do not lower it).
- Swift version: 5.0 (already set).
- Xcode project uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+ format) — any file created inside `CH5_AM_TFBali/` on disk is automatically part of the app target. **Do not hand-edit `project.pbxproj`.**
- This sandbox has no usable `xcodebuild` (only Command Line Tools are installed, not full Xcode) and no test target exists in the project. **Every "verify" step in this plan that needs a build or app run must be done by the human in Xcode**, not by an agent shell command. Steps say exactly what to click/read.
- No new Xcode test target is created (would require hand-editing `project.pbxproj`, risky on a synchronized-groups project, and not worth it for one service class). Instead, non-trivial logic (`RouteGeometry` segment chaining, corridor data integrity) gets an `#if DEBUG` assert-based self-check that runs once at app launch and prints ✅/💥 to the Xcode console. This is a deliberate substitute for XCTest, not an oversight — flag it to the user if they'd rather have a real test target.

---

## File Structure

```
CH5_AM_TFBali/
  Models/
    Corridor.swift          # BusStop, RouteDirection, Corridor, stop() helper — new
  Services/
    RouteGeometry.swift     # segment chaining + MKDirections calls + self-check — new
  Constants/
    Corridors/
      K1.swift               # new
      K2.swift               # new
      K3.swift               # new
      K4.swift               # new
      K5.swift               # new
      K6.swift               # new
      S1.swift                # new
      ShuttleSanur.swift      # new
    CorridorData.swift        # `let corridors: [Corridor]` + CorridorDataCheck self-check — new
  Views/
    RouteMapView.swift        # map + corridor toggle chips + stop detail sheet — new
  CH5_AM_TFBaliApp.swift      # modify: run self-checks in DEBUG
  ContentView.swift           # modify: show RouteMapView
```

Model structs (`BusStop`, `RouteDirection`, `Corridor`) live in one file because they're tiny, always used together, and none of them makes sense without the others — three near-empty files would be more fragmentation than clarity. Each corridor gets its own data file (not one big file) because the spec's revision workflow (fixing a bad `viaPoint` or `manualOverride`) happens per corridor, and a developer should be able to open exactly the file for the corridor they're fixing.

---

## Task 1: Models

**Files:**
- Create: `CH5_AM_TFBali/Models/Corridor.swift`

**Interfaces:**
- Produces: `BusStop(name: String, coordinate: CLLocationCoordinate2D) -> BusStop` (struct init), `BusStop.id: UUID`, `BusStop.name: String`, `BusStop.coordinate: CLLocationCoordinate2D`
- Produces: `RouteDirection(label: String, stops: [BusStop], viaPoints: [Int: [CLLocationCoordinate2D]] = [:], manualOverride: [Int: [CLLocationCoordinate2D]] = [:])`, `.id: UUID`, `.label: String`, `.stops: [BusStop]`, `.viaPoints`, `.manualOverride`
- Produces: `Corridor(id: String, name: String, color: Color, directions: [RouteDirection])`, `.id: String`, `.name: String`, `.color: Color`, `.directions: [RouteDirection]`
- Produces: `stop(_ name: String, _ lat: Double, _ lon: Double) -> BusStop` — free function, used by every corridor data file in Task 3–10.

- [ ] **Step 1: Create the model file**

```swift
import Foundation
import CoreLocation
import SwiftUI

struct BusStop: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
}

struct RouteDirection: Identifiable {
    let id = UUID()
    let label: String
    let stops: [BusStop]
    var viaPoints: [Int: [CLLocationCoordinate2D]] = [:]
    var manualOverride: [Int: [CLLocationCoordinate2D]] = [:]
}

struct Corridor: Identifiable {
    let id: String
    let name: String
    let color: Color
    let directions: [RouteDirection]
}

func stop(_ name: String, _ lat: Double, _ lon: Double) -> BusStop {
    BusStop(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
}
```

- [ ] **Step 2: Verify it compiles**

In Xcode: open the project, press Cmd+B.
Expected: "Build Succeeded", no errors in `Corridor.swift`.

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Models/Corridor.swift
git commit -m "feat: add BusStop, RouteDirection, Corridor models"
```

---

## Task 2: RouteGeometry service

**Files:**
- Create: `CH5_AM_TFBali/Services/RouteGeometry.swift`

**Interfaces:**
- Consumes: `RouteDirection` (Task 1) — `.stops`, `.viaPoints`, `.manualOverride`
- Produces: `RouteGeometry.Segment { index: Int; waypoints: [CLLocationCoordinate2D]; overrideCoordinates: [CLLocationCoordinate2D]? }`
- Produces: `RouteGeometry.segments(for: RouteDirection) -> [RouteGeometry.Segment]` — pure, no I/O, used by Task 15 (map) indirectly through `polyline(for:)` and directly by the self-check below.
- Produces: `RouteGeometry.polyline(for: RouteDirection) async -> [CLLocationCoordinate2D]` — hits `MKDirections`, used by `RouteMapView` (Task 12).
- Produces (DEBUG only): `RouteGeometry.runSelfCheck()`

- [ ] **Step 1: Write the file with the pure chaining logic, the async MKDirections integration, and the self-check together**

This is one cohesive service; the self-check at the bottom is the "test" for the pure part (there's no test target — see Global Constraints).

```swift
import Foundation
import CoreLocation
import MapKit

enum RouteGeometry {
    struct Segment {
        let index: Int
        let waypoints: [CLLocationCoordinate2D]       // >= 2: stop_i, (via...), stop_i+1 — used for routing
        let overrideCoordinates: [CLLocationCoordinate2D]?  // if set, skip routing and use this polyline directly
    }

    /// Pure: no network, no async. Turns a direction's stops + viaPoints + manualOverride
    /// into an ordered list of segments to route (or not route).
    static func segments(for direction: RouteDirection) -> [Segment] {
        guard direction.stops.count >= 2 else { return [] }
        var result: [Segment] = []
        for i in 0..<(direction.stops.count - 1) {
            let a = direction.stops[i].coordinate
            let b = direction.stops[i + 1].coordinate
            if let override = direction.manualOverride[i] {
                result.append(Segment(index: i, waypoints: [a, b], overrideCoordinates: override))
            } else {
                let via = direction.viaPoints[i] ?? []
                result.append(Segment(index: i, waypoints: [a] + via + [b], overrideCoordinates: nil))
            }
        }
        return result
    }

    /// Builds the full road-following polyline for a direction. Falls back to a straight
    /// line for any leg whose MKDirections request fails, so the map never shows a gap.
    static func polyline(for direction: RouteDirection) async -> [CLLocationCoordinate2D] {
        var full: [CLLocationCoordinate2D] = []
        for segment in segments(for: direction) {
            if let override = segment.overrideCoordinates {
                full.append(contentsOf: override)
                continue
            }
            for i in 0..<(segment.waypoints.count - 1) {
                let from = segment.waypoints[i]
                let to = segment.waypoints[i + 1]
                if let coords = await drivingRoute(from: from, to: to) {
                    full.append(contentsOf: coords)
                } else {
                    full.append(contentsOf: [from, to])
                }
            }
        }
        return full
    }

    private static func drivingRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .automobile
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }
            return route.polyline.coordinates
        } catch {
            return nil
        }
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}

#if DEBUG
extension RouteGeometry {
    static func runSelfCheck() {
        let a = stop("A", 0, 0)
        let b = stop("B", 1, 1)
        let c = stop("C", 2, 2)
        let via = CLLocationCoordinate2D(latitude: 0.5, longitude: 0.5)
        let override = [CLLocationCoordinate2D(latitude: 9, longitude: 9), CLLocationCoordinate2D(latitude: 9.5, longitude: 9.5)]

        let direction = RouteDirection(
            label: "self-check",
            stops: [a, b, c],
            viaPoints: [0: [via]],
            manualOverride: [1: override]
        )

        let segments = RouteGeometry.segments(for: direction)
        assert(segments.count == 2, "expected 2 segments for 3 stops, got \(segments.count)")
        assert(segments[0].waypoints.count == 3, "segment 0 should chain through 1 via point, got \(segments[0].waypoints.count) waypoints")
        assert(segments[0].overrideCoordinates == nil, "segment 0 should not have an override")
        assert(segments[1].overrideCoordinates?.count == 2, "segment 1 should use the 2-point manual override")
        assert(segments[1].overrideCoordinates?[0].latitude == 9, "segment 1 override should start at lat 9")

        print("✅ RouteGeometry.runSelfCheck passed")
    }
}
#endif
```

- [ ] **Step 2: Verify the self-check runs and passes**

This is wired up and run in Task 13. For now just verify the file compiles: in Xcode, Cmd+B.
Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Services/RouteGeometry.swift
git commit -m "feat: add RouteGeometry segment chaining and MKDirections integration"
```

---

## Task 3: K1 corridor data

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/K1.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.k1: Corridor` — static member, consumed by Task 11 (`CorridorData.swift`)

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let k1 = Corridor(
        id: "K1",
        name: "Central Parkir Kuta - Terminal Pesiapan Tabanan",
        color: .orange,
        directions: [
            RouteDirection(
                label: "Central Parkir Kuta → Terminal Pesiapan Tabanan",
                stops: [
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                    stop("Abian Base (Balenong)", -8.708141, 115.181280),
                    stop("Imam Bonjol Kelod (TSM)", -8.702626, 115.184702),
                    stop("Pulau Galang (Cat)", -8.696691, 115.186157),
                    stop("Simpang Soputan (Sinar)", -8.692240, 115.188700),
                    stop("Abian Timbul (Nadi)", -8.687161, 115.192894),
                    stop("Buagan 1 (Erlangga)", -8.679699, 115.198071),
                    stop("Dinas Pemadam Kebakaran Denpasar", -8.674890, 115.202188),
                    stop("Monang Maning (Ford)", -8.669936, 115.204892),
                    stop("Terminal Tegal Sari (Dalam)", -8.661913, 115.208697),
                    stop("Thamrin", -8.656316, 115.210142),
                    stop("Puri Kawan Jrokuta", -8.651324, 115.208780),
                    stop("RS Manuaba (Alfamart)", -8.641566, 115.209016),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("Banjar Tengah Ubung", -8.632389, 115.204578),
                    stop("Petangan Gede (Alfamart)", -8.626337, 115.200741),
                    stop("Pos Kargo (Bengkel Budi)", -8.619050, 115.196713),
                    stop("Simpang Kargo (Noir)", -8.613878, 115.193062),
                    stop("Puspem Badung", -8.601327, 115.186097),
                    stop("Delod Badung", -8.591886, 115.186619),
                    stop("Simpang Darmasaba", -8.581770, 115.187484),
                    stop("RSUD Kapal", -8.578490, 115.183550),
                    stop("Pasar Kapal", -8.572574, 115.179869),
                    stop("Simpang Tiga Panglan", -8.568399, 115.180650),
                    stop("Terminal Mengwi", -8.560112, 115.168185),
                    stop("Abian Tuwung (Lalapan)", -8.560032, 115.151996),
                    stop("Simpang Koripan (FIFGroup)", -8.556637, 115.145093),
                    stop("Simpang Ir. Soekarno (Semesta)", -8.554158, 115.139002),
                    stop("Simpang Bypass Kediri (Sanggulan)", -8.552703, 115.133815),
                    stop("Simpang Gerokgak", -8.550541, 115.125078),
                    stop("Simpang Turi Farigata", -8.548482, 115.120494),
                    stop("Simpang Dukuh (Daihatsu)", -8.544967, 115.114577),
                    stop("Simpang Gubug (Sanjaya)", -8.541610, 115.112919),
                    stop("SMK Bintang Persada", -8.538530, 115.111425),
                    stop("Terminal Pesiapan Tabanan", -8.535535, 115.113290),
                ]
            ),
            RouteDirection(
                label: "Terminal Pesiapan Tabanan → Central Parkir Kuta",
                stops: [
                    stop("Terminal Persiapan Tabanan", -8.535570, 115.112699),
                    stop("SMK Bintang Persada", -8.538720, 115.111641),
                    stop("Simpang Gubug (Bu Ketut)", -8.541756, 115.113126),
                    stop("Simpang Dukuh (Apotek)", -8.544806, 115.114586),
                    stop("Simpang Turi (K24)", -8.548387, 115.120488),
                    stop("Simpang Grokgak (Bumi Mas)", -8.550338, 115.124706),
                    stop("Simpang Bypass Kediri (Artasedana)", -8.552572, 115.133711),
                    stop("Terminal Kediri", -8.554197, 115.140234),
                    stop("Patung Nuwun Padi (JnT Cargo)", -8.556627, 115.145334),
                    stop("Abian Tuwung (Alfamart)", -8.559932, 115.151904),
                    stop("Terminal Mengwi", -8.560112, 115.168185),
                    stop("Pasar Bringkit", -8.563652, 115.173323),
                    stop("Simpang Tiga Panglan (Abadi)", -8.569855, 115.181224),
                    stop("Pasar Kapal (Pura Dalem Borneo)", -8.573050, 115.179746),
                    stop("RSUD Kapal (Tirta Mangutama)", -8.578352, 115.183484),
                    stop("Simpang Darmasaba (Sari Laut)", -8.581118, 115.186948),
                    stop("Delod Perempatan (Circle K)", -8.592137, 115.186705),
                    stop("Puspem Badung (Bekisar)", -8.600245, 115.186229),
                    stop("Simpang Kargo (Hino)", -8.613419, 115.192945),
                    stop("Pos Kargo (Mobil 89)", -8.617796, 115.195799),
                    stop("Petangan Gede (Bayu Mo)", -8.625522, 115.200812),
                    stop("Banjar Tengah Ubung", -8.632154, 115.203627),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("RS Manuaba", -8.643773, 115.209371),
                    stop("Sutomo", -8.648117, 115.210260),
                    stop("Puri Agung Jrokuta", -8.651789, 115.210918),
                    stop("Gajah Mada", -8.655374, 115.212803),
                    stop("Hasanudin", -8.658654, 115.213517),
                    stop("Griya Tegal", -8.664421, 115.207629),
                    stop("Monang Maning (Pura Dalem Segening)", -8.669671, 115.205140),
                    stop("Dinas Pemadam Kebakaran Denpasar (Buagan 2)", -8.675071, 115.202251),
                    stop("Buagan 3 (Buagan)", -8.678562, 115.199064),
                    stop("Banjar Buagan Selatan (Buagan 4)", -8.684077, 115.195351),
                    stop("Abian Timbul", -8.688022, 115.192387),
                    stop("Simpang Soputan", -8.691075, 115.189915),
                    stop("Pulau Galang", -8.694503, 115.187778),
                    stop("Imam Bonjol Kelod 2 (Imam Bonjol Square)", -8.700153, 115.185246),
                    stop("Imam Bonjol Kelod 3 (Dunlop)", -8.703027, 115.184876),
                    stop("Abian Base (Indomaret)", -8.708100, 115.181378),
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/K1.swift
git commit -m "feat: add K1 corridor data"
```

---

## Task 4: K2 corridor data

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/K2.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.k2: Corridor` — consumed by Task 11

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let k2 = Corridor(
        id: "K2",
        name: "Terminal Ubung - Bandara I Gusti Ngurah Rai",
        color: Color(red: 0.30, green: 0.60, blue: 0.95),
        directions: [
            RouteDirection(
                label: "Terminal UBUNG → Bandara I Gusti Ngurah Rai",
                stops: [
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("Dharma Negara Alaya", -8.637327, 115.212056),
                    stop("Gatsu 1 (Happy Puppy)", -8.635710, 115.218067),
                    stop("Nangka Selatan 1 (Hotel Nuansa Indah)", -8.637590, 115.222728),
                    stop("Nangka Selatan 2 (Gang Sandat)", -8.640183, 115.222207),
                    stop("Nangka Selatan 3 (Kertasari)", -8.644859, 115.219791),
                    stop("Banjar Tansiat", -8.648817, 115.217531),
                    stop("Gor Ngurah Rai", -8.649160, 115.223455),
                    stop("SMA N 7 Denpasar", -8.651201, 115.224534),
                    stop("Melati", -8.654547, 115.222620),
                    stop("Pasar Kreneng", -8.656000, 115.224283),
                    stop("Banjar Kayumas", -8.656579, 115.220744),
                    stop("RSAD Udayana", -8.663585, 115.218231),
                    stop("Unud Sudirman 1", -8.671669, 115.218275),
                    stop("Unud Sudirman 2 (Starbucks)", -8.672713, 115.217947),
                    stop("Dewi Sartika", -8.669740, 115.217010),
                    stop("Teuku Umar 1 (Cicilia Florist)", -8.669519, 115.213174),
                    stop("Teuku Umar 3 (Indoraya)", -8.672004, 115.208975),
                    stop("Teuku Umar 5 (Siantar Ponsel)", -8.675147, 115.207539),
                    stop("Teuku Umar 7 (Amaris Hotel)", -8.680738, 115.202751),
                    stop("Banjar Buagan Selatan (Ubi Cilembu)", -8.684077, 115.195351),
                    stop("Abian Timbul", -8.688022, 115.192387),
                    stop("Simpang Soputan", -8.691075, 115.189915),
                    stop("Pulau Galang (Agung)", -8.694503, 115.187778),
                    stop("Imam Bonjol Kelod 2 (Imam Bonjol Square)", -8.700153, 115.185246),
                    stop("Imam Bonjol Kelod 3 (Dunlop)", -8.703027, 115.184876),
                    stop("Abian Base (Indomaret)", -8.708100, 115.181378),
                    stop("Central Parkir Kuta Luar", -8.713402, 115.181173),
                    stop("Raya Kuta 1 (BCA)", -8.717918, 115.180971),
                    stop("Raya Kuta 2 (SPBU Pertamina)", -8.720887, 115.180042),
                    stop("Camat Kuta", -8.725514, 115.178021),
                    stop("Tuban 1 (Joger)", -8.727256, 115.176915),
                    stop("Tuban 2 (The Keranjang)", -8.731766, 115.177520),
                    stop("Tuban 3 (BMKG)", -8.739166, 115.178483),
                    stop("Tuban 4 (Krisna Wisata Kuliner)", -8.741887, 115.178885),
                    stop("Perum Komplek Burung", -8.743987, 115.172745),
                    stop("Terminal Internasional", -8.741886, 115.166149),
                    stop("Terminal Domestik", -8.742077, 115.164303),
                ]
            ),
            RouteDirection(
                label: "Bandara I Gusti Ngurah Rai → Terminal UBUNG",
                stops: [
                    stop("Terminal Domestik", -8.742077, 115.164303),
                    stop("Perum Komplek Burung (Arjuna)", -8.743816, 115.172422),
                    stop("Tuban 5 (Krisna Oleh-Oleh)", -8.742390, 115.178876),
                    stop("Tuban 6 (Yonif 741 Barat)", -8.739862, 115.178524),
                    stop("Tuban 7 (Bandung Collection)", -8.731547, 115.177411),
                    stop("Raya Kuta 3 (BPD Kuta)", -8.724110, 115.176659),
                    stop("Raya Kuta 4 (Alfamart)", -8.719895, 115.180241),
                    stop("Raya Kuta 5 (Indobat)", -8.717300, 115.181009),
                    stop("Central Parkir Kuta Luar (Exit Gate)", -8.712697, 115.181087),
                    stop("Abian Base (Balenong)", -8.708141, 115.181280),
                    stop("Imam Bonjol Kelod (TSM)", -8.702626, 115.184702),
                    stop("Pulau Galang (Cat)", -8.696691, 115.186157),
                    stop("Simpang Soputan (Sinar)", -8.692240, 115.188700),
                    stop("Abian Timbul (Nadi)", -8.687161, 115.192894),
                    stop("Teuku Umar (Rodalink)", -8.680398, 115.203137),
                    stop("Teuku Umar (Electronic)", -8.674776, 115.207535),
                    stop("Teuku Umar (Erafone)", -8.671717, 115.208970),
                    stop("Teuku Umar (SAS)", -8.669304, 115.212566),
                    stop("Unud Sudirman 1", -8.671669, 115.218275),
                    stop("Unud Sudirman 2 (Starbucks)", -8.672713, 115.217947),
                    stop("Dewi Sartika", -8.669740, 115.217010),
                    stop("Diponegoro 1 (Buccheri)", -8.665718, 115.215458),
                    stop("Diponegoro 2 (Nasi Kuning Hj. Siti Azis)", -8.661744, 115.215033),
                    stop("Inna Bali Heritage", -8.654883, 115.216979),
                    stop("Pasar Satria", -8.649974, 115.217382),
                    stop("GOR Ngurah Rai Luar", -8.649176, 115.223412),
                    stop("SMAN 7 Denpasar", -8.651201, 115.224534),
                    stop("Melati", -8.654547, 115.222620),
                    stop("Banjar Kayumas", -8.656579, 115.220744),
                    stop("Bali Post (Kepundung)", -8.649795, 115.220842),
                    stop("Suli 1", -8.648656, 115.223031),
                    stop("Suli 2 (Notaris)", -8.642062, 115.224282),
                    stop("Gatsu 1 (Maybank Finance)", -8.635869, 115.217917),
                    stop("SMP N 10 Denpasar", -8.637038, 115.213416),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/K2.swift
git commit -m "feat: add K2 corridor data"
```

---

## Task 5: K3 corridor data

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/K3.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.k3: Corridor` — consumed by Task 11

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let k3 = Corridor(
        id: "K3",
        name: "Terminal Ubung - ICON Mall Sanur (via Dalung)",
        color: Color(red: 0.05, green: 0.15, blue: 0.45),
        directions: [
            RouteDirection(
                label: "Terminal UBUNG → ICON Mall Sanur",
                stops: [
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("RS Manuaba", -8.643773, 115.209371),
                    stop("Sutomo", -8.648117, 115.210260),
                    stop("Puri Agung Jrokuta", -8.651789, 115.210918),
                    stop("Gajah Mada", -8.655374, 115.212803),
                    stop("Kantor Walikota Denpasar", -8.655834, 115.216230),
                    stop("Surapati", -8.656227, 115.219035),
                    stop("RSAD Udayana", -8.663585, 115.218231),
                    stop("Simpang Sudirman", -8.669558, 115.218471),
                    stop("Bank Indonesia Renon", -8.668063, 115.221830),
                    stop("Dishub Provinsi Bali", -8.666915, 115.225711),
                    stop("Kantor Samsat", -8.667028, 115.229387),
                    stop("Dinas Pariwisata Bali (arah Timur)", -8.670212, 115.230766),
                    stop("Kantor Gubernur Bali (arah Timur)", -8.669196, 115.234727),
                    stop("Simpang Renon 1 (Dermaster)", -8.673181, 115.239489),
                    stop("Simpang Renon 2 (Renon Plaza)", -8.673415, 115.243973),
                    stop("SD N 2 Sanur (Arah Timur)", -8.674421, 115.254817),
                    stop("Simpang Sanur Hangtuah", -8.674310, 115.259957),
                    stop("Pantai Sindhu 1", -8.681207, 115.259409),
                    stop("ICON Mall Sanur", -8.686875, 115.262701),
                ]
            ),
            RouteDirection(
                label: "ICON Mall Sanur → Terminal UBUNG (via Dalung)",
                stops: [
                    stop("ICON Mall Sanur", -8.686875, 115.262701),
                    stop("Pantai Sindhu 2 (Grandlucky Sanur)", -8.680493, 115.259016),
                    stop("Simpang Sanur HangTuah", -8.674310, 115.259957),
                    stop("SD N 2 Sanur (Arah Barat)", -8.674518, 115.255272),
                    stop("Simpang Renon 3 (Warung Puri Suranadi)", -8.673671, 115.243537),
                    stop("Simpang Renon 4 (SD N 11 Sumerta)", -8.673518, 115.240072),
                    stop("Kantor Gubernur Bali (arah Barat)", -8.669361, 115.234706),
                    stop("Dinas Pariwisata Bali (arah Barat)", -8.670277, 115.230693),
                    stop("Kejaksaan Tinggi Bali", -8.671002, 115.228411),
                    stop("Disdik Bali", -8.671264, 115.221623),
                    stop("Dewi Sartika", -8.669740, 115.217010),
                    stop("Diponegoro 1 (Buccheri)", -8.665718, 115.215458),
                    stop("Diponegoro 2 (Nasi Kuning Hj. Siti Azis)", -8.661744, 115.215033),
                    stop("Hasanudin", -8.658654, 115.213517),
                    stop("Thamrin", -8.656316, 115.210142),
                    stop("Puri Kawan Jrokuta", -8.651324, 115.208780),
                    stop("RS Manuaba (Alfamart)", -8.641566, 115.209016),
                    stop("Simpang Ubung (Aston)", -8.639127, 115.205886),
                    stop("Simpang Gunung Catur (Mitra10)", -8.636478, 115.190635),
                    stop("Gatsu (Danamon)", -8.637195, 115.175488),
                    stop("Pos Pengamanan Terpadu Dalung (Puter Balik)", -8.629848, 115.174779),
                    stop("Gatsu (Deva Store)", -8.637074, 115.175274),
                    stop("Simpang Gunung Catur (Phillips)", -8.636383, 115.190356),
                    stop("Simpang Ubung (Bata)", -8.638939, 115.206611),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/K3.swift
git commit -m "feat: add K3 corridor data"
```

---

## Task 6: K4 corridor data

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/K4.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.k4: Corridor` — consumed by Task 11

Note: "Hanoman 1 (Ceremony)" and "Simpang Sakah (Mata)" were supplied in DMS and converted to decimal (confirmed against Google Maps by the user) — see the spec doc.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let k4 = Corridor(
        id: "K4",
        name: "Terminal Ubung - Monkey Forest Ubud",
        color: .green,
        directions: [
            RouteDirection(
                label: "Terminal UBUNG → Monkey Forest Ubud",
                stops: [
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                    stop("Dharma Negara Alaya", -8.637327, 115.212056),
                    stop("Gatsu 1 (Happy Puppy)", -8.635710, 115.218067),
                    stop("Simpang Nangka (CV.SSM)", -8.635503, 115.226349),
                    stop("Living World", -8.635659, 115.231464),
                    stop("Simpang Noja", -8.635885, 115.234041),
                    stop("Simpang Trengguli (Cv. Putra Jaya)", -8.635790, 115.242097),
                    stop("Sekar Jepun (BCA)", -8.635273, 115.247630),
                    stop("Tohpati 1", -8.639532, 115.254126),
                    stop("Kertalangu", -8.642053, 115.255042),
                    stop("Titi Banda", -8.647312, 115.257324),
                    stop("Tohpati 2 (Ikura Sushi)", -8.640599, 115.254277),
                    stop("Asrama Brimob (Halte Siulan)", -8.633722, 115.256961),
                    stop("Terminal Batubulan Luar (Nasi Bebek)", -8.630894, 115.259589),
                    stop("Batubulan (Cening Bagus)", -8.625959, 115.257552),
                    stop("Banjar Kalah Batubulan", -8.618161, 115.254466),
                    stop("Lapangan Candra Muka", -8.611818, 115.253363),
                    stop("Celuk 1 (JnT Cargo)", -8.604227, 115.254231),
                    stop("RS Ganesha", -8.601330, 115.263939),
                    stop("Kantor Desa Celuk", -8.600002, 115.271014),
                    stop("Pasar Seni 3 Sukawati (Puspa Kebaya)", -8.602971, 115.279451),
                    stop("Pasar Seni Sukawati", -8.595962, 115.282758),
                    stop("Peninjoan", -8.587126, 115.282388),
                    stop("Simpang Batuan (Kimia Farma)", -8.580904, 115.277789),
                    stop("Sakah (Cantina Collection)", -8.569647, 115.275194),
                    stop("Simpang SaKah", -8.562993, 115.273649),
                    stop("RS Ari Canti", -8.552161, 115.272448),
                    stop("Kantor Perbekel Mas", -8.544070, 115.271987),
                    stop("RS Kenak Medika", -8.532273, 115.271912),
                    stop("Cok Rai Pudak (UPTD Lab KesMas)", -8.525474, 115.271326),
                    stop("Kantor Perbekel Peliatan", -8.518385, 115.268908),
                    stop("Puri Dalem Puri Peliatan Ubud", -8.509066, 115.268955),
                    stop("Hanoman 1 (Ceremony)", -8.509167, 115.265083),
                    stop("Hanoman 2", -8.513040, 115.264255),
                    stop("Hanoman 3 (Ryoshi)", -8.517444, 115.263591),
                    stop("Sentral Parkir Monkey Forest", -8.520441, 115.260722),
                ]
            ),
            RouteDirection(
                label: "Monkey Forest Ubud → Terminal UBUNG",
                stops: [
                    stop("Sentral Parkir Monkey Forest", -8.520441, 115.260722),
                    stop("Monkey Forest 1 (Valeria)", -8.515752, 115.260127),
                    stop("Lapangan Astina Ubud", -8.509751, 115.261353),
                    stop("Cok Sudarsana", -8.509058, 115.269430),
                    stop("Kantor Perbekel Desa Peliatan", -8.518173, 115.269034),
                    stop("Cok Rai Pudak (Yangloni)", -8.526596, 115.271366),
                    stop("RS Kenak Medika", -8.533644, 115.272126),
                    stop("Kantor Perbekel Mas (Indomaret)", -8.543410, 115.272135),
                    stop("RS Ari Canti (JnT Cargo)", -8.552795, 115.272540),
                    stop("Simpang Sakah (Mata)", -8.564639, 115.274083),
                    stop("Sakah (Pura Ratu Pasar)", -8.569530, 115.275236),
                    stop("Simpang Batuan", -8.581515, 115.278833),
                    stop("Delude Tunon", -8.584514, 115.282271),
                    stop("Babakan Sukawati", -8.596457, 115.284508),
                    stop("Pura Pande Bang", -8.603086, 115.279017),
                    stop("Celuk 2 (Mutiara Silver)", -8.600058, 115.267924),
                    stop("RS Ganesha", -8.601346, 115.264142),
                    stop("Celuk 3 (Clandys)", -8.603182, 115.259103),
                    stop("SMP N 5 Sukawati", -8.606608, 115.252975),
                    stop("Kantor Desa Bulan", -8.612346, 115.253484),
                    stop("BPR Tish", -8.622505, 115.256385),
                    stop("Batubulan (Azko)", -8.624636, 115.257177),
                    stop("Terminal Batu Bulan", -8.631304, 115.261289),
                    stop("Tohpati 3 (Men Bokir)", -8.635299, 115.255565),
                    stop("Tohpati 1", -8.639532, 115.254126),
                    stop("Kertalangu", -8.642053, 115.255042),
                    stop("Titi Banda", -8.647312, 115.257324),
                    stop("Tohpati 2 (Ikura Sushi)", -8.640599, 115.254277),
                    stop("Sekar Jepun (BPR Partakencana)", -8.635380, 115.248108),
                    stop("Simpang Trengguli (Aima)", -8.635789, 115.243334),
                    stop("Simpang Noja (Anugrah Variasi)", -8.635786, 115.231703),
                    stop("Living World (Alfamart)", -8.635795, 115.231681),
                    stop("Simpang Nangka (Gajah Gotra)", -8.635604, 115.226038),
                    stop("Gatsu 1 (Maybank Finance)", -8.635869, 115.217917),
                    stop("SMP N 10 Denpasar", -8.637038, 115.213416),
                    stop("Terminal UBUNG", -8.635028, 115.206202),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/K4.swift
git commit -m "feat: add K4 corridor data"
```

---

## Task 7: K5 corridor data (3-leg loop)

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/K5.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.k5: Corridor` (3 `directions`, not 2) — consumed by Task 11

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let k5 = Corridor(
        id: "K5",
        name: "Central Parkir Kuta - Politeknik Negeri Bali - Titi Banda (via Bandara)",
        color: .yellow,
        directions: [
            RouteDirection(
                label: "Central Parkir Kuta → Politeknik Negeri Bali",
                stops: [
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                    stop("Raya Kuta 1 (BCA)", -8.717869, 115.180972),
                    stop("Raya Kuta 2 (SPBU Pertamina)", -8.720869, 115.180033),
                    stop("Camat Kuta", -8.725526, 115.178015),
                    stop("Tuban 1 (Joger)", -8.727255, 115.176906),
                    stop("Tuban 2 (The Keranjang)", -8.731794, 115.177533),
                    stop("Tuban 3 (BMKG)", -8.739213, 115.178495),
                    stop("Tuban 4 (Krisna Wisata Kuliner)", -8.741880, 115.178892),
                    stop("Kelan (Daihatsu)", -8.750241, 115.182171),
                    stop("Bypass Ngurah Rai 3 (Benoa Square)", -8.761498, 115.178943),
                    stop("Jimbaran 1 (AION Jimbaran)", -8.767520, 115.178296),
                    stop("Jimbaran 2 (Money Changer)", -8.772332, 115.177934),
                    stop("Simpang Unud (Bengkel Las)", -8.783028, 115.178788),
                    stop("RS Unud (Fore)", -8.788634, 115.177292),
                    stop("Nirmala (Bandung Collection)", -8.790070, 115.177363),
                    stop("Faperta Unud", -8.792849, 115.176999),
                    stop("FT Unud", -8.795646, 115.175658),
                    stop("Rektorat Unud (Entrance Gate)", -8.797599, 115.171859),
                    stop("FMIPA Unud", -8.799535, 115.171033),
                    stop("FEB Unud", -8.800005, 115.169765),
                    stop("Politeknik Negeri Bali (Parking Lot)", -8.798821, 115.162367),
                ]
            ),
            RouteDirection(
                label: "Politeknik Negeri Bali → Titi Banda (via Central Parkir Kuta Luar)",
                stops: [
                    stop("Politeknik Negeri Bali (Parking Lot)", -8.798821, 115.162367),
                    stop("FEB Unud", -8.799977, 115.169029),
                    stop("FMIPA Unud (FT Pertanian)", -8.798401, 115.170944),
                    stop("Rektorat Unud (M Mart)", -8.797464, 115.171750),
                    stop("FT Unud", -8.795248, 115.175713),
                    stop("Faperta Unud", -8.792888, 115.176898),
                    stop("RS Unud", -8.788667, 115.177045),
                    stop("Simpang Unud (SMA Widiatmika)", -8.782539, 115.178601),
                    stop("Jimbaran 3 (Red Dragon)", -8.771481, 115.177787),
                    stop("Jimbaran 4 (Barbershop)", -8.768029, 115.178069),
                    stop("Bypass Ngurah Rai 4 (Carwash)", -8.763665, 115.178533),
                    stop("Kelan (Pura Desa Kelan)", -8.750036, 115.182059),
                    stop("Tuban 5 (Krisna Oleh-Oleh)", -8.742390, 115.178876),
                    stop("Tuban 6 (Yonif 741 Barat)", -8.739862, 115.178524),
                    stop("Tuban 7 (Bandung Collection)", -8.731547, 115.177411),
                    stop("Raya Kuta 3 (BPD Kuta)", -8.724110, 115.176659),
                    stop("Raya Kuta 4 (Alfamart)", -8.719895, 115.180241),
                    stop("Raya Kuta 5 (Indobat)", -8.717300, 115.181009),
                    stop("Central Parkir Kuta Luar (Exit Gate)", -8.712697, 115.181087),
                    stop("Sunset Road 3 (Ripcurl)", -8.710012, 115.185064),
                    stop("Sunset Road 5", -8.712022, 115.186163),
                    stop("RS Siloam (Ma Gung Hwa)", -8.714486, 115.186367),
                    stop("Dewa Ruci (Toms Yamaha)", -8.721572, 115.185975),
                    stop("Mangrove", -8.721841, 115.189840),
                    stop("Pedungan 1.2 (Indomaret)", -8.720129, 115.196531),
                    stop("Kepaon (HM Sampoerna)", -8.718195, 115.201735),
                    stop("Praja Raksaka (Notaris)", -8.716306, 115.206727),
                    stop("SMAN 10 Denpasar", -8.715767, 115.209074),
                    stop("Simpang Benoa", -8.716811, 115.213946),
                    stop("Serangan (Lotte)", -8.714522, 115.222057),
                    stop("Kerta Pertasikan", -8.709316, 115.238734),
                    stop("RSUD Bali Mandara (Danau Poso)", -8.704219, 115.248653),
                    stop("Mertasari", -8.704196, 115.252828),
                    stop("Bet Ngandang (Alfamart)", -8.700849, 115.258637),
                    stop("SMPN 9 Denpasar (SEA Diving)", -8.689596, 115.258557),
                    stop("Pantai Sindhu 2 (Grandlucky Sanur)", -8.680493, 115.259016),
                    stop("Simpang Sanur (Nirwana)", -8.673695, 115.259134),
                    stop("Patung Titi Banda (SPBU)", -8.651663, 115.254350),
                    stop("Titi Banda", -8.647312, 115.257324),
                ]
            ),
            RouteDirection(
                label: "Titi Banda → Central Parkir Kuta",
                stops: [
                    stop("Titi Banda", -8.647312, 115.257324),
                    stop("Patung Titi Banda (Gentong)", -8.649914, 115.254900),
                    stop("Padang Galak (Mulia)", -8.658989, 115.253643),
                    stop("Pelabuhan Sanur", -8.671778, 115.258290),
                    stop("Pantai Sindhu 1", -8.681207, 115.259409),
                    stop("SMPN 9 Denpasar", -8.689553, 115.258763),
                    stop("Bet Ngadang (Gill Wilson)", -8.701221, 115.258810),
                    stop("Mertasari (Pie Susu)", -8.704375, 115.252091),
                    stop("RSUD Bali Mandara (Danau Poso)", -8.704368, 115.248555),
                    stop("Kerta Petasikan", -8.709500, 115.238750),
                    stop("Serangan (Mooij)", -8.715129, 115.221424),
                    stop("Simpang Benoa (Ananda)", -8.716869, 115.213353),
                    stop("SMAN 10 Denpasar (Alfamart)", -8.716001, 115.209367),
                    stop("Praja Raksaka (Pendawa)", -8.717033, 115.205224),
                    stop("Kepaon (Pura Prajapati Suwung)", -8.718811, 115.200565),
                    stop("Mangrove", -8.722110, 115.190967),
                    stop("Dewa Ruci (Mall Bali Galeria)", -8.721794, 115.185656),
                    stop("RS Siloam", -8.715496, 115.185675),
                    stop("Sunset Road 4 (Sosro)", -8.710325, 115.184968),
                    stop("Mertanadi 2", -8.709970, 115.183221),
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/K5.swift
git commit -m "feat: add K5 corridor data (3-leg loop)"
```

---

## Task 8: K6 corridor data

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/K6.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.k6: Corridor` — consumed by Task 11

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let k6 = Corridor(
        id: "K6",
        name: "Central Parkir Kuta - ITDC Nusa Dua",
        color: Color(red: 0.65, green: 0.85, blue: 1.0),
        directions: [
            RouteDirection(
                label: "Central Parkir Kuta → ITDC Nusa Dua",
                stops: [
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                    stop("Abian Base", -8.708164, 115.181307),
                    stop("Agung Bali", -8.706850, 115.183263),
                    stop("Sunset Road 3 (Ripcord)", -8.710012, 115.185064),
                    stop("Sunset Road 5", -8.712022, 115.186163),
                    stop("RS Siloam (Ma Gung Hwa)", -8.714486, 115.186367),
                    stop("Dewa Ruci (Toms Yamaha)", -8.721572, 115.185975),
                    stop("Dewa Ruci (Mall Bali Galeria)", -8.721794, 115.185656),
                    stop("Bypass Ngurah Rai 1 (Patasari)", -8.730487, 115.178965),
                    stop("Bypass Ngurah Rai 2 (Panasonic)", -8.738657, 115.180169),
                    stop("Perum Komplek Burung", -8.743987, 115.172745),
                    stop("Terminal Internasional", -8.741886, 115.166149),
                    stop("Terminal Domestik", -8.742077, 115.164303),
                    stop("Perum Komplek Burung (Arjuna)", -8.743816, 115.172422),
                    stop("Kelan (Daihatsu)", -8.750241, 115.182171),
                    stop("Bypass Ngurah Rai 3 (Benoa Square)", -8.761498, 115.178943),
                    stop("Jimbaran 1 (AION Jimbaran)", -8.767520, 115.178296),
                    stop("Jimbaran 2 (Money Changer)", -8.772332, 115.177934),
                    stop("Taman Griya 1 (Coco)", -8.782265, 115.180821),
                    stop("Taman Griya 2 (Pyramid)", -8.783864, 115.188458),
                    stop("Coco Mart Mumbul", -8.784895, 115.194651),
                    stop("Mumbul", -8.785814, 115.202947),
                    stop("Graha Socio (Galago)", -8.788489, 115.209167),
                    stop("Bualu (Mufidah)", -8.792554, 115.214836),
                    stop("Gardu PLN Nusa Dua", -8.797804, 115.221849),
                    stop("ITDC Selatan (Novotel)", -8.807654, 115.226650),
                    stop("ITDC Central Parking", -8.801580, 115.228485),
                ]
            ),
            RouteDirection(
                label: "ITDC Nusa Dua → Central Parkir Kuta",
                stops: [
                    stop("ITDC Central Parking", -8.801580, 115.228485),
                    stop("BNDCC", -8.795539, 115.227213),
                    stop("ITDC Utara (Grand Whiz)", -8.791700, 115.227211),
                    stop("Pratama Nusa Dua", -8.789725, 115.223739),
                    stop("Bualu", -8.792710, 115.214751),
                    stop("Graha Socio (Hotel)", -8.788538, 115.208949),
                    stop("Mumbul (SMK Nusa Dua Pariwisata)", -8.786146, 115.203317),
                    stop("Coco Mart Mumbul (Taman Mumbul)", -8.785116, 115.194333),
                    stop("Taman Griya 3", -8.784085, 115.187505),
                    stop("Taman Griya 4", -8.782305, 115.180389),
                    stop("Jimbaran 3 (Red Dragon)", -8.771481, 115.177787),
                    stop("Jimbaran 4 (Barbershop)", -8.768029, 115.178069),
                    stop("Bypass Ngurah Rai 4 (Carwash)", -8.763665, 115.178533),
                    stop("Kelan (Pura Desa Kelan)", -8.750036, 115.182059),
                    stop("Perum Komplek Burung", -8.743987, 115.172745),
                    stop("Terminal Internasional", -8.741886, 115.166149),
                    stop("Terminal Domestik", -8.742077, 115.164303),
                    stop("Perum Komplek Burung (Arjuna)", -8.743816, 115.172422),
                    stop("Bypass Ngurah Rai 5", -8.738218, 115.179899),
                    stop("Bypass Ngurah Rai 6 (Melawai)", -8.730649, 115.178701),
                    stop("Setiabudi", -8.721216, 115.182291),
                    stop("RS Siloam", -8.715496, 115.185675),
                    stop("Sunset Road 4 (Sosro)", -8.710325, 115.184968),
                    stop("Sunset Road 2 (Agung Bali)", -8.707000, 115.182999),
                    stop("Abian Base (Indomaret)", -8.708118, 115.181374),
                    stop("Central Parkir Kuta", -8.713076, 115.180797),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/K6.swift
git commit -m "feat: add K6 corridor data"
```

---

## Task 9: S1 corridor data (Trans Sarbagita)

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/S1.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.s1: Corridor` — consumed by Task 11

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let s1 = Corridor(
        id: "S1",
        name: "Gor Ngurah Rai - Garuda Wisnu Kencana (Trans Sarbagita)",
        color: Color(red: 0.0, green: 0.55, blue: 0.55),
        directions: [
            RouteDirection(
                label: "Gor Ngurah Rai → Garuda Wisnu Kencana",
                stops: [
                    stop("Gor Ngurah Rai", -8.649393, 115.223728),
                    stop("SMAN 7 Denpasar", -8.651201, 115.224534),
                    stop("Melati", -8.654547, 115.222620),
                    stop("Banjar Kayumas", -8.656579, 115.220744),
                    stop("RSAD Udayana", -8.663585, 115.218231),
                    stop("Unud Sudirman 1", -8.671669, 115.218275),
                    stop("SMK Harapan (Alfamart)", -8.682288, 115.215422),
                    stop("Ramayana Sesetan (Conato)", -8.691606, 115.217970),
                    stop("McDonald's Sesetan", -8.703532, 115.219769),
                    stop("Simpang Benoa (Ananda)", -8.716869, 115.213353),
                    stop("Praja Raksaka (Pendawa)", -8.717033, 115.205224),
                    stop("Dewa Ruci (Mall Bali Galeria)", -8.721794, 115.185656),
                    stop("Bypass Ngurah Rai 1 (Patasari)", -8.730487, 115.178965),
                    stop("Bypass Ngurah Rai 2 (Panasonic)", -8.738657, 115.180169),
                    stop("Kelan (Daihatsu)", -8.750241, 115.182171),
                    stop("Bypass Ngurah Rai 3 (Benoa Square)", -8.761498, 115.178943),
                    stop("Jimbaran 1 (AION Jimbaran)", -8.767520, 115.178296),
                    stop("Jimbaran 2 (Money Changer)", -8.772332, 115.177934),
                    stop("Simpang Unud (Bengkel Las)", -8.783028, 115.178788),
                    stop("RS Unud (Fore)", -8.788634, 115.177292),
                    stop("Nirmala (Bandung Collection)", -8.790070, 115.177363),
                    stop("Faperta Unud", -8.792849, 115.176999),
                    stop("FT Unud", -8.795646, 115.175658),
                    stop("Rektorat Unud (Entrance Gate)", -8.797599, 115.171859),
                    stop("FMIPA Unud", -8.799535, 115.171033),
                    stop("FEB Unud", -8.800005, 115.169765),
                    stop("Politeknik Negeri Bali (Parking Lot)", -8.798821, 115.162367),
                    stop("Garuda Wisnu Kencana", -8.809015, 115.164697),
                ]
            ),
            RouteDirection(
                label: "Garuda Wisnu Kencana → Gor Ngurah Rai",
                stops: [
                    stop("Garuda Wisnu Kencana", -8.809015, 115.164697),
                    stop("Puri Gading", -8.803852, 115.159548),
                    stop("Politeknik Negeri Bali Luar", -8.798560, 115.162700),
                    stop("FEB Unud", -8.799977, 115.169029),
                    stop("FMIPA Unud (FT Pertanian)", -8.798401, 115.170944),
                    stop("Rektorat Unud (M Mart)", -8.797464, 115.171750),
                    stop("FT Unud", -8.795248, 115.175713),
                    stop("Faperta Unud", -8.792888, 115.176898),
                    stop("RS Unud", -8.788667, 115.177045),
                    stop("Simpang Unud (SMA Widiatmika)", -8.782539, 115.178601),
                    stop("Jimbaran 3 (Red Dragon)", -8.771481, 115.177787),
                    stop("Jimbaran 4 (Barbershop)", -8.768029, 115.178069),
                    stop("Bypass Ngurah Rai 4 (Carwash)", -8.763665, 115.178533),
                    stop("Kelan (Pura Desa Kelan)", -8.750036, 115.182059),
                    stop("Bypass Ngurah Rai 5", -8.738218, 115.179899),
                    stop("Bypass Ngurah Rai 6 (Melawai)", -8.730649, 115.178701),
                    stop("Dewa Ruci (Toms Yamaha)", -8.721572, 115.185975),
                    stop("Pedungan 1.2 (Indomaret)", -8.720129, 115.196531),
                    stop("Praja Raksaka (Notaris)", -8.716306, 115.206727),
                    stop("Simpang Benoa", -8.716811, 115.213946),
                    stop("PLUT KUMKM", -8.702555, 115.219554),
                    stop("Ramayana Sesetan", -8.691585, 115.217845),
                    stop("SMK Harapan", -8.683605, 115.215582),
                    stop("Sanglah (Vodkas Unud)", -8.675641, 115.215305),
                    stop("Unud Sudirman 2 (Starbucks)", -8.672717, 115.217943),
                    stop("Dewi Sartika", -8.669717, 115.217061),
                    stop("Diponegoro 1 (Buccheri)", -8.665718, 115.215458),
                    stop("Surapati", -8.656218, 115.218970),
                    stop("Gor Ngurah Rai", -8.649393, 115.223728),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/S1.swift
git commit -m "feat: add S1 corridor data (Trans Sarbagita)"
```

---

## Task 10: Shuttle Sanur corridor data

**Files:**
- Create: `CH5_AM_TFBali/Constants/Corridors/ShuttleSanur.swift`

**Interfaces:**
- Consumes: `Corridor`, `RouteDirection`, `stop()` (Task 1)
- Produces: `Corridor.shuttleSanur: Corridor` — consumed by Task 11. Its `id` is `"SHUTTLE_SANUR"`, referenced literally in `RouteMapView` (Task 12) to pick the dotted line style.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI

extension Corridor {
    static let shuttleSanur = Corridor(
        id: "SHUTTLE_SANUR",
        name: "Shuttle Bus Sanur",
        color: Color(red: 0.65, green: 0.85, blue: 1.0),
        directions: [
            RouteDirection(
                label: "Parkir Mertasari → Jl. Wira (Segara Ayu)",
                stops: [
                    stop("Parkir Mertasari", -8.711290, 115.249271),
                    stop("Mercure Resort", -8.709010, 115.253955),
                    stop("Sudamala Resort", -8.707615, 115.256147),
                    stop("Bhinneka", -8.704892, 115.258348),
                    stop("SPKLU Sanur", -8.705109, 115.259996),
                    stop("Duyung Barat", -8.702546, 115.261555),
                    stop("Andaz", -8.699300, 115.262941),
                    stop("The 101 Sanur", -8.695331, 115.263659),
                    stop("Soya", -8.690005, 115.263723),
                    stop("ICON Mall Beach", -8.686875, 115.262701),
                    stop("Pasar Sindhu", -8.685310, 115.260576),
                    stop("Jl. Wira (Segara Ayu)", -8.681325, 115.260554),
                ]
            ),
            RouteDirection(
                label: "Jl. Wira (Segara Ayu) → Parkir Mertasari",
                stops: [
                    stop("Jl. Wira (Segara Ayu)", -8.681325, 115.260554),
                    stop("Pasar Sindhu", -8.685247, 115.260658),
                    stop("ICON Mall Beach", -8.686875, 115.262701),
                    stop("Soya", -8.690005, 115.263723),
                    stop("The 101 Sanur", -8.695331, 115.263659),
                    stop("Hyatt Regency Sanur", -8.701859, 115.262186),
                    stop("Massimo Gelato", -8.704843, 115.260810),
                    stop("Art Shop Cemara", -8.706405, 115.259401),
                    stop("Prama", -8.707713, 115.256803),
                    stop("Mercure Resort", -8.709010, 115.253955),
                    stop("Parkir Mertasari", -8.711290, 115.249271),
                ]
            ),
        ]
    )
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/Corridors/ShuttleSanur.swift
git commit -m "feat: add Shuttle Sanur corridor data"
```

---

## Task 11: CorridorData aggregation + data self-check

**Files:**
- Create: `CH5_AM_TFBali/Constants/CorridorData.swift`

**Interfaces:**
- Consumes: `Corridor.k1` … `Corridor.shuttleSanur` (Tasks 3–10)
- Produces: `let corridors: [Corridor]` — consumed by `RouteMapView` (Task 12)
- Produces (DEBUG only): `CorridorDataCheck.run()`

- [ ] **Step 1: Create the file**

The self-check deliberately does **not** hardcode an expected stop count per corridor (a hand-typed expected-count table is exactly the kind of thing that silently goes stale or gets mistyped). Instead it checks structural integrity — no duplicate IDs, no empty corridor, no direction with fewer than 2 stops (a polyline needs at least 2 points) — and prints each corridor's actual per-leg stop counts so a human can eyeball them against the source notes.

```swift
let corridors: [Corridor] = [
    .k1, .k2, .k3, .k4, .k5, .k6, .s1, .shuttleSanur,
]

#if DEBUG
enum CorridorDataCheck {
    static func run() {
        var seenIDs: Set<String> = []
        for corridor in corridors {
            assert(!seenIDs.contains(corridor.id), "duplicate corridor id: \(corridor.id)")
            seenIDs.insert(corridor.id)
            assert(!corridor.directions.isEmpty, "\(corridor.id) has no directions")
            for direction in corridor.directions {
                assert(direction.stops.count >= 2, "\(corridor.id) / \(direction.label) has fewer than 2 stops")
            }
            let counts = corridor.directions.map { $0.stops.count }
            print("🚌 \(corridor.id): \(counts) stops per leg — cross-check against source notes")
        }
        print("✅ CorridorDataCheck.run passed — \(corridors.count) corridors, no duplicates, no empty legs")
    }
}
#endif
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Constants/CorridorData.swift
git commit -m "feat: aggregate corridors and add data integrity self-check"
```

---

## Task 12: RouteMapView

**Files:**
- Create: `CH5_AM_TFBali/Views/RouteMapView.swift`

**Interfaces:**
- Consumes: `corridors: [Corridor]` (Task 11), `RouteGeometry.polyline(for:)` (Task 2), `Corridor`, `RouteDirection`, `BusStop` (Task 1)
- Produces: `RouteMapView: View` — consumed by `ContentView` (Task 13)

This single file holds the map plus its two small helper views (`CorridorToggleRow`, `StopDetailSheet`) — both are only ever used here and are too small (~20 lines each) to justify their own files.

- [ ] **Step 1: Create the file**

```swift
import SwiftUI
import MapKit

struct RouteMapView: View {
    @State private var visibleCorridorIDs: Set<String> = Set(corridors.map(\.id))
    @State private var polylines: [String: [CLLocationCoordinate2D]] = [:]  // keyed by direction.id.uuidString
    @State private var selectedStop: BusStop?

    private let baliRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.4095, longitude: 115.1889),
        span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
    )

    var body: some View {
        Map(initialPosition: .region(baliRegion)) {
            ForEach(corridors.filter { visibleCorridorIDs.contains($0.id) }) { corridor in
                ForEach(Array(corridor.directions.enumerated()), id: \.element.id) { legIndex, direction in
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
                                .onTapGesture { selectedStop = busStop }
                        }
                    }
                }
            }
        }
        .task { await loadAllPolylines() }
        .safeAreaInset(edge: .top) {
            CorridorToggleRow(visibleCorridorIDs: $visibleCorridorIDs)
        }
        .sheet(item: $selectedStop) { busStop in
            StopDetailSheet(stop: busStop)
        }
    }

    private func strokeStyle(for corridor: Corridor, legIndex: Int) -> StrokeStyle {
        if corridor.id == "SHUTTLE_SANUR" {
            return StrokeStyle(lineWidth: 2, dash: [1, 5])
        }
        return legIndex % 2 == 0
            ? StrokeStyle(lineWidth: 4)
            : StrokeStyle(lineWidth: 4, dash: [8, 6])
    }

    private func loadAllPolylines() async {
        for corridor in corridors {
            for direction in corridor.directions {
                let coords = await RouteGeometry.polyline(for: direction)
                polylines[direction.id.uuidString] = coords
            }
        }
    }
}

private struct CorridorToggleRow: View {
    @Binding var visibleCorridorIDs: Set<String>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(corridors) { corridor in
                    let isOn = visibleCorridorIDs.contains(corridor.id)
                    Button {
                        if isOn {
                            visibleCorridorIDs.remove(corridor.id)
                        } else {
                            visibleCorridorIDs.insert(corridor.id)
                        }
                    } label: {
                        Text(corridor.id)
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isOn ? corridor.color : Color.gray.opacity(0.25))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
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

private struct StopDetailSheet: View {
    let stop: BusStop

    var body: some View {
        VStack(spacing: 8) {
            Text(stop.name)
                .font(.title3.bold())
            Text("\(stop.coordinate.latitude), \(stop.coordinate.longitude)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .presentationDetents([.height(120)])
    }
}
```

- [ ] **Step 2: Verify it compiles** — Xcode, Cmd+B. Expected: "Build Succeeded".

- [ ] **Step 3: Commit**

```bash
git add CH5_AM_TFBali/Views/RouteMapView.swift
git commit -m "feat: add RouteMapView with corridor toggle and stop detail sheet"
```

---

## Task 13: Wire self-checks and swap in RouteMapView

**Files:**
- Modify: `CH5_AM_TFBali/CH5_AM_TFBaliApp.swift`
- Modify: `CH5_AM_TFBali/ContentView.swift`

**Interfaces:**
- Consumes: `RouteGeometry.runSelfCheck()` (Task 2), `CorridorDataCheck.run()` (Task 11), `RouteMapView` (Task 12)

- [ ] **Step 1: Run both self-checks at launch, DEBUG only**

Replace the contents of `CH5_AM_TFBali/CH5_AM_TFBaliApp.swift`:

```swift
//
//  CH5_AM_TFBaliApp.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI

@main
struct CH5_AM_TFBaliApp: App {
    init() {
        #if DEBUG
        RouteGeometry.runSelfCheck()
        CorridorDataCheck.run()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 2: Show the map**

Replace the contents of `CH5_AM_TFBali/ContentView.swift`:

```swift
//
//  ContentView.swift
//  CH5_AM_TFBali
//
//  Created by Novia Rahman Nisa on 10/08/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RouteMapView()
    }
}

#Preview {
    ContentView()
}
```

- [ ] **Step 3: Build and check the console**

In Xcode: Cmd+R (run on an iOS Simulator, e.g. iPhone 16).
Expected in the Xcode console, in this order:
```
✅ RouteGeometry.runSelfCheck passed
🚌 K1: [35, 40] stops per leg — cross-check against source notes
🚌 K2: [38, 35] stops per leg — cross-check against source notes
🚌 K3: [20, 25] stops per leg — cross-check against source notes
🚌 K4: [36, 36] stops per leg — cross-check against source notes
🚌 K5: [21, 39, 21] stops per leg — cross-check against source notes
🚌 K6: [27, 26] stops per leg — cross-check against source notes
🚌 S1: [28, 29] stops per leg — cross-check against source notes
🚌 SHUTTLE_SANUR: [12, 11] stops per leg — cross-check against source notes
✅ CorridorDataCheck.run passed — 8 corridors, no duplicates, no empty legs
```
If any `assert` fails, the app will crash at launch with the assertion message pointing at the exact problem (duplicate ID, empty direction, etc.) — fix that file and re-run.

If the printed counts for any corridor don't match what's in the source notes, that's a sign a `stop(...)` line was dropped or duplicated while typing that corridor's file — recount against the plan's Task 3–10 code blocks (which were transcribed and double-checked against the original notes).

- [ ] **Step 4: Commit**

```bash
git add CH5_AM_TFBali/CH5_AM_TFBaliApp.swift CH5_AM_TFBali/ContentView.swift
git commit -m "feat: wire self-checks and show RouteMapView on launch"
```

---

## Task 14: Manual smoke test (map behavior)

No code changes — this is where a human confirms the feature actually works, since this sandbox can't run the Simulator.

- [ ] **Step 1: Run the app** (Cmd+R) on an iOS Simulator.
Expected: map opens centered on Bali; after a few seconds (MKDirections calls resolving), colored lines appear for all 8 corridors, plus small colored dots at every stop.

- [ ] **Step 2: Check corridor colors are distinguishable**
Expected: K1 orange, K2 medium blue, K3 navy, K4 green, K5 yellow, K6 pale blue, S1 teal, Shuttle Sanur pale blue with a dotted line (visibly different from K6's solid/dashed even though same color).

- [ ] **Step 3: Toggle corridors**
Tap a corridor chip (e.g. "K1") to turn it off — its line and stops disappear. Tap again — they come back. Turn off everything except "K1" to confirm the dev-mode single-corridor isolation use case from the design discussion works via the existing toggle (no separate dev screen was built — this is the reused mechanism).

- [ ] **Step 4: Tap a stop**
Tap any colored dot. Expected: a small sheet slides up showing the stop's name and coordinates.

- [ ] **Step 5: Eyeball the road-following lines**
Zoom into each corridor and check the lines roughly follow real roads (not straight lines through buildings). Note down any segment that looks wrong (cuts through a building, loops weirdly) — per the spec's revision workflow, fix it by adding a `viaPoints` entry (or `manualOverride` for a fully broken segment) to that segment's index in the relevant corridor's data file (Task 3–10), then re-run.

- [ ] **Step 6: Record findings**
If everything looks right, no further action. If specific segments need `viaPoints`/`manualOverride` fixes, that's expected follow-up work (out of scope for this plan — the spec's revision workflow handles it) — do not block merging this plan's work on it.

---

## Self-Review Notes

- **Spec coverage:** data model ✓ (Task 1), data storage per-corridor Swift files ✓ (Tasks 3–10 + 11), route geometry with viaPoints/manualOverride/fallback ✓ (Task 2), map view with polylines/markers/toggle/tap-sheet ✓ (Task 12), error handling (straight-line fallback) ✓ (Task 2), testing substitute (assert self-checks) ✓ (Task 2, 11, wired in Task 13). All 8 corridors from the finalized spec table are covered (Tasks 3–10). Manual revision workflow verification ✓ (Task 14).
- **Placeholder scan:** no TBD/TODO; every step has complete, runnable code.
- **Type consistency:** `RouteDirection.id` used consistently as the polyline dictionary key (`direction.id.uuidString`) across Task 12; `Corridor.id` used consistently as the toggle-set key and the `"SHUTTLE_SANUR"` special case; `stop()` signature (`name, lat, lon`) identical across Tasks 3–10, matching Task 1's declaration.

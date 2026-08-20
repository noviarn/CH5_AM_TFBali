import Foundation
import MapKit

/// Bakes every corridor direction into RoutePolylines.json.
///
/// MKDirections refuses everything after a burst of roughly 50 requests and the full sweep needs
/// 461, so this is throttled and resumable: an existing file is loaded first and only missing
/// directions are fetched. See scripts/README.md.
@main
enum BakePolylines {
    static func key(_ corridorID: String, _ directionIndex: Int) -> String { "\(corridorID)|\(directionIndex)" }

    /// Corridors that are not bound by the one-way car system. Measured on the Sanur shuttle:
    /// .automobile detours ICON Mall Beach -> Pasar Sindhu by 2.23x (650m for a 290m hop) and
    /// Hyatt Regency -> Massimo Gelato by 1.52x, while .walking matches the other 19 segments
    /// to within 10m. Confirmed with Pafras 2026-08-19.
    static let walkingCorridorIDs: Set<String> = ["SHUTTLE_SANUR"]

    static func main() async {
        let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "RoutePolylines.json"

        var baked: [String: [[Double]]] = [:]
        if let data = FileManager.default.contents(atPath: outputPath),
           let existing = try? JSONDecoder().decode([String: [[Double]]].self, from: data) {
            baked = existing
            print("resume: \(baked.count) directions already baked")
        }

        var quotaExhausted = false
        for corridor in corridors {
            for (directionIndex, direction) in corridor.directions.enumerated() {
                let k = key(corridor.id, directionIndex)
                if baked[k] != nil { continue }
                if quotaExhausted { break }

                var full: [[Double]] = []
                var failed = 0

                // Routed through RouteGeometry.segments, not the raw stop list, so viaPoints and
                // manualOverride reach the bake — they are the per-segment knobs for correcting a
                // corridor whose road route comes back wrong.
                //
                // Collected as an ordered list first: appending overrides while gathering the hops
                // would put every hand-drawn segment at the head of the line instead of in place.
                enum Piece {
                    case fixed([[Double]])
                    case hop(CLLocationCoordinate2D, CLLocationCoordinate2D)
                }
                var pieces: [Piece] = []
                for segment in RouteGeometry.segments(for: direction) {
                    if let override = segment.overrideCoordinates {
                        pieces.append(.fixed(override.map { [$0.latitude, $0.longitude] }))
                        continue
                    }
                    for i in 0..<(segment.waypoints.count - 1) {
                        pieces.append(.hop(segment.waypoints[i], segment.waypoints[i + 1]))
                    }
                }
                let hopCount = pieces.filter { if case .hop = $0 { return true } else { return false } }.count

                for piece in pieces {
                    guard case let .hop(a, b) = piece else {
                        if case let .fixed(coords) = piece { full.append(contentsOf: coords) }
                        continue
                    }
                    let request = MKDirections.Request()
                    request.source = MKMapItem(location: CLLocation(latitude: a.latitude, longitude: a.longitude), address: nil)
                    request.destination = MKMapItem(location: CLLocation(latitude: b.latitude, longitude: b.longitude), address: nil)
                    request.transportType = walkingCorridorIDs.contains(corridor.id) ? .walking : .automobile

                    // Pace the calls, and give a refused one a long cooling-off retry before
                    // writing the segment off.
                    var response = try? await MKDirections(request: request).calculate()
                    if response == nil {
                        try? await Task.sleep(for: .seconds(20))
                        response = try? await MKDirections(request: request).calculate()
                    }
                    try? await Task.sleep(for: .milliseconds(1200))

                    if let route = response?.routes.first {
                        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: route.polyline.pointCount)
                        route.polyline.getCoordinates(&coords, range: NSRange(location: 0, length: route.polyline.pointCount))
                        full.append(contentsOf: coords.map { [$0.latitude, $0.longitude] })
                    } else {
                        failed += 1
                        full.append(contentsOf: [[a.latitude, a.longitude], [b.latitude, b.longitude]])
                    }
                }

                // Only keep a direction that routed cleanly — a partly-straight one must be
                // refetched next run rather than baked with gaps in it.
                if failed == 0 {
                    baked[k] = full
                    print("baked \(k): \(full.count) points")
                } else {
                    print("skipped \(k): \(failed)/\(hopCount) segments refused — quota gone, rerun later")
                    quotaExhausted = true
                }
                try? JSONEncoder().encode(baked).write(to: URL(fileURLWithPath: outputPath))
                fflush(stdout)
            }
        }

        let all = corridors.flatMap { c in c.directions.indices.map { key(c.id, $0) } }
        print("PROGRESS \(all.filter { baked[$0] != nil }.count)/\(all.count) directions")
    }
}

import Foundation
import MapKit

/// Diagnoses the segments that check-polylines flagged, by asking MKDirections three questions
/// per segment. Needs network, so run it per corridor rather than across the whole network.
///
///     /tmp/probe CH5_AM_TFBali/Resources/RoutePolylines.json K2
///
/// - car vs walk: a big gap means the corridor is not bound by the one-way car system.
/// - through: routing previous -> next, skipping the stop entirely. Far shorter than the two
///   hops through it means the stop coordinate itself is dragging the route somewhere, the way
///   K1's Buagan 2 pulled it onto an SPBU forecourt.
@main
enum ProbeSegments {
    static func main() async {
        let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "RoutePolylines.json"
        let filter = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : nil
        guard let data = FileManager.default.contents(atPath: path),
              let baked = try? JSONDecoder().decode([String: [[Double]]].self, from: data) else {
            print("cannot read \(path)"); return
        }

        for corridor in corridors where filter == nil || corridor.id == filter {
            for (di, direction) in corridor.directions.enumerated() {
                guard let raw = baked["\(corridor.id)|\(di)"] else { continue }
                let line = raw.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
                let indices = direction.stops.map { s in
                    (0..<line.count).min { line[$0].distance(to: s.coordinate) < line[$1].distance(to: s.coordinate) }!
                }
                for j in 0..<(direction.stops.count - 1) {
                    let a = direction.stops[j], b = direction.stops[j + 1]
                    let lo = min(indices[j], indices[j + 1]), hi = max(indices[j], indices[j + 1])
                    let slice = Array(line[lo...hi])
                    let road = zip(slice, slice.dropFirst()).reduce(0.0) { $0 + $1.0.distance(to: $1.1) }
                    let straight = a.coordinate.distance(to: b.coordinate)
                    guard road / max(straight, 1) > 1.6 else { continue }

                    print("\n\(corridor.id)|\(di)  \(a.name) -> \(b.name)")
                    print("  lurus \(Int(straight))m, terpasang \(Int(road))m")
                    for (label, type) in [("car ", MKDirectionsTransportType.automobile), ("walk", .walking)] {
                        if let d = await distance(a.coordinate, b.coordinate, type) {
                            print(String(format: "  %@ %.0fm x%.2f", label, d, d / max(straight, 1)))
                        } else { print("  \(label) FAIL") }
                    }
                    // Is the stop itself the problem? Route around it, previous -> next.
                    if j > 0, j + 1 < direction.stops.count {
                        let prev = direction.stops[j - 1].coordinate
                        let next = direction.stops[j + 1].coordinate
                        let viaA = await distance(prev, a.coordinate, .automobile)
                        let viaB = await distance(a.coordinate, next, .automobile)
                        if let through = await distance(prev, next, .automobile), let viaA, let viaB {
                            let detour = viaA + viaB - through
                            print(String(format: "  tembus %.0fm vs lewat halte %.0fm — halte menambah %.0fm%@",
                                         through, viaA + viaB, detour, detour > 150 ? "  <== HALTE TERSANGKA" : ""))
                        }
                    }
                }
            }
        }
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ type: MKDirectionsTransportType) async -> Double? {
        let req = MKDirections.Request()
        req.source = MKMapItem(location: CLLocation(latitude: a.latitude, longitude: a.longitude), address: nil)
        req.destination = MKMapItem(location: CLLocation(latitude: b.latitude, longitude: b.longitude), address: nil)
        req.transportType = type
        let d = (try? await MKDirections(request: req).calculate())?.routes.first?.distance
        try? await Task.sleep(for: .milliseconds(700))
        return d
    }
}

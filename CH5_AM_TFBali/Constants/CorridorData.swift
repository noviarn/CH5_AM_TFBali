import Foundation
import CoreLocation

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

                for busStop in direction.stops {
                    assert((-9.3...(-8.0)).contains(busStop.coordinate.latitude), "\(corridor.id) / \(direction.label): \(busStop.name) latitude \(busStop.coordinate.latitude) is outside Bali bounds")
                    assert((114.3...115.9).contains(busStop.coordinate.longitude), "\(corridor.id) / \(direction.label): \(busStop.name) longitude \(busStop.coordinate.longitude) is outside Bali bounds")
                }

                for i in 0..<(direction.stops.count - 1) {
                    let d = roughMeters(direction.stops[i].coordinate, direction.stops[i + 1].coordinate)
                    if d < 15 {
                        print("⚠️ \(corridor.id) / \(direction.label): \(direction.stops[i].name) and \(direction.stops[i + 1].name) are only \(Int(d))m apart — check for a coordinate typo")
                    }
                }

                let maxSegment = direction.stops.count - 2
                for key in direction.viaPoints.keys {
                    assert((0...maxSegment).contains(key), "\(corridor.id) / \(direction.label): viaPoints key \(key) out of range 0...\(maxSegment)")
                }
                for key in direction.manualOverride.keys {
                    assert((0...maxSegment).contains(key), "\(corridor.id) / \(direction.label): manualOverride key \(key) out of range 0...\(maxSegment)")
                }
            }
            let counts = corridor.directions.map { $0.stops.count }
            print("🚌 \(corridor.id): \(counts) stops per leg — cross-check against source notes")
        }
        print("✅ CorridorDataCheck.run passed — \(corridors.count) corridors, no duplicates, no empty legs")
    }

    private static func roughMeters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        let latMetersPerDegree = 111_320.0
        let lonMetersPerDegree = 111_320.0 * cos(a.latitude * .pi / 180)
        let dLat = (b.latitude - a.latitude) * latMetersPerDegree
        let dLon = (b.longitude - a.longitude) * lonMetersPerDegree
        return (dLat * dLat + dLon * dLon).squareRoot()
    }
}
#endif

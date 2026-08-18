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

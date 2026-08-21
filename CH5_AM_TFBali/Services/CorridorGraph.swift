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

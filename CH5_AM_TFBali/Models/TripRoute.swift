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

import Foundation
import CoreLocation
import SwiftUI

//struct BusStop: Identifiable {
//    let id = UUID()
//    let name: String
//    let coordinate: CLLocationCoordinate2D
//}

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

//func stop(_ name: String, _ lat: Double, _ lon: Double) -> BusStop {
//    BusStop(name: name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
//}

func stop(
    _ name: String,
    _ lat: Double,
    _ lon: Double,
    corridor: Int = 0,
    direction: BusStop.Direction = .outbound,
    serviceBearing: CLLocationDirection = 0
) -> BusStop {
    BusStop(
        name: name,
        coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
        corridor: corridor,
        direction: direction,
        serviceBearing: serviceBearing
    )
}

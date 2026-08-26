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
    /// How often a bus runs this line, in minutes. Drives the wait a rider is told to expect
    /// when boarding it (see `TripTiming.expectedWait`), which is what makes a rare line like
    /// S1 lose to a frequent one even when its route looks shorter on the map.
    ///
    /// Deliberately has no default: a new corridor must state its frequency, or every trip
    /// planned onto it would silently inherit someone else's timetable.
    let headwayMinutes: Double
    let directions: [RouteDirection]

    /// Lines whose colour is light enough that white text on it disappears — K5's orange,
    /// K6's sky blue, the Sanur shuttle's. Everything else is dark enough for white.
    private static let lightIDs: Set<String> = ["K5", "K6", "SHUTTLE_SANUR"]

    /// What to draw on top of `color`, wherever a badge or chip is filled with the line's own
    /// colour. One rule for all of them: black text on K3's navy is as unreadable as white
    /// text on K5's orange.
    var labelColor: Color { Self.lightIDs.contains(id) ? .black : .white }
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

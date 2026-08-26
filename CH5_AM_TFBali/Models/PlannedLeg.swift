import MapKit
import SwiftUI

/// One bus leg of a planned trip: board at `stops.first`, ride `direction`, get off at
/// `stops.last`. A trip with a transfer is two of these; a direct trip is one.
///
/// Sits between `RoutePlanner` (which decides *which* buses to take) and the things that
/// have to draw or narrate the result — `RouteCalculator` needs the ridden road shape,
/// `TransitPlanner` needs to know which corridor the rider is on at each stop, and
/// `TripPreviewSheet` needs both plus the corridor's colour and label.
struct PlannedLeg: Identifiable {
    let corridor: Corridor
    let direction: RouteDirection
    /// The ridden slice only — board stop through alight stop, never the whole line.
    let stops: [BusStop]
    /// `direction`'s fetched road shape. Empty until it loads, in which case the leg falls
    /// back to a straight board→alight line rather than drawing nothing.
    var polyline: [CLLocationCoordinate2D]

    var boardStop: BusStop? { stops.first }
    var alightStop: BusStop? { stops.last }

    /// Derived from the ride itself instead of a random `UUID()`. `RouteMapView.servingLegs`
    /// rebuilds these fresh on every GPS tick — a random id changed on every rebuild even
    /// though the leg was the same ride, which reset any SwiftUI state keyed off it (e.g.
    /// `TripPreviewSheet`'s expanded-stops toggle) within about a second of the user opening it.
    var id: String {
        "\(corridor.id)|\(direction.id)|\(boardStop?.id.uuidString ?? "")|\(alightStop?.id.uuidString ?? "")"
    }
}

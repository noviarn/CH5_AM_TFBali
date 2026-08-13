import MapKit

struct MapRoute: Identifiable {
    let id = UUID()
    let name: String
    let waypoints: [CLLocationCoordinate2D]
    let approachWaypoints: [CLLocationCoordinate2D]

    init(
        name: String,
        waypoints: [CLLocationCoordinate2D],
        approachWaypoints: [CLLocationCoordinate2D] = []
    ) {
        self.name = name
        self.waypoints = waypoints
        self.approachWaypoints = approachWaypoints
    }

    /// Approach leg followed by the loop, as one continuous path. Progress, maneuver
    /// positions and checkpoint ordering are all measured against this so there is a single
    /// monotonic index for the whole trip.
    var combinedWaypoints: [CLLocationCoordinate2D] {
        approachWaypoints + waypoints
    }

    var polyline: MKPolyline {
        MKPolyline(coordinates: waypoints, count: waypoints.count)
    }

    var approachPolyline: MKPolyline? {
        guard approachWaypoints.count >= 2 else { return nil }
        return MKPolyline(coordinates: approachWaypoints, count: approachWaypoints.count)
    }
}

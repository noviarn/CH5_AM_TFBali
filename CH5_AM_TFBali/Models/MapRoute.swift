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

    var polyline: MKPolyline {
        MKPolyline(coordinates: waypoints, count: waypoints.count)
    }

    var approachPolyline: MKPolyline? {
        guard approachWaypoints.count >= 2 else { return nil }
        return MKPolyline(coordinates: approachWaypoints, count: approachWaypoints.count)
    }
}

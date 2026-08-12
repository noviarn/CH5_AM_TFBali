import MapKit

struct MapRoute: Identifiable {
    let id = UUID()
    let name: String
    let waypoints: [CLLocationCoordinate2D]

    var polyline: MKPolyline {
        MKPolyline(coordinates: waypoints, count: waypoints.count)
    }
}

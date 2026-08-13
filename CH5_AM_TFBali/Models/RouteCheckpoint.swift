import MapKit

struct RouteCheckpoint: Identifiable {
    enum Kind {
        case landmark
        case busStop
    }

    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
    let kind: Kind
}

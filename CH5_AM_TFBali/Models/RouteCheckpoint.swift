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
    /// Where this checkpoint falls along the route path. Checkpoints are ordered by it, so
    /// the rider meets them in the order the road reaches them rather than the order they
    /// happen to be declared in.
    var pathIndex: Int = 0
    /// Index back into `Landmark.coordinates`, for landmark checkpoints.
    var landmarkIndex: Int?
}

import MapKit

struct LocationPin: Identifiable, Hashable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.id = UUID()
        self.name = name
        self.coordinate = coordinate
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: LocationPin, rhs: LocationPin) -> Bool {
        lhs.id == rhs.id
    }
}

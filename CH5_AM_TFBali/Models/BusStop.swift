import MapKit

struct BusStop: Identifiable, Hashable {
    enum Direction: Hashable {
        case outbound
        case inbound
    }

    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let corridor: Int
    let direction: Direction

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BusStop, rhs: BusStop) -> Bool {
        lhs.id == rhs.id
    }
}

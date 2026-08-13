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
    /// Compass bearing the bus is travelling when it serves this stop. The stop across the
    /// road is metres away but carries riders the opposite way, so proximity alone can't
    /// pick the right one — this is what makes "nearest stop" mean "nearest useful stop".
    let serviceBearing: CLLocationDirection

    /// Whether boarding here takes the rider roughly toward `bearing`. The 90° window is
    /// wide on purpose: a corridor bends, and a rider's straight-line bearing to the
    /// destination rarely matches the road exactly.
    func serves(bearing: CLLocationDirection) -> Bool {
        abs(serviceBearing.shortestTurn(to: bearing)) <= 90
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BusStop, rhs: BusStop) -> Bool {
        lhs.id == rhs.id
    }
}

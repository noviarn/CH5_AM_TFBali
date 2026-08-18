import MapKit

struct DirectionStep: Identifiable {
    let id = UUID()
    let instruction: String
    /// Length of the maneuver as MapKit reports it — a fixed property of the route, not
    /// how far the rider still has to go.
    let distance: Double
    let coordinate: CLLocationCoordinate2D
    /// Position of this maneuver along the route's combined coordinate path, so the active
    /// step can be derived from where the rider actually is rather than by counting down a
    /// radius the rider may never enter.
    var pathIndex: Int = 0

    static func formatted(_ distance: CLLocationDistance) -> String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    var formattedDistance: String {
        Self.formatted(distance)
    }

    /// Pass `remaining` to count down live; without it this falls back to the static
    /// maneuver length.
    func displayText(remaining: CLLocationDistance? = nil) -> String {
        "\(instruction) in \(Self.formatted(remaining ?? distance))"
    }

    func shifted(by offset: Int) -> DirectionStep {
        DirectionStep(
            instruction: instruction,
            distance: distance,
            coordinate: coordinate,
            pathIndex: pathIndex + offset
        )
    }
}

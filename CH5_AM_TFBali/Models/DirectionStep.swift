import MapKit

struct DirectionStep: Identifiable {
    let id = UUID()
    let instruction: String
    let distance: Double
    let coordinate: CLLocationCoordinate2D

    var formattedDistance: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }

    var displayText: String {
        "\(instruction) in \(formattedDistance)"
    }
}

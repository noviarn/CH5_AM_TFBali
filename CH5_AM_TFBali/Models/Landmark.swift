import MapKit

struct Landmark: Identifiable {
    let id = UUID()
    let name: String
    let coordinates: [CLLocationCoordinate2D]

    var center: CLLocationCoordinate2D {
        guard !coordinates.isEmpty else {
            return CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }

        let avgLat = coordinates.map { $0.latitude }.reduce(0, +) / Double(coordinates.count)
        let avgLon = coordinates.map { $0.longitude }.reduce(0, +) / Double(coordinates.count)
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }

    var polygon: MKPolygon? {
        guard coordinates.count >= 3 else { return nil }
        return MKPolygon(coordinates: coordinates, count: coordinates.count)
    }
}

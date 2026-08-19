import MapKit

enum MapConstants {
    static let baliCenter = CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)

    static let defaultLocations: [LocationPin] = [
        LocationPin(name: "Bali", coordinate: CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)),
        LocationPin(name: "Ubud", coordinate: CLLocationCoordinate2D(latitude: -8.5069, longitude: 115.2625)),
        LocationPin(name: "Kuta Beach", coordinate: CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685))
    ]
}

import MapKit

enum MapConstants {
    static let baliCenter = CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)
    static let defaultSpan = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    static let kutaCenter = CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685)

    static let defaultLocations: [LocationPin] = [
        LocationPin(name: "Bali", coordinate: CLLocationCoordinate2D(latitude: -8.6705, longitude: 115.2126)),
        LocationPin(name: "Ubud", coordinate: CLLocationCoordinate2D(latitude: -8.5069, longitude: 115.2625)),
        LocationPin(name: "Kuta Beach", coordinate: CLLocationCoordinate2D(latitude: -8.7245, longitude: 115.1685))
    ]

    static let kutaLoop = MapRoute(
        name: "Kuta Beach Road Loop",
        waypoints: [
            CLLocationCoordinate2D(latitude: -8.737353, longitude: 115.178169),
            CLLocationCoordinate2D(latitude: -8.737139, longitude: 115.167211),
            CLLocationCoordinate2D(latitude: -8.724389, longitude: 115.171382),
            CLLocationCoordinate2D(latitude: -8.722369, longitude: 115.175475),
            CLLocationCoordinate2D(latitude: -8.722261, longitude: 115.178039),
            CLLocationCoordinate2D(latitude: -8.737353, longitude: 115.178169)
        ]
    )
}
